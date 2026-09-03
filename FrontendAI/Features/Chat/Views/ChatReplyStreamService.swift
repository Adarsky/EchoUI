import Foundation

private final class StreamChunkCoalescer: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = ""
    private var lastFlushTime = CFAbsoluteTimeGetCurrent()
    private var emittedCharCount = 0
    private let minInterval: CFAbsoluteTime
    private let maxBufferedChars: Int

    init(minInterval: CFAbsoluteTime = 1.0 / 30.0, maxBufferedChars: Int = 1200) {
        self.minInterval = minInterval
        self.maxBufferedChars = maxBufferedChars
    }

    func append(_ chunk: String) -> String? {
        guard !chunk.isEmpty else { return nil }

        lock.lock()
        defer { lock.unlock() }

        buffer.append(chunk)
        let now = CFAbsoluteTimeGetCurrent()
        let bufferedTotal = emittedCharCount + buffer.count
        let shouldFlushNow =
            chunk == "<think>" ||
            chunk == "</think>" ||
            buffer.count >= effectiveMaxBufferedChars(for: bufferedTotal) ||
            (now - lastFlushTime) >= effectiveMinInterval(for: bufferedTotal)

        guard shouldFlushNow else { return nil }

        let output = buffer
        buffer.removeAll(keepingCapacity: true)
        emittedCharCount += output.count
        lastFlushTime = now
        return output
    }

    func drain() -> String? {
        lock.lock()
        defer { lock.unlock() }

        guard !buffer.isEmpty else { return nil }
        let output = buffer
        buffer.removeAll(keepingCapacity: true)
        emittedCharCount += output.count
        lastFlushTime = CFAbsoluteTimeGetCurrent()
        return output
    }

    private func effectiveMinInterval(for totalChars: Int) -> CFAbsoluteTime {
        let adaptiveInterval: CFAbsoluteTime
        switch totalChars {
        case ..<8_000:
            adaptiveInterval = minInterval
        case ..<16_000:
            adaptiveInterval = 0.08
        case ..<32_000:
            adaptiveInterval = 0.12
        default:
            adaptiveInterval = 0.20
        }

        return max(minInterval, adaptiveInterval)
    }

    private func effectiveMaxBufferedChars(for totalChars: Int) -> Int {
        switch totalChars {
        case ..<8_000:
            return maxBufferedChars
        case ..<16_000:
            return max(maxBufferedChars, 1_800)
        case ..<32_000:
            return max(maxBufferedChars, 3_000)
        default:
            return max(maxBufferedChars, 5_000)
        }
    }
}

enum ChatReplyStreamEvent: Sendable {
    case chunk(String)
    case failed(ChatReplyFailure)
    case finished
}

struct ChatReplyEventStream {
    let stream: AsyncStream<ChatReplyStreamEvent>
    let cancel: @Sendable () -> Void
}

private final class CancellableStreamTaskBox: @unchecked Sendable {
    private let lock = NSLock()
    private var task: Task<Void, Never>?

    func set(_ task: Task<Void, Never>) {
        lock.lock()
        self.task = task
        lock.unlock()
    }

    func cancel() {
        lock.lock()
        let task = task
        lock.unlock()
        task?.cancel()
    }
}

enum ChatReplyStreamService {
    static func makeEventStream(
        payload: [ChatPayloadMessage],
        config: ServerConfig,
        chunkFlushIntervalMs: Double
    ) -> ChatReplyEventStream {
        let coalescer = StreamChunkCoalescer(
            minInterval: chunkFlushIntervalMs / 1000.0,
            maxBufferedChars: ChatStreamingDefaults.chunkMaxChars
        )
        let taskBox = CancellableStreamTaskBox()

        let stream = AsyncStream<ChatReplyStreamEvent> { continuation in
            let requestTask = Task {
                do {
                    try Task.checkCancellation()
                    _ = try await APIService.sendMessage(
                        messages: payload,
                        config: config,
                        onStream: { chunk in
                            if let batchedChunk = coalescer.append(chunk) {
                                continuation.yield(.chunk(batchedChunk))
                            }
                        }
                    )

                    if !Task.isCancelled, let remainingChunk = coalescer.drain() {
                        continuation.yield(.chunk(remainingChunk))
                    }
                } catch {
                    if !Task.isCancelled, let remainingChunk = coalescer.drain() {
                        continuation.yield(.chunk(remainingChunk))
                    }
                    if !isCancellationError(error) {
                        continuation.yield(.failed(userFacingFailure(from: error)))
                    }
                }

                if !Task.isCancelled {
                    continuation.yield(.finished)
                }
                continuation.finish()
            }

            taskBox.set(requestTask)
            continuation.onTermination = { @Sendable _ in
                taskBox.cancel()
            }
        }

        return ChatReplyEventStream(
            stream: stream,
            cancel: { taskBox.cancel() }
        )
    }

    private static func isCancellationError(_ error: Error) -> Bool {
        if error is CancellationError { return true }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return true
        }

        let normalized = nsError.localizedDescription.lowercased()
        return normalized == "canceled"
            || normalized == "cancelled"
            || normalized.contains("canceled")
            || normalized.contains("cancelled")
    }

    static func userFacingFailure(from error: Error) -> ChatReplyFailure {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                return ChatReplyFailure(
                    kind: .offline,
                    message: "Reconnect to the internet, then try sending your message again."
                )
            case NSURLErrorTimedOut:
                return ChatReplyFailure(
                    kind: .timedOut,
                    message: "The server didn’t respond in time. Try again in a moment."
                )
            case NSURLErrorNetworkConnectionLost:
                return ChatReplyFailure(
                    kind: .connectionInterrupted,
                    message: "The connection dropped while the reply was being generated."
                )
            case NSURLErrorCannotFindHost,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorDNSLookupFailed,
                 NSURLErrorCannotLoadFromNetwork,
                 NSURLErrorResourceUnavailable:
                return ChatReplyFailure(
                    kind: .serverUnavailable,
                    message: "Check the server address and your connection, then try again."
                )
            case NSURLErrorSecureConnectionFailed,
                 NSURLErrorServerCertificateHasBadDate,
                 NSURLErrorServerCertificateUntrusted,
                 NSURLErrorServerCertificateHasUnknownRoot,
                 NSURLErrorServerCertificateNotYetValid,
                 NSURLErrorClientCertificateRejected,
                 NSURLErrorClientCertificateRequired:
                return ChatReplyFailure(
                    kind: .configuration,
                    message: "A secure connection couldn’t be established. Review the server’s TLS settings."
                )
            default:
                break
            }
        }

        return ChatReplyFailure.classified(
            message: sanitizedErrorMessage(error.localizedDescription)
        )
    }

    private static func sanitizedErrorMessage(_ message: String) -> String {
        let normalized = message
            .replacing("\n", with: " ")
            .replacing("\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else {
            return "Something interrupted the request. Please try again."
        }

        let blockedTokens = [
            "<script",
            "file://",
            "/users/",
            "/var/",
            "authorization:",
            "bearer "
        ]
        let lowercased = normalized.lowercased()
        if blockedTokens.contains(where: { lowercased.contains($0) }) {
            return "Review your server settings, then try again."
        }

        let maxLength = 180
        if normalized.count > maxLength {
            return String(normalized.prefix(maxLength)) + "…"
        }
        return normalized
    }
}
