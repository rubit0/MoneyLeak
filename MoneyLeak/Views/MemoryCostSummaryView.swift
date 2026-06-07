import Charts
import SwiftUI

struct MemoryCostSummaryView: View {
    let viewModel: ProcessListViewModel

    @State private var highlightedID: String?
    @State private var hoverClearTask: Task<Void, Never>?
    @State private var topFiveListHeight: CGFloat = 200

    private static let chartColors: [Color] = [
        .blue, .orange, .green, .purple, .pink
    ]

    private var topFive: [ProcessMemoryInfo] {
        viewModel.topFiveByCost
    }

    private var topFiveTotalCost: Double {
        topFive.reduce(0) { $0 + $1.memoryCost }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            summaryColumn

            topFivePanel
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var summaryColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            summaryTile(
                title: "System RAM Value",
                value: String(format: "$%.2f", viewModel.systemRAMValue),
                subtitle: formatGB(viewModel.totalPhysicalRAMBytes)
            )

            summaryTile(
                title: "RAM In Use",
                value: String(format: "$%.2f", viewModel.totalOccupiedCost),
                subtitle: formatGB(viewModel.totalOccupiedBytes)
            )

            summaryTile(
                title: "Unused RAM Value",
                value: String(format: "$%.2f", viewModel.unusedRAMCost),
                subtitle: formatGB(viewModel.unusedRAMBytes)
            )
        }
        .frame(width: 168, alignment: .leading)
    }

    private var topFivePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Top 5 Most Expensive")
                .font(.headline)

            if topFive.isEmpty {
                Text("No processes")
                    .foregroundStyle(.secondary)
            } else {
                HStack(alignment: .top, spacing: 28) {
                    topFiveList
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            GeometryReader { geometry in
                                Color.clear
                                    .preference(key: TopFiveListHeightKey.self, value: geometry.size.height)
                            }
                        }

                    topFiveChart
                        .frame(width: topFiveListHeight, height: topFiveListHeight)
                }
                .onPreferenceChange(TopFiveListHeightKey.self) { height in
                    if height > 0 {
                        topFiveListHeight = height
                    }
                }
            }
        }
    }

    private var topFiveList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(topFive.enumerated()), id: \.element.id) { index, process in
                let isHighlighted = highlightedID == process.id
                let isDimmed = highlightedID != nil && !isHighlighted

                HStack(spacing: 8) {
                    Circle()
                        .fill(Self.chartColors[index % Self.chartColors.count])
                        .frame(width: 8, height: 8)

                    Text("\(index + 1).")
                        .foregroundStyle(.secondary)
                        .frame(width: 16, alignment: .trailing)
                        .monospacedDigit()

                    ProcessIconView(icon: process.icon)

                    Text(process.processName)
                        .lineLimit(1)
                        .fontWeight(isHighlighted ? .semibold : .regular)

                    Spacer(minLength: 8)

                    Text(shareLabel(for: process))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .font(.caption)

                    Text(process.formattedCost)
                        .monospacedDigit()
                        .foregroundStyle(viewModel.costColor(for: process.memoryCost))
                }
                .font(.callout)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHighlighted ? Color.accentColor.opacity(0.18) : Color.clear)
                }
                .opacity(isDimmed ? 0.45 : 1.0)
                .animation(.easeOut(duration: 0.15), value: highlightedID)
                .onHover { hovering in
                    if hovering {
                        setHighlight(process.id)
                    } else {
                        scheduleClearHighlight(process.id)
                    }
                }
            }
        }
    }

    private var topFiveChart: some View {
        ZStack {
            Chart(Array(topFive.enumerated()), id: \.element.id) { index, process in
                let isHighlighted = highlightedID == process.id
                let isDimmed = highlightedID != nil && !isHighlighted

                SectorMark(
                    angle: .value("Cost", process.memoryCost),
                    innerRadius: .ratio(0.58),
                    angularInset: isHighlighted ? 5 : 1.5
                )
                .foregroundStyle(Self.chartColors[index % Self.chartColors.count])
                .opacity(isDimmed ? 0.35 : 1.0)
                .cornerRadius(3)
            }
            .chartLegend(.hidden)
            .chartPlotStyle { plotArea in
                plotArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    if let plotFrame = proxy.plotFrame {
                        let frame = geometry[plotFrame]
                        Color.clear
                            .contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    if let id = processIDAt(location: location, in: frame) {
                                        setHighlight(id)
                                    } else if let current = highlightedID,
                                              topFive.contains(where: { $0.id == current }) {
                                        scheduleClearHighlight(current)
                                    }
                                case .ended:
                                    if let current = highlightedID,
                                       topFive.contains(where: { $0.id == current }) {
                                        scheduleClearHighlight(current)
                                    }
                                }
                            }
                    }
                }
            }
            .animation(.easeOut(duration: 0.15), value: highlightedID)

            VStack(spacing: 2) {
                if let highlightedID,
                   let process = topFive.first(where: { $0.id == highlightedID }) {
                    Text(process.processName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(process.formattedCost)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                    Text(shareLabel(for: process))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                } else {
                    Text("Top 5")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(String(format: "$%.0f", topFiveTotalCost))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
            }
            .animation(.easeOut(duration: 0.15), value: highlightedID)
            .allowsHitTesting(false)
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func setHighlight(_ id: String?) {
        hoverClearTask?.cancel()
        hoverClearTask = nil
        highlightedID = id
    }

    private func scheduleClearHighlight(_ id: String) {
        hoverClearTask?.cancel()
        hoverClearTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(60))
            guard !Task.isCancelled else { return }
            if highlightedID == id {
                highlightedID = nil
            }
        }
    }

    private func processIDAt(location: CGPoint, in frame: CGRect) -> String? {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = hypot(dx, dy)
        let outerRadius = min(frame.width, frame.height) / 2
        let innerRadius = outerRadius * 0.58

        guard distance >= innerRadius, distance <= outerRadius, topFiveTotalCost > 0 else {
            return nil
        }

        var angle = atan2(dx, -dy) * 180 / .pi
        if angle < 0 { angle += 360 }

        var cumulativeAngle: Double = 0
        for process in topFive {
            let sweep = (process.memoryCost / topFiveTotalCost) * 360
            if angle >= cumulativeAngle, angle < cumulativeAngle + sweep {
                return process.id
            }
            cumulativeAngle += sweep
        }

        return topFive.last?.id
    }

    private func shareLabel(for process: ProcessMemoryInfo) -> String {
        guard topFiveTotalCost > 0 else { return "0%" }
        let pct = (process.memoryCost / topFiveTotalCost) * 100
        return String(format: "%.1f%%", pct)
    }

    private func summaryTile(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .monospacedDigit()
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func formatGB(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824.0
        return String(format: "%.1f GB", gb)
    }
}

private struct TopFiveListHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
