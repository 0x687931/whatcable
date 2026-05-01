import SwiftUI

struct ContentView: View {
    @ObservedObject private var cableStore = CableStateStore.shared
    @EnvironmentObject private var refresh: RefreshSignal
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var updates = UpdateChecker.shared
    @State private var showAdvanced = false
    @State private var showSettings = false

    var body: some View {
        Group {
            if showSettings {
                SettingsView(showAdvanced: $showAdvanced, dismiss: { showSettings = false })
            } else {
                mainContent
            }
        }
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
                emptyState
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

                        if !cableStore.devices.isEmpty {
                            USBDeviceList(devices: cableStore.devices)
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
        .background(.regularMaterial)
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
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "powerplug")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)
            Text("No USB-C ports")
                .font(.system(size: 22, weight: .medium))
            Text("Plug a cable in to see what it can do.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}
