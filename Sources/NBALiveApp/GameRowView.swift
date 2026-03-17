import SwiftUI

struct GameRowView: View {
    let game: Game
    let isHomeFavorite: Bool
    let isAwayFavorite: Bool
    let onToggleFavorite: (String) -> Void
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    statusBadge
                    Spacer()
                    Text(game.statusLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                teamLine(team: game.awayTeam, score: game.awayScore, isFavorite: isAwayFavorite)
                teamLine(team: game.homeTeam, score: game.homeScore, isFavorite: isHomeFavorite)

                Text(game.headline)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func teamLine(team: Team, score: Int, isFavorite: Bool) -> some View {
        HStack(spacing: 10) {
            TeamBadgeView(team: team)
            VStack(alignment: .leading, spacing: 2) {
                Text(team.localizedName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(teamMetaText(team))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if game.status != .upcoming {
                Text("\(score)")
                    .font(.title3.monospacedDigit().weight(.bold))
                    .foregroundStyle(scoreColor(for: team.id))
            }

            Button {
                onToggleFavorite(team.id)
            } label: {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundStyle(isFavorite ? .yellow : .secondary)
            }
            .buttonStyle(.borderless)
        }
    }

    private var statusBadge: some View {
        Text(game.status.displayText)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(statusColor.opacity(0.15), in: Capsule())
            .foregroundStyle(statusColor)
    }

    private var statusColor: Color {
        switch game.status {
        case .upcoming:
            .blue
        case .live:
            .red
        case .final:
            .green
        }
    }

    private var cardBackground: Color {
        switch game.status {
        case .upcoming:
            Color.blue.opacity(0.06)
        case .live:
            Color.red.opacity(0.08)
        case .final:
            Color.green.opacity(0.06)
        }
    }

    private func scoreColor(for teamID: String) -> Color {
        game.dominantTeamID == teamID ? .primary : .secondary
    }

    private func teamMetaText(_ team: Team) -> String {
        let recordText = team.record?.displayText ?? "--"
        if let rank = team.conferenceRank {
            return "战绩 \(recordText) · 分区第\(rank)"
        }
        return "战绩 \(recordText)"
    }
}

struct TeamBadgeView: View {
    let team: Team

    var body: some View {
        Group {
            if let logoURL = team.logoURL {
                CachedRemoteImage(url: logoURL, contentMode: .fit) {
                    fallbackBadge
                }
            } else {
                fallbackBadge
            }
        }
        .frame(width: 38, height: 38)
    }

    private var fallbackBadge: some View {
        ZStack {
            Circle()
                .fill(Color.secondary.opacity(0.12))
            Text(team.canonicalAbbreviation)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
        }
    }
}
