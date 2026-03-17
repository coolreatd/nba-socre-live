import SwiftUI

struct GameDetailView: View {
    @Bindable var store: AppStore
    let game: Game
    @State private var selectedPlayer: PlayerGameSnapshot?

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    topBar
                    summaryCard
                    if game.status == .upcoming {
                        upcomingNoticeCard
                    } else {
                        statsCard
                        playersCard
                    }
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)

            if let snapshot = selectedPlayer {
                PlayerDetailOverlay(player: snapshot.player, team: snapshot.team) {
                    selectedPlayer = nil
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: selectedPlayer?.id)
    }

    private var topBar: some View {
        HStack {
            Button {
                store.showScoreboard()
            } label: {
                Label("返回", systemImage: "chevron.left")
            }
            .buttonStyle(.borderless)

            Spacer()

            Text(game.status.displayText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(game.status == .live ? .red : .secondary)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                teamSummary(game.awayTeam, score: game.awayScore, favored: store.isFavorite(teamID: game.awayTeam.id))
                Spacer()
                Text(":")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                teamSummary(game.homeTeam, score: game.homeScore, favored: store.isFavorite(teamID: game.homeTeam.id))
            }

            Text(game.statusLine)
                .font(.subheadline.weight(.medium))
            Text(game.headline)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func teamSummary(_ team: Team, score: Int, favored: Bool) -> some View {
        VStack(spacing: 8) {
            TeamBadgeView(team: team)
            Text(team.localizedName)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(team.canonicalAbbreviation)
                .font(.caption)
                .foregroundStyle(.secondary)
            if game.status != .upcoming {
                Text("\(score)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
            } else {
                Text(team.record?.displayText ?? "--")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                store.toggleFavorite(for: team.id)
            } label: {
                Label(favored ? "已收藏" : "收藏", systemImage: favored ? "star.fill" : "star")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("球队数据")
                .font(.headline)

            TeamStatComparisonRow(label: "篮板", awayValue: "\(game.awayTeamStats.rebounds)", homeValue: "\(game.homeTeamStats.rebounds)")
            TeamStatComparisonRow(label: "助攻", awayValue: "\(game.awayTeamStats.assists)", homeValue: "\(game.homeTeamStats.assists)")
            TeamStatComparisonRow(label: "命中率", awayValue: percentageText(game.awayTeamStats.fieldGoalPercentage), homeValue: percentageText(game.homeTeamStats.fieldGoalPercentage))
            TeamStatComparisonRow(label: "三分率", awayValue: percentageText(game.awayTeamStats.threePointPercentage), homeValue: percentageText(game.homeTeamStats.threePointPercentage))
            TeamStatComparisonRow(label: "失误", awayValue: "\(game.awayTeamStats.turnovers)", homeValue: "\(game.homeTeamStats.turnovers)")
        }
        .padding(16)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var upcomingNoticeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("比赛前瞻")
                .font(.headline)
            Text("比赛尚未开始，球队数据和球员明细会在开赛后展示。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("预计开赛时间：\(game.startTime.formatted(date: .omitted, time: .shortened))")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var playersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(PlayerMetricLabel.sectionTitle)
                    .font(.headline)
                Spacer()
                Picker("球队", selection: $store.selectedPlayerFilter) {
                    Text(PlayerMetricLabel.allTeams).tag(PlayerGroupFilter.all)
                    Text(PlayerMetricLabel.awayTeam).tag(PlayerGroupFilter.away)
                    Text(PlayerMetricLabel.homeTeam).tag(PlayerGroupFilter.home)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            ForEach(store.players(for: game, filter: store.selectedPlayerFilter)) { player in
                Button {
                    selectedPlayer = PlayerGameSnapshot(
                        player: player,
                        team: player.teamID == game.homeTeam.id ? game.homeTeam : game.awayTeam
                    )
                } label: {
                    PlayerStatRow(
                        player: player,
                        team: player.teamID == game.homeTeam.id ? game.homeTeam : game.awayTeam
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func percentageText(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(1))))%"
    }
}

private struct PlayerGameSnapshot: Identifiable {
    let player: PlayerStat
    let team: Team

    var id: String {
        "\(team.id)-\(player.id)"
    }
}

private struct TeamStatComparisonRow: View {
    let label: String
    let awayValue: String
    let homeValue: String

    var body: some View {
        HStack {
            Text(awayValue)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(homeValue)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.subheadline.monospacedDigit())
    }
}

private struct PlayerStatRow: View {
    let player: PlayerStat
    let team: Team

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                HStack(alignment: .top, spacing: 10) {
                    PlayerHeadshotView(player: player)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(player.playerName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text(subtitleText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(player.points)分")
                            .font(.title3.monospacedDigit().weight(.black))
                            .foregroundStyle(.primary)
                        Text("\(player.rebounds)板 \(player.assists)助")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary.opacity(0.72))
                    }
                    .frame(minWidth: 62, alignment: .trailing)

                    HStack(spacing: 4) {
                        Text("详细")
                            .font(.caption2.weight(.semibold))
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(.tertiary)
                }
            }

            HStack {
                MetricPill(title: PlayerMetricLabel.fieldGoal, value: player.fieldGoalText)
                MetricPill(title: PlayerMetricLabel.threePoint, value: player.threePointText)
                MetricPill(title: PlayerMetricLabel.plusMinus, value: player.plusMinus >= 0 ? "+\(player.plusMinus)" : "\(player.plusMinus)")
                MetricPill(title: PlayerMetricLabel.steals, value: "\(player.steals)")
                MetricPill(title: PlayerMetricLabel.blocks, value: "\(player.blocks)")
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.08))
        )
    }

    private var subtitleText: String {
        "\(team.localizedName) · \(player.localizedPosition) · #\(player.jerseyNumber) · \(player.minutes)"
    }
}

private struct PlayerDetailOverlay: View {
    let player: PlayerStat
    let team: Team
    let onClose: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.24))
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 12) {
                    headerCard
                    metricsCard
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: 398)
            .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(alignment: .topTrailing) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .frame(width: 28, height: 28)
                        .background(Color.primary.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(10)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.primary.opacity(0.08))
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private var headerCard: some View {
        HStack(alignment: .top, spacing: 10) {
            PlayerHeadshotView(player: player, size: 56)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(player.playerName)
                        .font(.title3.weight(.bold))
                    if player.isStarter {
                        Text("首发")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.16), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                }

                Text("\(team.localizedName) · \(player.localizedPosition) · #\(player.jerseyNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    SheetHighlightStat(title: PlayerMetricLabel.minutes, value: player.minutes)
                    SheetHighlightStat(title: PlayerMetricLabel.points, value: "\(player.points)")
                    SheetHighlightStat(title: PlayerMetricLabel.rebounds, value: "\(player.rebounds)")
                    SheetHighlightStat(title: PlayerMetricLabel.assists, value: "\(player.assists)")
                }
            }

            Spacer()
        }
        .padding(12)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var metricsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            detailSection(title: "投篮明细", metrics: [
                (PlayerMetricLabel.fieldGoal, player.fieldGoalText),
                (PlayerMetricLabel.fieldGoalPercentage, player.fieldGoalPercentageText),
                (PlayerMetricLabel.threePoint, player.threePointText),
                (PlayerMetricLabel.threePointPercentage, player.threePointPercentageText),
                (PlayerMetricLabel.freeThrow, player.freeThrowText),
                (PlayerMetricLabel.freeThrowPercentage, player.freeThrowPercentageText)
            ])

            Divider()

            detailSection(title: "比赛影响", metrics: [
                (PlayerMetricLabel.offensiveRebounds, "\(player.offensiveRebounds)"),
                (PlayerMetricLabel.defensiveRebounds, "\(player.defensiveRebounds)"),
                (PlayerMetricLabel.rebounds, "\(player.rebounds)"),
                (PlayerMetricLabel.assists, "\(player.assists)"),
                (PlayerMetricLabel.steals, "\(player.steals)"),
                (PlayerMetricLabel.blocks, "\(player.blocks)"),
                (PlayerMetricLabel.turnovers, "\(player.turnovers)"),
                (PlayerMetricLabel.fouls, "\(player.fouls)"),
                (PlayerMetricLabel.plusMinus, player.plusMinus >= 0 ? "+\(player.plusMinus)" : "\(player.plusMinus)")
            ])
        }
        .padding(12)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func detailSection(title: String, metrics: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(metrics.enumerated()), id: \.offset) { _, metric in
                    DetailMetricCard(title: metric.0, value: metric.1)
                }
            }
        }
    }
}

private struct PlayerHeadshotView: View {
    let player: PlayerStat
    var size: CGFloat = 42

    var body: some View {
        Group {
            if !player.headshotImageURLs.isEmpty {
                CachedRemoteImage(urls: player.headshotImageURLs, contentMode: .fill) {
                    placeholder
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var placeholder: some View {
        ZStack {
            Circle()
                .fill(Color.secondary.opacity(0.12))
            Image(systemName: "person.fill")
                .font(.system(size: size * 0.35, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

private struct DetailMetricCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text(value)
                .font(.footnote.monospacedDigit().weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SheetHighlightStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.footnote.monospacedDigit().weight(.semibold))
        }
    }
}

private struct MetricPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
