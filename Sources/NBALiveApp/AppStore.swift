import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AppStore {
    private var provider: any ScoreboardProviding
    private let defaults: UserDefaults
    private let usesFactoryManagedProvider: Bool
    private let proxyConnectivityTester: any ProxyConnectivityTesting
    private var refreshTask: Task<Void, Never>?
    private var transitionTask: Task<Void, Never>?
    private let calendar = Calendar.current
    private let pastSelectableDayCount = 30
    private let futureSelectableDayCount = 14

    var currentScreen: PrimaryScreen = .scoreboard
    var games: [Game] = []
    var isLoading = false
    var isTransitioning = false
    var errorMessage: String?
    var lastUpdated: Date?
    var selectedDate: Date
    var favoriteTeamIDs: Set<String>
    var showsFavoritesOnly: Bool
    var refreshInterval: TimeInterval
    var selectedPlayerFilter: PlayerGroupFilter = .all
    var notificationsEnabled: Bool
    var proxySettings: ProxySettings
    var proxyFeedbackMessage: String?
    var proxyConnectivityMessage: String?
    var isTestingProxyConnectivity = false

    init(
        provider: (any ScoreboardProviding)? = nil,
        proxyConnectivityTester: any ProxyConnectivityTesting = NetworkProxyConnectivityTester(),
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults
        self.usesFactoryManagedProvider = provider == nil
        self.proxyConnectivityTester = proxyConnectivityTester
        self.selectedDate = Calendar.current.startOfDay(for: .now)
        self.favoriteTeamIDs = Set(defaults.stringArray(forKey: StorageKey.favoriteTeams) ?? [])
        self.showsFavoritesOnly = defaults.bool(forKey: StorageKey.favoritesOnly)

        let storedRefresh = defaults.double(forKey: StorageKey.refreshInterval)
        self.refreshInterval = storedRefresh > 0 ? storedRefresh : 20
        self.notificationsEnabled = defaults.object(forKey: StorageKey.notificationsEnabled) as? Bool ?? true
        self.proxySettings = ProviderFactory.loadProxySettings(from: defaults)
        self.provider = provider ?? ProviderFactory.makeDefaultProvider(defaults: defaults)
    }

    var filteredGames: [Game] {
        let source = showsFavoritesOnly ? games.filter(isFavoriteMatch(_:)) : games
        return source.sorted(by: gamePriority(_:_:))
    }

    var selectedGame: Game? {
        guard case let .detail(gameID) = currentScreen else {
            return nil
        }
        return games.first(where: { $0.id == gameID })
    }

    var liveGames: [Game] {
        games.filter(\.isLive)
    }

    var menuBarTitle: String {
        if let featured = liveGames.first {
            return "\(featured.awayTeam.abbreviation) \(featured.awayScore)-\(featured.homeScore) \(featured.homeTeam.abbreviation)"
        }
        return "NBA Live"
    }

    var menuBarSymbol: String {
        liveGames.isEmpty ? "basketball" : "dot.radiowaves.left.and.right"
    }

    var loadingMessage: String? {
        if isTransitioning {
            return "正在切换页面"
        }
        if isLoading {
            return "正在刷新数据"
        }
        return nil
    }

    var dataSourceDescription: String {
        provider.sourceDescription
    }

    var canApplyProxySettings: Bool {
        !proxySettings.isEnabled || proxySettings.isValid
    }

    var proxySettingsDescription: String {
        proxySettings.summaryText
    }

    var canEditProxySettings: Bool {
        usesFactoryManagedProvider && !ProviderFactory.isMockModeEnabled
    }

    var canTestProxyConnectivity: Bool {
        canEditProxySettings && canApplyProxySettings && !isTestingProxyConnectivity
    }

    var availableDates: [Date] {
        stride(from: -pastSelectableDayCount + 1, through: futureSelectableDayCount, by: 1).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: referenceDate)
        }
    }

    var selectableDateRange: ClosedRange<Date> {
        earliestSelectableDate ... latestSelectableDate
    }

    var selectedDateTitle: String {
        if calendar.isDateInToday(selectedDate) {
            return "今天"
        }
        if calendar.isDateInYesterday(selectedDate) {
            return "昨天"
        }
        if calendar.isDateInTomorrow(selectedDate) {
            return "明天"
        }
        return selectedDate.formatted(.dateTime.month(.twoDigits).day(.twoDigits).weekday(.abbreviated))
    }

    var selectedDateSubtitle: String {
        selectedDate.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits))
    }

    var canStepBackwardDate: Bool {
        selectedDate > earliestSelectableDate
    }

    var canStepForwardDate: Bool {
        selectedDate < latestSelectableDate
    }

    func start() {
        guard refreshTask == nil else { return }

        refreshTask = Task { [weak self] in
            guard let self else { return }
            await refreshNow()

            while !Task.isCancelled {
                let interval = refreshIntervalForCurrentState
                try? await Task.sleep(for: .seconds(interval))
                await refreshNow()
            }
        }
    }

    func refreshNow() async {
        isLoading = true
        errorMessage = nil

        do {
            let fetchedGames = try await provider.fetchGames(for: selectedDate)
            games = fetchedGames
            lastUpdated = .now

            if case let .detail(gameID) = currentScreen,
               !fetchedGames.contains(where: { $0.id == gameID }) {
                currentScreen = .scoreboard
            }
        } catch {
            errorMessage = "刷新失败：\(error.localizedDescription)"
        }

        isLoading = false
    }

    func openSettings() {
        performScreenTransition(to: .settings)
    }

    func showScoreboard() {
        performScreenTransition(to: .scoreboard)
    }

    func openGame(_ game: Game) {
        selectedPlayerFilter = .all
        performScreenTransition(to: .detail(gameID: game.id))
    }

    func setSelectedDate(_ date: Date) {
        selectedDate = calendar.startOfDay(for: date)
        Task {
            await refreshNow()
        }
    }

    func stepDate(by value: Int) {
        guard let targetDate = calendar.date(byAdding: .day, value: value, to: selectedDate) else {
            return
        }
        guard selectableDateRange.contains(targetDate) else { return }
        setSelectedDate(targetDate)
    }

    private var referenceDate: Date {
        calendar.startOfDay(for: .now)
    }

    private var earliestSelectableDate: Date {
        calendar.date(byAdding: .day, value: -pastSelectableDayCount + 1, to: referenceDate) ?? referenceDate
    }

    private var latestSelectableDate: Date {
        calendar.date(byAdding: .day, value: futureSelectableDayCount, to: referenceDate) ?? referenceDate
    }

    func toggleFavorite(for teamID: String) {
        if favoriteTeamIDs.contains(teamID) {
            favoriteTeamIDs.remove(teamID)
        } else {
            favoriteTeamIDs.insert(teamID)
        }

        defaults.set(Array(favoriteTeamIDs).sorted(), forKey: StorageKey.favoriteTeams)
    }

    func setFavoritesOnly(_ enabled: Bool) {
        showsFavoritesOnly = enabled
        defaults.set(enabled, forKey: StorageKey.favoritesOnly)
    }

    func setRefreshInterval(_ interval: TimeInterval) {
        refreshInterval = interval
        defaults.set(interval, forKey: StorageKey.refreshInterval)
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        notificationsEnabled = enabled
        defaults.set(enabled, forKey: StorageKey.notificationsEnabled)
    }

    func setProxyEnabled(_ enabled: Bool) {
        proxySettings.isEnabled = enabled
        proxyFeedbackMessage = nil
        proxyConnectivityMessage = nil
    }

    func setProxyType(_ type: ProxyType) {
        proxySettings.type = type
        proxyFeedbackMessage = nil
        proxyConnectivityMessage = nil
    }

    func setProxyHost(_ host: String) {
        proxySettings.host = host
        proxyFeedbackMessage = nil
        proxyConnectivityMessage = nil
    }

    func setProxyPortText(_ portText: String) {
        proxySettings.portText = portText
        proxyFeedbackMessage = nil
        proxyConnectivityMessage = nil
    }

    func applyProxySettings() {
        guard canApplyProxySettings else {
            proxyFeedbackMessage = proxySettings.validationMessage
            return
        }

        persistProxySettings()

        guard usesFactoryManagedProvider else {
            proxyFeedbackMessage = "当前数据源由外部注入，代理配置已保存。"
            return
        }

        guard !ProviderFactory.isMockModeEnabled else {
            proxyFeedbackMessage = "当前是 Mock 数据源，代理配置已保存，切回 ESPN 数据源后生效。"
            return
        }

        provider = ProviderFactory.makeDefaultProvider(defaults: defaults)
        proxyFeedbackMessage = proxySettings.isEnabled ? "代理配置已应用。" : "代理已关闭。"

        Task {
            await refreshNow()
        }
    }

    func testProxyConnectivity() async {
        guard canEditProxySettings else {
            proxyConnectivityMessage = "当前数据源不支持代理测试。"
            return
        }

        guard canApplyProxySettings else {
            proxyConnectivityMessage = proxySettings.validationMessage
            return
        }

        isTestingProxyConnectivity = true
        proxyConnectivityMessage = nil

        do {
            let message = try await proxyConnectivityTester.testConnection(using: proxySettings)
            proxyConnectivityMessage = message
        } catch {
            proxyConnectivityMessage = error.localizedDescription
        }

        isTestingProxyConnectivity = false
    }

    func players(for game: Game, filter: PlayerGroupFilter) -> [PlayerStat] {
        let allPlayers = game.awayLeaders + game.homeLeaders

        switch filter {
        case .all:
            return allPlayers.sorted(by: playerSort(_:_:))
        case .away:
            return game.awayLeaders.sorted(by: playerSort(_:_:))
        case .home:
            return game.homeLeaders.sorted(by: playerSort(_:_:))
        }
    }

    func isFavorite(teamID: String) -> Bool {
        favoriteTeamIDs.contains(teamID)
    }

    private func performScreenTransition(to screen: PrimaryScreen) {
        transitionTask?.cancel()
        isTransitioning = true

        withAnimation(.snappy(duration: 0.22, extraBounce: 0.02)) {
            selectedPlayerFilter = .all
            currentScreen = screen
        }

        transitionTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.isTransitioning = false
            }
        }
    }

    private var refreshIntervalForCurrentState: TimeInterval {
        if !calendar.isDateInToday(selectedDate) {
            return max(refreshInterval * 6, 300)
        }
        return liveGames.isEmpty ? max(refreshInterval * 3, 60) : refreshInterval
    }

    private func isFavoriteMatch(_ game: Game) -> Bool {
        favoriteTeamIDs.contains(game.homeTeam.id) || favoriteTeamIDs.contains(game.awayTeam.id)
    }

    private func gamePriority(_ lhs: Game, _ rhs: Game) -> Bool {
        let lhsScore = priorityScore(for: lhs)
        let rhsScore = priorityScore(for: rhs)

        if lhsScore == rhsScore {
            return lhs.startTime < rhs.startTime
        }
        return lhsScore > rhsScore
    }

    private func priorityScore(for game: Game) -> Int {
        switch game.status {
        case .live:
            3
        case .upcoming:
            2
        case .final:
            1
        }
    }

    private func playerSort(_ lhs: PlayerStat, _ rhs: PlayerStat) -> Bool {
        if lhs.points == rhs.points {
            return lhs.assists + lhs.rebounds > rhs.assists + rhs.rebounds
        }
        return lhs.points > rhs.points
    }

    private func persistProxySettings() {
        defaults.set(proxySettings.isEnabled, forKey: StorageKey.proxyEnabled)
        defaults.set(proxySettings.type.rawValue, forKey: StorageKey.proxyType)
        defaults.set(proxySettings.host, forKey: StorageKey.proxyHost)
        defaults.set(proxySettings.portText, forKey: StorageKey.proxyPort)
    }
}

enum StorageKey {
    static let favoriteTeams = "favoriteTeamIDs"
    static let favoritesOnly = "favoritesOnly"
    static let refreshInterval = "refreshInterval"
    static let notificationsEnabled = "notificationsEnabled"
    static let proxyEnabled = "proxyEnabled"
    static let proxyType = "proxyType"
    static let proxyHost = "proxyHost"
    static let proxyPort = "proxyPort"
}
