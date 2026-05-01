import Foundation
import IOKit

/// Watches `IOPortFeaturePowerSource` services. These appear under each port's
/// `Power In` feature when something that advertises PD is connected.
@MainActor
final class PowerSourceWatcher: ObservableObject {
    @Published private(set) var sources: [PowerSource] = []

    private var notifyPort: IONotificationPortRef?
    private var addedIter: io_iterator_t = 0
    private var removedIter: io_iterator_t = 0

    func start() {
        guard notifyPort == nil else { return }
        let port = IONotificationPortCreate(kIOMainPortDefault)
        IONotificationPortSetDispatchQueue(port, DispatchQueue.main)
        notifyPort = port

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let added: IOServiceMatchingCallback = { refcon, iter in
            guard let refcon else { return }
            let w = Unmanaged<PowerSourceWatcher>.fromOpaque(refcon).takeUnretainedValue()
            Task { @MainActor in w.handleAdded(iter) }
        }
        let removed: IOServiceMatchingCallback = { refcon, iter in
            guard let refcon else { return }
            let w = Unmanaged<PowerSourceWatcher>.fromOpaque(refcon).takeUnretainedValue()
            Task { @MainActor in w.handleRemoved(iter) }
        }

        let matching = IOServiceMatching("IOPortFeaturePowerSource")
        IOServiceAddMatchingNotification(port, kIOMatchedNotification, matching, added, selfPtr, &addedIter)
        handleAdded(addedIter)

        let matching2 = IOServiceMatching("IOPortFeaturePowerSource")
        IOServiceAddMatchingNotification(port, kIOTerminatedNotification, matching2, removed, selfPtr, &removedIter)
        handleRemoved(removedIter)
    }

    func stop() {
        if addedIter != 0 { IOObjectRelease(addedIter); addedIter = 0 }
        if removedIter != 0 { IOObjectRelease(removedIter); removedIter = 0 }
        if let p = notifyPort { IONotificationPortDestroy(p); notifyPort = nil }
        sources.removeAll()
    }

    func refresh() {
        sources.removeAll()
        var iter: io_iterator_t = 0
        if IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOPortFeaturePowerSource"), &iter) == KERN_SUCCESS {
            handleAdded(iter)
            IOObjectRelease(iter)
        }
    }

    private func handleAdded(_ iter: io_iterator_t) {
        while case let service = IOIteratorNext(iter), service != 0 {
            if let s = makeSource(from: service), !sources.contains(where: { $0.id == s.id }) {
                sources.append(s)
            }
            IOObjectRelease(service)
        }
    }

    private func handleRemoved(_ iter: io_iterator_t) {
        while case let service = IOIteratorNext(iter), service != 0 {
            let entryID = IOKitSupport.entryID(for: service)
            sources.removeAll { $0.id == entryID }
            IOObjectRelease(service)
        }
    }

    private func makeSource(from service: io_service_t) -> PowerSource? {
        let entryID = IOKitSupport.entryID(for: service)
        guard let dict = IOKitSupport.properties(for: service) else { return nil }

        let name = (dict["PowerSourceName"] as? String) ?? "Unknown"
        let parentType = (dict["ParentPortType"] as? NSNumber)?.intValue ?? 0
        let parentNum = (dict["ParentPortNumber"] as? NSNumber)?.intValue ?? 0

        let options: [PowerOption] = parseOptions(dict["PowerSourceOptions"])
        let winning: PowerOption? = parseOption(dict["WinningPowerSourceOption"])

        return PowerSource(
            id: entryID,
            name: name,
            parentPortType: parentType,
            parentPortNumber: parentNum,
            options: options,
            winning: winning
        )
    }

    private func parseOptions(_ value: Any?) -> [PowerOption] {
        // CF arrays from IOKit don't always bridge cleanly to [Any] in Swift.
        // Cast to NSArray and iterate — that's the reliable path.
        guard let arr = value as? NSArray else { return [] }
        return arr.compactMap { parseOption($0) }
    }

    private func parseOption(_ value: Any?) -> PowerOption? {
        let dict: [String: Any]?
        if let d = value as? [String: Any] {
            dict = d
        } else if let nsd = value as? NSDictionary {
            var converted: [String: Any] = [:]
            for case let (key, val) as (String, Any) in nsd {
                converted[key] = val
            }
            dict = converted
        } else {
            dict = nil
        }
        guard let dict else { return nil }
        let v = (dict["Voltage (mV)"] as? NSNumber)?.intValue ?? 0
        let i = (dict["Max Current (mA)"] as? NSNumber)?.intValue ?? 0
        let p = (dict["Max Power (mW)"] as? NSNumber)?.intValue ?? (v * i / 1000)
        guard v > 0 else { return nil }
        return PowerOption(voltageMV: v, maxCurrentMA: i, maxPowerMW: p)
    }
}
