import SwiftUI
import AppKit
import Combine

@main
struct WhatCableApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // Headless — UI is owned by AppDelegate (status item + popover, or
        // a regular window, depending on AppSettings.useMenuBarMode).
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, NSWindowDelegate {
    static let refreshSignal = RefreshSignal()

    // Menu bar mode
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var isPinned = false

    // Window mode
    private var window: NSWindow?

    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Override the process name so the About panel and menus use the
        // app name even though the SwiftPM executable name might differ.
        ProcessInfo.processInfo.setValue(AppInfo.name, forKey: "processName")

        NotificationManager.shared.start()
        UpdateChecker.shared.start()

        applyDisplayMode(menuBar: AppSettings.shared.useMenuBarMode)

        // Live-switch when the user flips the toggle in Settings.
        AppSettings.shared.$useMenuBarMode
            .removeDuplicates()
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] menuBar in
                self?.applyDisplayMode(menuBar: menuBar)
            }
            .store(in: &cancellables)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // In window mode, closing the window quits the app. In menu bar mode
        // there's no window to close, so this is harmless either way.
        !AppSettings.shared.useMenuBarMode
    }

    // MARK: - Display mode

    private func applyDisplayMode(menuBar: Bool) {
        if menuBar {
            tearDownWindowMode()
            setUpMenuBarMode()
            NSApp.setActivationPolicy(.accessory)
        } else {
            tearDownMenuBarMode()
            NSApp.setActivationPolicy(.regular)
            setUpWindowMode()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func setUpMenuBarMode() {
        if popover == nil {
            let p = NSPopover()
            p.behavior = isPinned ? .applicationDefined : .transient
            p.animates = true
            p.contentSize = NSSize(width: 320, height: 520)
            p.contentViewController = NSHostingController(
                rootView: ContentView().environmentObject(Self.refreshSignal)
            )
            p.delegate = self
            popover = p
        }
        if statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let button = item.button {
                button.image = NSImage(systemSymbolName: "cable.connector", accessibilityDescription: AppInfo.name)
                button.target = self
                button.action = #selector(handleClick(_:))
                button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            }
            statusItem = item
        }
    }

    private func tearDownMenuBarMode() {
        if let popover, popover.isShown { popover.performClose(nil) }
        popover = nil
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
    }

    private func setUpWindowMode() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let host = NSHostingController(
            rootView: ContentView().environmentObject(Self.refreshSignal)
        )
        let w = NSWindow(contentViewController: host)
        w.title = AppInfo.name
        w.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        w.setContentSize(NSSize(width: 320, height: 520))
        w.minSize = NSSize(width: 320, height: 420)
        w.center()
        w.delegate = self
        w.isReleasedWhenClosed = false
        window = w
        w.makeKeyAndOrderFront(nil)
    }

    private func tearDownWindowMode() {
        window?.delegate = nil
        window?.close()
        window = nil
    }

    // MARK: - Status item handling (menu bar mode)

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showMenu(from: sender)
        } else {
            togglePopover(from: sender)
        }
    }

    private func togglePopover(from button: NSStatusBarButton) {
        guard let popover else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            Self.refreshSignal.bump()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showMenu(from button: NSStatusBarButton) {
        guard let statusItem else { return }
        let menu = NSMenu()
        menu.addItem(.init(title: "Refresh", action: #selector(menuRefresh), keyEquivalent: "r"))
        let pinItem = NSMenuItem(title: "Keep window open", action: #selector(menuTogglePin), keyEquivalent: "p")
        pinItem.state = isPinned ? .on : .off
        menu.addItem(pinItem)
        menu.addItem(.separator())
        menu.addItem(.init(title: "Check for Updates…", action: #selector(menuCheckUpdates), keyEquivalent: ""))
        menu.addItem(.init(title: "About \(AppInfo.name)", action: #selector(menuAbout), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(.init(title: "Quit \(AppInfo.name)", action: #selector(menuQuit), keyEquivalent: "q"))
        for item in menu.items where item.action != nil { item.target = self }

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func menuTogglePin() {
        isPinned.toggle()
        popover?.behavior = isPinned ? .applicationDefined : .transient
    }

    @objc private func menuRefresh() {
        Self.refreshSignal.bump()
    }

    @objc private func menuAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let credits = NSAttributedString(
            string: "\(AppInfo.tagline)\n\nBuilt by \(AppInfo.credit).",
            attributes: [
                .foregroundColor: NSColor.labelColor,
                .font: NSFont.systemFont(ofSize: 11)
            ]
        )
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: AppInfo.name,
            .applicationVersion: AppInfo.version,
            .version: "",
            .credits: credits,
            .init(rawValue: "Copyright"): AppInfo.copyright
        ])
    }

    @objc private func menuCheckUpdates() {
        UpdateChecker.shared.check(silent: false)
    }

    @objc private func menuQuit() {
        NSApp.terminate(nil)
    }
}

final class RefreshSignal: ObservableObject {
    @Published var tick: Int = 0
    func bump() { tick &+= 1 }
}
