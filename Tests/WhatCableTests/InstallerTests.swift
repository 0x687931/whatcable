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
        let candidateApp = try makeFakeApp(named: "WhatCable.app", in: root)
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
        let candidateApp = try makeFakeApp(named: "WhatCable.app", in: root)
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

    @MainActor
    func testValidationRejectsUnexpectedAppNameBeforeRunningTools() throws {
        let root = try makeTemporaryDirectory()
        let candidateApp = try makeFakeApp(named: "Other.app", in: root)
        let currentApp = try makeFakeApp(named: "Current.app", in: root)
        var calls: [CommandInvocation] = []

        let installer = Installer { launchPath, arguments in
            calls.append(CommandInvocation(launchPath: launchPath, arguments: arguments))
            return self.output(for: launchPath, arguments: arguments)
        }

        XCTAssertThrowsError(
            try installer.validateExtractedUpdate(candidateApp: candidateApp, currentApp: currentApp)
        )
        XCTAssertTrue(calls.isEmpty)
    }

    @MainActor
    func testAdHocValidationSkipsGatekeeperButStillStripsQuarantine() throws {
        let root = try makeTemporaryDirectory()
        let candidateApp = try makeFakeApp(named: "WhatCable.app", in: root)
        let currentApp = try makeFakeApp(named: "Current.app", in: root)
        var calls: [CommandInvocation] = []

        let installer = Installer { launchPath, arguments in
            calls.append(CommandInvocation(launchPath: launchPath, arguments: arguments))
            return self.output(for: launchPath, arguments: arguments, adHoc: true)
        }

        try installer.validateExtractedUpdate(candidateApp: candidateApp, currentApp: currentApp)

        XCTAssertFalse(calls.contains { $0.launchPath == "/usr/sbin/spctl" })
        XCTAssertTrue(
            calls.contains(
                CommandInvocation(
                    launchPath: "/usr/bin/xattr",
                    arguments: ["-dr", "com.apple.quarantine", candidateApp.path]
                )
            )
        )
    }

    @MainActor
    func testValidationRejectsMixedSignedAndAdHocUpdates() throws {
        let root = try makeTemporaryDirectory()
        let candidateApp = try makeFakeApp(named: "WhatCable.app", in: root)
        let currentApp = try makeFakeApp(named: "Current.app", in: root)

        let installer = Installer { launchPath, arguments in
            if launchPath == "/usr/bin/codesign", arguments.first == "-dvv" {
                return self.output(
                    for: launchPath,
                    arguments: arguments,
                    adHoc: arguments.contains(candidateApp.path)
                )
            }
            return self.output(for: launchPath, arguments: arguments)
        }

        XCTAssertThrowsError(
            try installer.validateExtractedUpdate(candidateApp: candidateApp, currentApp: currentApp)
        )
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
        output(for: launchPath, arguments: arguments, adHoc: false)
    }

    private func output(for launchPath: String, arguments: [String], adHoc: Bool) -> String {
        if launchPath == "/usr/bin/codesign", arguments.first == "-dvv" {
            if adHoc {
                return """
                Executable=/tmp/WhatCable.app/Contents/MacOS/WhatCable
                Identifier=com.bitmoor.whatcable
                Format=app bundle with Mach-O universal (x86_64 arm64)
                Signature=adhoc
                TeamIdentifier=not set
                designated => cdhash H"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
                """
            }
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
