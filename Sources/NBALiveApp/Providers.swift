import Foundation

protocol ScoreboardProviding: Sendable {
    var sourceDescription: String { get }
    func fetchGames(for date: Date) async throws -> [Game]
}

actor MockScoreboardProvider: ScoreboardProviding {
    private var tick: Int = 0

    nonisolated let sourceDescription = "Mock 数据源。用于本地开发和 UI 调试。"

    func fetchGames(for date: Date) async throws -> [Game] {
        tick += 1
        return MockScheduleFactory.makeGames(referenceDate: date, tick: tick)
    }
}

struct ProviderFactory {
    static var isMockModeEnabled: Bool {
        ProcessInfo.processInfo.environment["NBA_LIVE_USE_MOCK"] == "1"
    }

    static func makeDefaultProvider(defaults: UserDefaults = .standard) -> any ScoreboardProviding {
        if isMockModeEnabled {
            return MockScoreboardProvider()
        }
        return ESPNScoreboardProvider(proxySettings: loadProxySettings(from: defaults))
    }

    static func loadProxySettings(from defaults: UserDefaults = .standard) -> ProxySettings {
        ProxySettings(
            isEnabled: defaults.bool(forKey: StorageKey.proxyEnabled),
            type: ProxyType(rawValue: defaults.string(forKey: StorageKey.proxyType) ?? ProxyType.http.rawValue) ?? .http,
            host: defaults.string(forKey: StorageKey.proxyHost) ?? "",
            portText: defaults.string(forKey: StorageKey.proxyPort) ?? ""
        )
    }
}

struct ESPNScoreboardProvider: ScoreboardProviding {
    let sourceDescription: String

    private let session: URLSession

    init(proxySettings: ProxySettings = ProxySettings()) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        configuration.connectionProxyDictionary = proxySettings.connectionProxyDictionary
        session = URLSession(configuration: configuration)

        if proxySettings.isEnabled, proxySettings.isValid {
            sourceDescription = "ESPN 公共 NBA scoreboard/summary 接口。比赛日期按美国东部时间的 NBA league day 计算。当前代理：\(proxySettings.summaryText)。"
        } else {
            sourceDescription = "ESPN 公共 NBA scoreboard/summary 接口。比赛日期按美国东部时间的 NBA league day 计算。"
        }
    }

    func fetchGames(for date: Date) async throws -> [Game] {
        let requestDate = NBALeagueCalendar.leagueDateString(for: date)
        let scoreboardURL = URL(string: "https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard?dates=\(requestDate)")!
        let scoreboard: ESPNScoreboardResponse = try await load(scoreboardURL, as: ESPNScoreboardResponse.self)
        let baseGames = scoreboard.events.compactMap(makeBaseGame(from:))

        return try await withThrowingTaskGroup(of: Game.self) { group in
            for game in baseGames {
                group.addTask {
                    guard game.status != .upcoming else {
                        return game
                    }

                    do {
                        return try await enrich(game: game)
                    } catch {
                        return game
                    }
                }
            }

            var games: [Game] = []
            for try await game in group {
                games.append(game)
            }
            return games.sorted { $0.startTime < $1.startTime }
        }
    }

    private func enrich(game: Game) async throws -> Game {
        let summaryURL = URL(string: "https://site.api.espn.com/apis/site/v2/sports/basketball/nba/summary?event=\(game.id)")!
        let summary: ESPNSummaryResponse = try await load(summaryURL, as: ESPNSummaryResponse.self)

        let awayPlayers = summary.boxscore.players.first(where: { $0.team.id == game.awayTeam.id })?.toPlayerStats(teamID: game.awayTeam.id) ?? game.awayLeaders
        let homePlayers = summary.boxscore.players.first(where: { $0.team.id == game.homeTeam.id })?.toPlayerStats(teamID: game.homeTeam.id) ?? game.homeLeaders
        let awayStats = summary.boxscore.teams.first(where: { $0.team.id == game.awayTeam.id })?.toTeamStatLine() ?? game.awayTeamStats
        let homeStats = summary.boxscore.teams.first(where: { $0.team.id == game.homeTeam.id })?.toTeamStatLine() ?? game.homeTeamStats

        return Game(
            id: game.id,
            status: game.status,
            startTime: game.startTime,
            period: game.period,
            clock: game.clock,
            homeTeam: game.homeTeam,
            awayTeam: game.awayTeam,
            homeScore: game.homeScore,
            awayScore: game.awayScore,
            headline: summary.header.competitions.first?.headlines?.first?.shortLinkText ?? game.headline,
            homeLeaders: homePlayers,
            awayLeaders: awayPlayers,
            homeTeamStats: homeStats,
            awayTeamStats: awayStats
        )
    }

    private func makeBaseGame(from event: ESPNEvent) -> Game? {
        guard let competition = event.competitions.first,
              let homeCompetitor = competition.competitors.first(where: { $0.homeAway == "home" }),
              let awayCompetitor = competition.competitors.first(where: { $0.homeAway == "away" }) else {
            return nil
        }

        let status = GameStatus(competitionState: competition.status.type.state, completed: competition.status.type.completed)
        let startTime = NBALeagueCalendar.parseStartDate(from: competition.startDate)
        let headline = competition.headlines?.first?.shortLinkText
            ?? event.name
            ?? "\(awayCompetitor.team.displayName) at \(homeCompetitor.team.displayName)"

        return Game(
            id: event.id,
            status: status,
            startTime: startTime,
            period: competition.status.period,
            clock: clockText(for: competition.status.displayClock, status: status),
            homeTeam: homeCompetitor.toTeam(),
            awayTeam: awayCompetitor.toTeam(),
            homeScore: Int(homeCompetitor.score) ?? 0,
            awayScore: Int(awayCompetitor.score) ?? 0,
            headline: headline,
            homeLeaders: homeCompetitor.toLeaderPlayers(),
            awayLeaders: awayCompetitor.toLeaderPlayers(),
            homeTeamStats: homeCompetitor.toTeamStatLine(),
            awayTeamStats: awayCompetitor.toTeamStatLine()
        )
    }

    private func load<T: Decodable>(_ url: URL, as type: T.Type) async throws -> T {
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw ProviderError.http(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            if let decodingError = error as? DecodingError {
                print("ESPN decoding error:", decodingError)
            }
            throw error
        }
    }

    private func clockText(for displayClock: String, status: GameStatus) -> String {
        if status == .live {
            return displayClock == "0.0" ? "0:00" : displayClock.replacingOccurrences(of: ".0", with: "")
        }
        return ""
    }
}

