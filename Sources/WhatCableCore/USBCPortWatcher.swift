import Foundation
import IOKit

/// Watches USB-C / MagSafe port-controller services. On Apple-silicon Macs the
/// relevant class is `AppleHPMInterfaceType10` (USB-C) and `Type11` (MagSafe).
@MainActor
public final class USBCPortWatcher: ObservableObject {
    @Published public private(set) var ports: [USBCPort] = []

    // Match only Type-C / MagSafe physical port controllers. Generic
    // `AppleUSBHostPort` would sweep in internal DRD (dual-role device)
    // ports — those have no physical connector and just confuse the UI.
    // The exact IOKit class for a USB-C port node varies by chip
    // generation. M3-era machines expose `AppleHPMInterfaceType10/11/12`;
    // M1 and M2 expose `AppleTCControllerType10`. We register against
    // both. The `PortTypeDescription` / `Port-` filter in `makePort`
    // drops anything that isn't a real physical port.
    private static let candidateClasses = [
        "AppleHPMInterfaceType10",
        "AppleHPMInterfaceType11",
        "AppleHPMInterfaceType12",
        "AppleTCControllerType10",
        "AppleTCControllerType11"
    ]

    private var notifyPort: IONotificationPortRef?
    private var iterators: [io_iterator_t] = []

    public init() {}

    public func start() {
        guard notifyPort == nil else { return }
        let port = IONotificationPortCreate(kIOMainPortDefault)
        IONotificationPortSetDispatchQueue(port, DispatchQueue.main)
        notifyPort = port

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let cb: IOServiceMatchingCallback = { refcon, iterator in
            guard let refcon else { return }
            let watcher = Unmanaged<USBCPortWatcher>.fromOpaque(refcon).takeUnretainedValue()
            Task { @MainActor in watcher.drain(iterator: iterator) }
        }

        for cls in Self.candidateClasses {
            let matching = IOServiceMatching(cls)
            var iter: io_iterator_t = 0
            if IOServiceAddMatchingNotification(port, kIOMatchedNotification, matching, cb, selfPtr, &iter) == KERN_SUCCESS {
                iterators.append(iter)
                drain(iterator: iter)
            }
        }
    }

    public func stop() {
        for iter in iterators { IOObjectRelease(iter) }
        iterators.removeAll()
        if let port = notifyPort {
            IONotificationPortDestroy(port)
            notifyPort = nil
        }
        ports.removeAll()
    }

