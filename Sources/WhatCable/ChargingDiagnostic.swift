import Foundation

/// Compares charger output, cable rating, and currently negotiated PDO to
/// identify the bottleneck — the "why is my Mac charging slowly?" answer.
struct ChargingDiagnostic {
    enum Bottleneck {
        case chargerLimit(chargerW: Int)
        case cableLimit(cableW: Int, chargerW: Int)
        case macLimit(negotiatedW: Int, chargerW: Int, cableW: Int)
        case unknownCableLimit(negotiatedW: Int, chargerW: Int)
        case fine(negotiatedW: Int)
    }

    let bottleneck: Bottleneck
    let summary: String
    let detail: String

    var icon: String {
        switch bottleneck {
        case .chargerLimit: return "exclamationmark.triangle.fill"
        case .cableLimit: return "exclamationmark.triangle.fill"
        case .macLimit: return "questionmark.circle"
        case .unknownCableLimit: return "questionmark.circle"
        case .fine: return "checkmark.seal.fill"
        }
    }

    var isWarning: Bool {
        switch bottleneck {
        case .fine: return false
        default: return true
        }
    }
}

extension ChargingDiagnostic {
    init?(port: USBCPort, sources: [PowerSource], identities: [PDIdentity]) {
        guard let usbPD = sources.first(where: { $0.name == "USB-PD" }) else {
            return nil // No PD source on this port — no diagnostic to make.
        }
        guard port.connectionActive == true else {
            return nil // IOKit can retain stale PDOs after a cable is unplugged.
        }

        let chargerMaxW = Int((Double(usbPD.maxPowerMW) / 1000).rounded())
        let negotiatedW = usbPD.winning.map { Int((Double($0.maxPowerMW) / 1000).rounded()) }

        let cableMaxW: Int? = identities
            .first(where: { $0.endpoint == .sopPrime || $0.endpoint == .sopDoublePrime })?
            .cableVDO?.maxWatts

        // Order of suspicion:
        // 1. If cable rated below charger, cable is the bottleneck.
        // 2. If negotiated below both, the Mac (or current state) limits.
        // 3. Otherwise charger is the ceiling.
        if let cableW = cableMaxW, cableW < chargerMaxW {
            self.bottleneck = .cableLimit(cableW: cableW, chargerW: chargerMaxW)
            self.summary = "Cable is limiting charging speed"
            self.detail = "Charger can deliver up to \(chargerMaxW)W, but this cable is only rated to carry \(cableW)W. Replace the cable to charge faster."
        } else if let n = negotiatedW, n < chargerMaxW - 5 {
            if let cableW = cableMaxW {
                self.bottleneck = .macLimit(negotiatedW: n, chargerW: chargerMaxW, cableW: cableW)
                self.summary = "Power negotiated at \(n)W (charger can offer \(chargerMaxW)W)"
                self.detail = "Both the charger and cable can offer more, but the Mac is currently negotiating a lower power profile. This can be normal when the battery is full or nearly full, or when the system does not need more power."
            } else {
                self.bottleneck = .unknownCableLimit(negotiatedW: n, chargerW: chargerMaxW)
                self.summary = "Power negotiated at \(n)W (charger can offer \(chargerMaxW)W)"
                self.detail = "This cable does not advertise its rating, so WhatCable cannot tell whether the cable or the Mac is limiting available charging power."
            }
        } else if let n = negotiatedW {
            self.bottleneck = .fine(negotiatedW: n)
            self.summary = "Power negotiated at \(n)W"
            self.detail = "Charger and cable are well-matched. This is the available USB-PD power; macOS may still show Fully Charged when the battery is not drawing it."
        } else {
            self.bottleneck = .chargerLimit(chargerW: chargerMaxW)
            self.summary = "Charger advertises up to \(chargerMaxW)W"
            self.detail = "Negotiation hasn't completed yet."
        }
    }
}
