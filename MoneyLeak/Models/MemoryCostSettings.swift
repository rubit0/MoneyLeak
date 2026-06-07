import Foundation

@Observable
final class MemoryCostSettings {
    private enum Keys {
        static let refreshInterval = "refreshInterval"
        static let costAlertThreshold = "costAlertThreshold"
        static let costAlertsEnabled = "costAlertsEnabled"
        static let useCustomCostPerMB = "useCustomCostPerMB"
        static let customCostPerMB = "customCostPerMB"
    }

    static let defaultCostPerMB = RAMOpportunityCostModel.defaultDollarsPerMB

    var refreshInterval: TimeInterval {
        didSet {
            let clamped = max(0.5, min(refreshInterval, 60.0))
            if clamped != refreshInterval {
                refreshInterval = clamped
                return
            }
            UserDefaults.standard.set(refreshInterval, forKey: Keys.refreshInterval)
        }
    }

    var costAlertThreshold: Double {
        didSet {
            UserDefaults.standard.set(costAlertThreshold, forKey: Keys.costAlertThreshold)
        }
    }

    var costAlertsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(costAlertsEnabled, forKey: Keys.costAlertsEnabled)
        }
    }

    var useCustomCostPerMB: Bool {
        didSet {
            UserDefaults.standard.set(useCustomCostPerMB, forKey: Keys.useCustomCostPerMB)
        }
    }

    var customCostPerMB: Double {
        didSet {
            let clamped = max(0.0001, min(customCostPerMB, 100.0))
            if clamped != customCostPerMB {
                customCostPerMB = clamped
                return
            }
            UserDefaults.standard.set(customCostPerMB, forKey: Keys.customCostPerMB)
        }
    }

    var activeCostPerMB: Double? {
        useCustomCostPerMB ? customCostPerMB : nil
    }

    init() {
        let defaults = UserDefaults.standard
        refreshInterval = defaults.object(forKey: Keys.refreshInterval) as? TimeInterval ?? 1.0
        costAlertThreshold = defaults.object(forKey: Keys.costAlertThreshold) as? Double ?? 10.0
        costAlertsEnabled = defaults.object(forKey: Keys.costAlertsEnabled) as? Bool ?? false
        useCustomCostPerMB = defaults.object(forKey: Keys.useCustomCostPerMB) as? Bool ?? false
        customCostPerMB = defaults.object(forKey: Keys.customCostPerMB) as? Double ?? Self.defaultCostPerMB
    }
}