    /// Re-walk the registry. Property changes (cable plug/unplug) don't fire
    /// match notifications, so we expose this for manual polling.
    public func refresh() {
        ports.removeAll()
        for cls in Self.candidateClasses {
            let matching = IOServiceMatching(cls)
            var iter: io_iterator_t = 0
            if IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iter) == KERN_SUCCESS {
                drain(iterator: iter)
                IOObjectRelease(iter)
            }
        }
    }

    private func drain(iterator: io_iterator_t) {
        while case let service = IOIteratorNext(iterator), service != 0 {
            if let port = makePort(from: service), !ports.contains(where: { $0.id == port.id }) {
                ports.append(port)
            }
            IOObjectRelease(service)
        }
        // Active connections first, then alphabetically within each group.
        ports.sort { lhs, rhs in
            let lhsActive = lhs.connectionActive == true
            let rhsActive = rhs.connectionActive == true
            if lhsActive != rhsActive { return lhsActive }
            return lhs.serviceName < rhs.serviceName
        }
    }

    private func makePort(from service: io_service_t) -> USBCPort? {
        var entryID: UInt64 = 0
        IORegistryEntryGetRegistryEntryID(service, &entryID)

        var nameBuf = [CChar](repeating: 0, count: 128)
        IORegistryEntryGetName(service, &nameBuf)
        let serviceName = String(cString: nameBuf)

        var classBuf = [CChar](repeating: 0, count: 128)
        IOObjectGetClass(service, &classBuf)
        let className = String(cString: classBuf)

        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any] else {
            return nil
        }

        // Sanity check: only return things that actually look like a physical
        // Type-C or MagSafe port. Real ports have a "PortTypeDescription"
        // and a name like "Port-USB-C@N" / "Port-MagSafe 3@N".
        let portType = dict["PortTypeDescription"] as? String
        let isRealPort = (portType == "USB-C" || portType?.hasPrefix("MagSafe") == true)
            && serviceName.hasPrefix("Port-")
        guard isRealPort else { return nil }

        var raw: [String: String] = [:]
        for (k, v) in dict { raw[k] = stringify(v) }

        return USBCPort(
            id: entryID,
            serviceName: serviceName,
            className: className,
            portDescription: dict["PortDescription"] as? String,
            portTypeDescription: dict["PortTypeDescription"] as? String,
            portNumber: (dict["PortNumber"] as? NSNumber)?.intValue,
            connectionActive: (dict["ConnectionActive"] as? NSNumber)?.boolValue,
            activeCable: (dict["ActiveCable"] as? NSNumber)?.boolValue,
            opticalCable: (dict["OpticalCable"] as? NSNumber)?.boolValue,
            usbActive: (dict["IOAccessoryUSBActive"] as? NSNumber)?.boolValue,
            superSpeedActive: (dict["IOAccessoryUSBSuperSpeedActive"] as? NSNumber)?.boolValue,
            usbModeType: (dict["IOAccessoryUSBModeType"] as? NSNumber)?.intValue,
            usbConnectString: dict["IOAccessoryUSBConnectString"] as? String,
            transportsSupported: stringArray(dict["TransportsSupported"]),
            transportsActive: stringArray(dict["TransportsActive"]),
            transportsProvisioned: stringArray(dict["TransportsProvisioned"]),
            plugOrientation: (dict["PlugOrientation"] as? NSNumber)?.intValue,
            plugEventCount: (dict["Plug Event Count"] as? NSNumber)?.intValue,
            connectionCount: (dict["ConnectionCount"] as? NSNumber)?.intValue,
            overcurrentCount: (dict["Overcurrent Count"] as? NSNumber)?.intValue,
            pinConfiguration: pinConfig(dict["Pin Configuration"]),
            powerCurrentLimits: intArray(dict["IOAccessoryPowerCurrentLimits"]),
            firmwareVersion: hexData(dict["FW Version"]),
            bootFlagsHex: hexData(dict["Boot Flags"]),
            busIndex: busIndex(for: service),
            rawProperties: raw
        )
    }

    /// Walks the IOKit parent chain looking for an `hpm<N>@…` SPMI node and
    /// returns N. On M3+ machines this N matches the upper byte of the
    /// associated XHCI controller's `locationID`, giving a bus index that
    /// can be matched against `USBDevice.busIndex`. Returns `nil` on
    /// machines that don't expose the hpm hierarchy (M1/M2, where ports
    /// register directly under `AppleTCControllerType10/11`).
    private func busIndex(for service: io_service_t) -> Int? {
        var current = service
        IOObjectRetain(current)
        defer { IOObjectRelease(current) }

        for _ in 0..<8 {
            var parent: io_service_t = 0
            guard IORegistryEntryGetParentEntry(current, kIOServicePlane, &parent) == KERN_SUCCESS else {
                return nil
            }
            IOObjectRelease(current)
            current = parent

            var nameBuf = [CChar](repeating: 0, count: 128)
            IORegistryEntryGetName(current, &nameBuf)
            let name = String(cString: nameBuf)
            if name.hasPrefix("hpm"), let at = name.firstIndex(of: "@") {
                let digits = name[name.index(name.startIndex, offsetBy: 3)..<at]
                if let n = Int(digits) {
                    return n
                }
            }
        }
        return nil
    }

    private func stringArray(_ value: Any?) -> [String] {
        (value as? [Any])?.compactMap { $0 as? String } ?? []
    }

    private func intArray(_ value: Any?) -> [Int] {
        (value as? [Any])?.compactMap { ($0 as? NSNumber)?.intValue } ?? []
    }

    private func pinConfig(_ value: Any?) -> [String: String] {
        guard let dict = value as? [String: Any] else { return [:] }
        var result: [String: String] = [:]
        for (k, v) in dict { result[k] = stringify(v) }
        return result
    }

    private func hexData(_ value: Any?) -> String? {
        guard let data = value as? Data else { return nil }
        return data.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    private func stringify(_ value: Any) -> String {
        switch value {
        case let n as NSNumber: return n.stringValue
        case let s as String: return s
        case let d as Data: return d.map { String(format: "%02X", $0) }.joined(separator: " ")
        case let a as [Any]: return "[" + a.map { stringify($0) }.joined(separator: ", ") + "]"
        case let d as [String: Any]:
            return "{" + d.map { "\($0.key): \(stringify($0.value))" }.joined(separator: ", ") + "}"
        default: return String(describing: value)
        }
    }
}
