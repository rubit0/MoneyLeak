import AppKit
import SwiftUI
import UserNotifications

@Observable
@MainActor
final class ProcessListViewModel {
    private(set) var processes: [ProcessMemoryInfo] = []
    private(set) var totalPhysicalRAMBytes: UInt64 = 0
    private(set) var totalOccupiedCost: Double = 0
    private(set) var totalOccupiedBytes: UInt64 = 0
    private(set) var isLoading = false
    var searchText = ""
    var sortOrder = [KeyPathComparator(\ProcessMemoryInfo.memoryCost, order: .reverse)]

    private let service = ProcessMemoryService.shared
    let settings: MemoryCostSettings
    private var refreshTask: Task<Void, Never>?
    private var alertedProcessIDs: Set<String> = []

    init(settings: MemoryCostSettings) {
        self.settings = settings
    }

    var costModel: RAMOpportunityCostModel {
        RAMOpportunityCostModel(
            totalPhysicalRAMBytes: totalPhysicalRAMBytes,
            customCostPerMB: settings.activeCostPerMB
        )
    }

    var filteredProcesses: [ProcessMemoryInfo] {
        let filtered: [ProcessMemoryInfo]
        if searchText.isEmpty {
            filtered = processes
        } else {
            let query = searchText.lowercased()
            filtered = processes.filter {
                $0.processName.lowercased().contains(query)
            }
        }
        return filtered.sorted(using: sortOrder)
    }

    var topFiveByCost: [ProcessMemoryInfo] {
        Array(processes.sorted { $0.memoryCost > $1.memoryCost }.prefix(5))
    }

    var unusedRAMBytes: UInt64 {
        totalPhysicalRAMBytes > totalOccupiedBytes
            ? totalPhysicalRAMBytes - totalOccupiedBytes
            : 0
    }

    var unusedRAMCost: Double {
        costModel.memoryCost(for: unusedRAMBytes)
    }

    var systemRAMValue: Double {
        costModel.systemRAMValue
    }

    func startRefreshing() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refresh()
                try? await Task.sleep(for: .seconds(self.settings.refreshInterval))
            }
        }
    }

    func stopRefreshing() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refresh() async {
        isLoading = true
        let customCostPerMB = settings.activeCostPerMB
        let snapshot = await Task.detached(priority: .userInitiated) {
            let service = ProcessMemoryService.shared
            let totalRAM = service.totalPhysicalRAMBytes()
            let processes = service.fetchProcesses(customCostPerMB: customCostPerMB)
            let occupiedBytes = processes.reduce(UInt64(0)) { $0 + $1.residentMemoryBytes }
            let occupiedCost = processes.reduce(0.0) { $0 + $1.memoryCost }
            return (totalRAM, processes, occupiedBytes, occupiedCost)
        }.value

        totalPhysicalRAMBytes = snapshot.0
        processes = snapshot.1
        totalOccupiedBytes = snapshot.2
        totalOccupiedCost = snapshot.3
        isLoading = false

        checkCostAlerts()
    }

    var suggestedExportFilename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return "Money Leak Monitor \(formatter.string(from: Date())).csv"
    }

    var suggestedReceiptFilename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return "Money Leak Receipt \(formatter.string(from: Date())).png"
    }

    func makeReceiptData() -> TopFiveReceiptData {
        let topFive = topFiveByCost
        return TopFiveReceiptData(
            processes: topFive,
            topFiveTotalCost: topFive.reduce(0) { $0 + $1.memoryCost },
            systemRAMValue: systemRAMValue,
            totalPhysicalRAMGB: Double(totalPhysicalRAMBytes) / 1_073_741_824.0,
            generatedAt: Date()
        )
    }

    func makeReceiptImage() -> NSImage? {
        guard !topFiveByCost.isEmpty else { return nil }
        return TopFiveReceiptRenderer.render(data: makeReceiptData())
    }

    func writeReceipt(to url: URL) throws {
        guard let image = makeReceiptImage(),
              let pngData = TopFiveReceiptRenderer.pngData(from: image) else {
            throw ReceiptExportError.renderFailed
        }
        try pngData.write(to: url, options: .atomic)
    }

    enum ReceiptExportError: LocalizedError {
        case renderFailed

        var errorDescription: String? {
            switch self {
            case .renderFailed:
                "Could not generate the receipt image."
            }
        }
    }

    func csvExportContent() -> String {
        let header = "Process Name,Memory (MB),Cost (USD),% of Total RAM\n"
        let rows = filteredProcesses.map { process in
            let percentage = process.memoryPercentage(of: totalPhysicalRAMBytes)
            return "\"\(process.processName)\",\(String(format: "%.2f", process.memoryMB)),\(String(format: "%.2f", process.memoryCost)),\(String(format: "%.2f", percentage))"
        }
        return header + rows.joined(separator: "\n")
    }

    func writeExport(to url: URL) throws {
        try csvExportContent().write(to: url, atomically: true, encoding: .utf8)
    }

    func costColor(for cost: Double) -> Color {
        let maxCost = processes.first?.memoryCost ?? 1.0
        let ratio = min(cost / max(maxCost, 0.01), 1.0)
        return Color(
            red: 0.2 + ratio * 0.8,
            green: max(0.15, 0.7 - ratio * 0.55),
            blue: max(0.1, 0.3 - ratio * 0.2)
        )
    }

    func isTopExpensive(_ process: ProcessMemoryInfo) -> Bool {
        topFiveByCost.contains(where: { $0.id == process.id })
    }

    private func checkCostAlerts() {
        guard settings.costAlertsEnabled else {
            alertedProcessIDs.removeAll()
            return
        }

        for process in processes where process.memoryCost >= settings.costAlertThreshold {
            guard !alertedProcessIDs.contains(process.id) else { continue }
            alertedProcessIDs.insert(process.id)
            sendCostAlert(for: process)
        }
    }

    private func sendCostAlert(for process: ProcessMemoryInfo) {
        let content = UNMutableNotificationContent()
        content.title = "Money Leak Monitor: High RAM Cost"
        content.body = "\(process.processName) is using \(process.formattedCost) of RAM value."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "cost-alert-\(process.id)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
