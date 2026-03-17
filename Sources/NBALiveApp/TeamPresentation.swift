import Foundation

extension Team {
    var localizedName: String {
        TeamPresentation.localizedName(for: canonicalAbbreviation) ?? displayName
    }

    var logoURL: URL? {
        URL(string: TeamPresentation.logoURLString(for: canonicalAbbreviation) ?? TeamPresentation.defaultLogoURL(for: canonicalAbbreviation))
    }

    var canonicalAbbreviation: String {
        switch abbreviation.uppercased() {
        case "GSW":
            "GS"
        case "SAS":
            "SA"
        case "NOP":
            "NO"
        default:
            abbreviation.uppercased()
        }
    }
}

private enum TeamPresentation {
    private static let catalog: [String: TeamPresentationEntry] = [
        "ATL": .init(localizedName: "亚特兰大老鹰", logoURL: defaultLogoURL(for: "atl")),
        "BKN": .init(localizedName: "布鲁克林篮网", logoURL: defaultLogoURL(for: "bkn")),
        "BOS": .init(localizedName: "波士顿凯尔特人", logoURL: defaultLogoURL(for: "bos")),
        "CHA": .init(localizedName: "夏洛特黄蜂", logoURL: defaultLogoURL(for: "cha")),
        "CHI": .init(localizedName: "芝加哥公牛", logoURL: defaultLogoURL(for: "chi")),
        "CLE": .init(localizedName: "克利夫兰骑士", logoURL: defaultLogoURL(for: "cle")),
        "DAL": .init(localizedName: "达拉斯独行侠", logoURL: defaultLogoURL(for: "dal")),
        "DEN": .init(localizedName: "丹佛掘金", logoURL: defaultLogoURL(for: "den")),
        "DET": .init(localizedName: "底特律活塞", logoURL: defaultLogoURL(for: "det")),
        "GS": .init(localizedName: "金州勇士", logoURL: defaultLogoURL(for: "gs")),
        "HOU": .init(localizedName: "休斯敦火箭", logoURL: defaultLogoURL(for: "hou")),
        "IND": .init(localizedName: "印第安纳步行者", logoURL: defaultLogoURL(for: "ind")),
        "LAC": .init(localizedName: "洛杉矶快船", logoURL: defaultLogoURL(for: "lac")),
        "LAL": .init(localizedName: "洛杉矶湖人", logoURL: defaultLogoURL(for: "lal")),
        "MEM": .init(localizedName: "孟菲斯灰熊", logoURL: defaultLogoURL(for: "mem")),
        "MIA": .init(localizedName: "迈阿密热火", logoURL: defaultLogoURL(for: "mia")),
        "MIL": .init(localizedName: "密尔沃基雄鹿", logoURL: defaultLogoURL(for: "mil")),
        "MIN": .init(localizedName: "明尼苏达森林狼", logoURL: defaultLogoURL(for: "min")),
        "NO": .init(localizedName: "新奥尔良鹈鹕", logoURL: defaultLogoURL(for: "no")),
        "NY": .init(localizedName: "纽约尼克斯", logoURL: defaultLogoURL(for: "ny")),
        "OKC": .init(localizedName: "俄克拉荷马城雷霆", logoURL: defaultLogoURL(for: "okc")),
        "ORL": .init(localizedName: "奥兰多魔术", logoURL: defaultLogoURL(for: "orl")),
        "PHI": .init(localizedName: "费城76人", logoURL: defaultLogoURL(for: "phi")),
        "PHX": .init(localizedName: "菲尼克斯太阳", logoURL: defaultLogoURL(for: "phx")),
        "POR": .init(localizedName: "波特兰开拓者", logoURL: defaultLogoURL(for: "por")),
        "SAC": .init(localizedName: "萨克拉门托国王", logoURL: defaultLogoURL(for: "sac")),
        "SA": .init(localizedName: "圣安东尼奥马刺", logoURL: defaultLogoURL(for: "sa")),
        "TOR": .init(localizedName: "多伦多猛龙", logoURL: defaultLogoURL(for: "tor")),
        "UTA": .init(localizedName: "犹他爵士", logoURL: defaultLogoURL(for: "uta")),
        "WSH": .init(localizedName: "华盛顿奇才", logoURL: defaultLogoURL(for: "wsh"))
    ]

    static func defaultLogoURL(for key: String) -> String {
        "https://a.espncdn.com/i/teamlogos/nba/500/\(key.lowercased()).png"
    }

    static func localizedName(for abbreviation: String) -> String? {
        catalog[abbreviation]?.localizedName
    }

    static func logoURLString(for abbreviation: String) -> String? {
        catalog[abbreviation]?.logoURL
    }

    private struct TeamPresentationEntry {
        let localizedName: String
        let logoURL: String
    }
}
