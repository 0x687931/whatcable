import Foundation

protocol DiagnosticBannerContent {
    var icon: String { get }
    var isWarning: Bool { get }
    var summary: String { get }
    var detail: String { get }
}

extension ChargingDiagnostic: DiagnosticBannerContent {}

struct SessionQualityDiagnostic: DiagnosticBannerContent, Equatable {
    enum Kind: Equatable {
        case overcurrent
        case unstableConnection
    }

    let kind: Kind

    var icon: String {
        switch kind {
        case .overcurrent:
            return "exclamationmark.triangle.fill"
        case .unstableConnection:
            return "cable.connector.slash"
        }
    }

    var isWarning: Bool { true }

    var summary: String {
        switch kind {
        case .overcurrent:
            return "Possible cable power fault"
        case .unstableConnection:
            return "Connection looks unstable"
        }
    }

    var detail: String {
        switch kind {
        case .overcurrent:
            return "This port reported an overcurrent event during this connection. Disconnect the cable, inspect the cable and port, and reconnect only if everything looks clean and undamaged."
        case .unstableConnection:
            return "This port has seen repeated plug or connection drops during this connection. Reseat the cable and inspect it if the warning returns."
        }
    }
}

struct SessionQualitySnapshot: Equatable {
    let plugEventCount: Int?
    let connectionCount: Int?
    let overcurrentCount: Int?

    init(port: USBCPort) {
        self.plugEventCount = port.plugEventCount
        self.connectionCount = port.connectionCount
        self.overcurrentCount = port.overcurrentCount
    }

    func diagnostic(for port: USBCPort) -> SessionQualityDiagnostic? {
        if positiveDelta(from: overcurrentCount, to: port.overcurrentCount) {
            return SessionQualityDiagnostic(kind: .overcurrent)
        }

        let plugDropEvents = max(
            delta(from: plugEventCount, to: port.plugEventCount) ?? 0,
            delta(from: connectionCount, to: port.connectionCount) ?? 0
        )
        if plugDropEvents >= 2 {
            return SessionQualityDiagnostic(kind: .unstableConnection)
        }

        return nil
    }

    private func positiveDelta(from baseline: Int?, to current: Int?) -> Bool {
        guard let delta = delta(from: baseline, to: current) else { return false }
        return delta > 0
    }

    private func delta(from baseline: Int?, to current: Int?) -> Int? {
        guard let baseline, let current else { return nil }
        return max(0, current - baseline)
    }
}
