import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject private var cableStore = CableStateStore.shared
    @EnvironmentObject private var refresh: RefreshSignal
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var updates = UpdateChecker.shared
    @State private var showSettings = false

    private var showAdvanced: Bool {
        settings.showTechnicalDetails || refresh.optionHeld
    }

    private var idlePortsCopy: String {
        let count = cableStore.ports.count
        let subject = count == 1 ? "port is" : "ports are"
        return "\(count) \(subject) idle. Turn off Hide empty ports in Settings to show idle ports."
    }

    var body: some View {
        Group {
            if showSettings {
                SettingsView(dismiss: { showSettings = false })
            } else {
                mainContent
            }
        }
        .frame(width: 320)
        .fixedSize(horizontal: false, vertical: true)
        .modifier(LiquidGlassBackground())
        .onAppear {
            cableStore.start()
        }
        .onChange(of: refresh.tick) { _, _ in
            cableStore.refresh()
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            header
            if let update = updates.available {
                UpdateBanner(update: update)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
            let visiblePorts = settings.hideEmptyPorts
                ? cableStore.ports.filter { $0.connectionActive == true }
                : cableStore.ports
            if visiblePorts.isEmpty {
                if cableStore.ports.isEmpty {
                    noPortsState
                } else {
                    nothingConnectedState
                }
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        let warningItems = visiblePorts.compactMap { port -> PortWarningItem? in
                            let sources = cableStore.sources(for: port)
                            let identities = cableStore.identities(for: port)
                            guard let diagnostic = ChargingDiagnostic(port: port, sources: sources, identities: identities),
                                  diagnostic.isWarning else {
                                return nil
                            }
                            return PortWarningItem(
                                id: port.id,
                                portName: port.portDescription ?? port.serviceName,
                                diagnostic: diagnostic
                            )
                        }
                        ForEach(warningItems) { item in
                            PortWarningBanner(item: item)
                        }

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 8),
                                GridItem(.flexible(), spacing: 8)
                            ],
                            spacing: 8
                        ) {
                            ForEach(visiblePorts) { port in
                                PortCard(
                                    port: port,
                                    powerSources: cableStore.sources(for: port),
                                    identities: cableStore.identities(for: port)
                                )
                            }
                        }

                        if showAdvanced {
                            ForEach(visiblePorts) { port in
                                PortDetailsSection(
                                    port: port,
                                    powerSources: cableStore.sources(for: port),
                                    identities: cableStore.identities(for: port)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 16)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text(AppInfo.name.uppercased())
                .font(.system(size: 10, weight: .medium))
                .tracking(1.6)
                .foregroundStyle(.tertiary)
            Spacer()
            Button {
                refresh.bump()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh")
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")
            if !settings.useMenuBarMode {
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(.borderless)
                .help("Quit \(AppInfo.name)")
            }
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var noPortsState: some View {
        VStack(spacing: 8) {
            Image(systemName: "powerplug")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)
            Text("No USB-C ports")
                .font(.system(size: 22, weight: .medium))
            Text("No port-controller services were found. Try Refresh, or check USB in System Information.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private var nothingConnectedState: some View {
        VStack(spacing: 8) {
            Image(systemName: "cable.connector.slash")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)
            Text("Nothing connected")
                .font(.system(size: 22, weight: .medium))
            Text(idlePortsCopy)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

}

private struct LiquidGlassBackground: ViewModifier {
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            content.glassEffect(
                .regular,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        } else {
            content.background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.regularMaterial)
            )
        }
        #else
        content.background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.regularMaterial)
        )
        #endif
    }
}
