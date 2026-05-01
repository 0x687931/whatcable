import SwiftUI

struct USBDeviceList: View {
    let devices: [USBDevice]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("USB devices observed")
                .font(.system(size: 10, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
            ForEach(devices) { device in
                HStack(spacing: 6) {
                    Image(systemName: "externaldrive")
                        .foregroundStyle(.secondary)
                    Text("\(device.productName ?? "Unknown") - \(device.speedLabel)")
                        .font(.system(size: 12))
                    Spacer()
                }
            }
        }
        .padding(.top, 8)
    }
}
