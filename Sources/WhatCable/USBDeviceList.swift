import SwiftUI

struct USBDeviceList: View {
    let devices: [USBDevice]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("USB devices observed")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(devices) { device in
                HStack(spacing: 6) {
                    Image(systemName: "externaldrive")
                        .foregroundStyle(.secondary)
                    Text("\(device.productName ?? "Unknown") - \(device.speedLabel)")
                        .font(.callout)
                    Spacer()
                }
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }
}