private enum ProviderError: LocalizedError {
    case invalidResponse
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "数据源响应无效"
        case let .http(code):
            return "数据源请求失败，HTTP \(code)"
        }
    }
}

enum NBALeagueCalendar {
    private static let leagueTimeZone = TimeZone(identifier: "America/New_York")!

    static func leagueDateString(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = leagueTimeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 1970
        let month = components.month ?? 1
        let day = components.day ?? 1
        return String(format: "%04d%02d%02d", year, month, day)
    }

    static func parseStartDate(from raw: String) -> Date {
        let internetDateFormatter = ISO8601DateFormatter()
        internetDateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = internetDateFormatter.date(from: raw) {
            return parsed
        }

        let basicInternetDateFormatter = ISO8601DateFormatter()
        basicInternetDateFormatter.formatOptions = [.withInternetDateTime]
        if let parsed = basicInternetDateFormatter.date(from: raw) {
            return parsed
        }

        for format in ["yyyy-MM-dd'T'HH:mmZ", "yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd'T'HH:mm:ss.SSSZ"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            if let parsed = formatter.date(from: raw) {
                return parsed
            }
        }
        return .now
    }
}

private extension GameStatus {
    init(competitionState: String, completed: Bool) {
        if completed || competitionState == "post" {
            self = .final
        } else if competitionState == "pre" {
            self = .upcoming
        } else {
            self = .live
        }
    }

    init(_ competitionState: String, completed: Bool) {
        self.init(competitionState: competitionState, completed: completed)
    }
}

private struct ESPNScoreboardResponse: Decodable {
    let events: [ESPNEvent]
}

private struct ESPNEvent: Decodable {
    let id: String
    let name: String?
    let competitions: [ESPNCompetition]
}

private struct ESPNCompetition: Decodable {
    let competitors: [ESPNCompetitor]
    let status: ESPNStatus
    let startDate: String
    let headlines: [ESPNCompetitionHeadline]?
}

