import SwiftUI

/// Settings panel shown in place of the main popover content. Pushes a
/// "Done" header and groups toggles by purpose. `showAdvanced` is owned
/// by `ContentView` (ephemeral, resets between sessions) so we take it
/// as a binding; everything else lives on `AppSettings`.
struct SettingsView: View {
    @Binding var showAdvanced: Bool
    let dismiss: () -> Void

    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    section("Display") {
                        Toggle("Show technical details", isOn: $showAdvanced)
                        Toggle("Hide empty ports", isOn: $settings.hideEmptyPorts)
                    }
                    section("Behavior") {
                        Toggle("Launch at login", isOn: $settings.launchAtLogin)
                        Toggle("Show in menu bar", isOn: $settings.useMenuBarMode)
                        Text(settings.useMenuBarMode
                             ? "Lives in the menu bar with no Dock icon."
                             : "Runs as a regular Dock app with a window.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    section("Notifications") {
                        Toggle("Notify on cable changes", isOn: $settings.notifyOnChanges)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "gearshape")
                .font(.title2)
            Text("Settings").font(.headline)
            Spacer()
            Button("Done", action: dismiss)
                .keyboardShortcut(.defaultAction)
        }
        .padding(12)
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                content()
            }
            .toggleStyle(GreenSwitchToggleStyle())
            .controlSize(.small)
        }
    }
}

struct GreenSwitchToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? Color.green : Color.gray.opacity(0.35))
                    .frame(width: 32, height: 18)
                Circle()
                    .fill(Color.white)
                    .frame(width: 14, height: 14)
                    .padding(.horizontal, 2)
                    .shadow(color: .black.opacity(0.18), radius: 1, y: 0.5)
            }
            .animation(.easeInOut(duration: 0.16), value: configuration.isOn)
            .onTapGesture {
                configuration.isOn.toggle()
            }
        }
        .contentShape(Rectangle())
    }
}
