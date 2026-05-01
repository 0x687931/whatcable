import SwiftUI

struct AdvancedPortDetails: View {
    let port: USBCPort

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            group("Connection") {
                row("Active", bool(port.connectionActive))
                row("E-marker chip", bool(port.activeCable))
                row("Optical", bool(port.opticalCable))
                row("USB active", bool(port.usbActive))
                row("SuperSpeed", bool(port.superSpeedActive))
                row("Plug events", port.plugEventCount.map(String.init) ?? "-")
            }
            group("Transports") {
                row("Supported", port.transportsSupported.joined(separator: ", "))
                row("Provisioned", port.transportsProvisioned.joined(separator: ", "))
                row("Active", port.transportsActive.isEmpty ? "-" : port.transportsActive.joined(separator: ", "))
            }
            rawProperties
        }
    }

    private var rawProperties: some View {
        DisclosureGroup("All raw IOKit properties (\(port.rawProperties.count))") {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(port.rawProperties.sorted(by: { $0.key < $1.key }), id: \.key) { property in
                    HStack(alignment: .top) {
                        Text(property.key).font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 200, alignment: .leading)
                        Text(property.value).font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                        Spacer()
                    }
                }
            }
            .padding(.top, 4)
        }
        .font(.caption)
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).bold().foregroundStyle(.secondary)
            content()
        }
    }

    private func row(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).font(.caption).foregroundStyle(.secondary).frame(width: 120, alignment: .leading)
            Text(value).font(.system(.caption, design: .monospaced))
            Spacer()
        }
    }

    private func bool(_ value: Bool?) -> String {
        guard let value else { return "-" }
        return value ? "Yes" : "No"
    }
}
