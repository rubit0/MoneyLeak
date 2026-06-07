import SwiftUI

struct ProcessRowView: View {
    let process: ProcessMemoryInfo
    let totalRAMBytes: UInt64
    let isHighlighted: Bool
    let costColor: Color

    var body: some View {
        HStack(spacing: 0) {
            HStack {
                ProcessIconView(icon: process.icon)
            }
            .frame(width: 32, alignment: .leading)

            Text(process.processName)
                .lineLimit(1)
                .frame(minWidth: 140, maxWidth: .infinity, alignment: .leading)

            Text(process.formattedMemory)
                .monospacedDigit()
                .frame(width: 90, alignment: .trailing)

            Text(process.formattedCost)
                .monospacedDigit()
                .foregroundStyle(costColor)
                .fontWeight(isHighlighted ? .semibold : .regular)
                .frame(width: 80, alignment: .trailing)

            Text(process.formattedPercentage(of: totalRAMBytes))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 8)
        .background(isHighlighted ? costColor.opacity(0.12) : Color.clear)
    }
}
