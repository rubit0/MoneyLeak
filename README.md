# Money Leak Monitor

A native macOS app that shows running processes and their memory usage as **dollar values** — Activity Monitor meets personal finance.

The display name is **Money Leak Monitor**. The Xcode target and repository folder are named `MoneyLeak`.

## What it does

Money Leak Monitor helps you see RAM as a shared economic budget:

- Lists running apps with memory usage translated into cost
- Groups helper processes (Chrome, Cursor, Electron apps, etc.) by `.app` bundle
- Highlights the top five most expensive apps with a linked list and donut chart
- Refreshes automatically every second (configurable)
- Lives in the menu bar with a quick RAM-cost summary

## Requirements

- macOS 26.4+
- Xcode 26.4+
- Swift 5

The app runs **without App Sandbox** so it can enumerate system processes via `libproc`.

## Build & run

```bash
open MoneyLeak.xcodeproj
```

Select the **MoneyLeak** scheme and run (⌘R), or:

```bash
xcodebuild -scheme MoneyLeak -configuration Debug build
```

## Pricing model

By default, RAM is priced with an **opportunity-cost model**:

- Total physical RAM is detected automatically (`sysctl`)
- Default rate: **$25 per GB** (≈ $0.0244 per MB)
- Per-process cost: `memoryMB × dollarsPerMB`

This is equivalent to each process paying for its share of a synthetic full-system RAM value. No process is free; cost scales linearly with usage.

### Custom pricing

In **Settings** (⌘,), users can optionally enable **custom cost per MB** to override the default rate — for example, to reflect what they actually paid for a RAM upgrade.

## Features

| Feature | Description |
|--------|-------------|
| Process table | Sortable columns: icon, name, memory, cost, % RAM |
| Bundle grouping | Helpers under the same `.app` are merged into one row |
| Summary dashboard | System RAM value, RAM in use, unused RAM value |
| Top 5 panel | List + interactive donut chart with hover linking |
| Search | Filter processes by name |
| CSV export | Save panel lets you choose export location |
| Cost alerts | Optional notifications when a process exceeds a threshold |
| Menu bar extra | Shows total RAM cost and top processes |

## Project structure

```
MoneyLeak/
├── App/
│   └── MoneyLeakApp.swift          # @main entry, menu bar, settings command
├── Models/
│   ├── ProcessMemoryInfo.swift     # Process row model
│   ├── MemoryCostSettings.swift    # UserDefaults-backed preferences
│   └── RAMOpportunityCostModel.swift
├── Services/
│   └── ProcessMemoryService.swift  # libproc / sysctl process enumeration
├── ViewModels/
│   └── ProcessListViewModel.swift
├── Views/
│   ├── ProcessListView.swift
│   ├── ProcessTableView.swift
│   ├── MemoryCostSummaryView.swift
│   ├── SettingsView.swift
│   └── …
└── ContentView.swift               # SwiftUI preview host only
```

## System APIs

Process enumeration uses public macOS APIs only:

- `proc_listallpids`, `proc_pidinfo`, `proc_name`, `proc_pidpath`
- `sysctl` (`HW_MEMSIZE`) for total RAM
- `host_statistics64` is not used in the current version

## Settings (persisted in UserDefaults)

- Refresh interval (0.5–10 s, default 1 s)
- Custom cost per MB (optional)
- Cost alert threshold and enable/disable

## Notes

- **Grouped rows** show one entry per app bundle; standalone daemons/CLIs remain separate.
- **Unused RAM value** is derived from total physical RAM minus summed process resident memory.
- `ContentView.swift` exists for Xcode canvas previews; the app launches from `MoneyLeakApp`.

## License

Not specified.
