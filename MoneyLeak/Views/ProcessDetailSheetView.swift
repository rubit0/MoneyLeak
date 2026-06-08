import Charts
import SwiftUI

struct ProcessDetailSheetView: View {
    let process: ProcessMemoryInfo
    let totalPhysicalRAMBytes: UInt64
    let costColor: (Double) -> Color

    @Environment(\.dismiss) private var dismiss

    @State private var highlightedPID: Int32?
    @State private var hoverClearTask: Task<Void, Never>?

    private static let chartColors: [Color] = [
        .blue, .orange, .green, .purple, .pink, .teal, .indigo, .mint, .yellow, .cyan
    ]

    private var members: [ProcessMemberInfo] {
        process.members
    }

    private var totalMemberMemory: UInt64 {
        process.residentMemoryBytes
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(minWidth: 560, minHeight: 420)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ProcessIconView(icon: process.icon)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(process.processName)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(process.formattedMemory)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                Text(process.formattedCost)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(costColor(process.memoryCost))
            }
        }
        .padding(20)
    }

    private var subtitle: String {
        if process.isGrouped {
            return "\(process.processCount) processes · \(process.formattedPercentage(of: totalPhysicalRAMBytes)) of RAM"
        }
        return "\(process.formattedPercentage(of: totalPhysicalRAMBytes)) of RAM"
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 24) {
            memberList
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            chartPanel
                .frame(width: 240, alignment: .top)
        }
        .padding(20)
        .frame(maxHeight: .infinity)
    }

    private var chartPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            memberChart
                .frame(width: 220, height: 220)
                .frame(maxWidth: .infinity)

            chartMemberDetail
        }
        .padding(.top, 8)
    }

    private var memberList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Processes")
                .font(.headline)

            if members.isEmpty {
                Text("No process details available")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
                            memberRow(member, index: index)
                        }
                    }
                }
            }
        }
    }

    private func memberRow(_ member: ProcessMemberInfo, index: Int) -> some View {
        let isHighlighted = highlightedPID == member.pid
        let isDimmed = highlightedPID != nil && !isHighlighted
        let color = Self.chartColors[index % Self.chartColors.count]

        return HStack(alignment: .center, spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(member.name)
                .fontWeight(isHighlighted ? .semibold : .regular)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                Text(member.formattedShare(of: totalMemberMemory))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                Text(member.formattedMemory)
                    .monospacedDigit()

                Text(member.formattedCost)
                    .monospacedDigit()
                    .foregroundStyle(costColor(member.memoryCost))
            }
            .font(.callout)
            .frame(minWidth: 72, alignment: .trailing)
        }
        .font(.callout)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(isHighlighted ? Color.accentColor.opacity(0.18) : Color.clear)
        }
        .opacity(isDimmed ? 0.45 : 1.0)
        .animation(.easeOut(duration: 0.15), value: highlightedPID)
        .onHover { hovering in
            if hovering {
                setHighlight(member.pid)
            } else {
                scheduleClearHighlight(member.pid)
            }
        }
    }

    private var memberChart: some View {
        ZStack {
            Chart(Array(members.enumerated()), id: \.element.id) { index, member in
                let isHighlighted = highlightedPID == member.pid
                let isDimmed = highlightedPID != nil && !isHighlighted

                SectorMark(
                    angle: .value("Memory", member.residentMemoryBytes),
                    innerRadius: .ratio(0.58),
                    angularInset: isHighlighted ? 5 : 1.5
                )
                .foregroundStyle(Self.chartColors[index % Self.chartColors.count])
                .opacity(isDimmed ? 0.35 : 1.0)
                .cornerRadius(3)
            }
            .chartLegend(.hidden)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    if let plotFrame = proxy.plotFrame {
                        let frame = geometry[plotFrame]
                        Color.clear
                            .contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    if let pid = memberPIDAt(location: location, in: frame) {
                                        setHighlight(pid)
                                    } else if let current = highlightedPID,
                                              members.contains(where: { $0.pid == current }) {
                                        scheduleClearHighlight(current)
                                    }
                                case .ended:
                                    if let current = highlightedPID,
                                       members.contains(where: { $0.pid == current }) {
                                        scheduleClearHighlight(current)
                                    }
                                }
                            }
                    }
                }
            }
            .animation(.easeOut(duration: 0.15), value: highlightedPID)

            chartCenterLabel
                .allowsHitTesting(false)
        }
        .padding(8)
    }

    @ViewBuilder
    private var chartCenterLabel: some View {
        if let highlightedPID,
           let member = members.first(where: { $0.pid == highlightedPID }) {
            VStack(spacing: 2) {
                Text(member.formattedMemory)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                Text(member.formattedShare(of: totalMemberMemory))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        } else {
            VStack(spacing: 2) {
                Text(process.formattedMemory)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                if process.isGrouped {
                    Text("100%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
    }

    @ViewBuilder
    private var chartMemberDetail: some View {
        if let highlightedPID,
           let member = members.first(where: { $0.pid == highlightedPID }) {
            VStack(alignment: .leading, spacing: 4) {
                Text(member.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)

                if let path = member.executablePath {
                    Text(path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.easeOut(duration: 0.15), value: highlightedPID)
        } else {
            Text("Hover a process to view its executable path")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(16)
    }

    private func setHighlight(_ pid: Int32?) {
        hoverClearTask?.cancel()
        hoverClearTask = nil
        highlightedPID = pid
    }

    private func scheduleClearHighlight(_ pid: Int32) {
        hoverClearTask?.cancel()
        hoverClearTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(60))
            guard !Task.isCancelled else { return }
            if highlightedPID == pid {
                highlightedPID = nil
            }
        }
    }

    private func memberPIDAt(location: CGPoint, in frame: CGRect) -> Int32? {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = hypot(dx, dy)
        let outerRadius = min(frame.width, frame.height) / 2
        let innerRadius = outerRadius * 0.58

        guard distance >= innerRadius, distance <= outerRadius, totalMemberMemory > 0 else {
            return nil
        }

        var angle = atan2(dx, -dy) * 180 / .pi
        if angle < 0 { angle += 360 }

        var cumulativeAngle: Double = 0
        for member in members {
            let sweep = (Double(member.residentMemoryBytes) / Double(totalMemberMemory)) * 360
            if angle >= cumulativeAngle, angle < cumulativeAngle + sweep {
                return member.pid
            }
            cumulativeAngle += sweep
        }

        return members.last?.pid
    }
}
