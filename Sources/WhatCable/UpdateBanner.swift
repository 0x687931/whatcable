import AppKit
import SwiftUI

struct UpdateBanner: View {
    let update: AvailableUpdate
    @ObservedObject private var installer = Installer.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("WhatCable \(update.version) is available")
                        .font(.system(size: 12, weight: .semibold))
                    statusLine
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
            }
            actionButtons
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var statusLine: some View {
        switch installer.state {
        case .idle:
            Text("You're on \(AppInfo.version)")
        case .downloading:
            Text("Downloading...")
        case .verifying:
            Text("Verifying signature...")
        case .installing:
            Text("Installing - WhatCable will relaunch")
        case .failed(let message):
            Text("Install failed: \(message)").foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch installer.state {
        case .idle, .failed:
            HStack(spacing: 6) {
                Button("View release") {
                    NSWorkspace.shared.open(update.url)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if update.downloadURL != nil {
                    Button("Install update") {
                        Installer.shared.install(update)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .downloading, .verifying, .installing:
            ProgressView().controlSize(.small)
        }
    }
}
