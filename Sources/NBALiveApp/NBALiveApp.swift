import AppKit
import SwiftUI

@main
struct NBALiveApp: App {
    @State private var store = AppStore()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra(store.menuBarTitle, systemImage: store.menuBarSymbol) {
            MenuRootView(store: store)
                .frame(width: 430, height: 640)
                .task {
                    store.start()
                }
        }
        .menuBarExtraStyle(.window)
    }
}
