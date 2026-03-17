import SwiftUI

struct SettingsView: View {
    @Bindable var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Button {
                    store.showScoreboard()
                } label: {
                    Label("返回", systemImage: "chevron.left")
                }
                .buttonStyle(.borderless)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("刷新频率")
                    .font(.headline)

                Picker("刷新频率", selection: Binding(
                    get: { Int(store.refreshInterval) },
                    set: { store.setRefreshInterval(TimeInterval($0)) }
                )) {
                    Text("15 秒").tag(15)
                    Text("20 秒").tag(20)
                    Text("30 秒").tag(30)
                    Text("60 秒").tag(60)
                }
                .pickerStyle(.segmented)

                Text("当没有进行中的比赛时，应用会自动降低刷新频率以节省资源。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("提醒与过滤")
                    .font(.headline)

                Toggle("开启系统通知（预留开关）", isOn: Binding(
                    get: { store.notificationsEnabled },
                    set: { store.setNotificationsEnabled($0) }
                ))

                Toggle("默认只看收藏球队", isOn: Binding(
                    get: { store.showsFavoritesOnly },
                    set: { store.setFavoritesOnly($0) }
                ))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("数据源")
                    .font(.headline)
                Text(store.dataSourceDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("代理设置")
                    .font(.headline)

                Toggle("启用代理", isOn: Binding(
                    get: { store.proxySettings.isEnabled },
                    set: { store.setProxyEnabled($0) }
                ))
                .disabled(!store.canEditProxySettings)

                Picker("代理类型", selection: Binding(
                    get: { store.proxySettings.type },
                    set: { store.setProxyType($0) }
                )) {
                    ForEach(ProxyType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!store.canEditProxySettings || !store.proxySettings.isEnabled)

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("主机")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField("127.0.0.1", text: Binding(
                            get: { store.proxySettings.host },
                            set: { store.setProxyHost($0) }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .disabled(!store.canEditProxySettings || !store.proxySettings.isEnabled)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("端口")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField("7890", text: Binding(
                            get: { store.proxySettings.portText },
                            set: { store.setProxyPortText($0.filter(\.isNumber)) }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 92)
                        .disabled(!store.canEditProxySettings || !store.proxySettings.isEnabled)
                    }
                }

                HStack {
                    Text(store.proxySettingsDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(store.isTestingProxyConnectivity ? "测试中..." : "测试代理") {
                        Task {
                            await store.testProxyConnectivity()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!store.canTestProxyConnectivity)

                    Button("应用代理") {
                        store.applyProxySettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(!store.canEditProxySettings || !store.canApplyProxySettings)
                }

                if let validationMessage = store.proxySettings.validationMessage,
                   store.proxySettings.isEnabled,
                   store.canEditProxySettings {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if let feedbackMessage = store.proxyFeedbackMessage {
                    Text(feedbackMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let connectivityMessage = store.proxyConnectivityMessage {
                    Text(connectivityMessage)
                        .font(.caption)
                        .foregroundStyle(connectivityMessage.contains("成功") || connectivityMessage.contains("正常") || connectivityMessage.contains("可用") ? .green : .secondary)
                }

                if !store.canEditProxySettings {
                    Text("当前数据源不支持应用代理配置。Mock 模式下会保留设置，但不会走代理。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("支持 HTTP(S) 和 SOCKS5 代理，例如 127.0.0.1:7890。应用后会立即刷新数据。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("当前 MVP")
                    .font(.headline)
                Text("已包含菜单栏常驻、比赛列表、单场详情、球员数据、收藏球队和自动刷新。默认走 ESPN 公共接口；设置环境变量 NBA_LIVE_USE_MOCK=1 可以切回本地模拟数据。")
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
    }
}
