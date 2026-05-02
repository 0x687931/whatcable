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
    private static let panelWidth: CGFloat = 320
    private static let fallbackPanelHeight: CGFloat = 420
    private static let screenPadding: CGFloat = 8
    private let cableStore = CableStateStore.shared

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
        if let appIcon = Self.appIconImage() {
            NSApp.applicationIconImage = appIcon
        }

        NotificationManager.shared.start()
        UpdateChecker.shared.start()
        observeCableStateForStatusItem()

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
                button.target = self
                button.action = #selector(handleClick(_:))
                button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            }
            statusItem = item
            updateStatusItemAppearance()
        }
    }

    private func observeCableStateForStatusItem() {
        Publishers.CombineLatest4(
            cableStore.$ports,
            cableStore.$sources,
            cableStore.$identities,
            cableStore.$devices
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in self?.updateStatusItemAppearance() }
        .store(in: &cancellables)
    }

    private func updateStatusItemAppearance() {
        guard let button = statusItem?.button else { return }
        let state = currentMenuBarState()

        button.image = Self.coloredSymbol(
            state.symbolName,
            color: state.symbolColor,
            accessibilityDescription: state.accessibilityLabel,
            pointSize: 15,
            weight: .semibold
        )
        button.contentTintColor = nil
        button.toolTip = state.help
        button.setAccessibilityLabel(state.accessibilityLabel)
        button.setAccessibilityValue(state.accessibilityValue)
    }

    private func currentMenuBarState() -> MenuBarState {
        let activePorts = cableStore.ports.filter { $0.connectionActive == true }
        if let warning = activePorts.compactMap(firstWarningDiagnostic(for:)).first {
            return MenuBarState(
                symbolName: "exclamationmark.triangle.fill",
                symbolColor: .systemOrange,
                help: warning.summary,
                accessibilityLabel: "\(AppInfo.name): charging issue",
                accessibilityValue: warning.summary
            )
        }
        if activePorts.contains(where: hasPowerSource) {
            return MenuBarState(
                symbolName: "bolt.fill",
                symbolColor: .systemGreen,
                help: "Power is connected",
                accessibilityLabel: "\(AppInfo.name): charging",
                accessibilityValue: "Power is connected"
            )
        }
        if !activePorts.isEmpty || !cableStore.devices.isEmpty {
            return MenuBarState(
                symbolName: "cable.connector",
                symbolColor: .controlAccentColor,
                help: "USB-C device connected",
                accessibilityLabel: "\(AppInfo.name): device connected",
                accessibilityValue: "USB-C device connected"
            )
        }
        return MenuBarState(
            symbolName: "powerplug",
            symbolColor: .secondaryLabelColor,
            help: "No USB-C device connected",
            accessibilityLabel: "\(AppInfo.name): idle",
            accessibilityValue: "No USB-C device connected"
        )
    }

    private func firstWarningDiagnostic(for port: USBCPort) -> ChargingDiagnostic? {
        guard let diagnostic = ChargingDiagnostic(
            port: port,
            sources: cableStore.sources(for: port),
            identities: cableStore.identities(for: port)
        ), diagnostic.isWarning else {
            return nil
        }
        return diagnostic
    }

    private func hasPowerSource(for port: USBCPort) -> Bool {
        !cableStore.sources(for: port).isEmpty
    }

    private static func coloredSymbol(
        _ symbolName: String,
        color: NSColor,
        accessibilityDescription: String,
        pointSize: CGFloat,
        weight: NSFont.Weight = .regular
    ) -> NSImage? {
        let sizeConfig = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        let colorConfig = NSImage.SymbolConfiguration(paletteColors: [color])
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityDescription)?
            .withSymbolConfiguration(sizeConfig)?
            .withSymbolConfiguration(colorConfig)
        image?.isTemplate = false
        return image
    }

    private static func appIconImage() -> NSImage? {
        if let bundledURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: bundledURL) {
            return image
        }

        let developmentURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("scripts/AppIcon.icns")
        if let image = NSImage(contentsOf: developmentURL) {
            return image
        }

        return NSImage(named: NSImage.applicationIconName)
    }

    private func buildMenuPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.panelWidth, height: Self.fallbackPanelHeight),
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
        let maxHeight = maxPanelHeight(
            below: panel.isVisible ? frame.maxY : nil,
            on: panel.screen
        )
        let clampedSize = clampedPanelSize(size, maxHeight: maxHeight)
        guard frame.size != clampedSize else { return }
        frame.size = clampedSize
        // Keep top edge anchored: origin.y + height stays constant.
        frame.origin.y += oldHeight - clampedSize.height
        panel.setFrame(frame, display: true, animate: panel.isVisible)
    }

    private func clampedPanelSize(_ preferred: NSSize, maxHeight: CGFloat) -> NSSize {
        let width = preferred.width > 0 ? preferred.width : Self.panelWidth
        let height = preferred.height > 0 ? preferred.height : Self.fallbackPanelHeight
        return NSSize(
            width: max(Self.panelWidth, width),
            height: min(height, maxHeight)
        )
    }

    private func maxPanelHeight(below topY: CGFloat? = nil, on screen: NSScreen?) -> CGFloat {
        let visibleFrame = (screen ?? NSScreen.main)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: Self.panelWidth, height: Self.fallbackPanelHeight)
        let anchoredTopY = topY ?? visibleFrame.maxY
        return max(1, anchoredTopY - visibleFrame.minY - Self.screenPadding)
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
        let buttonRectInWindow = button.convert(button.bounds, to: nil)
        let buttonRectInScreen = buttonWindow.convertToScreen(buttonRectInWindow)
        let maxHeight = maxPanelHeight(
            below: buttonRectInScreen.minY,
            on: buttonWindow.screen
        )
        let finalSize = clampedPanelSize(preferred, maxHeight: maxHeight)
        panel.setContentSize(finalSize)

        // Anchor flush below the status button: right edge aligned with the
        // button's right edge, top edge touching the bottom of the menu bar.
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
        menu.addItem(.init(title: "Check for Updates...", action: #selector(menuCheckUpdates), keyEquivalent: ""))
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
        let aboutText = """
        \(AppInfo.tagline)

        Built by \(AppInfo.credit).

        Open source attribution:
        Based on WhatCable by \(AppInfo.upstreamCredit).
        Original project: \(AppInfo.upstreamURL)
        License: MIT License.

        Third-party runtime libraries:
        None. WhatCable uses Apple system frameworks and SF Symbols.
        """
        let credits = NSAttributedString(
            string: aboutText,
            attributes: [
                .foregroundColor: NSColor.labelColor,
                .font: NSFont.systemFont(ofSize: 11)
            ]
        )
        var options: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationName: AppInfo.name,
            .applicationVersion: AppInfo.version,
            .version: "",
            .credits: credits,
            .init(rawValue: "Copyright"): AppInfo.copyright
        ]
        if let appIcon = Self.appIconImage() {
            options[.applicationIcon] = appIcon
        }
        NSApp.orderFrontStandardAboutPanel(options: options)
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

private struct MenuBarState {
    let symbolName: String
    let symbolColor: NSColor
    let help: String
    let accessibilityLabel: String
    let accessibilityValue: String
}
