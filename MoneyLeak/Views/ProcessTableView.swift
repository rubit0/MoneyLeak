import AppKit
import SwiftUI

struct ProcessTableView: View {
    @Bindable var viewModel: ProcessListViewModel

    @State private var detailProcessID: String?

    private var detailProcess: ProcessMemoryInfo? {
        guard let detailProcessID else { return nil }
        return viewModel.processes.first { $0.id == detailProcessID }
    }

    var body: some View {
        Table(viewModel.filteredProcesses, sortOrder: $viewModel.sortOrder) {
            TableColumn("") { process in
                ProcessIconView(icon: process.icon)
            }
            .width(32)

            TableColumn("Process Name", value: \.processName) { process in
                processNameCell(process)
            }
            .width(min: 160, ideal: 220)

            TableColumn("Memory", value: \.residentMemoryBytes) { process in
                Text(process.formattedMemory)
                    .monospacedDigit()
            }
            .width(90)

            TableColumn("Cost", value: \.memoryCost) { process in
                costCell(process)
            }
            .width(80)

            TableColumn("% RAM") { process in
                Text(process.formattedPercentage(of: viewModel.totalPhysicalRAMBytes))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .width(70)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .sheet(isPresented: detailSheetPresented) {
            if let process = detailProcess {
                ProcessDetailSheetView(
                    process: process,
                    totalPhysicalRAMBytes: viewModel.totalPhysicalRAMBytes,
                    costColor: viewModel.costColor(for:)
                )
            }
        }
    }

    private var detailSheetPresented: Binding<Bool> {
        Binding(
            get: { detailProcessID != nil },
            set: { isPresented in
                if !isPresented {
                    detailProcessID = nil
                }
            }
        )
    }

    private func processNameCell(_ process: ProcessMemoryInfo) -> some View {
        HStack(spacing: 6) {
            Text(process.processName)
                .fontWeight(viewModel.isTopExpensive(process) ? .semibold : .regular)

            if process.isGrouped {
                ProcessCountBadge(count: process.processCount) {
                    detailProcessID = process.id
                }
            }
        }
    }

    private func costCell(_ process: ProcessMemoryInfo) -> some View {
        Text(process.formattedCost)
            .monospacedDigit()
            .foregroundStyle(viewModel.costColor(for: process.memoryCost))
    }
}

private struct ProcessCountBadge: View {
    let count: Int
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.caption2)
                    .imageScale(.small)

                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .frame(minWidth: count >= 100 ? 24 : 18, alignment: .center)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .imageScale(.small)
            }
            .foregroundStyle(isHovered ? Color.accentColor : Color.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .fixedSize()
            .background {
                Capsule()
                    .fill(isHovered ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.06))
            }
            .overlay {
                Capsule()
                    .strokeBorder(
                        isHovered ? Color.accentColor.opacity(0.45) : Color.primary.opacity(0.12),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .help("View \(count) process breakdown")
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
