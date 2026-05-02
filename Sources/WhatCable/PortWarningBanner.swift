import SwiftUI

struct PortWarningItem: Identifiable {
    let id: String
    let portName: String
    let diagnostic: any DiagnosticBannerContent
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
