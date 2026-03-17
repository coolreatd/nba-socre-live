import SwiftUI

struct MenuRootView: View {
    @Bindable var store: AppStore
    @State private var showsCalendarPicker = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ZStack {
                content

                if let loadingMessage = store.loadingMessage {
                    LoadingOverlay(message: loadingMessage)
                        .transition(.opacity)
                }
            }
            .clipped()
            .animation(.snappy(duration: 0.22, extraBounce: 0.02), value: store.currentScreen)
            .animation(.easeInOut(duration: 0.18), value: store.loadingMessage)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(titleText)
                        .font(.headline)
                    Text(subtitleText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    Task {
                        await store.refreshNow()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("立即刷新")

                Button {
                    store.openSettings()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .buttonStyle(.borderless)
                .help("设置")
            }

            if store.currentScreen == .scoreboard {
                scoreboardDateBar
            }

            Toggle("只看收藏球队", isOn: Binding(
                get: { store.showsFavoritesOnly },
                set: { store.setFavoritesOnly($0) }
            ))
            .toggleStyle(.switch)
            .font(.caption)
        }
        .padding(16)
    }

    private var scoreboardDateBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                dateStepButton(systemName: "chevron.left", enabled: store.canStepBackwardDate) {
                    store.stepDate(by: -1)
                }

                Button {
                    showsCalendarPicker.toggle()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.subheadline.weight(.semibold))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(store.selectedDateTitle)
                                .font(.body.weight(.semibold))
                            Text(store.selectedDateSubtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showsCalendarPicker, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("选择日期")
                                .font(.title3.weight(.bold))
                            Text("支持查看未来 14 天赛程")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        LargeCalendarPicker(
                            selection: Binding(
                                get: { store.selectedDate },
                                set: {
                                    store.setSelectedDate($0)
                                    showsCalendarPicker = false
                                }
                            ),
                            selectableRange: store.selectableDateRange
                        )

                        HStack(spacing: 10) {
                            quickDateButton("今天") {
                                store.setSelectedDate(.now)
                                showsCalendarPicker = false
                            }
                            quickDateButton("昨天") {
                                store.stepDate(by: -1)
                                showsCalendarPicker = false
                            }
                            quickDateButton("明天") {
                                store.stepDate(by: 1)
                                showsCalendarPicker = false
                            }
                            Spacer()
                        }
                    }
                    .padding(20)
                    .frame(width: 392)
                }

                dateStepButton(systemName: "chevron.right", enabled: store.canStepForwardDate) {
                    store.stepDate(by: 1)
                }
            }
        }
    }

    private func dateStepButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.subheadline.weight(.bold))
                .frame(width: 36, height: 36)
                .background(Color.primary.opacity(enabled ? 0.08 : 0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .foregroundStyle(enabled ? Color.primary : Color.secondary)
    }

    private func quickDateButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .controlSize(.regular)
    }

    @ViewBuilder
    private var content: some View {
        switch store.currentScreen {
        case .scoreboard:
            ScoreboardView(store: store)
                .id("scoreboard")
                .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .opacity))
        case let .detail(gameID):
            if let game = store.games.first(where: { $0.id == gameID }) {
                GameDetailView(store: store, game: game)
                    .id("detail-\(gameID)")
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            } else {
                unavailableView("比赛已不存在")
            }
        case .settings:
            SettingsView(store: store)
                .id("settings")
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
        }
    }

    private func unavailableView(_ title: String) -> some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.headline)
            Button("返回") {
                store.showScoreboard()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var titleText: String {
        switch store.currentScreen {
        case .scoreboard:
            "NBA Live"
        case .detail:
            "比赛详情"
        case .settings:
            "设置"
        }
    }

    private var subtitleText: String {
        if let updated = store.lastUpdated {
            return "最近更新 \(updated.formatted(date: .omitted, time: .standard))"
        }
        return "等待首次刷新"
    }
}

private struct LoadingOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                ProgressView()
                    .controlSize(.regular)
                Text(message)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.92), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.08))
            )
        }
    }
}

private struct LargeCalendarPicker: View {
    @Binding var selection: Date
    let selectableRange: ClosedRange<Date>

