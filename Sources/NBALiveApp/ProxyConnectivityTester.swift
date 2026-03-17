import Foundation

protocol ProxyConnectivityTesting: Sendable {
    func testConnection(using proxySettings: ProxySettings) async throws -> String
}

struct NetworkProxyConnectivityTester: ProxyConnectivityTesting {
    private let timeoutInterval: TimeInterval = 8

    func testConnection(using proxySettings: ProxySettings) async throws -> String {
        guard !proxySettings.isEnabled || proxySettings.isValid else {
            throw ProxyConnectivityError.invalidConfiguration(proxySettings.validationMessage ?? "代理配置无效。")
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeoutInterval
        configuration.timeoutIntervalForResource = timeoutInterval
        configuration.connectionProxyDictionary = proxySettings.connectionProxyDictionary

        let session = URLSession(configuration: configuration)
        let requestDate = NBALeagueCalendar.leagueDateString(for: .now)
        let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard?dates=\(requestDate)")!
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: timeoutInterval)

        let startedAt = Date()
        do {
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ProxyConnectivityError.invalidResponse
            }
            guard (200 ... 299).contains(httpResponse.statusCode) else {
                throw ProxyConnectivityError.http(httpResponse.statusCode)
            }

            let elapsed = Date().timeIntervalSince(startedAt)
            let latencyText = "\(Int(elapsed * 1000))ms"
            return proxySettings.isEnabled
                ? "代理连通正常，ESPN 请求成功（\(latencyText)）。"
                : "直连可用，ESPN 请求成功（\(latencyText)）。"
        } catch let error as ProxyConnectivityError {
            throw error
        } catch {
            throw ProxyConnectivityError.transport(error.localizedDescription)
        }
    }
}

enum ProxyConnectivityError: LocalizedError {
    case invalidConfiguration(String)
    case invalidResponse
    case http(Int)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case let .invalidConfiguration(message):
            message
        case .invalidResponse:
            "代理测试失败：响应无效。"
        case let .http(code):
            "代理测试失败：远端返回 HTTP \(code)。"
        case let .transport(message):
            "代理测试失败：\(message)"
        }
    }
}
