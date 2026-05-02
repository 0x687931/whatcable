import Foundation
import AppKit
import os.log

struct AvailableUpdate: Equatable {
    let version: String
    let url: URL
    let downloadURL: URL?
    let notes: String?
}

/// Polls the GitHub releases API for newer versions of WhatCable.
@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    private nonisolated static let log = Logger(subsystem: "com.bitmoor.whatcable", category: "updates")
    private nonisolated static let endpoint = URL(string: "https://api.github.com/repos/0x687931/whatcable/releases/latest")!
    private nonisolated static let releaseHost = "github.com"
    private nonisolated static let releasePathPrefix = "/0x687931/whatcable/releases/"
    private nonisolated static let downloadPathPrefix = "/0x687931/whatcable/releases/download/"
    private nonisolated static let updateAssetName = "WhatCable.zip"
    private nonisolated static let pollInterval: TimeInterval = 6 * 60 * 60 // 6h

    @Published private(set) var available: AvailableUpdate?
    @Published private(set) var isChecking = false
    @Published private(set) var lastCheck: Date?

    private var timer: Timer?
    private var pendingVisibleCheck = false

    private init() {}

    func start() {
        check(silent: true)
        timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.check(silent: true) }
        }
    }

    /// Manually trigger a check. When `silent` is false, surfaces an alert
    /// for the "no update" case so the user gets feedback from the menu item.
    func check(silent: Bool) {
        if isChecking {
            if !silent { pendingVisibleCheck = true }
            return
        }
        pendingVisibleCheck = !silent
        isChecking = true

        var request = URLRequest(url: Self.endpoint)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("WhatCable/\(AppInfo.version)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            Task { @MainActor in
                guard let self else { return }
                self.isChecking = false
                self.lastCheck = Date()
                let visible = self.pendingVisibleCheck
                self.pendingVisibleCheck = false

                if let error {
                    Self.log.error("Update check failed: \(error.localizedDescription, privacy: .public)")
                    if visible { self.showAlert(title: "Couldn't check for updates", message: error.localizedDescription) }
                    return
                }

                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tag = json["tag_name"] as? String,
                      let urlString = json["html_url"] as? String,
                      let url = URL(string: urlString),
                      Self.isTrustedReleaseURL(url) else {
                    if visible { self.showAlert(title: "Couldn't check for updates", message: "Unexpected response from GitHub.") }
                    return
                }

                let remote = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
                let notes = json["body"] as? String
                let downloadURL = (json["assets"] as? [[String: Any]])?
                    .first(where: { ($0["name"] as? String) == Self.updateAssetName })
                    .flatMap { $0["browser_download_url"] as? String }
                    .flatMap { URL(string: $0) }
                    .flatMap { Self.isTrustedDownloadURL($0) ? $0 : nil }

                if Self.isNewer(remote: remote, current: AppInfo.version) {
                    self.available = AvailableUpdate(version: remote, url: url, downloadURL: downloadURL, notes: notes)
                } else {
                    self.available = nil
                    if visible {
                        self.showAlert(
                            title: "You're up to date",
                            message: "WhatCable \(AppInfo.version) is the latest version."
                        )
                    }
                }
            }
        }.resume()
    }

    private func showAlert(title: String, message: String) {
        // LSUIElement apps can't reliably bring a modal alert to the front.
        // Briefly promote to a regular app so the alert takes focus, then
        // restore accessory policy after dismissal.
        let originalPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.window.level = .floating
        alert.runModal()

        NSApp.setActivationPolicy(originalPolicy)
    }

    /// Compare dot-separated numeric versions. Non-numeric segments compare lexically.
    nonisolated static func isNewer(remote: String, current: String) -> Bool {
        let r = parts(remote)
        let c = parts(current)
        for i in 0..<max(r.count, c.count) {
            let rv = i < r.count ? r[i] : 0
            let cv = i < c.count ? c[i] : 0
            if rv != cv { return rv > cv }
        }
        return false
    }

    private nonisolated static func parts(_ version: String) -> [Int] {
        version.split(separator: ".").map { Int($0) ?? 0 }
    }

    nonisolated static func isTrustedReleaseURL(_ url: URL) -> Bool {
        url.scheme == "https"
            && url.host == releaseHost
            && url.path.hasPrefix(releasePathPrefix)
    }

    nonisolated static func isTrustedDownloadURL(_ url: URL) -> Bool {
        url.scheme == "https"
            && url.host == releaseHost
            && url.path.hasPrefix(downloadPathPrefix)
            && url.lastPathComponent == updateAssetName
    }
}