    @State private var visibleMonth: Date

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = .current
        calendar.firstWeekday = 1
        return calendar
    }

    private let weekdaySymbols = ["日", "一", "二", "三", "四", "五", "六"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    init(selection: Binding<Date>, selectableRange: ClosedRange<Date>) {
        _selection = selection
        self.selectableRange = selectableRange

        let calendar = {
            var calendar = Calendar(identifier: .gregorian)
            calendar.locale = Locale(identifier: "zh_CN")
            calendar.timeZone = .current
            calendar.firstWeekday = 1
            return calendar
        }()
        let month = calendar.date(from: calendar.dateComponents([.year, .month], from: selection.wrappedValue))
            ?? selection.wrappedValue
        _visibleMonth = State(initialValue: month)
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Button {
                    shiftMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 30, height: 30)
                        .background(Color.primary.opacity(canShiftMonth(by: -1) ? 0.08 : 0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canShiftMonth(by: -1))

                Spacer()

                Text(monthTitle)
                    .font(.title3.weight(.bold))
                    .monospacedDigit()

                Spacer()

                Button {
                    shiftMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 30, height: 30)
                        .background(Color.primary.opacity(canShiftMonth(by: 1) ? 0.08 : 0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canShiftMonth(by: 1))
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(monthGridDates, id: \.self) { date in
                    calendarCell(for: date)
                }
            }
        }
        .padding(16)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onChange(of: selection) { _, newValue in
            visibleMonth = startOfMonth(for: newValue)
        }
    }

    private var monthTitle: String {
        visibleMonth.formatted(.dateTime.year().month(.wide))
    }

    private var monthGridDates: [Date] {
        let monthStart = startOfMonth(for: visibleMonth)
        guard let monthRange = calendar.range(of: .day, in: .month, for: monthStart),
              let gridStart = calendar.date(byAdding: .day, value: -(calendar.component(.weekday, from: monthStart) - calendar.firstWeekday + 7) % 7, to: monthStart),
              let lastDay = calendar.date(byAdding: .day, value: monthRange.count - 1, to: monthStart),
              let gridEnd = calendar.date(byAdding: .day, value: 41, to: gridStart) else {
            return []
        }

        let lastVisibleDate = max(lastDay, gridEnd)
        let totalDays = calendar.dateComponents([.day], from: gridStart, to: lastVisibleDate).day ?? 41
        return (0 ... totalDays).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: gridStart)
        }
    }

    @ViewBuilder
    private func calendarCell(for date: Date) -> some View {
        let isCurrentMonth = calendar.isDate(date, equalTo: visibleMonth, toGranularity: .month)
        let isSelected = calendar.isDate(date, inSameDayAs: selection)
        let isEnabled = selectableRange.contains(calendar.startOfDay(for: date))

        Button {
            guard isEnabled else { return }
            selection = calendar.startOfDay(for: date)
        } label: {
            Text("\(calendar.component(.day, from: date))")
                .font(.body.monospacedDigit().weight(isSelected ? .bold : .semibold))
                .foregroundStyle(foregroundStyle(isSelected: isSelected, isCurrentMonth: isCurrentMonth, isEnabled: isEnabled))
                .frame(width: 36, height: 36)
                .background(backgroundStyle(isSelected: isSelected, isEnabled: isEnabled))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .frame(maxWidth: .infinity)
    }

    private func foregroundStyle(isSelected: Bool, isCurrentMonth: Bool, isEnabled: Bool) -> Color {
        if isSelected {
            return .white
        }
        if !isEnabled {
            return .secondary.opacity(0.3)
        }
        return isCurrentMonth ? .primary : .secondary
    }

    private func backgroundStyle(isSelected: Bool, isEnabled: Bool) -> Color {
        if isSelected {
            return .accentColor
        }
        if !isEnabled {
            return .clear
        }
        return Color.primary.opacity(0.06)
    }

    private func canShiftMonth(by offset: Int) -> Bool {
        guard let nextMonth = calendar.date(byAdding: .month, value: offset, to: visibleMonth) else {
            return false
        }
        let monthStart = startOfMonth(for: nextMonth)
        let lowerMonth = startOfMonth(for: selectableRange.lowerBound)
        let upperMonth = startOfMonth(for: selectableRange.upperBound)
        return monthStart >= lowerMonth && monthStart <= upperMonth
    }

    private func shiftMonth(by offset: Int) {
        guard canShiftMonth(by: offset),
              let nextMonth = calendar.date(byAdding: .month, value: offset, to: visibleMonth) else {
            return
        }
        visibleMonth = startOfMonth(for: nextMonth)
    }

    private func startOfMonth(for date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }
}

private struct ScoreboardView: View {
    @Bindable var store: AppStore

    var body: some View {
        Group {
            if store.isLoading && store.games.isEmpty {
                ProgressView("正在拉取比赛数据")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = store.errorMessage, store.games.isEmpty {
                VStack(spacing: 12) {
                    Text(errorMessage)
                        .multilineTextAlignment(.center)
                    Button("重试") {
                        Task {
                            await store.refreshNow()
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.filteredGames.isEmpty {
                VStack(spacing: 12) {
                    Text("没有匹配的比赛")
                        .font(.headline)
                    Text("可以先关闭“只看收藏球队”，或收藏一支球队。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if let errorMessage = store.errorMessage {
                            ErrorBanner(message: errorMessage)
                        }

                        ForEach(store.filteredGames) { game in
                            GameRowView(
                                game: game,
                                isHomeFavorite: store.isFavorite(teamID: game.homeTeam.id),
                                isAwayFavorite: store.isFavorite(teamID: game.awayTeam.id),
                                onToggleFavorite: { teamID in store.toggleFavorite(for: teamID) },
                                onOpen: { store.openGame(game) }
                            )
                        }
                    }
                    .padding(16)
                }
            }
        }
    }
}

private struct ErrorBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }
}
