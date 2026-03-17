import XCTest
@testable import NBALiveApp

@MainActor
final class AppStoreTests: XCTestCase {
    func testFavoritesFilterKeepsOnlyFavoriteMatchups() async {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let store = AppStore(provider: StaticProvider(), defaults: defaults)
        await store.refreshNow()

        store.toggleFavorite(for: "lal")
        store.setFavoritesOnly(true)

        XCTAssertEqual(store.filteredGames.count, 1)
        XCTAssertEqual(store.filteredGames.first?.id, "gsw-lal")
    }

    func testLiveGameAppearsInMenuBarTitle() async {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let store = AppStore(provider: StaticProvider(), defaults: defaults)
        await store.refreshNow()

        XCTAssertTrue(store.menuBarTitle.contains("GSW"))
        XCTAssertTrue(store.menuBarTitle.contains("LAL"))
    }

    func testAvailableDatesIncludePastAndFutureRange() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let store = AppStore(provider: StaticProvider(), defaults: defaults)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let expectedEarliest = calendar.date(byAdding: .day, value: -29, to: today)
        let expectedLatest = calendar.date(byAdding: .day, value: 14, to: today)

        XCTAssertEqual(store.availableDates.count, 44)
        XCTAssertEqual(store.availableDates.first, expectedEarliest)
        XCTAssertEqual(store.availableDates.last, expectedLatest)
    }

    func testCanStepForwardIntoFutureDates() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let store = AppStore(provider: StaticProvider(), defaults: defaults)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let expectedTomorrow = calendar.date(byAdding: .day, value: 1, to: today)

        XCTAssertTrue(store.canStepForwardDate)

        store.stepDate(by: 1)

        XCTAssertEqual(store.selectedDate, expectedTomorrow)
    }

    func testESPNStartDateParsingPreservesScheduledTime() {
        let parsed = NBALeagueCalendar.parseStartDate(from: "2026-03-20T02:00Z")
        let calendar = Calendar(identifier: .gregorian)
        let utc = TimeZone(secondsFromGMT: 0)!
        let components = calendar.dateComponents(in: utc, from: parsed)

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 20)
        XCTAssertEqual(components.hour, 2)
        XCTAssertEqual(components.minute, 0)
    }

    func testHTTPProxySettingsBuildConnectionDictionary() {
        let settings = ProxySettings(isEnabled: true, type: .http, host: "127.0.0.1", portText: "7890")
        let dictionary = settings.connectionProxyDictionary

        XCTAssertEqual(dictionary?[kCFNetworkProxiesHTTPEnable as String] as? Int, 1)
        XCTAssertEqual(dictionary?[kCFNetworkProxiesHTTPProxy as String] as? String, "127.0.0.1")
        XCTAssertEqual(dictionary?[kCFNetworkProxiesHTTPPort as String] as? Int, 7890)
        XCTAssertEqual(dictionary?[kCFNetworkProxiesHTTPSEnable as String] as? Int, 1)
        XCTAssertEqual(dictionary?[kCFNetworkProxiesHTTPSProxy as String] as? String, "127.0.0.1")
        XCTAssertEqual(dictionary?[kCFNetworkProxiesHTTPSPort as String] as? Int, 7890)
    }

    func testApplyProxySettingsPersistsValues() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let store = AppStore(provider: StaticProvider(), defaults: defaults)

        store.setProxyEnabled(true)
        store.setProxyType(.socks5)
        store.setProxyHost("localhost")
        store.setProxyPortText("1080")
        store.applyProxySettings()

        XCTAssertTrue(defaults.bool(forKey: StorageKey.proxyEnabled))
        XCTAssertEqual(defaults.string(forKey: StorageKey.proxyType), ProxyType.socks5.rawValue)
        XCTAssertEqual(defaults.string(forKey: StorageKey.proxyHost), "localhost")
        XCTAssertEqual(defaults.string(forKey: StorageKey.proxyPort), "1080")
    }

    func testProxyConnectivityUsesInjectedTester() async {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let tester = StubProxyConnectivityTester(result: .success("代理连通正常，ESPN 请求成功（120ms）。"))
        let store = AppStore(proxyConnectivityTester: tester, defaults: defaults)

        store.setProxyEnabled(true)
        store.setProxyType(.http)
        store.setProxyHost("127.0.0.1")
        store.setProxyPortText("7890")

        await store.testProxyConnectivity()

        XCTAssertEqual(store.proxyConnectivityMessage, "代理连通正常，ESPN 请求成功（120ms）。")
        XCTAssertFalse(store.isTestingProxyConnectivity)
    }

    func testProxyConnectivityStopsOnInvalidSettings() async {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let tester = StubProxyConnectivityTester(result: .success("should not be used"))
        let store = AppStore(proxyConnectivityTester: tester, defaults: defaults)

        store.setProxyEnabled(true)
        store.setProxyHost("")
        store.setProxyPortText("abc")

        await store.testProxyConnectivity()

        XCTAssertEqual(store.proxyConnectivityMessage, "请填写代理主机地址。")
        XCTAssertFalse(store.isTestingProxyConnectivity)
    }

    func testPlayerHeadshotURLsIncludeFallbackSource() {
        let player = PlayerStat(
            id: "1966",
            playerName: "Test Player",
            headshotURL: "https://example.com/custom.png",
            jerseyNumber: "23",
            teamID: "lal",
            position: "G",
            minutes: "30",
            points: 20,
            rebounds: 5,
            assists: 7,
            steals: 1,
            blocks: 0,
            fieldGoalsMade: 8,
            fieldGoalsAttempted: 15,
            threePointersMade: 2,
            threePointersAttempted: 6,
            plusMinus: 8
        )

        XCTAssertEqual(player.headshotImageURLs.count, 2)
        XCTAssertEqual(player.headshotImageURLs.first?.absoluteString, "https://example.com/custom.png")
        XCTAssertEqual(player.headshotImageURLs.last?.absoluteString, "https://a.espncdn.com/i/headshots/nba/players/full/1966.png")
    }
}

private struct StaticProvider: ScoreboardProviding {
    let sourceDescription = "Static test provider"

    func fetchGames(for date: Date) async throws -> [Game] {
        MockScheduleFactory.makeGames(referenceDate: date, tick: 2)
    }
}

private struct StubProxyConnectivityTester: ProxyConnectivityTesting {
    let result: Result<String, Error>

    func testConnection(using proxySettings: ProxySettings) async throws -> String {
        try result.get()
    }
}
