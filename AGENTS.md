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
| **Models** | `ProcessMemoryInfo`, `ProcessMemberInfo`, `MemoryCostSettings`, `RAMOpportunityCostModel` |
| **Services** | `ProcessMemoryService` — process fetch, bundle grouping, icons |
| **ViewModels** | `ProcessListViewModel` — refresh loop, filtering, sorting, export content, alerts |
| **Views** | SwiftUI UI; `ProcessTableView` uses native `Table` |
| **App** | Scenes: main window, settings sheet (⌘,), menu bar extra |

### Data flow

1. `ProcessListViewModel.startRefreshing()` runs a loop: `refresh()` → sleep(`settings.refreshInterval`).
2. `refresh()` calls `ProcessMemoryService.fetchProcesses(customCostPerMB:)` on a detached task.
3. Service enumerates PIDs via `sysctl(KERN_PROC_ALL)` (not `proc_listallpids`, which omits many long-lived processes), reads resident memory, groups by `.app` bundle path, populates `ProcessMemoryInfo.members`, applies `RAMOpportunityCostModel`.
4. ViewModel publishes `processes`; `totalOccupiedBytes` is the sum of row resident memory. Views observe via `@Observable` / `@Bindable`.

### Pricing rules (do not break without explicit request)

- **Default:** opportunity cost at **$25/GB** (`RAMOpportunityCostModel.defaultDollarsPerGB`).
- Formula: `memoryCost = memoryMB × dollarsPerMB`.
- **Optional override:** `MemoryCostSettings.useCustomCostPerMB` + `customCostPerMB`.
- Do **not** reintroduce user-entered total RAM / total price fields unless asked.
- Do **not** use private APIs or external pricing services.

### Process grouping

Processes sharing the same `.app` bundle path (from `proc_pidpath`) are aggregated:

- Summed `residentMemoryBytes` and `memoryCost`
- Display name from bundle basename (e.g. `Google Chrome.app` → `Google Chrome`) — not `CFBundleDisplayName` or Activity Monitor’s marketing label
- Process names for members come from executable path basename; **`proc_name` is not used** (kernel log spam on protected PIDs)
- `ProcessMemoryInfo.id` = bundle path or `pid:<pid>` for standalone processes
- `processCount > 1` for grouped rows
- `members: [ProcessMemberInfo]` — per-PID breakdown (name, path, memory, cost), sorted by memory descending

### Process enumeration (do not regress)

- Use **`sysctl(KERN_PROC_ALL)`** in `ProcessMemoryService.allPIDs()`.
- **Do not switch back to `proc_listallpids`** — it returns a truncated PID list and hides long-lived background apps (Logi Options+, many daemons).
- Skip PIDs where `proc_pidinfo` fails or `pti_resident_size` is 0.

### Memory accounting (do not break without explicit request)

Money Leak is **cost-per-app**, not a clone of Activity Monitor’s system memory bar.

- **Per row:** `proc_pidinfo` → `pti_resident_size` (resident memory). Do **not** switch to footprint (`phys_footprint` / `proc_pid_rusage`) unless explicitly asked.
- **RAM In Use:** sum of all row `residentMemoryBytes`. This will be **lower** than Activity Monitor **Memory Used** (wired, compressed, kernel, and unreadable PIDs are excluded).
- **Unused RAM value:** `totalPhysicalRAM − RAM In Use` — a budgeting leftover for the opportunity-cost model, **not** free or reclaimable memory.
- See README **How memory is counted** for the user-facing explanation.

## UI conventions

- **Tone:** fun, native macOS, Activity Monitor–inspired — avoid overly technical columns (no PID in the table).
- **Summary row:** vertical stats column | Top 5 list | donut chart — all one horizontal band.
- **Settings:** sheet with Done button; opened via gear toolbar or ⌘,. Do **not** add a separate SwiftUI `Settings { }` scene (causes focus/quit issues).
- **Export:** `NSSavePanel` — user picks save location; do not write silently to tmp and open Finder. Toolbar has CSV (`square.and.arrow.up`) and receipt PNG (`receipt`); receipt uses `TopFiveReceiptRenderer` / `TopFiveReceiptView`.
- **Refresh:** automatic only; no manual refresh toolbar button.
- **Process detail:** grouped rows show a clickable process-count badge (list icon + count + chevron). Click opens `ProcessDetailSheetView` — member list, donut chart, memory + % in chart center; name and executable path appear below the chart on hover. No PID column in the main table.
- **About:** `CommandGroup(replacing: .appInfo)` opens `AboutView` sheet; Settings also has an About section. Taglines live in `AppAboutInfo.taglines`; `AboutTaglineText` picks a random one on each `onAppear`.

## Swift / concurrency notes

- Project uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
- `ProcessMemoryService` methods are `nonisolated`; class is `@unchecked Sendable` with a lock-backed icon cache.
- `ProcessMemoryInfo` equality must include **memory, cost, and `members` fields**, not just `pid`, or the `Table` will not update live.

## Key files

| File | When to edit |
|------|----------------|
| `ProcessMemoryService.swift` | Process enumeration, grouping, icons |
| `RAMOpportunityCostModel.swift` | Cost math |
| `MemoryCostSettings.swift` | UserDefaults preferences |
| `ProcessListViewModel.swift` | Refresh loop, alerts, CSV content |
| `MemoryCostSummaryView.swift` | Summary + top 5 + chart layout |
| `ProcessTableView.swift` | Main process table, process-count badge, detail sheet presentation |
| `ProcessDetailSheetView.swift` | Grouped-app breakdown: member list + donut chart |
| `ProcessMemberInfo.swift` | Per-PID member model for grouped rows |
| `ProcessListView.swift` | Toolbar, CSV/receipt export save panels, settings sheet |
| `TopFiveReceiptView.swift` | Thermal-receipt layout for PNG export |
| `TopFiveReceiptRenderer.swift` | `ImageRenderer` → PNG data |
| `AppAboutInfo.swift` | Version string, credits, tagline pool |
| `AboutView.swift` / `AboutTaglineText.swift` | About sheet and random tagline |
| `MoneyLeakApp.swift` | App scenes, menu bar, About command |
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
- Use `proc_listallpids` for enumeration (truncated list; breaks visibility of background apps).
- Call `proc_name` for process labels (noisy kernel logs).
- Remove `ContentView.swift` without updating Xcode workspace state (stale tab references).

## Testing manually

1. Launch app — process table should populate within ~1 s.
2. Confirm grouped apps (Chrome, Cursor, Xcode) appear as one row with combined memory and a process-count badge.
3. Click the badge on a grouped row — detail sheet lists members, chart hover links to rows, path shows below chart.
4. Watch memory/cost columns update without manual refresh.
5. Open Settings, change custom cost per MB, close — values should recalculate.
6. Export CSV — save panel appears; file writes to chosen path.
7. Export receipt PNG — save panel appears; image shows top 5.
8. Open About (app menu or Settings) — version/credits shown; tagline changes each time About appears.
9. Search `logi` — `logioptionsplus_agent` should appear if Logi Options+ is running.
10. ⌘Q should quit with settings or About sheet open or closed.

## Future enhancements (not implemented)

- Memory pressure / money pressure graph (removed by design)
- Memory pressure multipliers, foreground/background weighting
- System-level memory categories (wired, compressed, cache) in summary totals
- Footprint-based per-process memory to align with Activity Monitor

Only implement these if explicitly requested.
