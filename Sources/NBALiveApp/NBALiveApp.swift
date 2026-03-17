import AppKit
import Observation
import SwiftUI

@main
struct NBALiveApp: App {
    @NSApplicationDelegateAdaptor(NBALiveAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
                .frame(width: 0, height: 0)
        }
    }
}

@MainActor
final class NBALiveAppDelegate: NSObject, NSApplicationDelegate {
    private let store = AppStore()
    private var statusController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        statusController = StatusBarController(store: store)
        store.start()
    }
}

@MainActor
private final class StatusBarController: NSObject {
    private let store: AppStore
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let contextMenu = NSMenu()

    init(store: AppStore) {
        self.store = store
        super.init()
        configurePopover()
        configureStatusItem()
        configureContextMenu()
        updateStatusItemAppearance()
        observeStatusItemPresentation()
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 430, height: 640)
        popover.contentViewController = NSHostingController(
            rootView: MenuRootView(store: store)
                .frame(width: 430, height: 640)
        )
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configureContextMenu() {
        contextMenu.autoenablesItems = false

        let openItem = NSMenuItem(title: "打开 NBA Live", action: #selector(openFromMenu), keyEquivalent: "")
        openItem.target = self
        contextMenu.addItem(openItem)

        let refreshItem = NSMenuItem(title: "立即刷新", action: #selector(refreshFromMenu), keyEquivalent: "")
        refreshItem.target = self
        contextMenu.addItem(refreshItem)

        let settingsItem = NSMenuItem(title: "设置", action: #selector(openSettingsFromMenu), keyEquivalent: "")
        settingsItem.target = self
        contextMenu.addItem(settingsItem)

        contextMenu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出", action: #selector(quitFromMenu), keyEquivalent: "q")
        quitItem.target = self
        contextMenu.addItem(quitItem)
    }

    private func updateStatusItemAppearance() {
        guard let button = statusItem.button else { return }
        button.title = ""
        button.image = NSImage(systemSymbolName: store.menuBarSymbol, accessibilityDescription: "NBA Live")
        button.imagePosition = .imageOnly
        button.appearsDisabled = false
    }

    private func observeStatusItemPresentation() {
        withObservationTracking {
            _ = store.menuBarTitle
            _ = store.menuBarSymbol
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.updateStatusItemAppearance()
                self?.observeStatusItemPresentation()
            }
        }
    }

    @objc
    private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            togglePopover(relativeTo: sender)
            return
        }

        switch event.type {
        case .rightMouseUp:
            showContextMenu()
        default:
            togglePopover(relativeTo: sender)
        }
    }

    private func togglePopover(relativeTo button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showContextMenu() {
        statusItem.menu = contextMenu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc
    private func openFromMenu() {
        popover.performClose(nil)
        if let button = statusItem.button {
            togglePopover(relativeTo: button)
        }
    }

    @objc
    private func refreshFromMenu() {
        Task {
            await store.refreshNow()
        }
    }

    @objc
    private func openSettingsFromMenu() {
        store.openSettings()
        popover.performClose(nil)
        if let button = statusItem.button {
            togglePopover(relativeTo: button)
        }
    }

    @objc
    private func quitFromMenu() {
        NSApplication.shared.terminate(nil)
    }
}
