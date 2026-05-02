import Foundation
import AppKit
import os.log

/// Downloads a new release zip from GitHub, validates its code signature
/// matches the currently running app, and swaps the bundles via a small
/// shell script that waits for this process to exit before doing the move.
@MainActor
final class Installer: ObservableObject {
    static let shared = Installer()
    private nonisolated static let log = Logger(subsystem: "com.bitmoor.whatcable", category: "installer")
    typealias CommandRunner = (_ launchPath: String, _ arguments: [String]) throws -> String

    enum State: Equatable {
        case idle
        case downloading
        case verifying
        case installing
        case failed(String)

        var canStartInstall: Bool {
            switch self {
            case .idle, .failed:
                return true
            case .downloading, .verifying, .installing:
                return false
            }
        }
    }

    @Published private(set) var state: State = .idle
    private let commandRunner: CommandRunner

    init(commandRunner: @escaping CommandRunner = Installer.captureOutput) {
        self.commandRunner = commandRunner
    }

    func install(_ update: AvailableUpdate) {
        guard state.canStartInstall else { return }
        guard let downloadURL = update.downloadURL else {
            state = .failed("No download asset for this release")
            return
        }
        state = .downloading

        Task {
            do {
                let workDir = try makeWorkDir()
                let zipURL = try await download(from: downloadURL, into: workDir)

                state = .verifying
                let extractedApp = try unzipAndLocate(zip: zipURL, in: workDir)
                try validateExtractedUpdate(candidateApp: extractedApp, currentApp: Bundle.main.bundleURL)

                state = .installing
                try launchSwapScript(newApp: extractedApp, currentApp: Bundle.main.bundleURL)

                // Give the script a moment to start before we quit.
                try await Task.sleep(nanoseconds: 250_000_000)
                NSApp.terminate(nil)
            } catch {
                Self.log.error("Install failed: \(error.localizedDescription, privacy: .public)")
                state = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: - Steps

    private func makeWorkDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("whatcable-update-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func download(from url: URL, into dir: URL) async throws -> URL {
        guard UpdateChecker.isTrustedDownloadURL(url) else {
            throw InstallError("Untrusted update download URL")
        }
        let (tmpURL, response) = try await URLSession.shared.download(from: url)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw InstallError("Download failed with HTTP \(http.statusCode)")
        }
        let dest = dir.appendingPathComponent("update.zip")
        try FileManager.default.moveItem(at: tmpURL, to: dest)
        return dest
    }

    private func unzipAndLocate(zip: URL, in dir: URL) throws -> URL {
        try validateZipEntries(zip)
        try run("/usr/bin/unzip", ["-q", zip.path, "-d", dir.path])

        let contents = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        let apps = contents.filter { $0.pathExtension == "app" }
        guard apps.count == 1, let app = apps.first else {
            throw InstallError("Expected exactly one .app inside the downloaded zip")
        }
        return app
    }

    func validateExtractedUpdate(candidateApp: URL, currentApp: URL) throws {
        try verifyUpdateIdentity(candidateApp: candidateApp, currentApp: currentApp)
        try assessWithGatekeeper(candidateApp)
        try stripQuarantine(at: candidateApp)
    }

    private func assessWithGatekeeper(_ app: URL) throws {
        try run("/usr/sbin/spctl", ["--assess", "--type", "execute", app.path])
    }

    private func stripQuarantine(at url: URL) throws {
        // Best-effort after validation. Failure to strip isn't fatal;
        // Gatekeeper will just prompt the user instead of launching silently.
        _ = try? run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", url.path])
    }

    private func verifyUpdateIdentity(candidateApp: URL, currentApp: URL) throws {
        try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", candidateApp.path])

        let candidateBundle = try bundleIdentity(of: candidateApp)
        let currentBundle = try bundleIdentity(of: currentApp)
        guard candidateBundle == currentBundle else {
            throw InstallError("Bundle identity mismatch: refusing to install")
        }

        let candidateSignature = try signatureIdentity(of: candidateApp)
        let currentSignature = try signatureIdentity(of: currentApp)
        guard candidateSignature == currentSignature else {
            throw InstallError("Signature identity mismatch: refusing to install")
        }
    }

    private func validateZipEntries(_ zip: URL) throws {
        let output = try run("/usr/bin/unzip", ["-Z1", zip.path])
        for line in output.split(separator: "\n") {
            let path = String(line)
            let components = path.split(separator: "/", omittingEmptySubsequences: false)
            if path.hasPrefix("/") || components.contains("..") {
                throw InstallError("Unsafe path in update zip: \(path)")
            }
        }
    }

    private struct BundleIdentity: Equatable {
        let bundleIdentifier: String
        let executableName: String
        let bundleName: String
    }

    private func bundleIdentity(of app: URL) throws -> BundleIdentity {
        guard let bundle = Bundle(url: app),
              let bundleIdentifier = bundle.bundleIdentifier,
              let executableName = bundle.object(forInfoDictionaryKey: "CFBundleExecutable") as? String,
              let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String else {
            throw InstallError("Could not read bundle identity from \(app.lastPathComponent)")
        }
        return BundleIdentity(
            bundleIdentifier: bundleIdentifier,
            executableName: executableName,
            bundleName: bundleName
        )
    }

    private struct SignatureIdentity: Equatable {
        let identifier: String
        let teamIdentifier: String
        let designatedRequirement: String
    }

    private func signatureIdentity(of app: URL) throws -> SignatureIdentity {
        let output = try run("/usr/bin/codesign", ["-dvv", "-r-", app.path])
        var identifier: String?
        var teamIdentifier: String?
        var requirement: String?

        for rawLine in output.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("Identifier=") {
                identifier = String(line.dropFirst("Identifier=".count))
            } else if line.hasPrefix("TeamIdentifier=") {
                teamIdentifier = String(line.dropFirst("TeamIdentifier=".count))
            } else if line.hasPrefix("designated =>") {
                requirement = String(line.dropFirst("designated =>".count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        guard let identifier, let teamIdentifier, let requirement else {
            throw InstallError("Could not read signature identity from \(app.lastPathComponent)")
        }
        return SignatureIdentity(
            identifier: identifier,
            teamIdentifier: teamIdentifier,
            designatedRequirement: requirement
        )
    }

    private func launchSwapScript(newApp: URL, currentApp: URL) throws {
        let script = """
        #!/bin/bash
        set -e
        PID=\(ProcessInfo.processInfo.processIdentifier)
        NEW=\(shellQuote(newApp.path))
        OLD=\(shellQuote(currentApp.path))

        # Wait up to 30s for the running app to exit
        for _ in $(seq 1 60); do
            if ! kill -0 "$PID" 2>/dev/null; then break; fi
            sleep 0.5
        done

        rm -rf "$OLD"
        mv "$NEW" "$OLD"
        open "$OLD"
        """

        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("whatcable-swap-\(UUID().uuidString).sh")
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [scriptURL.path]
        // Detach stdio so the child survives our exit cleanly.
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        task.standardInput = FileHandle.nullDevice
        try task.run()
    }

    // MARK: - Process helpers

    @discardableResult
    private func run(_ launchPath: String, _ arguments: [String]) throws -> String {
        let result = try commandRunner(launchPath, arguments)
        return result
    }

    private nonisolated static func captureOutput(_ launchPath: String, _ arguments: [String]) throws -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: launchPath)
        task.arguments = arguments
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        try task.run()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        if task.terminationStatus != 0 {
            throw InstallError("\(launchPath) failed (\(task.terminationStatus)): \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
        return output
    }

    private func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

private struct InstallError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { self.errorDescription = message }
}