private struct ESPNCompetitionHeadline: Decodable {
    let shortLinkText: String?
}

private struct ESPNStatus: Decodable {
    let displayClock: String
    let period: Int
    let type: ESPNStatusType
}

private struct ESPNStatusType: Decodable {
    let state: String
    let completed: Bool
}

private struct ESPNCompetitor: Decodable {
    let homeAway: String
    let team: ESPNTeamIdentity
    let score: String
    let statistics: [ESPNNamedStat]?
    let leaders: [ESPNLeaderCategory]?
    let records: [ESPNRecord]?

    func toTeam() -> Team {
        Team(
            id: team.id,
            city: team.location,
            name: team.name,
            abbreviation: team.abbreviation,
            conferenceRank: nil,
            record: (records ?? []).first(where: { $0.name.lowercased() == "overall" }).flatMap { TeamRecord(summary: $0.summary) }
        )
    }

    func toTeamStatLine() -> TeamStatLine {
        TeamStatLine(
            points: statInt("points"),
            rebounds: statInt("rebounds"),
            assists: statInt("assists"),
            fieldGoalPercentage: statDouble("fieldGoalPct"),
            threePointPercentage: statDouble("threePointPct"),
            turnovers: statInt("totalTurnovers", fallback: "turnovers")
        )
    }

    func toLeaderPlayers() -> [PlayerStat] {
        let pointsLeader = leaders?.first(where: { $0.name == "points" })?.leaders?.first
        let reboundsLeader = leaders?.first(where: { $0.name == "rebounds" })?.leaders?.first
        let assistsLeader = leaders?.first(where: { $0.name == "assists" })?.leaders?.first

        guard let athlete = pointsLeader?.athlete ?? reboundsLeader?.athlete ?? assistsLeader?.athlete else {
            return []
        }

        return [
            PlayerStat(
                id: athlete.id,
                playerName: athlete.displayName,
                headshotURL: athlete.headshot?.href,
                jerseyNumber: athlete.jersey ?? "--",
                teamID: team.id,
                position: athlete.position?.abbreviation ?? "--",
                minutes: "--",
                points: Int(pointsLeader?.displayValue ?? "") ?? 0,
                rebounds: Int(reboundsLeader?.displayValue ?? "") ?? 0,
                assists: Int(assistsLeader?.displayValue ?? "") ?? 0,
                steals: 0,
                blocks: 0,
                fieldGoalsMade: 0,
                fieldGoalsAttempted: 0,
                threePointersMade: 0,
                threePointersAttempted: 0,
                plusMinus: 0
            )
        ]
    }

    private func statInt(_ name: String, fallback: String? = nil) -> Int {
        if let value = statistics?.first(where: { $0.name == name })?.displayValue {
            return Int(value) ?? 0
        }
        if let fallback,
           let value = statistics?.first(where: { $0.name == fallback })?.displayValue {
            return Int(value) ?? 0
        }
        return 0
    }

    private func statDouble(_ name: String) -> Double {
        guard let value = statistics?.first(where: { $0.name == name })?.displayValue else {
            return 0
        }
        return Double(value) ?? 0
    }
}

private struct ESPNTeamIdentity: Decodable {
    let id: String
    let location: String
    let name: String
    let abbreviation: String

    var displayName: String {
        "\(location) \(name)"
    }
}

private struct ESPNNamedStat: Decodable {
    let name: String?
    let displayValue: String
    let abbreviation: String?
    let label: String?
}

private struct ESPNLeaderCategory: Decodable {
    let name: String?
    let leaders: [ESPNLeader]?
}

private struct ESPNLeader: Decodable {
    let displayValue: String?
    let athlete: ESPNAthleteSummary?
}

private struct ESPNRecord: Decodable {
    let name: String
    let summary: String
}

private struct ESPNAthleteSummary: Decodable {
    let id: String
    let displayName: String
    let headshot: ESPNHeadshot?
    let jersey: String?
    let position: ESPNAthletePosition?
}

private struct ESPNAthletePosition: Decodable {
    let abbreviation: String
}

private struct ESPNSummaryResponse: Decodable {
    let boxscore: ESPNBoxscore
    let header: ESPNHeader
}

