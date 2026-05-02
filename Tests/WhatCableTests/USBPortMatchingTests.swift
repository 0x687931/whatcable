import XCTest
@testable import WhatCable

final class USBPortMatchingTests: XCTestCase {

    func testMatchesDevicesByUsbIOPortPhysicalPortName() {
        let port = makePort(serviceName: "Port-USB-C@1", busIndex: 2)
        let matching = makeDevice(id: 1, controllerPortName: "Port-USB-C@1", busIndex: 9)
        let other = makeDevice(id: 2, controllerPortName: "Port-USB-C@2", busIndex: 2)

        XCTAssertEqual(port.matchingDevices(from: [other, matching]), [matching])
    }

    func testDirectUsbIOPortPresencePreventsBusFallback() {
        let port = makePort(serviceName: "Port-USB-C@1", busIndex: 1)
        let deviceOnOtherPort = makeDevice(id: 1, controllerPortName: "Port-USB-C@2", busIndex: 1)

        XCTAssertEqual(port.matchingDevices(from: [deviceOnOtherPort]), [])
    }

    func testFallsBackToBusIndexOnlyWhenNoDirectPortNamesExist() {
        let port = makePort(serviceName: "Port-USB-C@1", busIndex: 3)
        let matching = makeDevice(id: 1, busIndex: 3)
        let other = makeDevice(id: 2, busIndex: 4)

        XCTAssertEqual(port.matchingDevices(from: [matching, other]), [matching])
    }

    func testNoMatchKeyReturnsNoDevicesInsteadOfAllDevices() {
        let port = makePort(serviceName: "Port-USB-C@1")
        let devices = [
            makeDevice(id: 1, busIndex: 1),
            makeDevice(id: 2, busIndex: 2)
        ]

        XCTAssertEqual(port.matchingDevices(from: devices), [])
    }

    func testIntelThunderboltFallbackCreatesConservativeUSBCPort() throws {
        let port = try XCTUnwrap(USBCPort.intelThunderboltFallback(
            entryID: 10,
            serviceName: "AppleThunderboltNHIType3@0",
            className: "AppleThunderboltNHIType3",
            properties: ["vendor-id": NSNumber(value: 0x8086)],
            ordinal: 1
        ))

        XCTAssertEqual(port.portDescription, "Intel Thunderbolt USB-C 1")
        XCTAssertEqual(port.portTypeDescription, "USB-C")
        XCTAssertNil(port.connectionActive)
        XCTAssertNil(port.busIndex)
        XCTAssertEqual(port.transportsSupported, ["Thunderbolt", "USB"])
        XCTAssertEqual(port.rawProperties["WhatCableDetectionMode"], "Intel Thunderbolt fallback")
        XCTAssertEqual(port.rawProperties["vendor-id"], "32902")
    }

    func testIntelThunderboltFallbackSummarizesAsUnsupported() throws {
        let port = try XCTUnwrap(USBCPort.intelThunderboltFallback(
            entryID: 10,
            serviceName: "AppleThunderboltNHIType3@0",
            className: "AppleThunderboltNHIType3",
            properties: [:],
            ordinal: 1
        ))

        let summary = PortSummary(port: port)

        XCTAssertEqual(summary.status, .unknown)
        XCTAssertEqual(summary.headline, "Intel USB-C unsupported")
        XCTAssertTrue(summary.subtitle.contains("does not expose USB-PD"))
    }

    func testIntelThunderboltFallbackRejectsGenericUSBHostPort() {
        let port = USBCPort.intelThunderboltFallback(
            entryID: 11,
            serviceName: "AppleUSBHostPort@00100000",
            className: "AppleUSBHostPort",
            properties: [:],
            ordinal: 1
        )

        XCTAssertNil(port)
    }

    private func makePort(
        serviceName: String,
        portDescription: String? = nil,
        busIndex: Int? = nil
    ) -> USBCPort {
        USBCPort(
            id: UInt64(abs(serviceName.hashValue)),
            serviceName: serviceName,
            className: "AppleHPMInterfaceType10",
            portDescription: portDescription,
            portTypeDescription: "USB-C",
            portNumber: 1,
            connectionActive: true,
            activeCable: nil,
            opticalCable: nil,
            usbActive: true,
            superSpeedActive: nil,
            usbModeType: nil,
            usbConnectString: nil,
            transportsSupported: ["USB2", "USB3"],
            transportsActive: ["USB2"],
            transportsProvisioned: ["CC"],
            plugOrientation: nil,
            plugEventCount: nil,
            connectionCount: nil,
            overcurrentCount: nil,
            pinConfiguration: [:],
            powerCurrentLimits: [],
            firmwareVersion: nil,
            bootFlagsHex: nil,
            busIndex: busIndex,
            rawProperties: ["PortType": "2"]
        )
    }

    private func makeDevice(
        id: UInt64,
        controllerPortName: String? = nil,
        busIndex: Int? = nil
    ) -> USBDevice {
        USBDevice(
            id: id,
            locationID: 0,
            vendorID: 0,
            productID: 0,
            vendorName: nil,
            productName: "Device \(id)",
            serialNumber: nil,
            usbVersion: nil,
            speedRaw: nil,
            busPowerMA: nil,
            currentMA: nil,
            busIndex: busIndex,
            controllerPortName: controllerPortName,
            rawProperties: [:]
        )
    }
}
