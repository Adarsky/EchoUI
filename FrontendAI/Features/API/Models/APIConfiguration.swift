import Foundation
import Security
import SwiftData

enum APIType: String, Codable, CaseIterable {
    case openai
    case openrouter
}

enum APIConnectionStatus: String, Codable, CaseIterable {
    case online
    case warning
    case offline

    var displayName: String {
        switch self {
        case .online:
            return "Online"
        case .warning:
            return "Warning"
        case .offline:
            return "Offline"
        }
    }
}

enum APIConnectionStatusMapper {
    static func status(forHTTPStatusCode statusCode: Int) -> APIConnectionStatus {
        (200..<300).contains(statusCode) ? .online : .warning
    }
}

extension APIType {
    var displayName: String {
        switch self {
        case .openai:
            return "OpenAI"
        case .openrouter:
            return "OpenRouter"
        }
    }

    func normalizedBaseURL(_ rawValue: String) -> String {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        while value.hasSuffix("/") {
            value.removeLast()
        }

        let lowercased = value.lowercased()
        switch self {
        case .openai:
            if lowercased.hasSuffix("/v1") {
                value = String(value.dropLast("/v1".count))
            }
            value = enforcingHTTPSForOfficialEndpoint(baseURL: value)
        case .openrouter:
            if lowercased.hasSuffix("/api/v1") {
                value = String(value.dropLast("/api/v1".count))
            } else if lowercased.hasSuffix("/v1") {
                value = String(value.dropLast("/v1".count))
            }
            value = enforcingHTTPSForOfficialEndpoint(baseURL: value)
        }

        while value.hasSuffix("/") {
            value.removeLast()
        }

        return value
    }

    func endpoint(baseURL: String, path: String) -> String {
        let root = normalizedBaseURL(baseURL)
        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path

        switch self {
        case .openai:
            return "\(root)/v1/\(normalizedPath)"
        case .openrouter:
            return "\(root)/api/v1/\(normalizedPath)"
        }
    }

    func requiresHTTPAPIKeyConfirmation(baseURL: String, apiKey: String) -> Bool {
        let normalizedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKey.isEmpty else { return false }
        return usesInsecureHTTPTransport(baseURL: baseURL)
    }

    func usesInsecureHTTPTransport(baseURL: String) -> Bool {
        let normalized = normalizedBaseURL(baseURL)
        guard let components = urlComponents(from: normalized) else { return false }
        return components.scheme?.lowercased() == "http"
    }

    func requiresHTTPSForOfficialEndpoint(baseURL: String) -> Bool {
        let normalized = normalizedBaseURL(baseURL)
        guard let components = urlComponents(from: normalized) else { return false }

        switch self {
        case .openai:
            return isOfficialOpenAIHost(components.host)
        case .openrouter:
            return isOfficialOpenRouterHost(components.host)
        }
    }

    func requiresHTTPSForOfficialOpenRouter(baseURL: String) -> Bool {
        guard self == .openrouter else { return false }
        return requiresHTTPSForOfficialEndpoint(baseURL: baseURL)
    }

    func isSecureTransportURL(_ url: URL, baseURL: String) -> Bool {
        guard requiresHTTPSForOfficialEndpoint(baseURL: baseURL) else { return true }
        return url.scheme?.lowercased() == "https"
    }

    private func enforcingHTTPSForOfficialEndpoint(baseURL rawValue: String) -> String {
        guard var components = urlComponents(from: rawValue) else { return rawValue }

        let isOfficialHost: Bool
        switch self {
        case .openai:
            isOfficialHost = isOfficialOpenAIHost(components.host)
        case .openrouter:
            isOfficialHost = isOfficialOpenRouterHost(components.host)
        }
        guard isOfficialHost else { return rawValue }

        components.scheme = "https"
        components.user = nil
        components.password = nil
        if components.port == 80 {
            components.port = nil
        }

        return components.string ?? rawValue
    }

    private func urlComponents(from rawValue: String) -> URLComponents? {
        if let components = URLComponents(string: rawValue), components.host != nil {
            return components
        }

        let candidate: String
        if rawValue.hasPrefix("//") {
            candidate = "https:\(rawValue)"
        } else {
            candidate = "https://\(rawValue)"
        }

        if let components = URLComponents(string: candidate), components.host != nil {
            return components
        }

        return nil
    }

    private func isOfficialOpenAIHost(_ host: String?) -> Bool {
        guard let host else { return false }
        return host.lowercased() == "api.openai.com"
    }

    private func isOfficialOpenRouterHost(_ host: String?) -> Bool {
        guard let host else { return false }
        let normalizedHost = host.lowercased()
        return normalizedHost == "openrouter.ai" || normalizedHost.hasSuffix(".openrouter.ai")
    }
}

struct TLSPolicy: Sendable {
    let allowInsecureTLS: Bool
    let customCACertificateData: Data?

    static let strict = TLSPolicy(allowInsecureTLS: false, customCACertificateData: nil)
}

enum APIAuthorization {
    static func bearerHeaderValue(apiKey: String?, for url: URL) -> String? {
        guard url.scheme?.lowercased() == "https" else {
            return nil
        }

        let normalizedKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !normalizedKey.isEmpty else {
            return nil
        }

        return "Bearer \(normalizedKey)"
    }