private struct ESPNBoxscore: Decodable {
    let teams: [ESPNBoxscoreTeam]
    let players: [ESPNBoxscorePlayerGroup]
}

private struct ESPNHeader: Decodable {
    let competitions: [ESPNHeaderCompetition]
}

private struct ESPNHeaderCompetition: Decodable {
    let headlines: [ESPNCompetitionHeadline]?
}

private struct ESPNBoxscoreTeam: Decodable {
    let team: ESPNTeamIdentity
    let statistics: [ESPNNamedStat]

    func toTeamStatLine() -> TeamStatLine {
        TeamStatLine(
            points: derivedPoints(),
            rebounds: statInt(name: "totalRebounds", fallbackLiteral: "REB"),
            assists: statInt(name: "assists", fallbackLiteral: "AST"),
            fieldGoalPercentage: statDouble(label: "fieldGoalPct", fallbackLiteral: "FG%"),
            threePointPercentage: statDouble(label: "threePointFieldGoalPct", fallbackLiteral: "3P%"),
            turnovers: statInt(name: "totalTurnovers", fallbackLiteral: "ToTO")
        )
    }

    private func derivedPoints() -> Int {
        let fg = pairStat(label: "FG")
        let threes = pairStat(label: "3PT")
        let ft = pairStat(label: "FT")
        return (fg.made * 2) + threes.made + ft.made
    }

    private func pairStat(label: String) -> (made: Int, attempted: Int) {
        guard let raw = statistics.first(where: { $0.label == label })?.displayValue else {
            return (0, 0)
        }
        let parts = raw.split(separator: "-")
        return (Int(parts.first ?? "0") ?? 0, Int(parts.dropFirst().first ?? "0") ?? 0)
    }

    private func statInt(name: String, fallbackLiteral: String? = nil) -> Int {
        if let value = statistics.first(where: { $0.name == name })?.displayValue {
            return Int(value) ?? 0
        }
        if let fallbackLiteral,
           let value = statistics.first(where: { $0.abbreviation == fallbackLiteral || $0.label == fallbackLiteral })?.displayValue {
            return Int(value) ?? 0
        }
        return 0
    }

    private func statDouble(label: String, fallbackLiteral: String) -> Double {
        if let value = statistics.first(where: { $0.name == label })?.displayValue {
            return Double(value) ?? 0
        }
        if let value = statistics.first(where: { $0.abbreviation == fallbackLiteral || $0.label == fallbackLiteral })?.displayValue {
            return Double(value) ?? 0
        }
        return 0
    }
}

private struct ESPNBoxscorePlayerGroup: Decodable {
    let team: ESPNTeamIdentity
    let statistics: [ESPNPlayerTable]?

    func toPlayerStats(teamID: String) -> [PlayerStat] {
        (statistics ?? []).flatMap { table in
            table.athletes.compactMap { athlete in
                guard athlete.didNotPlay != true, athlete.stats.isEmpty == false else {
                    return nil
                }
                return athlete.toPlayerStat(teamID: teamID, keys: table.keys)
            }
        }
        .sorted { lhs, rhs in
            if lhs.points == rhs.points {
                return lhs.rebounds + lhs.assists > rhs.rebounds + rhs.assists
            }
            return lhs.points > rhs.points
        }
    }
}

private struct ESPNPlayerTable: Decodable {
    let keys: [String]
    let athletes: [ESPNBoxscoreAthlete]
}

private struct ESPNBoxscoreAthlete: Decodable {
    let athlete: ESPNPlayerIdentity
    let didNotPlay: Bool?
    let starter: Bool?
    let stats: [String]

