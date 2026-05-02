import XCTest
@testable import WhatCable

final class InstallerTests: XCTestCase {
    func testFailedInstallStateCanRetry() {
        XCTAssertTrue(Installer.State.idle.canStartInstall)
        XCTAssertTrue(Installer.State.failed("network error").canStartInstall)
        XCTAssertFalse(Installer.State.downloading.canStartInstall)
        XCTAssertFalse(Installer.State.verifying.canStartInstall)
        XCTAssertFalse(Installer.State.installing.canStartInstall)
    }

    @MainActor
    func testValidationAssessesGatekeeperBeforeQuarantineStripping() throws {
        let root = try makeTemporaryDirectory()
        let candidateApp = try makeFakeApp(named: "Candidate.app", in: root)
        let currentApp = try makeFakeApp(named: "Current.app", in: root)
        var calls: [CommandInvocation] = []

        let installer = Installer { launchPath, arguments in
            calls.append(CommandInvocation(launchPath: launchPath, arguments: arguments))
            return self.output(for: launchPath, arguments: arguments)
        }

        try installer.validateExtractedUpdate(candidateApp: candidateApp, currentApp: currentApp)

        XCTAssertEqual(calls, [
            CommandInvocation(
                launchPath: "/usr/bin/codesign",
                arguments: ["--verify", "--deep", "--strict", candidateApp.path]
            ),
            CommandInvocation(
                launchPath: "/usr/bin/codesign",
                arguments: ["-dvv", "-r-", candidateApp.path]
            ),
            CommandInvocation(
                launchPath: "/usr/bin/codesign",
                arguments: ["-dvv", "-r-", currentApp.path]
            ),
            CommandInvocation(
                launchPath: "/usr/sbin/spctl",
                arguments: ["--assess", "--type", "execute", candidateApp.path]
            ),
            CommandInvocation(
                launchPath: "/usr/bin/xattr",
                arguments: ["-dr", "com.apple.quarantine", candidateApp.path]
            )
        ])
    }

    @MainActor
    func testValidationDoesNotStripQuarantineWhenGatekeeperFails() throws {
        let root = try makeTemporaryDirectory()
        let candidateApp = try makeFakeApp(named: "Candidate.app", in: root)
        let currentApp = try makeFakeApp(named: "Current.app", in: root)
        var calls: [CommandInvocation] = []

        let installer = Installer { launchPath, arguments in
            calls.append(CommandInvocation(launchPath: launchPath, arguments: arguments))
            if launchPath == "/usr/sbin/spctl" {
                throw NSError(domain: "InstallerTests", code: 1)
            }
            return self.output(for: launchPath, arguments: arguments)
        }

        XCTAssertThrowsError(
            try installer.validateExtractedUpdate(candidateApp: candidateApp, currentApp: currentApp)
        )
        XCTAssertFalse(calls.contains { $0.launchPath == "/usr/bin/xattr" })
    }

    private struct CommandInvocation: Equatable {
        let launchPath: String
        let arguments: [String]
    }

    private func makeTemporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("whatcable-installer-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return root
    }

    private func makeFakeApp(named appName: String, in root: URL) throws -> URL {
        let app = root.appendingPathComponent(appName, isDirectory: true)
        let contents = app.appendingPathComponent("Contents", isDirectory: true)
        let macOS = contents.appendingPathComponent("MacOS", isDirectory: true)
        try FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)

        let executable = macOS.appendingPathComponent("WhatCable")
        try Data().write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let info: NSDictionary = [
            "CFBundleIdentifier": "com.bitmoor.whatcable",
            "CFBundleExecutable": "WhatCable",
            "CFBundleName": "WhatCable",
            "CFBundlePackageType": "APPL"
        ]
        let infoURL = contents.appendingPathComponent("Info.plist")
        XCTAssertTrue(info.write(to: infoURL, atomically: true))
        return app
    }

    private func output(for launchPath: String, arguments: [String]) -> String {
        if launchPath == "/usr/bin/codesign", arguments.first == "-dvv" {
            return """
            Executable=/tmp/WhatCable.app/Contents/MacOS/WhatCable
            Identifier=com.bitmoor.whatcable
            TeamIdentifier=ABCDE12345
            designated => identifier "com.bitmoor.whatcable" and anchor apple generic and certificate leaf[subject.OU] = ABCDE12345
            """
        }
        return ""
    }
}
