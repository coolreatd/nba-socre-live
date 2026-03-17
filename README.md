# NBA Live

一个基于 SwiftUI + Swift Package Manager 构建的 macOS 菜单栏应用，用来查看 NBA 比赛列表、单场详情、球员数据，以及未来赛程。

## 功能

- 菜单栏常驻，点击即可查看当天或指定日期的 NBA 赛程
- 比赛列表支持收藏球队过滤
- 单场详情支持球队数据、球员数据、球员详情弹层
- 日期选择支持过去 30 天和未来 14 天
- 未来比赛详情会展示前瞻信息，不显示未开赛的球队数据
- 支持配置 HTTP(S) / SOCKS5 代理，并提供代理连通性测试
- 支持使用 ESPN 公共接口，也支持本地 Mock 数据源

## 环境要求

- macOS 14+
- Xcode 16+ 或支持 Swift 6.2 的工具链

## 本地运行

```bash
swift run NBALiveApp
```

## 测试

```bash
swift test
```

## 数据源

默认使用 ESPN 公共接口。

如果需要切换到本地 Mock 数据源：

```bash
NBA_LIVE_USE_MOCK=1 swift run NBALiveApp
```

## 代理配置

应用内设置页已支持：

- 启用/关闭代理
- 选择 `HTTP(S)` 或 `SOCKS5`
- 设置主机与端口
- 测试代理连通性
- 应用后立即刷新数据

常见示例：

- `127.0.0.1:7890`
- `127.0.0.1:1080`

## 项目结构

```text
Sources/NBALiveApp/
  AppStore.swift               状态管理与设置持久化
  Providers.swift              ESPN / Mock 数据源
  MenuRootView.swift           主界面与日期选择
  GameDetailView.swift         比赛详情与球员详情
  SettingsView.swift           设置页
  RemoteImageCache.swift       远程图片缓存
  ProxySettings.swift          代理配置模型
  ProxyConnectivityTester.swift 代理连通性测试
Tests/NBALiveAppTests/
  AppStoreTests.swift
```

## 当前状态

当前版本已包含：

- 比赛列表与详情
- 球员头像加载兜底
- 自定义大号日期选择器
- 代理配置与连通性测试
- 单元测试基础覆盖
