import SwiftUI

struct PowerSourceList: View {
    let sources: [PowerSource]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(sources) { source in
                if !source.options.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(source.name) profiles")
                            .font(.caption).foregroundStyle(.secondary)
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
                .font(.callout.monospacedDigit())
            if isActive {
                Text("active").font(.caption2).foregroundStyle(.green)
            }
            Spacer()
        }
    }
}
