import AppKit
import SwiftUI

struct TopFiveReceiptData {
    let processes: [ProcessMemoryInfo]
    let topFiveTotalCost: Double
    let systemRAMValue: Double
    let totalPhysicalRAMGB: Double
    let generatedAt: Date
}

struct TopFiveReceiptView: View {
    let data: TopFiveReceiptData

    private static let paper = Color(red: 0.96, green: 0.94, blue: 0.90)
    private static let ink = Color(red: 0.10, green: 0.10, blue: 0.10)
    private static let fadedInk = Color(red: 0.10, green: 0.10, blue: 0.10).opacity(0.55)
    private static let receiptWidth: CGFloat = 340

    private var timestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd  HH:mm:ss"
        return formatter.string(from: data.generatedAt)
    }

    var body: some View {
        ZStack {
            Color(white: 0.42)

            VStack(spacing: 0) {
                receiptBody
            }
            .frame(width: Self.receiptWidth)
            .background(Self.paper)
            .shadow(color: .black.opacity(0.28), radius: 10, x: 2, y: 6)
            .rotationEffect(.degrees(-1.2))
        }
        .padding(40)
    }

    private var receiptBody: some View {
        VStack(spacing: 10) {
            headerBlock
            dashedRule
            metaBlock
            dashedRule
            lineItemsBlock
            dashedRule
            totalsBlock
            dashedRule
            footerBlock
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 28)
        .foregroundStyle(Self.ink)
        .font(.system(size: 11, design: .monospaced))
    }

    private var headerBlock: some View {
        VStack(spacing: 4) {
            Text("MONEY LEAK MONITOR")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .tracking(1.2)

            Text("RAM EXPENSE REPORT")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Self.fadedInk)
        }
        .frame(maxWidth: .infinity)
    }

    private var metaBlock: some View {
        VStack(spacing: 3) {
            metaRow(label: "DATE", value: timestamp)
            metaRow(label: "TERMINAL", value: "RAM AUDIT #1")
            metaRow(
                label: "SYSTEM",
                value: String(format: "%.0f GB @ $%.0f", data.totalPhysicalRAMGB, data.systemRAMValue)
            )
        }
    }

    private var lineItemsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TOP 5 LEAKS")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(Self.fadedInk)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 2)

            ForEach(Array(data.processes.enumerated()), id: \.element.id) { index, process in
                lineItem(rank: index + 1, process: process)
            }
        }
    }

    private func lineItem(rank: Int, process: ProcessMemoryInfo) -> some View {
        VStack(spacing: 3) {
            HStack(alignment: .top, spacing: 6) {
                Text(String(format: "%d.", rank))
                    .frame(width: 18, alignment: .leading)
                    .foregroundStyle(Self.fadedInk)

                if let icon = process.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.medium)
                        .saturation(0)
                        .contrast(1.1)
                        .frame(width: 14, height: 14)
                        .padding(.top, 1)
                }

                Text(process.processName)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(process.formattedCost)
                    .monospacedDigit()
            }

            HStack {
                Text("")
                    .frame(width: 18)
                Text(process.formattedMemory)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Self.fadedInk)
                Spacer()
                if data.topFiveTotalCost > 0 {
                    let pct = (process.memoryCost / data.topFiveTotalCost) * 100
                    Text(String(format: "%.1f%% of top 5", pct))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Self.fadedInk)
                }
            }
        }
    }

    private var totalsBlock: some View {
        VStack(spacing: 6) {
            HStack {
                Text("TOP 5 SUBTOTAL")
                Spacer()
                Text(String(format: "$%.2f", data.topFiveTotalCost))
                    .monospacedDigit()
                    .fontWeight(.semibold)
            }

            if let top = data.processes.first {
                HStack {
                    Text("BIGGEST LEAK")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Self.fadedInk)
                    Spacer()
                    Text(top.processName)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Self.fadedInk)
                        .lineLimit(1)
                }
            }
        }
    }

    private var footerBlock: some View {
        VStack(spacing: 6) {
            Text("THANK YOU FOR LEAKING")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(0.8)

            Text("NO REFUNDS ON RAM")
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(Self.fadedInk)

            Text("* * *")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Self.fadedInk)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    private var dashedRule: some View {
        Text(String(repeating: "- ", count: 28))
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(Self.fadedInk)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity)
    }

    private func metaRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(Self.fadedInk)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 9, design: .monospaced))
    }
}
