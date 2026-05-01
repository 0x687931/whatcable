import SwiftUI

struct PowerSourceList: View {
    let sources: [PowerSource]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(sources) { source in
                if !source.options.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(source.name) profiles")
                            .font(.system(size: 10, weight: .medium))
                            .tracking(0.6)
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)
                        ForEach(source.options.sorted(by: { $0.voltageMV < $1.voltageMV }), id: \.self) { option in
                            PowerOptionRow(option: option, isActive: option == source.winning)
                        }
                    }
                }
            }
        }
    }
}

private struct PowerOptionRow: View {
    let option: PowerOption
    let isActive: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isActive ? Color.green : Color.secondary)
                .font(.caption)
            Text("\(option.voltsLabel) @ \(option.ampsLabel) - \(option.wattsLabel)")
                .font(.system(size: 12).monospacedDigit())
            if isActive {
                Text("active").font(.system(size: 9, weight: .medium)).foregroundStyle(.green)
            }
            Spacer()
        }
    }
}
