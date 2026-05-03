import Foundation
import IOKit
import IOKit.usb

@MainActor
final class USBWatcher: ObservableObject {
    @Published private(set) var devices: [USBDevice] = []

    private var notifyPort: IONotificationPortRef?
    private var addedIter: io_iterator_t = 0
    private var removedIter: io_iterator_t = 0

    func start() {
        guard notifyPort == nil else { return }
        let port = IONotificationPortCreate(kIOMainPortDefault)
        IONotificationPortSetDispatchQueue(port, DispatchQueue.main)
        notifyPort = port

        let matching = IOServiceMatching("IOUSBHostDevice") as NSMutableDictionary

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let addedCallback: IOServiceMatchingCallback = { refcon, iterator in
            guard let refcon else { return }
            let watcher = Unmanaged<USBWatcher>.fromOpaque(refcon).takeUnretainedValue()
            Task { @MainActor in watcher.handleAdded(iterator: iterator) }
        }

        let removedCallback: IOServiceMatchingCallback = { refcon, iterator in
            guard let refcon else { return }
            let watcher = Unmanaged<USBWatcher>.fromOpaque(refcon).takeUnretainedValue()
            Task { @MainActor in watcher.handleRemoved(iterator: iterator) }
        }

        IOServiceAddMatchingNotification(
            port,
            kIOMatchedNotification,
            (matching.copy() as! CFDictionary),
            addedCallback,
            selfPtr,
            &addedIter
        )
        handleAdded(iterator: addedIter)

        IOServiceAddMatchingNotification(
            port,
            kIOTerminatedNotification,
            (matching.copy() as! CFDictionary),
            removedCallback,
            selfPtr,
            &removedIter
        )
        handleRemoved(iterator: removedIter)
    }

    func stop() {
        if addedIter != 0 { IOObjectRelease(addedIter); addedIter = 0 }
        if removedIter != 0 { IOObjectRelease(removedIter); removedIter = 0 }
        if let port = notifyPort {
            IONotificationPortDestroy(port)
            notifyPort = nil
        }
        devices.removeAll()
    }

    func refresh() {
        devices.removeAll()
        var iter: io_iterator_t = 0
        if IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOUSBHostDevice"), &iter) == KERN_SUCCESS {
            handleAdded(iterator: iter)
            IOObjectRelease(iter)
        }
    }

    private func handleAdded(iterator: io_iterator_t) {
        while case let service = IOIteratorNext(iterator), service != 0 {
            if let device = makeDevice(from: service) {
                if !devices.contains(where: { $0.id == device.id }) {
                    devices.append(device)
                }
            }
            IOObjectRelease(service)
        }
        devices.sort { ($0.productName ?? "") < ($1.productName ?? "") }
    }

    private func handleRemoved(iterator: io_iterator_t) {
        while case let service = IOIteratorNext(iterator), service != 0 {
            let entryID = IOKitSupport.entryID(for: service)
            devices.removeAll { $0.id == entryID }
            IOObjectRelease(service)
        }
    }

    private func makeDevice(from service: io_service_t) -> USBDevice? {
        let entryID = IOKitSupport.entryID(for: service)
        guard let dict = IOKitSupport.properties(for: service) else { return nil }

        let vendorID = (dict["idVendor"] as? NSNumber)?.uint16Value ?? 0
        let productID = (dict["idProduct"] as? NSNumber)?.uint16Value ?? 0
        let locationID = (dict["locationID"] as? NSNumber)?.uint32Value ?? 0
        let speedRaw = (dict["Device Speed"] as? NSNumber)?.uint8Value
        let bcdUSB = (dict["bcdUSB"] as? NSNumber)?.uint16Value
        let busPower = (dict["Bus Power Available"] as? NSNumber).map { $0.intValue * 2 }
        let current = (dict["Requested Power"] as? NSNumber).map { $0.intValue * 2 }
        let (busIndex, controllerPortName) = controllerInfo(for: service, fallback: locationID)

        return USBDevice(
            id: entryID,
            locationID: locationID,
            vendorID: vendorID,
            productID: productID,
            vendorName: dict["USB Vendor Name"] as? String,
            productName: dict["USB Product Name"] as? String,
            serialNumber: dict["USB Serial Number"] as? String,
            usbVersion: bcdUSB.map { formatBCD($0) },
            speedRaw: speedRaw,
            busPowerMA: busPower,
            currentMA: current,
            busIndex: busIndex,
            controllerPortName: controllerPortName,
            rawProperties: IOKitSupport.stringProperties(from: dict)
        )
    }

    /// Walk up from an `IOUSBHostDevice` to find the USB port node that carries
    /// `UsbIOPort`, whose path ends in the physical port service name. If that
    /// direct path is not available, keep the controller bus index as a narrow
    /// fallback for older topologies.
    private func controllerInfo(for service: io_service_t, fallback locationID: UInt32) -> (Int?, String?) {
        var current = service
        IOObjectRetain(current)
        defer { IOObjectRelease(current) }

        var busIndex: Int?
        var controllerPortName: String?

        for _ in 0..<20 {
            var parent: io_service_t = 0
            guard IORegistryEntryGetParentEntry(current, kIOServicePlane, &parent) == KERN_SUCCESS else {
                break
            }
            IOObjectRelease(current)
            current = parent

            if controllerPortName == nil,
               let rawPort = IORegistryEntryCreateCFProperty(
                    current,
                    "UsbIOPort" as CFString,
                    kCFAllocatorDefault,
                    0
               )?.takeRetainedValue(),
               let portPath = Self.usbIOPortPath(from: rawPort),
               let portName = Self.portName(fromUSBIOPortPath: portPath) {
                controllerPortName = portName
            }

            var classBuf = [CChar](repeating: 0, count: 128)
            IOObjectGetClass(current, &classBuf)
            let className = String(cString: classBuf)
            if className.hasPrefix("AppleT") && className.hasSuffix("USBXHCI") {
                if let loc = IORegistryEntryCreateCFProperty(
                    current,
                    "locationID" as CFString,
                    kCFAllocatorDefault,
                    0
                )?.takeRetainedValue() as? NSNumber {
                    busIndex = Self.busIndex(fromLocationID: loc.uint32Value)
                }
                break
            }
        }

        if busIndex == nil {
            busIndex = Self.busIndex(fromLocationID: locationID)
        }
        return (busIndex, controllerPortName)
    }

    nonisolated static func busIndex(fromLocationID locationID: UInt32) -> Int {
        Int((locationID >> 24) & 0xFF)
    }

    nonisolated static func usbIOPortPath(from value: Any) -> String? {
        if let string = value as? String {
            return string
        }
        if let data = value as? Data {
            return String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .controlCharacters)
        }
        return nil
    }

    nonisolated static func portName(fromUSBIOPortPath path: String) -> String? {
        guard let last = path.split(separator: "/").last else { return nil }
        let name = String(last)
        return name.hasPrefix("Port-") ? name : nil
    }

    private func formatBCD(_ value: UInt16) -> String {
        let major = (value >> 8) & 0xFF
        let minor = (value >> 4) & 0xF
        let sub = value & 0xF
        return sub == 0 ? "\(major).\(minor)" : "\(major).\(minor).\(sub)"
    }

}
