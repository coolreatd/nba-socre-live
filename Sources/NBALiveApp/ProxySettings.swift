import Foundation

enum ProxyType: String, CaseIterable, Codable, Identifiable, Sendable {
    case http
    case socks5

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .http:
            "HTTP(S)"
        case .socks5:
            "SOCKS5"
        }
    }
}

struct ProxySettings: Equatable, Sendable {
    var isEnabled: Bool
    var type: ProxyType
    var host: String
    var portText: String

    init(
        isEnabled: Bool = false,
        type: ProxyType = .http,
        host: String = "",
        portText: String = ""
    ) {
        self.isEnabled = isEnabled
        self.type = type
        self.host = host
        self.portText = portText
    }

    var trimmedHost: String {
        host.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var port: Int? {
        guard let port = Int(portText), (1 ... 65535).contains(port) else {
            return nil
        }
        return port
    }

    var validationMessage: String? {
        guard isEnabled else { return nil }
        if trimmedHost.isEmpty {
            return "请填写代理主机地址。"
        }
        if port == nil {
            return "请填写 1 到 65535 之间的端口。"
        }
        return nil
    }

    var isValid: Bool {
        validationMessage == nil
    }

    var summaryText: String {
        guard isEnabled else {
            return "未启用代理"
        }
        guard let port else {
            return "代理配置未完成"
        }
        return "\(type.displayName)  \(trimmedHost):\(port)"
    }

    var connectionProxyDictionary: [AnyHashable: Any]? {
        guard isEnabled, let port else {
            return nil
        }

        switch type {
        case .http:
            return [
                kCFNetworkProxiesHTTPEnable as String: 1,
                kCFNetworkProxiesHTTPProxy as String: trimmedHost,
                kCFNetworkProxiesHTTPPort as String: port,
                kCFNetworkProxiesHTTPSEnable as String: 1,
                kCFNetworkProxiesHTTPSProxy as String: trimmedHost,
                kCFNetworkProxiesHTTPSPort as String: port
            ]
        case .socks5:
            return [
                kCFNetworkProxiesSOCKSEnable as String: 1,
                kCFNetworkProxiesSOCKSProxy as String: trimmedHost,
                kCFNetworkProxiesSOCKSPort as String: port
            ]
        }
    }
}