    static func canSendBearerToken(to url: URL) -> Bool {
        url.scheme?.lowercased() == "https"
    }
}

private enum APIKeychainStore {
    private static let service = (Bundle.main.bundleIdentifier ?? "com.frontendai.app") + ".api-keys"

    private static func baseQuery(for uuid: UUID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: uuid.uuidString
        ]
    }

    static func loadAPIKey(for uuid: UUID) -> String? {
        var query = baseQuery(for: uuid)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard
            status == errSecSuccess,
            let data = item as? Data,
            let key = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        let normalized = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    static func saveAPIKey(_ rawKey: String, for uuid: UUID) {
        let normalized = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            deleteAPIKey(for: uuid)
            return
        }

        let data = Data(normalized.utf8)
        let query = baseQuery(for: uuid)
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        if updateStatus != errSecItemNotFound {
            _ = SecItemDelete(query as CFDictionary)
        }

        var insertItem = query
        insertItem[kSecValueData as String] = data
        insertItem[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        _ = SecItemAdd(insertItem as CFDictionary, nil)
    }

    static func deleteAPIKey(for uuid: UUID) {
        _ = SecItemDelete(baseQuery(for: uuid) as CFDictionary)
    }
}

extension APIServer {
    var tlsPolicy: TLSPolicy {
        TLSPolicy(
            allowInsecureTLS: allowInsecureTLS,
            customCACertificateData: customCACertificateData
        )
    }
}

enum TLSSessionFactory {
    static func makeSession(policy: TLSPolicy) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        return URLSession(
            configuration: configuration,
            delegate: TLSSessionDelegate(policy: policy),
            delegateQueue: nil
        )
    }
}

enum APIRedirectPolicy {
    static func redirectedRequest(
        from currentRequest: URLRequest?,
        to proposedRequest: URLRequest
    ) -> URLRequest? {
        guard
            let sourceURL = currentRequest?.url,
            let destinationURL = proposedRequest.url,
            isHTTPFamilyURL(sourceURL),
            isHTTPFamilyURL(destinationURL)
        else {
            return nil
        }

        guard !isHTTPSDowngrade(from: sourceURL, to: destinationURL) else {
            return nil
        }

        guard sameHost(sourceURL, destinationURL) else {
            return nil
        }

        let carriesAuthorization = hasAuthorizationHeader(currentRequest)
            || hasAuthorizationHeader(proposedRequest)

        if carriesAuthorization {
            return sameOrigin(sourceURL, destinationURL) ? proposedRequest : nil
        }

        if sameOrigin(sourceURL, destinationURL) {
            return proposedRequest
        }

        return isHTTPToHTTPSUpgradeOnSameHost(sourceURL, destinationURL) ? proposedRequest : nil
    }

    private static func hasAuthorizationHeader(_ request: URLRequest?) -> Bool {
        guard let value = request?.value(forHTTPHeaderField: "Authorization") else {
            return false
        }
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func isHTTPFamilyURL(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased()
        return scheme == "http" || scheme == "https"
    }

    private static func isHTTPSDowngrade(from sourceURL: URL, to destinationURL: URL) -> Bool {
        sourceURL.scheme?.lowercased() == "https"
            && destinationURL.scheme?.lowercased() != "https"
    }

    private static func sameOrigin(_ lhs: URL, _ rhs: URL) -> Bool {
        sameHost(lhs, rhs)
            && lhs.scheme?.lowercased() == rhs.scheme?.lowercased()
            && normalizedPort(lhs) == normalizedPort(rhs)
    }

    private static func sameHost(_ lhs: URL, _ rhs: URL) -> Bool {
        guard
            let lhsHost = lhs.host?.lowercased(),
            let rhsHost = rhs.host?.lowercased(),
            !lhsHost.isEmpty,
            !rhsHost.isEmpty
        else {
            return false
        }

        return lhsHost == rhsHost
    }

    private static func isHTTPToHTTPSUpgradeOnSameHost(_ sourceURL: URL, _ destinationURL: URL) -> Bool {
        sourceURL.scheme?.lowercased() == "http"
            && destinationURL.scheme?.lowercased() == "https"
            && sameHost(sourceURL, destinationURL)
    }

    private static func normalizedPort(_ url: URL) -> Int? {
        if let port = url.port {
            return port
        }

        switch url.scheme?.lowercased() {
        case "http":
            return 80
        case "https":
            return 443
        default:
            return nil
        }
    }
}

enum TLSCertificateDecoder {
    static func decodeCertificates(from rawData: Data) -> [SecCertificate] {
        if let certificate = SecCertificateCreateWithData(nil, rawData as CFData) {
            return [certificate]
        }

        guard let pem = String(data: rawData, encoding: .utf8) else {
            return []
        }

        return decodePEMCertificates(from: pem)
    }