    func toPlayerStat(teamID: String, keys: [String]) -> PlayerStat {
        let table = Dictionary(uniqueKeysWithValues: zip(keys, stats))
        let fieldGoals = parsePair(table["fieldGoalsMade-fieldGoalsAttempted"])
        let threes = parsePair(table["threePointFieldGoalsMade-threePointFieldGoalsAttempted"])
        let freeThrows = parsePair(table["freeThrowsMade-freeThrowsAttempted"])

        return PlayerStat(
            id: athlete.id,
            playerName: athlete.displayName,
            headshotURL: athlete.headshot?.href,
            jerseyNumber: athlete.jersey ?? "--",
            teamID: teamID,
            position: athlete.position?.abbreviation ?? "--",
            minutes: table["minutes"] ?? "--",
            points: Int(table["points"] ?? "0") ?? 0,
            rebounds: Int(table["rebounds"] ?? "0") ?? 0,
            offensiveRebounds: Int(table["offensiveRebounds"] ?? "0") ?? 0,
            defensiveRebounds: Int(table["defensiveRebounds"] ?? "0") ?? 0,
            assists: Int(table["assists"] ?? "0") ?? 0,
            steals: Int(table["steals"] ?? "0") ?? 0,
            blocks: Int(table["blocks"] ?? "0") ?? 0,
            turnovers: Int(table["turnovers"] ?? "0") ?? 0,
            fouls: Int(table["fouls"] ?? "0") ?? 0,
            fieldGoalsMade: fieldGoals.made,
            fieldGoalsAttempted: fieldGoals.attempted,
            threePointersMade: threes.made,
            threePointersAttempted: threes.attempted,
            freeThrowsMade: freeThrows.made,
            freeThrowsAttempted: freeThrows.attempted,
            plusMinus: parsePlusMinus(table["plusMinus"]),
            isStarter: starter ?? false
        )
    }

    private func parsePair(_ value: String?) -> (made: Int, attempted: Int) {
        let parts = (value ?? "0-0").split(separator: "-")
        return (Int(parts.first ?? "0") ?? 0, Int(parts.dropFirst().first ?? "0") ?? 0)
    }

    private func parsePlusMinus(_ value: String?) -> Int {
        guard let value else { return 0 }
        return Int(value.replacingOccurrences(of: "+", with: "")) ?? 0
    }
}

private struct ESPNPlayerIdentity: Decodable {
    let id: String
    let displayName: String
    let headshot: ESPNHeadshot?
    let jersey: String?
    let position: ESPNAthletePosition?
}

private struct ESPNHeadshot: Decodable {
    let href: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let rawString = try? container.decode(String.self) {
            href = rawString
            return
        }

        if let object = try? container.decode(HeadshotObject.self) {
            href = object.href
            return
        }

        throw DecodingError.typeMismatch(
            String.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected headshot as either a string URL or an object with href."
            )
        )
    }
}

private struct HeadshotObject: Decodable {
    let href: String
}

private extension TeamRecord {
    init?(summary: String) {
        let parts = summary.split(separator: "-")
        guard parts.count == 2,
              let wins = Int(parts[0]),
              let losses = Int(parts[1]) else {
            return nil
        }
        self.init(wins: wins, losses: losses)
    }
}

