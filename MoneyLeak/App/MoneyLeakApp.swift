import SwiftUI
import UserNotifications

@main
struct MoneyLeakApp: App {
    @State private var settings = MemoryCostSettings()
    @State private var viewModel: ProcessListViewModel?
    @State private var showSettings = false
    @State private var showAbout = false

    var body: some Scene {
        WindowGroup {
            Group {
                if let viewModel {
                    NavigationStack {
                        ProcessListView(viewModel: viewModel, showSettings: $showSettings)
                    }
                } else {
                    ProgressView("Loading…")
                        .frame(width: 300, height: 200)
                }
            }
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
            .onAppear {
                if viewModel == nil {
                    let model = ProcessListViewModel(settings: settings)
                    viewModel = model
                    requestNotificationPermission()
                }
            }
        }
        .defaultSize(width: 960, height: 640)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Money Leak Monitor") {
                    showAbout = true
                }
            }

            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    showSettings = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        MenuBarExtra("Money Leak Monitor", systemImage: "dollarsign.circle") {
            if let viewModel {
                MenuBarPopoverView(viewModel: viewModel)
            } else {
                Text("Loading…")
            }
        }
        .menuBarExtraStyle(.window)
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}

struct MenuBarPopoverView: View {
    let viewModel: ProcessListViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RAM In Use")
                .font(.headline)
            Text(String(format: "$%.2f", viewModel.totalOccupiedCost))
                .font(.title)
                .monospacedDigit()
            Text(String(format: "%.1f GB of %.1f GB",
                        Double(viewModel.totalOccupiedBytes) / 1_073_741_824.0,
                        Double(viewModel.totalPhysicalRAMBytes) / 1_073_741_824.0))
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Text("Top Processes")
                .font(.subheadline)
                .fontWeight(.semibold)
            ForEach(viewModel.topFiveByCost.prefix(3)) { process in
                HStack {
                    Text(process.processName)
                        .lineLimit(1)
                    Spacer()
                    Text(process.formattedCost)
                        .monospacedDigit()
                }
                .font(.caption)
            }

            Divider()

            Button("Open Money Leak Monitor") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }
        }
        .padding()
        .frame(width: 240)
    }
}
