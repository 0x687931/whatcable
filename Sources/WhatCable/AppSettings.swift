import Foundation
import ServiceManagement
import os.log

/// User-facing preferences, persisted in UserDefaults and (where relevant)
/// reflected into system services like SMAppService.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private nonisolated static let log = Logger(subsystem: "com.bitmoor.whatcable", category: "settings")

    private enum Keys {
        static let notifyOnChanges = "notifyOnChanges"
        static let hideEmptyPorts = "hideEmptyPorts"
        static let showTechnicalDetails = "showTechnicalDetails"
        static let useMenuBarMode = "useMenuBarMode"
    }

    @Published var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue else { return }
            applyLaunchAtLogin(launchAtLogin)
        }
    }

    @Published var notifyOnChanges: Bool {
        didSet {
            guard notifyOnChanges != oldValue else { return }
            UserDefaults.standard.set(notifyOnChanges, forKey: Keys.notifyOnChanges)
            if notifyOnChanges {
                NotificationManager.shared.requestAuthorizationIfNeeded()
            }
        }
    }

    @Published var hideEmptyPorts: Bool {
        didSet {
            guard hideEmptyPorts != oldValue else { return }
            UserDefaults.standard.set(hideEmptyPorts, forKey: Keys.hideEmptyPorts)
        }
    }

    @Published var showTechnicalDetails: Bool {
        didSet {
            guard showTechnicalDetails != oldValue else { return }
            UserDefaults.standard.set(showTechnicalDetails, forKey: Keys.showTechnicalDetails)
        }
    }

    /// When true (default), WhatCable lives in the menu bar with no Dock
    /// icon. When false, it runs as a regular Dock app with a window.
    @Published var useMenuBarMode: Bool {
        didSet {
            guard useMenuBarMode != oldValue else { return }
            UserDefaults.standard.set(useMenuBarMode, forKey: Keys.useMenuBarMode)
        }
    }

    private init() {
        // Launch at Login is owned by the system; read its current state.
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
        // Notifications default off — opt in to avoid noise.
        self.notifyOnChanges = UserDefaults.standard.bool(forKey: Keys.notifyOnChanges)
        self.hideEmptyPorts = UserDefaults.standard.bool(forKey: Keys.hideEmptyPorts)
        self.showTechnicalDetails = UserDefaults.standard.bool(forKey: Keys.showTechnicalDetails)
        // Menu bar mode is the default; UserDefaults returns false for unset
        // bool keys, so explicitly check presence.
        if UserDefaults.standard.object(forKey: Keys.useMenuBarMode) == nil {
            self.useMenuBarMode = true
        } else {
            self.useMenuBarMode = UserDefaults.standard.bool(forKey: Keys.useMenuBarMode)
        }
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Self.log.error("Failed to update launch at login: \(error.localizedDescription, privacy: .public)")
            // Roll the published value back so the UI matches reality.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let actual = SMAppService.mainApp.status == .enabled
                if self.launchAtLogin != actual {
                    self.launchAtLogin = actual
                }
            }
        }
    }
}
