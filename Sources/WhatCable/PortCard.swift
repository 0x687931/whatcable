import SwiftUI

struct PortCard: View {
    let port: USBCPort
    let powerSources: [PowerSource]
    let identities: [PDIdentity]
    let showAdvanced: Bool

    var summary: PortSummary {
        PortSummary(port: port, sources: powerSources, identities: identities)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if !summary.bullets.isEmpty {
                bulletList
            }

            if let diag = ChargingDiagnostic(port: port, sources: powerSources, identities: identities) {
                DiagnosticBanner(diagnostic: diag)
                    .padding(.leading, 48)
            }

            if !powerSources.isEmpty {
                PowerSourceList(sources: powerSources)
                    .padding(.leading, 48)
            }

            if showAdvanced {
                Divider()
                AdvancedPortDetails(port: port)
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: summary.icon)
                .font(.system(size: 28))
                .foregroundStyle(summary.iconColor)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(port.portDescription ?? port.serviceName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(summary.headline)
                    .font(.title3).bold()
                Text(summary.subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var bulletList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(summary.bullets, id: \.self) { bullet in
                HStack(alignment: .top, spacing: 6) {
                    Text("-").foregroundStyle(.secondary)
                    Text(bullet).font(.callout)
                    Spacer()
                }
            }
        }
        .padding(.leading, 48)
    }
}
