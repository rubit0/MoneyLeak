import SwiftUI

struct SettingsView: View {
    @Bindable var settings: MemoryCostSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Refresh") {
                    HStack {
                        Text("Interval")
                        Spacer()
                        Text("\(settings.refreshInterval, specifier: "%.1f")s")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $settings.refreshInterval, in: 0.5...10, step: 0.5)
                }

                Section("Pricing") {
                    Toggle("Use custom cost per MB", isOn: $settings.useCustomCostPerMB)

                    if settings.useCustomCostPerMB {
                        HStack {
                            Text("Cost per MB")
                            Spacer()
                            TextField(
                                "0.0000",
                                value: $settings.customCostPerMB,
                                format: .currency(code: "USD").precision(.fractionLength(4))
                            )
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .multilineTextAlignment(.trailing)
                        }
                        Slider(
                            value: $settings.customCostPerMB,
                            in: 0.001...0.1,
                            step: 0.0005
                        )
                        Text("Process cost = memory (MB) × your rate")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        LabeledContent("Default Rate", value: String(format: "$%.4f per MB", MemoryCostSettings.defaultCostPerMB))
                        LabeledContent("Equivalent", value: String(format: "$%.2f per GB", RAMOpportunityCostModel.defaultDollarsPerGB))
                        Text("Uses the opportunity-cost model based on your system's total RAM.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Cost Alerts") {
                    Toggle("Notify when a process exceeds threshold", isOn: $settings.costAlertsEnabled)

                    if settings.costAlertsEnabled {
                        HStack {
                            Text("Threshold")
                            Spacer()
                            Text("$\(settings.costAlertThreshold, specifier: "%.2f")")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $settings.costAlertThreshold, in: 1...50, step: 0.5)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .frame(width: 440, height: 420)
    }
}
