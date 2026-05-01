import SwiftUI

struct DiagnosticBanner: View {
    let diagnostic: ChargingDiagnostic

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: diagnostic.icon)
                .foregroundStyle(diagnostic.isWarning ? Color.orange : Color.green)
                .font(.callout)
            VStack(alignment: .leading, spacing: 2) {
                Text(diagnostic.summary).font(.callout).bold()
                Text(diagnostic.detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(
            (diagnostic.isWarning ? Color.orange : Color.green)
                .opacity(0.1),
            in: RoundedRectangle(cornerRadius: 8)
        )
    }
}
