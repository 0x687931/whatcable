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
            }
            Divider()
            let visiblePorts = settings.hideEmptyPorts
                ? cableStore.ports.filter { $0.connectionActive == true }
                : cableStore.ports
            if visiblePorts.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(visiblePorts) { port in
                            PortCard(
                                port: port,
                                powerSources: cableStore.sources(for: port),
                                identities: cableStore.identities(for: port),
                                showAdvanced: showAdvanced
                            )
                        }
                        if !cableStore.devices.isEmpty {
                            USBDeviceList(devices: cableStore.devices)
                        }
                    }
                    .padding(12)
                }
            }
            Divider()
            footer
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "cable.connector.horizontal")
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(AppInfo.name).font(.headline)
                Text(AppInfo.tagline)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
        .padding(12)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Text("\(cableStore.devices.count) USB device\(cableStore.devices.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("·").font(.caption).foregroundStyle(.secondary)
            Text("v\(AppInfo.version) · \(AppInfo.credit)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "powerplug")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No USB-C ports detected")
                .font(.headline)
            Text("This Mac doesn't seem to expose its port-controller services. Hit refresh, or check System Information → USB.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}
