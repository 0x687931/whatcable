import SwiftUI
import AppKit
import Combine

@main
struct WhatCableApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // Headless — UI is owned by AppDelegate (status item + menu panel, or
        // a regular window, depending on AppSettings.useMenuBarMode).
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static let refreshSignal = RefreshSignal()

    // Menu bar mode
    private var statusItem: NSStatusItem?
    private var menuPanel: NSPanel?
    private var hostingController: NSHostingController<AnyView>?
    private var contentSizeObservation: NSKeyValueObservation?
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    private var isPinned = false

    // Window mode
    private var window: NSWindow?

    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.setValue(AppInfo.name, forKey: "processName")

        NotificationManager.shared.start()
        UpdateChecker.shared.start()

        applyDisplayMode(menuBar: AppSettings.shared.useMenuBarMode)

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
        if menuPanel == nil {
            buildMenuPanel()
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

    private func buildMenuPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 520),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isMovable = false
        panel.isReleasedWhenClosed = false

        // SwiftUI owns the Liquid Glass background via `.glassEffect(...)` in
        // ContentView. The panel itself is a transparent host; the rounded-rect
        // glass shape provides the visible chrome and the panel shadow follows
        // the content alpha.
        let controller = NSHostingController(
            rootView: AnyView(ContentView().environmentObject(Self.refreshSignal))
        )
        controller.sizingOptions = .preferredContentSize
        panel.contentViewController = controller

        // Track SwiftUI's preferred content size so the panel grows/shrinks as
        // the user toggles "Show technical details" or expands a port detail
        // accordion — keeping the top edge anchored to the menu bar.
        contentSizeObservation = controller.observe(
            \.preferredContentSize, options: [.new]
        ) { [weak self] _, change in
            guard let new = change.newValue, new.width > 0, new.height > 0 else { return }
            Task { @MainActor [weak self] in self?.syncPanelSize(to: new) }
        }

        self.menuPanel = panel
        self.hostingController = controller
    }

    private func syncPanelSize(to size: NSSize) {
        guard let panel = menuPanel else { return }
        var frame = panel.frame
        let oldHeight = frame.size.height
        guard frame.size != size else { return }
        frame.size = size
        // Keep top edge anchored: origin.y + height stays constant.
        frame.origin.y += oldHeight - size.height
        panel.setFrame(frame, display: true, animate: panel.isVisible)
    }

    private func tearDownMenuBarMode() {
        hideMenuPanel()
        contentSizeObservation?.invalidate()
        contentSizeObservation = nil
        menuPanel?.orderOut(nil)
        menuPanel = nil
        hostingController = nil
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
            togglePanel(from: sender)
        }
    }

    private func togglePanel(from button: NSStatusBarButton) {
        guard let panel = menuPanel else { return }
        if panel.isVisible {
            hideMenuPanel()
        } else {
            showMenuPanel(from: button)
        }
    }

    private func showMenuPanel(from button: NSStatusBarButton) {
        guard let panel = menuPanel,
              let controller = hostingController,
              let buttonWindow = button.window else { return }

        Self.refreshSignal.bump()

        // Size the panel to SwiftUI's preferred content size before showing.
        controller.view.layoutSubtreeIfNeeded()
        let preferred = controller.preferredContentSize
        let finalSize = NSSize(
            width: preferred.width > 0 ? preferred.width : 320,
            height: preferred.height > 0 ? preferred.height : 420
        )
        panel.setContentSize(finalSize)

        // Anchor flush below the status button: right edge aligned with the
        // button's right edge, top edge touching the bottom of the menu bar.
        let buttonRectInWindow = button.convert(button.bounds, to: nil)
        let buttonRectInScreen = buttonWindow.convertToScreen(buttonRectInWindow)
        let originX = buttonRectInScreen.maxX - finalSize.width
        let originY = buttonRectInScreen.minY - finalSize.height
        panel.setFrameOrigin(NSPoint(x: originX, y: originY))

        panel.makeKeyAndOrderFront(nil)
        button.highlight(true)
        installEventMonitors()
    }

    private func hideMenuPanel() {
        menuPanel?.orderOut(nil)
        statusItem?.button?.highlight(false)
        removeEventMonitors()
    }

    private func installEventMonitors() {
        removeEventMonitors()
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            guard let self else { return }
            if !self.isPinned { self.hideMenuPanel() }
        }
        localEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown]
        ) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.hideMenuPanel()
                return nil
            }
            return event
        }
    }

    private func removeEventMonitors() {
        if let m = globalEventMonitor { NSEvent.removeMonitor(m); globalEventMonitor = nil }
        if let m = localEventMonitor  { NSEvent.removeMonitor(m);  localEventMonitor = nil  }
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
