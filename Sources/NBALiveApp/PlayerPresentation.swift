import Foundation

extension PlayerStat {
    var headshotImageURLs: [URL] {
        var candidates: [URL] = []
        var seen = Set<String>()

        if let headshotURL,
           let primaryURL = URL(string: headshotURL),
           seen.insert(primaryURL.absoluteString).inserted {
            candidates.append(primaryURL)
        }

        if let fallbackURL = URL(string: "https://a.espncdn.com/i/headshots/nba/players/full/\(id).png"),
           seen.insert(fallbackURL.absoluteString).inserted {
            candidates.append(fallbackURL)
        }

        return candidates
    }

    var localizedPosition: String {
        switch position.uppercased() {
        case "G":
            return "后卫"
        case "F":
            return "前锋"
        case "C":
            return "中锋"
        case "G-F", "F-G":
            return "锋卫"
        case "F-C", "C-F":
            return "锋中"
        default:
            return position
        }
    }
}

enum PlayerMetricLabel {
    static let points = "得分"
    static let rebounds = "篮板"
    static let assists = "助攻"
    static let minutes = "时间"
    static let fieldGoal = "投篮"
    static let fieldGoalPercentage = "投篮命中率"
    static let threePoint = "三分"
    static let threePointPercentage = "三分命中率"
    static let freeThrow = "罚球"
    static let freeThrowPercentage = "罚球命中率"
    static let plusMinus = "正负值"
    static let steals = "抢断"
    static let blocks = "盖帽"
    static let offensiveRebounds = "前场篮板"
    static let defensiveRebounds = "后场篮板"
    static let turnovers = "失误"
    static let fouls = "犯规"
    static let sectionTitle = "球员数据"
    static let allTeams = "全部"
    static let awayTeam = "客队"
    static let homeTeam = "主队"
}
