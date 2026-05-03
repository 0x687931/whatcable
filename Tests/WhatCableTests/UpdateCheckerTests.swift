import XCTest
@testable import WhatCable

final class UpdateCheckerTests: XCTestCase {
    func testRemoteIsNewer() {
        XCTAssertTrue(UpdateChecker.isNewer(remote: "0.4.0", current: "0.3.1"))
        XCTAssertTrue(UpdateChecker.isNewer(remote: "0.3.2", current: "0.3.1"))
        XCTAssertTrue(UpdateChecker.isNewer(remote: "1.0.0", current: "0.99.99"))
    }

    func testRemoteIsOlderOrEqual() {
        XCTAssertFalse(UpdateChecker.isNewer(remote: "0.3.0", current: "0.3.1"))
        XCTAssertFalse(UpdateChecker.isNewer(remote: "0.3.1", current: "0.3.1"))
        XCTAssertFalse(UpdateChecker.isNewer(remote: "0.2.9", current: "0.3.0"))
    }

    func testDifferentLengths() {
        // "0.4" should equal "0.4.0", neither newer.
        XCTAssertFalse(UpdateChecker.isNewer(remote: "0.4", current: "0.4.0"))
        XCTAssertFalse(UpdateChecker.isNewer(remote: "0.4.0", current: "0.4"))
        // "0.4.1" newer than "0.4".
        XCTAssertTrue(UpdateChecker.isNewer(remote: "0.4.1", current: "0.4"))
    }

    func testDevFallback() {
        // Legacy/non-numeric versions should be considered older than any
        // real version.
        XCTAssertTrue(UpdateChecker.isNewer(remote: "0.3.0", current: "dev"))
    }

    func testAppInfoVersionFallsBackToBuildScriptVersion() throws {
        let scriptVersion = try buildScriptVersion()
        XCTAssertEqual(AppInfo.version, scriptVersion)
        XCTAssertNotEqual(AppInfo.version, "dev")
    }

    func testTrustedReleaseURLs() {
        XCTAssertTrue(UpdateChecker.isTrustedReleaseURL(URL(string: "https://github.com/0x687931/whatcable/releases/tag/v0.4.3")!))
        XCTAssertFalse(UpdateChecker.isTrustedReleaseURL(URL(string: "http://github.com/0x687931/whatcable/releases/tag/v0.4.3")!))
        XCTAssertFalse(UpdateChecker.isTrustedReleaseURL(URL(string: "https://github.com/darrylmorley/whatcable/releases/tag/v0.4.3")!))
        XCTAssertFalse(UpdateChecker.isTrustedReleaseURL(URL(string: "https://github.com/example/whatcable/releases/tag/v0.4.3")!))
    }

    func testTrustedDownloadURLs() {
        XCTAssertTrue(UpdateChecker.isTrustedDownloadURL(URL(string: "https://github.com/0x687931/whatcable/releases/download/v0.4.3/WhatCable.zip")!))
        XCTAssertFalse(UpdateChecker.isTrustedDownloadURL(URL(string: "https://github.com/0x687931/whatcable/releases/download/v0.4.3/Other.zip")!))
        XCTAssertFalse(UpdateChecker.isTrustedDownloadURL(URL(string: "https://github.com/darrylmorley/whatcable/releases/download/v0.4.3/WhatCable.zip")!))
        XCTAssertFalse(UpdateChecker.isTrustedDownloadURL(URL(string: "https://example.com/0x687931/whatcable/releases/download/v0.4.3/WhatCable.zip")!))
    }

    func testNoReleaseResponseMessage() {
        let data = #"{"message":"Not Found","status":"404"}"#.data(using: .utf8)
        XCTAssertEqual(
            UpdateChecker.message(forHTTPStatus: 404, data: data),
            "No public releases have been published for 0x687931/whatcable yet."
        )
    }

    func testHTTPErrorResponseIncludesGitHubMessage() {
        let data = #"{"message":"API rate limit exceeded"}"#.data(using: .utf8)
        XCTAssertEqual(
            UpdateChecker.message(forHTTPStatus: 403, data: data),
            "GitHub returned HTTP 403: API rate limit exceeded"
        )
    }

    private func buildScriptVersion() throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let repoRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let script = repoRoot.appendingPathComponent("scripts/build-app.sh")
        let contents = try String(contentsOf: script, encoding: .utf8)
        for line in contents.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("VERSION=") {
                return trimmed
                    .dropFirst("VERSION=".count)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            }
        }
        XCTFail("VERSION not found in scripts/build-app.sh")
        return ""
    }
}
