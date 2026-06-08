import Foundation

struct ProcessMemberInfo: Identifiable, Equatable, Sendable {
    let pid: Int32
    let name: String
    let executablePath: String?
    let residentMemoryBytes: UInt64
    let memoryCost: Double

    var id: Int32 { pid }

    var memoryGB: Double {
        Double(residentMemoryBytes) / 1_073_741_824.0
    }

    var memoryMB: Double {
        Double(residentMemoryBytes) / 1_048_576.0
    }

    var formattedMemory: String {
        if memoryGB >= 1.0 {
            return String(format: "%.1f GB", memoryGB)
        }
        return String(format: "%.0f MB", memoryMB)
    }

    var formattedCost: String {
        String(format: "$%.2f", memoryCost)
    }

    func sharePercentage(of totalBytes: UInt64) -> Double {
        guard totalBytes > 0 else { return 0 }
        return (Double(residentMemoryBytes) / Double(totalBytes)) * 100.0
    }

    func formattedShare(of totalBytes: UInt64) -> String {
        String(format: "%.1f%%", sharePercentage(of: totalBytes))
    }
}
