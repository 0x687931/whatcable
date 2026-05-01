import SwiftUI

struct DiagnosticBanner: View {
    let diagnostic: ChargingDiagnostic

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: diagnostic.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(diagnostic.isWarning ? Color.orange : Color.green, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(diagnostic.summary).font(.system(size: 12, weight: .semibold))
                Text(diagnostic.detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(
            (diagnostic.isWarning ? Color.orange : Color.green)
                .opacity(0.1),
            in: RoundedRectangle(cornerRadius: 8)
        )
    }
}