enum MockScheduleFactory {
    static func makeGames(referenceDate: Date, tick: Int) -> [Game] {
        let calendar = Calendar(identifier: .gregorian)
        let noon = calendar.date(bySettingHour: 12, minute: 30, second: 0, of: referenceDate) ?? referenceDate
        let evening = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: referenceDate) ?? referenceDate
        let night = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: referenceDate) ?? referenceDate

        let lakers = Team(
            id: "lal",
            city: "Los Angeles",
            name: "Lakers",
            abbreviation: "LAL",
            conferenceRank: 5,
            record: TeamRecord(wins: 42, losses: 25)
        )
        let warriors = Team(
            id: "gsw",
            city: "Golden State",
            name: "Warriors",
            abbreviation: "GSW",
            conferenceRank: 7,
            record: TeamRecord(wins: 38, losses: 29)
        )
        let celtics = Team(
            id: "bos",
            city: "Boston",
            name: "Celtics",
            abbreviation: "BOS",
            conferenceRank: 1,
            record: TeamRecord(wins: 51, losses: 16)
        )
        let bucks = Team(
            id: "mil",
            city: "Milwaukee",
            name: "Bucks",
            abbreviation: "MIL",
            conferenceRank: 2,
            record: TeamRecord(wins: 46, losses: 20)
        )
        let nuggets = Team(
            id: "den",
            city: "Denver",
            name: "Nuggets",
            abbreviation: "DEN",
            conferenceRank: 3,
            record: TeamRecord(wins: 44, losses: 23)
        )
        let suns = Team(
            id: "phx",
            city: "Phoenix",
            name: "Suns",
            abbreviation: "PHX",
            conferenceRank: 6,
            record: TeamRecord(wins: 39, losses: 28)
        )

        let liveBaseAwayScore = 104 + min(tick, 10)
        let liveBaseHomeScore = 101 + min(max(tick - 1, 0), 11)
        let liveClock = max(11 * 60 - tick * 23, 18)
        let liveMinute = liveClock / 60
        let liveSecond = liveClock % 60

        return [
            Game(
                id: "bos-mil",
                status: .final,
                startTime: noon,
                period: 4,
                clock: "0:00",
                homeTeam: bucks,
                awayTeam: celtics,
                homeScore: 109,
                awayScore: 118,
                headline: "塔图姆 32 分 11 篮板，凯尔特人客场拿下强强对话。",
                homeLeaders: [
                    player("giannis", "Giannis Antetokounmpo", "34", teamID: bucks.id, position: "F", minutes: "36", points: 30, rebounds: 12, assists: 7, steals: 1, blocks: 2, fgMade: 12, fgAttempted: 21, threeMade: 1, threeAttempted: 3, plusMinus: -6),
                    player("lillard", "Damian Lillard", "0", teamID: bucks.id, position: "G", minutes: "35", points: 25, rebounds: 4, assists: 8, steals: 1, blocks: 0, fgMade: 8, fgAttempted: 17, threeMade: 4, threeAttempted: 10, plusMinus: -3)
                ],
                awayLeaders: [
                    player("tatum", "Jayson Tatum", "0", teamID: celtics.id, position: "F", minutes: "37", points: 32, rebounds: 11, assists: 5, steals: 2, blocks: 1, fgMade: 12, fgAttempted: 22, threeMade: 5, threeAttempted: 11, plusMinus: 9),
                    player("brown", "Jaylen Brown", "7", teamID: celtics.id, position: "G", minutes: "36", points: 27, rebounds: 6, assists: 4, steals: 1, blocks: 1, fgMade: 10, fgAttempted: 18, threeMade: 3, threeAttempted: 6, plusMinus: 7)
                ],
                homeTeamStats: TeamStatLine(points: 109, rebounds: 45, assists: 26, fieldGoalPercentage: 48.9, threePointPercentage: 34.3, turnovers: 13),
                awayTeamStats: TeamStatLine(points: 118, rebounds: 48, assists: 29, fieldGoalPercentage: 50.5, threePointPercentage: 39.1, turnovers: 10)
            ),
            Game(
                id: "gsw-lal",
                status: .live,
                startTime: evening,
                period: 4,
                clock: "\(liveMinute):" + String(format: "%02d", liveSecond),
                homeTeam: lakers,
                awayTeam: warriors,
                homeScore: liveBaseHomeScore,
                awayScore: liveBaseAwayScore,
                headline: "末节胶着，库里与东契奇级别的球星对飙持续上演。",
                homeLeaders: [
                    player("lebron", "LeBron James", "23", teamID: lakers.id, position: "F", minutes: "32", points: 29 + tick / 3, rebounds: 8, assists: 9, steals: 1, blocks: 1, fgMade: 11, fgAttempted: 18, threeMade: 3, threeAttempted: 6, plusMinus: 4),
                    player("davis", "Anthony Davis", "3", teamID: lakers.id, position: "C", minutes: "31", points: 24, rebounds: 13, assists: 3, steals: 2, blocks: 3, fgMade: 9, fgAttempted: 16, threeMade: 0, threeAttempted: 1, plusMinus: 2),
                    player("reaves", "Austin Reaves", "15", teamID: lakers.id, position: "G", minutes: "28", points: 16, rebounds: 4, assists: 5, steals: 1, blocks: 0, fgMade: 5, fgAttempted: 11, threeMade: 2, threeAttempted: 5, plusMinus: -1)
                ],
                awayLeaders: [
                    player("curry", "Stephen Curry", "30", teamID: warriors.id, position: "G", minutes: "33", points: 31 + tick / 2, rebounds: 5, assists: 7, steals: 2, blocks: 0, fgMade: 10, fgAttempted: 19, threeMade: 6, threeAttempted: 13, plusMinus: 6),
                    player("butler", "Jimmy Butler", "10", teamID: warriors.id, position: "F", minutes: "30", points: 21, rebounds: 7, assists: 6, steals: 1, blocks: 1, fgMade: 7, fgAttempted: 14, threeMade: 1, threeAttempted: 3, plusMinus: 3),
                    player("green", "Draymond Green", "23", teamID: warriors.id, position: "F", minutes: "29", points: 8, rebounds: 9, assists: 10, steals: 1, blocks: 1, fgMade: 3, fgAttempted: 7, threeMade: 1, threeAttempted: 2, plusMinus: 7)
                ],
                homeTeamStats: TeamStatLine(points: liveBaseHomeScore, rebounds: 44, assists: 25, fieldGoalPercentage: 49.4, threePointPercentage: 35.8, turnovers: 12),
                awayTeamStats: TeamStatLine(points: liveBaseAwayScore, rebounds: 41, assists: 30, fieldGoalPercentage: 50.7, threePointPercentage: 41.2, turnovers: 11)
            ),
            Game(
                id: "phx-den",
                status: .upcoming,
                startTime: night,
                period: 0,
                clock: "",
                homeTeam: suns,
                awayTeam: nuggets,
                homeScore: 0,
                awayScore: 0,
                headline: "杜兰特 vs 约基奇，西部焦点战将在晚间打响。",
                homeLeaders: [
                    player("durant", "Kevin Durant", "35", teamID: suns.id, position: "F", minutes: "--", points: 0, rebounds: 0, assists: 0, steals: 0, blocks: 0, fgMade: 0, fgAttempted: 0, threeMade: 0, threeAttempted: 0, plusMinus: 0),
                    player("booker", "Devin Booker", "1", teamID: suns.id, position: "G", minutes: "--", points: 0, rebounds: 0, assists: 0, steals: 0, blocks: 0, fgMade: 0, fgAttempted: 0, threeMade: 0, threeAttempted: 0, plusMinus: 0)
                ],
                awayLeaders: [
                    player("jokic", "Nikola Jokic", "15", teamID: nuggets.id, position: "C", minutes: "--", points: 0, rebounds: 0, assists: 0, steals: 0, blocks: 0, fgMade: 0, fgAttempted: 0, threeMade: 0, threeAttempted: 0, plusMinus: 0),
                    player("murray", "Jamal Murray", "27", teamID: nuggets.id, position: "G", minutes: "--", points: 0, rebounds: 0, assists: 0, steals: 0, blocks: 0, fgMade: 0, fgAttempted: 0, threeMade: 0, threeAttempted: 0, plusMinus: 0)
                ],
                homeTeamStats: TeamStatLine(points: 0, rebounds: 0, assists: 0, fieldGoalPercentage: 0, threePointPercentage: 0, turnovers: 0),
                awayTeamStats: TeamStatLine(points: 0, rebounds: 0, assists: 0, fieldGoalPercentage: 0, threePointPercentage: 0, turnovers: 0)
            )
        ]
    }

    private static func player(
        _ id: String,
        _ name: String,
        _ jerseyNumber: String,
        teamID: String,
        position: String,
        minutes: String,
        points: Int,
        rebounds: Int,
        assists: Int,
        steals: Int,
        blocks: Int,
        turnovers: Int = 0,
        fouls: Int = 0,
        fgMade: Int,
        fgAttempted: Int,
        threeMade: Int,
        threeAttempted: Int,
        ftMade: Int = 0,
        ftAttempted: Int = 0,
        offensiveRebounds: Int = 0,
        defensiveRebounds: Int = 0,
        isStarter: Bool = true,
        plusMinus: Int
    ) -> PlayerStat {
        PlayerStat(
            id: id,
            playerName: name,
            headshotURL: nil,
            jerseyNumber: jerseyNumber,
            teamID: teamID,
            position: position,
            minutes: minutes,
            points: points,
            rebounds: rebounds,
            offensiveRebounds: offensiveRebounds,
            defensiveRebounds: defensiveRebounds,
            assists: assists,
            steals: steals,
            blocks: blocks,
            turnovers: turnovers,
            fouls: fouls,
            fieldGoalsMade: fgMade,
            fieldGoalsAttempted: fgAttempted,
            threePointersMade: threeMade,
            threePointersAttempted: threeAttempted,
            freeThrowsMade: ftMade,
            freeThrowsAttempted: ftAttempted,
            plusMinus: plusMinus,
            isStarter: isStarter
        )
    }
}
