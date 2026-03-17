import Foundation

enum GameStatus: String, Codable, CaseIterable, Sendable {
    case upcoming
    case live
    case final

    var displayText: String {
        switch self {
        case .upcoming:
            "未开始"
        case .live:
            "进行中"
        case .final:
            "已结束"
        }
    }
}

struct TeamRecord: Codable, Hashable, Sendable {
    let wins: Int
    let losses: Int

    var displayText: String {
        "\(wins)-\(losses)"
    }
}

struct Team: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let city: String
    let name: String
    let abbreviation: String
    let conferenceRank: Int?
    let record: TeamRecord?

    var displayName: String {
        "\(city) \(name)"
    }
}

struct TeamStatLine: Codable, Hashable, Sendable {
    let points: Int
    let rebounds: Int
    let assists: Int
    let fieldGoalPercentage: Double
    let threePointPercentage: Double
    let turnovers: Int
}

struct PlayerStat: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let playerName: String
    let headshotURL: String?
    let jerseyNumber: String
    let teamID: String
    let position: String
    let minutes: String
    let points: Int
    let rebounds: Int
    let offensiveRebounds: Int
    let defensiveRebounds: Int
    let assists: Int
    let steals: Int
    let blocks: Int
    let turnovers: Int
    let fouls: Int
    let fieldGoalsMade: Int
    let fieldGoalsAttempted: Int
    let threePointersMade: Int
    let threePointersAttempted: Int
    let freeThrowsMade: Int
    let freeThrowsAttempted: Int
    let plusMinus: Int
    let isStarter: Bool

    init(
        id: String,
        playerName: String,
        headshotURL: String?,
        jerseyNumber: String,
        teamID: String,
        position: String,
        minutes: String,
        points: Int,
        rebounds: Int,
        offensiveRebounds: Int = 0,
        defensiveRebounds: Int = 0,
        assists: Int,
        steals: Int,
        blocks: Int,
        turnovers: Int = 0,
        fouls: Int = 0,
        fieldGoalsMade: Int,
        fieldGoalsAttempted: Int,
        threePointersMade: Int,
        threePointersAttempted: Int,
        freeThrowsMade: Int = 0,
        freeThrowsAttempted: Int = 0,
        plusMinus: Int,
        isStarter: Bool = false
    ) {
        self.id = id
        self.playerName = playerName
        self.headshotURL = headshotURL
        self.jerseyNumber = jerseyNumber
        self.teamID = teamID
        self.position = position
        self.minutes = minutes
        self.points = points
        self.rebounds = rebounds
        self.offensiveRebounds = offensiveRebounds
        self.defensiveRebounds = defensiveRebounds
        self.assists = assists
        self.steals = steals
        self.blocks = blocks
        self.turnovers = turnovers
        self.fouls = fouls
        self.fieldGoalsMade = fieldGoalsMade
        self.fieldGoalsAttempted = fieldGoalsAttempted
        self.threePointersMade = threePointersMade
        self.threePointersAttempted = threePointersAttempted
        self.freeThrowsMade = freeThrowsMade
        self.freeThrowsAttempted = freeThrowsAttempted
        self.plusMinus = plusMinus
        self.isStarter = isStarter
    }

    var fieldGoalText: String {
        "\(fieldGoalsMade)-\(fieldGoalsAttempted)"
    }

    var threePointText: String {
        "\(threePointersMade)-\(threePointersAttempted)"
    }

    var freeThrowText: String {
        "\(freeThrowsMade)-\(freeThrowsAttempted)"
    }

    var fieldGoalPercentageText: String {
        shootingPercentageText(made: fieldGoalsMade, attempted: fieldGoalsAttempted)
    }

    var threePointPercentageText: String {
        shootingPercentageText(made: threePointersMade, attempted: threePointersAttempted)
    }

    var freeThrowPercentageText: String {
        shootingPercentageText(made: freeThrowsMade, attempted: freeThrowsAttempted)
    }

    var efficiencyHeadline: String {
        "\(points)分 \(rebounds)板 \(assists)助"
    }

    private func shootingPercentageText(made: Int, attempted: Int) -> String {
        guard attempted > 0 else {
            return "--"
        }
        let percentage = (Double(made) / Double(attempted)) * 100
        return "\(percentage.formatted(.number.precision(.fractionLength(1))))%"
    }
}

struct Game: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let status: GameStatus
    let startTime: Date
    let period: Int
    let clock: String
    let homeTeam: Team
    let awayTeam: Team
    let homeScore: Int
    let awayScore: Int
    let headline: String
    let homeLeaders: [PlayerStat]
    let awayLeaders: [PlayerStat]
    let homeTeamStats: TeamStatLine
    let awayTeamStats: TeamStatLine

    var isLive: Bool {
        status == .live
    }

    var scoreText: String {
        "\(awayTeam.abbreviation) \(awayScore) : \(homeScore) \(homeTeam.abbreviation)"
    }

    var statusLine: String {
        switch status {
        case .upcoming:
            "北京时间 \(startTime.formatted(date: .omitted, time: .shortened)) 开赛"
        case .live:
            "第\(period)节 \(clock)"
        case .final:
            "已结束"
        }
    }

    var dominantTeamID: String? {
        if homeScore == awayScore {
            return nil
        }
        return homeScore > awayScore ? homeTeam.id : awayTeam.id
    }
}

enum PlayerGroupFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case away = "客队"
    case home = "主队"

    var id: String { rawValue }
}

enum PrimaryScreen: Hashable {
    case scoreboard
    case detail(gameID: String)
    case settings
}
