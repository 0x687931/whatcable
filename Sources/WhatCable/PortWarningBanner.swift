import SwiftUI

struct PortWarningItem: Identifiable {
    let id: UInt64
    let portName: String
    let diagnostic: ChargingDiagnostic
}

struct PortWarningBanner: View {
    let item: PortWarningItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.portName.uppercased())
                .font(.system(size: 10, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(.tertiary)

            DiagnosticBanner(diagnostic: item.diagnostic)
        }
    }
}
