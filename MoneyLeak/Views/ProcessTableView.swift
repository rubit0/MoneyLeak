import SwiftUI

struct ProcessTableView: View {
    @Bindable var viewModel: ProcessListViewModel

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
    }

    private func processNameCell(_ process: ProcessMemoryInfo) -> some View {
        Text(process.processName)
            .fontWeight(viewModel.isTopExpensive(process) ? .semibold : .regular)
    }

    private func costCell(_ process: ProcessMemoryInfo) -> some View {
        Text(process.formattedCost)
            .monospacedDigit()
            .foregroundStyle(viewModel.costColor(for: process.memoryCost))
    }
}
