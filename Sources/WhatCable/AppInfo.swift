import Foundation

enum AppInfo {
    static let name = "WhatCable"
    static let version: String = {
        // Single source of truth lives in the .app's Info.plist (written by
        // scripts/build-app.sh). Falls back to "dev" when run via `swift run`,
        // which has no bundled Info.plist.
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "dev"
    }()
    static let credit = "WhatCable contributors"
    static let originalAuthor = "Darryl Morley"
    static let originalProjectURL = "https://github.com/darrylmorley/whatcable"
    static let tagline = "What can this USB-C cable actually do?"
    static let copyright = "© \(Calendar.current.component(.year, from: Date())) \(credit)"
}
