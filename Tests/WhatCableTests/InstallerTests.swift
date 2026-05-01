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
}