    private static func decodePEMCertificates(from pem: String) -> [SecCertificate] {
        let beginMarker = "-----BEGIN CERTIFICATE-----"
        let endMarker = "-----END CERTIFICATE-----"

        var certificates: [SecCertificate] = []
        var isCollecting = false
        var base64Buffer = ""

        for rawLine in pem.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

            if line == beginMarker {
                isCollecting = true
                base64Buffer = ""
                continue
            }

            if line == endMarker {
                if
                    let certData = Data(base64Encoded: base64Buffer),
                    let cert = SecCertificateCreateWithData(nil, certData as CFData)
                {
                    certificates.append(cert)
                }
                isCollecting = false
                base64Buffer = ""
                continue
            }

            if isCollecting {
                base64Buffer.append(line)
            }
        }

        return certificates
    }
}

private final class TLSSessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    private let policy: TLSPolicy
    private let customAnchorCertificates: [SecCertificate]

    init(policy: TLSPolicy) {
        self.policy = policy
        if let customCACertificateData = policy.customCACertificateData {
            let certificates = TLSCertificateDecoder.decodeCertificates(from: customCACertificateData)
            self.customAnchorCertificates = certificates
        } else {
            self.customAnchorCertificates = []
        }
        super.init()
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        handle(challenge: challenge, completionHandler: completionHandler)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(
            APIRedirectPolicy.redirectedRequest(
                from: task.currentRequest ?? task.originalRequest,
                to: request
            )
        )
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        handle(challenge: challenge, completionHandler: completionHandler)
    }

    private func handle(
        challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard
            challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            let trust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        if !policy.allowInsecureTLS {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        guard !customAnchorCertificates.isEmpty else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        if evaluateTrustWithCustomAnchors(trust, host: challenge.protectionSpace.host) {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    private func evaluateTrustWithCustomAnchors(_ trust: SecTrust, host: String) -> Bool {
        // Ensure hostname-aware HTTPS validation is enforced for this endpoint.
        let sslPolicy = SecPolicyCreateSSL(true, host as CFString)
        SecTrustSetPolicies(trust, sslPolicy)

        SecTrustSetAnchorCertificates(trust, customAnchorCertificates as CFArray)
        SecTrustSetAnchorCertificatesOnly(trust, true)

        var trustError: CFError?
        return SecTrustEvaluateWithError(trust, &trustError)
    }
}

@Model
final class APIServer {
    @Attribute(.unique) var uuid: UUID
    var name: String
    var baseURL: String
    var selectedModel: String
    var availableModels: [String]
    var type: APIType
    var isOnline: Bool
    @Attribute(originalName: "connectionStatus") private var persistedConnectionStatus: APIConnectionStatus? = nil
    @Attribute(originalName: "apiKey") private var legacyAPIKeyStorage: String?
    var allowInsecureTLS: Bool = false
    var customCACertificateData: Data? = nil
    var customCACertificateName: String? = nil
    
    init(
        uuid: UUID = UUID(),
        name: String,
        baseURL: String,
        selectedModel: String,
        availableModels: [String] = [],
        type: APIType,
        isOnline: Bool = false,
        connectionStatus: APIConnectionStatus? = nil,
        apiKey: String? = nil,
        allowInsecureTLS: Bool = false,
        customCACertificateData: Data? = nil,
        customCACertificateName: String? = nil
    ) {
        self.uuid = uuid
        self.name = name
        self.baseURL = baseURL
        self.selectedModel = selectedModel
        self.availableModels = availableModels
        self.type = type
        let resolvedStatus = connectionStatus ?? (isOnline ? .online : .offline)
        self.persistedConnectionStatus = resolvedStatus
        self.isOnline = resolvedStatus == .online
        self.legacyAPIKeyStorage = nil
        self.apiKey = apiKey
        self.allowInsecureTLS = allowInsecureTLS
        self.customCACertificateData = customCACertificateData
        self.customCACertificateName = customCACertificateName
    }
}

extension APIServer {
    var connectionStatus: APIConnectionStatus {
        get {
            persistedConnectionStatus ?? (isOnline ? .online : .offline)
        }
        set {
            persistedConnectionStatus = newValue
            isOnline = newValue == .online
        }
    }

    var apiKey: String? {
        get {
            return APIKeychainStore.loadAPIKey(for: uuid)
        }
        set {
            if let newValue {
                APIKeychainStore.saveAPIKey(newValue, for: uuid)
            } else {
                APIKeychainStore.deleteAPIKey(for: uuid)
            }
            legacyAPIKeyStorage = nil
        }
    }

    @discardableResult
    func migrateAPIKeyToKeychainIfNeeded() -> Bool {
        guard let legacy = legacyAPIKeyStorage else { return false }
        let normalized = legacy.trimmingCharacters(in: .whitespacesAndNewlines)

        if !normalized.isEmpty, APIKeychainStore.loadAPIKey(for: uuid) == nil {
            APIKeychainStore.saveAPIKey(normalized, for: uuid)
        }

        legacyAPIKeyStorage = nil
        return true
    }

    func deleteAPIKeyFromKeychain() {
        APIKeychainStore.deleteAPIKey(for: uuid)
        legacyAPIKeyStorage = nil
    }

    func updateConnectionStatus(_ status: APIConnectionStatus) {
        connectionStatus = status
        isOnline = status == .online
    }
}
