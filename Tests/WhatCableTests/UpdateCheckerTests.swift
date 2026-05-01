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
        // "dev" (the swift-run fallback) should be considered older than any
        // real version, so a dev build always sees an "update available" —
        // matches the actual behavior of AppInfo.version under `swift run`.
        XCTAssertTrue(UpdateChecker.isNewer(remote: "0.3.0", current: "dev"))
    }

    func testTrustedReleaseURLs() {
        XCTAssertTrue(UpdateChecker.isTrustedReleaseURL(URL(string: "https://github.com/darrylmorley/whatcable/releases/tag/v0.4.3")!))
        XCTAssertFalse(UpdateChecker.isTrustedReleaseURL(URL(string: "http://github.com/darrylmorley/whatcable/releases/tag/v0.4.3")!))
        XCTAssertFalse(UpdateChecker.isTrustedReleaseURL(URL(string: "https://github.com/example/whatcable/releases/tag/v0.4.3")!))
    }

    func testTrustedDownloadURLs() {
        XCTAssertTrue(UpdateChecker.isTrustedDownloadURL(URL(string: "https://github.com/darrylmorley/whatcable/releases/download/v0.4.3/WhatCable.zip")!))
        XCTAssertFalse(UpdateChecker.isTrustedDownloadURL(URL(string: "https://github.com/darrylmorley/whatcable/releases/download/v0.4.3/Other.zip")!))
        XCTAssertFalse(UpdateChecker.isTrustedDownloadURL(URL(string: "https://example.com/darrylmorley/whatcable/releases/download/v0.4.3/WhatCable.zip")!))
    }
}
