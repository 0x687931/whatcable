import Foundation

enum AppInfo {
    static let name = "WhatCable"
    static let bundleIdentifier = "com.bitmoor.whatcable"
    static let version: String = {
        // Single source of truth lives in the .app's Info.plist (written by
        // scripts/build-app.sh). SwiftPM runs have no bundled Info.plist, so
        // they fall back to the same script instead of advertising "dev".
        bundledVersion()
            ?? versionFromBuildScript()
            ?? "0.0.0"
    }()
    static let credit = "WhatCable contributors"
    static let originalAuthor = "Darryl Morley"
    static let originalProjectURL = "https://github.com/darrylmorley/whatcable"
    static let tagline = "What can this USB-C cable actually do?"
    static let copyright = "© \(Calendar.current.component(.year, from: Date())) \(credit)"

    private static func bundledVersion() -> String? {
        guard Bundle.main.bundleIdentifier == bundleIdentifier else { return nil }
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    private static func versionFromBuildScript() -> String? {
        let fileManager = FileManager.default
        let starts = [
            URL(fileURLWithPath: fileManager.currentDirectoryPath),
            Bundle.main.executableURL,
            Bundle.main.bundleURL,
            CommandLine.arguments.first.map { URL(fileURLWithPath: $0) }
        ].compactMap { $0 }

        for start in starts {
            if let version = versionFromBuildScript(startingAt: start, fileManager: fileManager) {
                return version
            }
        }
        return nil
    }

    private static func versionFromBuildScript(startingAt start: URL, fileManager: FileManager) -> String? {
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: start.path, isDirectory: &isDirectory)
        var dir = exists && !isDirectory.boolValue ? start.deletingLastPathComponent() : start

        for _ in 0..<8 {
            let script = dir.appendingPathComponent("scripts/build-app.sh")
            if let version = version(inBuildScript: script) {
                return version
            }
            let parent = dir.deletingLastPathComponent()
            if parent.path == dir.path { break }
            dir = parent
        }
        return nil
    }

    private static func version(inBuildScript script: URL) -> String? {
        guard let contents = try? String(contentsOf: script, encoding: .utf8) else { return nil }
        for line in contents.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("VERSION=") else { continue }
            return trimmed
                .dropFirst("VERSION=".count)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        }
        return nil
    }
}
