import Foundation

/// Prices RAM using opportunity-cost share of total system memory.
struct RAMOpportunityCostModel: Sendable {
    static let defaultDollarsPerGB: Double = 25.0
    static var defaultDollarsPerMB: Double { defaultDollarsPerGB / 1024.0 }

    let totalPhysicalRAMBytes: UInt64
    let customCostPerMB: Double?

    init(totalPhysicalRAMBytes: UInt64, customCostPerMB: Double? = nil) {
        self.totalPhysicalRAMBytes = totalPhysicalRAMBytes
        self.customCostPerMB = customCostPerMB
    }

    var dollarsPerMB: Double {
        customCostPerMB ?? Self.defaultDollarsPerMB
    }

    var dollarsPerGB: Double {
        dollarsPerMB * 1024.0
    }

    var totalPhysicalRAMGB: Double {
        Double(totalPhysicalRAMBytes) / 1_073_741_824.0
    }

    var totalPhysicalRAMMB: Double {
        Double(totalPhysicalRAMBytes) / 1_048_576.0
    }

    /// Hypothetical value of the entire installed RAM configuration.
    var systemRAMValue: Double {
        totalPhysicalRAMMB * dollarsPerMB
    }

    /// Opportunity cost: memoryShare × systemRAMValue, equivalent to memoryMB × dollarsPerMB.
    func memoryCost(for residentBytes: UInt64) -> Double {
        guard totalPhysicalRAMBytes > 0 else { return 0 }
        let memoryMB = Double(residentBytes) / 1_048_576.0
        return memoryMB * dollarsPerMB
    }
}
