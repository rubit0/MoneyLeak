import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ProcessListView: View {
    @Bindable var viewModel: ProcessListViewModel
    @Binding var showSettings: Bool
    @State private var showExportError = false
    @State private var exportErrorMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            MemoryCostSummaryView(viewModel: viewModel)

            Divider()

            ProcessTableView(viewModel: viewModel)
        }
        .navigationTitle("Money Leak Monitor")
        .searchable(text: $viewModel.searchText, prompt: "Search processes")
        .searchPresentationToolbarBehavior(.avoidHidingContent)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    exportCSV()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .help("Export CSV")

                Button {
                    exportReceipt()
                } label: {
                    Image(systemName: "receipt")
                }
                .disabled(viewModel.topFiveByCost.isEmpty)
                .help("Save thermal receipt image")

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("Settings")
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: viewModel.settings)
                .interactiveDismissDisabled(false)
        }
        .onChange(of: showSettings) { _, isShowing in
            if !isShowing {
                Task { await viewModel.refresh() }
            }
        }
        .alert("Export Failed", isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage)
        }
        .onAppear {
            viewModel.startRefreshing()
        }
        .onDisappear {
            viewModel.stopRefreshing()
        }
    }

    private func exportReceipt() {
        let panel = NSSavePanel()
        panel.title = "Save RAM Expense Receipt"
        panel.prompt = "Save"
        panel.nameFieldStringValue = viewModel.suggestedReceiptFilename
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        Task { @MainActor in
            let response = await panel.begin()
            guard response == .OK, let url = panel.url else { return }

            do {
                try viewModel.writeReceipt(to: url)
            } catch {
                exportErrorMessage = error.localizedDescription
                showExportError = true
            }
        }
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.title = "Export Process List"
        panel.prompt = "Save"
        panel.nameFieldStringValue = viewModel.suggestedExportFilename
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        Task { @MainActor in
            let response = await panel.begin()
            guard response == .OK, let url = panel.url else { return }

            do {
                try viewModel.writeExport(to: url)
            } catch {
                exportErrorMessage = error.localizedDescription
                showExportError = true
            }
        }
    }
}
