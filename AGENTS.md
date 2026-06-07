# AGENTS.md

Guidance for AI agents and contributors working on **Money Leak Monitor** (`MoneyLeak` Xcode project).

## Project summary

Native **Swift / SwiftUI** macOS utility. No Electron, no web stack. Displays process memory as dollar cost using a local pricing model.

- **Display name:** Money Leak Monitor
- **Entry point:** `MoneyLeak/App/MoneyLeakApp.swift` (`@main`)
- **Bundle ID:** `com.studio-delatorre.MoneyLeak`
- **Sandbox:** disabled (`ENABLE_APP_SANDBOX = NO`) — required for full process visibility

## Build commands

```bash
# Build
xcodebuild -scheme MoneyLeak -configuration Debug build

# Build with local DerivedData (useful in CI/sandboxes)
xcodebuild -scheme MoneyLeak -configuration Debug \
  -derivedDataPath ./DerivedData build
```

Open `MoneyLeak.xcodeproj` in Xcode for normal development. The `MoneyLeak/` source folder uses **PBXFileSystemSynchronizedRootGroup** — new files under `MoneyLeak/` are picked up automatically; no manual `project.pbxproj` file entries needed.

## Architecture

```
App → Views → ViewModels → Services → Models
```

| Layer | Responsibility |
|-------|----------------|
| **Models** | `ProcessMemoryInfo`, `MemoryCostSettings`, `RAMOpportunityCostModel` |
| **Services** | `ProcessMemoryService` — process fetch, bundle grouping, icons |
| **ViewModels** | `ProcessListViewModel` — refresh loop, filtering, sorting, export content, alerts |
| **Views** | SwiftUI UI; `ProcessTableView` uses native `Table` |
| **App** | Scenes: main window, settings sheet (⌘,), menu bar extra |

### Data flow

1. `ProcessListViewModel.startRefreshing()` runs a loop: `refresh()` → sleep(`settings.refreshInterval`).
2. `refresh()` calls `ProcessMemoryService.fetchProcesses(customCostPerMB:)` on a detached task.
3. Service enumerates PIDs, reads resident memory, groups by `.app` bundle path, applies `RAMOpportunityCostModel`.
4. ViewModel publishes `processes`; views observe via `@Observable` / `@Bindable`.

### Pricing rules (do not break without explicit request)

- **Default:** opportunity cost at **$25/GB** (`RAMOpportunityCostModel.defaultDollarsPerGB`).
- Formula: `memoryCost = memoryMB × dollarsPerMB`.
- **Optional override:** `MemoryCostSettings.useCustomCostPerMB` + `customCostPerMB`.
- Do **not** reintroduce user-entered total RAM / total price fields unless asked.
- Do **not** use private APIs or external pricing services.

### Process grouping

Processes sharing the same `.app` bundle path (from `proc_pidpath`) are aggregated:

- Summed `residentMemoryBytes` and `memoryCost`
- Display name from bundle (e.g. `Google Chrome.app` → `Google Chrome`)
- `ProcessMemoryInfo.id` = bundle path or `pid:<pid>` for standalone processes
- `processCount > 1` for grouped rows

## UI conventions

- **Tone:** fun, native macOS, Activity Monitor–inspired — avoid overly technical columns (no PID in the table).
- **Summary row:** vertical stats column | Top 5 list | donut chart — all one horizontal band.
- **Settings:** sheet with Done button; opened via gear toolbar or ⌘,. Do **not** add a separate SwiftUI `Settings { }` scene (causes focus/quit issues).
- **Export:** `NSSavePanel` — user picks save location; do not write silently to tmp and open Finder.
- **Refresh:** automatic only; no manual refresh toolbar button.

## Swift / concurrency notes

- Project uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
- `ProcessMemoryService` methods are `nonisolated`; class is `@unchecked Sendable` with a lock-backed icon cache.
- `ProcessMemoryInfo` equality must include **memory and cost fields**, not just `pid`, or the `Table` will not update live.

## Key files

| File | When to edit |
|------|----------------|
| `ProcessMemoryService.swift` | Process enumeration, grouping, icons |
| `RAMOpportunityCostModel.swift` | Cost math |
| `MemoryCostSettings.swift` | UserDefaults preferences |
| `ProcessListViewModel.swift` | Refresh loop, alerts, CSV content |
| `MemoryCostSummaryView.swift` | Summary + top 5 + chart layout |
| `ProcessTableView.swift` | Main process table columns |
| `ProcessListView.swift` | Toolbar, export save panel, settings sheet |
| `MoneyLeakApp.swift` | App scenes, menu bar |
| `ContentView.swift` | Preview only — not the app entry point |

## Making changes safely

### Do

- Keep changes scoped; match existing naming and folder layout.
- Preserve bundle-based grouping for multi-process apps.
- Run `xcodebuild` after non-trivial edits.
- Use native SwiftUI `Table`, `Charts`, `NSSavePanel`, `.searchable`.
- Persist user prefs through `MemoryCostSettings` + UserDefaults.

### Don't

- Add Electron, web views, or npm dependencies.
- Enable App Sandbox without adding the entitlements needed for `libproc`.
- Add a second settings window (`Settings { }` scene).
- Compare `ProcessMemoryInfo` by `pid` alone in `Equatable`.
- Remove `ContentView.swift` without updating Xcode workspace state (stale tab references).

## Testing manually

1. Launch app — process table should populate within ~1 s.
2. Confirm grouped apps (Chrome, Cursor) appear as one row with combined memory.
3. Watch memory/cost columns update without manual refresh.
4. Open Settings, change custom cost per MB, close — values should recalculate.
5. Export CSV — save panel appears; file writes to chosen path.
6. ⌘Q should quit with settings sheet open or closed.

## Future enhancements (not implemented)

- Memory pressure / money pressure graph (removed by design)
- Memory pressure multipliers, foreground/background weighting
- Per-process detail drill-down

Only implement these if explicitly requested.
