import Foundation

enum OpenRouterAttributionStorageKeys {
    static let httpReferer = "openRouterHTTPReferer"
    static let xTitle = "openRouterXTitle"
    static let userAgent = "openRouterUserAgent"
}

struct OpenRouterAttributionPreset: Identifiable, Equatable {
    let id: String
    let displayName: String
    let httpReferer: String
    let xTitle: String
    let userAgent: String
}

enum OpenRouterAttributionHeaders {
    static let defaultReferer = "https://echo-ui.app"
    static let defaultTitle = "Echo UI"
    static let defaultUserAgent = "EchoUI/1.0"

    static let presets: [OpenRouterAttributionPreset] = [
        OpenRouterAttributionPreset(
            id: "echo-ui",
            displayName: "Echo UI",
            httpReferer: defaultReferer,
            xTitle: defaultTitle,
            userAgent: defaultUserAgent
        ),
        OpenRouterAttributionPreset(
            id: "openclaw",
            displayName: "OpenClaw",
            httpReferer: "https://openclaw.ai",
            xTitle: "OpenClaw",
            userAgent: "OpenClaw/1.0"
        ),
        OpenRouterAttributionPreset(
            id: "janitor-ai",
            displayName: "Janitor AI",
            httpReferer: "https://janitorai.com",
            xTitle: "Janitor AI",
            userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 26_4_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1"
        )
    ]

    static func current(defaults: UserDefaults = .standard) -> (httpReferer: String, xTitle: String, userAgent: String) {
        let httpReferer = normalizedHeaderValue(
            defaults.string(forKey: OpenRouterAttributionStorageKeys.httpReferer),
            fallback: defaultReferer
        )
        let xTitle = normalizedHeaderValue(
            defaults.string(forKey: OpenRouterAttributionStorageKeys.xTitle),
            fallback: defaultTitle
        )
        let userAgent = normalizedHeaderValue(
            defaults.string(forKey: OpenRouterAttributionStorageKeys.userAgent),
            fallback: defaultUserAgent
        )

        return (httpReferer, xTitle, userAgent)
    }

    static func matchingPreset(
        httpReferer: String,
        xTitle: String,
        userAgent: String
    ) -> OpenRouterAttributionPreset? {
        presets.first {
            $0.httpReferer == normalizedHeaderValue(httpReferer, fallback: defaultReferer)
                && $0.xTitle == normalizedHeaderValue(xTitle, fallback: defaultTitle)
                && $0.userAgent == normalizedHeaderValue(userAgent, fallback: defaultUserAgent)
        }
    }

    static func apply(to request: inout URLRequest, defaults: UserDefaults = .standard) {
        let headers = current(defaults: defaults)
        request.setValue(headers.httpReferer, forHTTPHeaderField: "HTTP-Referer")
        request.setValue(headers.xTitle, forHTTPHeaderField: "X-Title")
        request.setValue(headers.userAgent, forHTTPHeaderField: "User-Agent")
    }

    private static func normalizedHeaderValue(_ rawValue: String?, fallback: String) -> String {
        guard let rawValue else { return fallback }

        let normalized = rawValue
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return normalized.isEmpty ? fallback : normalized
    }
}

extension URLRequest {
    mutating func applyOpenRouterAttributionHeaders(defaults: UserDefaults = .standard) {
        OpenRouterAttributionHeaders.apply(to: &self, defaults: defaults)
    }
}
