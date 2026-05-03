import Foundation

/// One PDO (Power Data Object) advertised by the connected source.
struct PowerOption: Hashable {
    let voltageMV: Int
    let maxCurrentMA: Int
    let maxPowerMW: Int

    var voltsLabel: String {
        String(format: "%.0fV", Double(voltageMV) / 1000)
    }
    var ampsLabel: String {
        String(format: "%.2fA", Double(maxCurrentMA) / 1000)
    }
    var wattsLabel: String {
        String(format: "%.0fW", Double(maxPowerMW) / 1000)
    }
}

/// A power source advertised on a USB-C / MagSafe port (parsed from
/// `IOPortFeaturePowerSource`). One port may have multiple sources
/// (e.g. "USB-PD" + "Brick ID").
struct PowerSource: Identifiable, Hashable {
    let id: UInt64
    let name: String                // "USB-PD", "Brick ID"
    let parentPortType: Int         // 0x2 = USB-C, 0x11 = MagSafe 3
    let parentPortNumber: Int
    let options: [PowerOption]
    let winning: PowerOption?

    var maxPowerMW: Int {
        if let max = options.map(\.maxPowerMW).max(), max > 0 {
            return max
        }
        return winning?.maxPowerMW ?? 0
    }

    /// Match key joining a power source to its port.
    var portKey: String { "\(parentPortType)/\(parentPortNumber)" }
}

extension PowerSource {
    static func preferredChargingSource(in sources: [PowerSource]) -> PowerSource? {
        sources.first { $0.name == "USB-PD" }
            ?? sources.first { $0.name == "Brick ID" }
    }
}
