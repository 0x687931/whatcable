import SwiftUI

struct PortCard: View {
    private static let tileHeight: CGFloat = 154

    let port: USBCPort
    let powerSources: [PowerSource]
    let identities: [PDIdentity]

    var summary: PortSummary {
        PortSummary(port: port, sources: powerSources, identities: identities)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: tileIcon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(tileColor)
                .frame(width: 24, height: 24, alignment: .leading)

            Text(tileName.uppercased())
                .font(.system(size: 10, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(summary.status == .empty ? .quaternary : .tertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(tileHeadline)
                .font(.system(size: 22, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(summary.status == .empty ? .tertiary : .primary)
                .lineLimit(2, reservesSpace: true)
                .minimumScaleFactor(0.75)

            Text(tileContext ?? " ")
                .font(.system(size: 12))
                .monospacedDigit()
                .foregroundStyle(summary.status == .empty ? .tertiary : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .opacity(tileContext == nil ? 0 : 1)
        }
        .padding(12)
        .frame(
            maxWidth: .infinity,
            minHeight: Self.tileHeight,
            maxHeight: Self.tileHeight,
            alignment: .topLeading
        )
        .background(tileBackground, in: RoundedRectangle(cornerRadius: 10))
    }

    private var diagnostic: ChargingDiagnostic? {
        ChargingDiagnostic(port: port, sources: powerSources, identities: identities)
    }

    private var tileName: String {
        if let description = port.portTypeDescription, description.hasPrefix("MagSafe") {
            return "MagSafe"
        }
        if let number = port.portNumber {
            return "USB-C \(number)"
        }
        return port.portTypeDescription ?? "USB-C"
    }

    private var tileIcon: String {
        if let diagnostic, diagnostic.isWarning {
            return "bolt.fill"
        }
        switch summary.status {
        case .empty:
            return "powerplug"
        case .charging:
            return "bolt.fill"
        case .dataDevice, .thunderboltCable:
            return "cable.connector"
        case .displayCable:
            return "display"
        case .unknown:
            return "questionmark.circle"
        }
    }

    private var tileColor: Color {
        if let diagnostic {
            return diagnostic.isWarning ? .orange : .green
        }
        switch summary.status {
        case .empty:
            return Color.secondary.opacity(0.3)
        case .charging:
            return .green
        case .unknown:
            return .orange
        case .dataDevice, .thunderboltCable, .displayCable:
            return .primary
        }
    }

    private var tileBackground: Color {
        Color.gray.opacity(summary.status == .empty ? 0.04 : 0.08)
    }

    private var tileHeadline: String {
        if let diagnostic {
            switch diagnostic.bottleneck {
            case .cableLimit:
                return "Cable can't go faster"
            case .macLimit:
                return "Charging slower than possible"
            case .unknownCableLimit:
                return "Cable not rated"
            case .fine:
                return "Power looks good"
            case .chargerLimit:
                return "Checking charger"
            }
        }
        switch summary.status {
        case .empty:
            return "Empty"
        case .charging:
            return "Power connected"
        case .dataDevice:
            return summary.headline.contains("Slow") ? "Slow USB" : "USB device"
        case .thunderboltCable:
            return "Thunderbolt"
        case .displayCable:
            return "Display"
        case .unknown:
            return summary.headline
        }
    }

    private var tileContext: String? {
        if let diagnostic {
            return wattContext(for: diagnostic.bottleneck)
        }
        if let cableVDO = identities
            .first(where: { $0.endpoint == .sopPrime || $0.endpoint == .sopDoublePrime })?
            .cableVDO {
            return speedValue(for: cableVDO.speed)
        }
        if summary.status == .dataDevice {
            return port.superSpeedActive == true ? "5 Gbps" : "480 Mbps"
        }
        if summary.status == .displayCable {
            return "DisplayPort"
        }
        if summary.status == .empty {
            return nil
        }
        return summary.subtitle
    }

    private func wattContext(for bottleneck: ChargingDiagnostic.Bottleneck) -> String {
        switch bottleneck {
        case .cableLimit(let cableW, let chargerW):
            return "\(cableW) W of \(chargerW) W"
        case .macLimit(let negotiatedW, let chargerW, _):
            return "\(negotiatedW) W of \(chargerW) W"
        case .unknownCableLimit(let negotiatedW, let chargerW):
            return "\(negotiatedW) W of \(chargerW) W"
        case .fine(let negotiatedW):
            if let chargerW, chargerW > negotiatedW {
                return "\(negotiatedW) W of \(chargerW) W"
            }
            return "\(negotiatedW) W"
        case .chargerLimit(let chargerW):
            return "Up to \(chargerW) W"
        }
    }

    private var chargerW: Int? {
        guard let usbPD = powerSources.first(where: { $0.name == "USB-PD" }),
              usbPD.maxPowerMW > 0 else {
            return nil
        }
        return Int((Double(usbPD.maxPowerMW) / 1000).rounded())
    }

    private func speedValue(for speed: PDVDO.CableSpeed) -> String {
        switch speed {
        case .usb20:
            return "480 Mbps"
        case .usb32Gen1:
            return "5 Gbps"
        case .usb32Gen2:
            return "10 Gbps"
        case .usb4Gen3:
            return "40 Gbps"
        case .usb4Gen4:
            return "80 Gbps"
        }
    }
}
