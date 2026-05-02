import SwiftUI

struct PortDetailsSection: View {
    let port: USBCPort
    let powerSources: [PowerSource]
    let identities: [PDIdentity]

    @State private var isExpanded: Bool = false

    private var summary: PortSummary {
        PortSummary(port: port, sources: powerSources, identities: identities)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                if !summary.bullets.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(summary.bullets, id: \.self) { bullet in
                            HStack(alignment: .top, spacing: 6) {
                                Text("-").foregroundStyle(.secondary)
                                Text(bullet).font(.system(size: 12))
                                Spacer()
                            }
                        }
                    }
                }

                if let diagnostic = ChargingDiagnostic(port: port, sources: powerSources, identities: identities) {
                    DiagnosticBanner(diagnostic: diagnostic)
                }

                if !powerSources.isEmpty {
                    PowerSourceList(sources: powerSources)
                }

                AdvancedPortDetails(port: port)
            }
            .padding(.top, 8)
        } label: {
            Text(port.portDescription ?? port.serviceName)
                .font(.system(size: 10, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
        }
    }
}
