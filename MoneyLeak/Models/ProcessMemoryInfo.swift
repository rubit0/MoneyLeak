import AppKit

struct ProcessMemoryInfo: Identifiable, Equatable {
    let id: String
    let pid: Int32
    let processCount: Int
    let processName: String
    let icon: NSImage?
    let residentMemoryBytes: UInt64
    let memoryCost: Double
    let members: [ProcessMemberInfo]

    var isGrouped: Bool { processCount > 1 }

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

    func memoryPercentage(of totalBytes: UInt64) -> Double {
        guard totalBytes > 0 else { return 0 }
        return (Double(residentMemoryBytes) / Double(totalBytes)) * 100.0
    }

    func formattedPercentage(of totalBytes: UInt64) -> String {
        String(format: "%.1f%%", memoryPercentage(of: totalBytes))
    }

    static func == (lhs: ProcessMemoryInfo, rhs: ProcessMemoryInfo) -> Bool {
        lhs.id == rhs.id
            && lhs.processName == rhs.processName
            && lhs.processCount == rhs.processCount
            && lhs.residentMemoryBytes == rhs.residentMemoryBytes
            && lhs.memoryCost == rhs.memoryCost
            && lhs.members == rhs.members
    }
}
