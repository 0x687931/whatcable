import XCTest
@testable import WhatCable

final class SessionQualityDiagnosticTests: XCTestCase {
    func testWarnsForMidSessionOvercurrent() {
        let snapshot = SessionQualitySnapshot(port: port(overcurrentCount: 1))

        let diagnostic = snapshot.diagnostic(for: port(overcurrentCount: 2))

        XCTAssertEqual(diagnostic, SessionQualityDiagnostic(kind: .overcurrent))
        XCTAssertFalse(diagnostic!.detail.contains("2"))
    }

    func testWarnsForRepeatedPlugEvents() {
        let snapshot = SessionQualitySnapshot(port: port(plugEventCount: 4))

        let diagnostic = snapshot.diagnostic(for: port(plugEventCount: 6))

        XCTAssertEqual(diagnostic, SessionQualityDiagnostic(kind: .unstableConnection))
    }

    func testWarnsForRepeatedConnectionDrops() {
        let snapshot = SessionQualitySnapshot(port: port(connectionCount: 10))

        let diagnostic = snapshot.diagnostic(for: port(connectionCount: 12))

        XCTAssertEqual(diagnostic, SessionQualityDiagnostic(kind: .unstableConnection))
    }

    func testDoesNotWarnForSingleConnectionEvent() {
        let snapshot = SessionQualitySnapshot(port: port(connectionCount: 10))

        let diagnostic = snapshot.diagnostic(for: port(connectionCount: 11))

        XCTAssertNil(diagnostic)
    }

    func testDoesNotWarnWithoutComparableCounters() {
        let snapshot = SessionQualitySnapshot(port: port(plugEventCount: nil, connectionCount: nil, overcurrentCount: nil))

        let diagnostic = snapshot.diagnostic(for: port(plugEventCount: 3, connectionCount: 3, overcurrentCount: 1))

        XCTAssertNil(diagnostic)
    }

    private func port(
        plugEventCount: Int? = 0,
        connectionCount: Int? = 0,
        overcurrentCount: Int? = 0
    ) -> USBCPort {
        USBCPort(
            id: 1,
            serviceName: "Port-USB-C@1",
            className: "AppleHPMInterfaceType10",
            portDescription: nil,
            portTypeDescription: "USB-C",
            portNumber: 1,
            connectionActive: true,
            activeCable: nil,
            opticalCable: nil,
            usbActive: nil,
            superSpeedActive: nil,
            usbModeType: nil,
            usbConnectString: nil,
            transportsSupported: [],
            transportsActive: [],
            transportsProvisioned: [],
            plugOrientation: nil,
            plugEventCount: plugEventCount,
            connectionCount: connectionCount,
            overcurrentCount: overcurrentCount,
            pinConfiguration: [:],
            powerCurrentLimits: [],
            firmwareVersion: nil,
            bootFlagsHex: nil,
            rawProperties: [:]
        )
    }
}
