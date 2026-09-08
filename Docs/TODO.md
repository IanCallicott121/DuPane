# DuPane — TODO


## Next items
none yet

### Bug fixes — Critical

- **`FileOperationService.moveOrCopy` "Overwrite" replaces folders instead of merging, destroying data** — `detectConflicts` flags directories by name like any other item, so a folder collision offers Overwrite / Skip / Keep Both. `.overwrite` on a directory moves the existing destination aside, copies the source over it, then deletes the backup with `removeItem` (line ~123) — not `trashItem`. Every file present only in the destination folder is permanently destroyed with no Trash recovery and no undo. Reachable from the copy/move conflict alert (`ContentView` "Overwrite") and the drag-drop conflict alert (`PaneView`). Finder offers Merge for exactly this case; there is no merge here and the alert gives no warning that a folder is replaced wholesale. The Overwrite button is also not `role: .destructive`. Fix: recurse per-file for directories (merge), or at minimum trash the replaced items and warn explicitly. (`Models/FileOperationService.swift`, `Views/ContentView.swift`, `Views/PaneView.swift`)

### Bug fixes — High

- **Concurrent file operations clobber each other's progress UI** — `fileOpInfo` / `fileOpVisible` / `fileOpRevealTask` are a single shared `@State` slot and nothing serialises operations. Start a large copy, then a small one: the small one finishes first and runs the teardown, cancelling the large op's reveal task and setting `fileOpVisible = false`. The large copy then runs to completion with no progress overlay, followed by a toast from nowhere. Serialise operations or key the progress state per operation. (`Views/ContentView.swift`)
- **Cancelled directory loads keep running; a hung volume can exhaust the cooperative thread pool** — `loadingTask?.cancel()` cancels only the wrapper; the inner `Task.detached` does not inherit cancellation and `loadFolder` has no `Task.isCancelled` checks, so cancelling discards the result while the blocking read keeps a pool thread. With several tabs on an unresponsive SMB/NFS share (or after toggling "Show hidden files", which reloads every tab at once) the pool — capped near core count — fills and no `Task.detached` body in the app starts: panes spin forever, metadata stops, copy/move/delete never begin. Main thread stays responsive so the app looks alive. Add cancellation checks inside `loadFolder`'s enumeration loop. (`ViewModels/PaneState.swift`)
- **Type-ahead writes into a closed tab's `PaneState`** — the type-ahead closure is installed once in `onAppear`, capturing the `PaneView` struct and its `pane` reference. View identity is `.id(tabs.activeTabIndex)`, an `Int`. Closing the middle of three tabs leaves `activeTabIndex` unchanged while it now points at a different `PaneState`, so `onAppear` does not re-run. Typing then sets selection on the closed tab's state; type-ahead is silently dead in that pane and the old `PaneState` is retained. Key view identity on tab identity rather than index, or reinstall the closure on change. (`Views/PaneView.swift`, `Views/TabbedPaneView.swift`, `ViewModels/TabbedPaneState.swift`)

### Bug fixes — Medium

- **`PaneState.goBack()`/`goForward()` history race** — `canGoBack`/`canGoForward` are checked, then `history[historyIndex]` is accessed; if history is mutated between the guard and the access (async callback), index goes out of bounds. (`ViewModels/PaneState.swift`)
- **`PaneState.endDeepSearch` cancellation window** — Spotlight results can arrive after `endDeepSearch()` is called but before `spotlightQuery = nil` is set; rapid navigation leaves search state inconsistent. (`ViewModels/PaneState.swift`)
- **`NetworkVolumeMonitor.ejectAndRemove` ignores unmount failure** — `try? NSWorkspace.unmountAndEjectDevice` failure is silently discarded; volume is removed from `mountedVolumes` even if the unmount didn't succeed, so the sidebar shows it gone while it's still mounted. (`Models/NetworkVolumeMonitor.swift`)
- **Sync plan not atomic** — `executeSyncPlan()` with `.overwrite` has no transaction log; a crash mid-operation leaves the destination partially overwritten with no way to resume or roll back. (`Views/ContentView.swift`)
- **Partial trash failure unrecoverable** — `FileOperationService.trash()` collects errors but can't identify which items were successfully trashed before the failure; user has no way to undo the partial deletion. (`Models/FileOperationService.swift`)
- **`SidebarModel.recordVisit` and `init` block main thread** — `FileManager.fileExists` called synchronously on the main actor per bookmark and per recent URL. Move to a background task. (`Models/SidebarModel.swift`)
- **`TabbedPaneView` calls `pane.load()` on every tab switch** — fires a directory read even when tab contents are current, causing unnecessary I/O and flicker. Only load if the tab has never loaded or its URL changed. (`Views/TabbedPaneView.swift`)
- **`NetworkVolumeMonitor` Bonjour delegate mutates `@Published` on background thread** — `BonjourBrowserDelegate` callbacks fire on the `NetServiceBrowser` queue without a `DispatchQueue.main` hop. (`Models/NetworkVolumeMonitor.swift`)
- **`DuplicateFinderView` resolved groups linger** — after trashing all-but-one duplicate, the kept file stays in the list indefinitely with no dismiss affordance. Add a "Dismiss resolved" or "Rescan" action. (`Views/DuplicateFinderView.swift`)
- **`ContentView.performDelete` peer-pane nav uses first deleted URL** — if multiple items are deleted and the peer pane is inside a later one, the nav target points to the wrong parent. (`Views/ContentView.swift`)

- **Spotlight observers and `NSMetadataQuery` leak when a searching tab is closed** — the three `addObserver` tokens and the running query are torn down only in `endDeepSearch()`, called from navigate/goBack/goForward/filter-cleared. `PaneState` has no `deinit`, so closing a tab mid-search leaves the observers registered for the process lifetime and the query never `stop()`ped. Distinct from the `endDeepSearch` cancellation-window item above. (`ViewModels/PaneState.swift`)
- **`SmartMetadataService` re-spawns a task per file on every reload** — `compute` returns `nil` for any extension outside its three lists (.pdf, .txt, .dmg, extension-less, and unreadable files of supported types) and nothing is recorded for a `nil`, so `loadIfNeeded` restarts the whole set on every `pane.items` change: navigation, refresh, after every file operation, and once per tab when hidden files are toggled. A folder with thousands of such files re-creates thousands of no-op detached tasks plus `MainActor.run` hops each time. Cache the negative result. (`Models/SmartMetadataService.swift`)
- **`PaneState.displayedItems` re-filters and re-sorts on every access** — it is a computed property consumed at seven sites in `PaneView` (list body, empty-state overlay, status bar count, selection, type-ahead), so a single body evaluation performs four or more full sorts, plus one per click and one per type-ahead keystroke. Cache the sorted result and invalidate on items/sortKey/sortAscending/filterText/tag-filter changes. (`ViewModels/PaneState.swift`, `Views/PaneView.swift`)
- **`NetworkVolumeMonitor.refresh()` runs `statfs` per volume on the main thread** — invoked from `.onAppear` and from the `didMount`/`didUnmount` observers, both `queue: .main`. `statfs` on a stale SMB/NFS mount blocks for the mount timeout, so plugging in a USB drive while a share is unreachable beachballs the UI. Same class as the `SidebarModel.recordVisit` item, different site. (`Models/NetworkVolumeMonitor.swift`)
- **`ProcessRunner.run` has no timeout or cancellation and inherits stdin** — nothing resumes the continuation if the child never exits, and `standardInput` is never redirected. `unzip` on a password-protected archive is the realistic trigger. Closing the Command Runner sheet does not terminate the process. Add a timeout, wire `Task` cancellation to `process.terminate()`, and set `standardInput` to `/dev/null`. (`Models/FileOperationService.swift`, `Views/CommandRunnerView.swift`)
- **`uncompressItem` writes `@State` through a stale captured struct** — two `ProcessRunner` awaits precede writes to `uncompressConflicts` / `pendingUncompressURL` / `showUncompressAlert`. Switching tabs during the awaits tears down that `PaneView` (identity is `.id(activeTabIndex)`), so the conflict alert is written into an orphaned state box: no alert appears and the archive is silently never extracted. (`Views/PaneView.swift`)

### Bug fixes — Low / Inconsistencies

- **`QuickLookCoordinator.toggle` requires double-Space to change selection** — calls `orderOut` when panel is visible with new URLs instead of refreshing in place. (`Views/QuickLookCoordinator.swift`)
- **`ColumnResizeHandle.anyIsDragging` stuck on missed mouseUp** — static flag never reset if `mouseUp` is missed (focus lost mid-drag), permanently suppressing cursor reset for all handles until restart. (`Views/ColumnResizeHandle.swift`)
- **`SmartMetadataService.cache` not `Sendable`-verified** — `cache: [URL: String]` is a non-`Sendable` type accessed on `@MainActor`; correct today but fragile against future Swift concurrency strictness or accidental off-actor reads. (`Models/SmartMetadataService.swift`)
- **`UserDefaults` writes have no transaction semantics** — each `@Published` setting's `didSet` writes to `UserDefaults` immediately and independently; rapid successive changes (e.g. import settings) could leave defaults in an inconsistent intermediate state. (`Models/AppSettings.swift`)

- **Sort tiebreak ignores `sortAscending`** — for `.size`, `.kind` and `.modified`, equal values fall through to `a.name.localizedStandardCompare(b.name) == .orderedAscending`, which is hardcoded ascending. Sorting descending by size shows equal-size files in ascending name order. The comparator stays consistent so there is no crash risk, only visible inconsistency. (`ViewModels/PaneState.swift`)
- **`onProgress` never fires for items skipped by the subtree guard** — the `defer { onProgress?(index + 1, files.count) }` is registered *after* the self-containment guard's `continue`, so a batch containing a self-referential folder never reports progress for that item and the progress bar never reaches its total. (`Models/FileOperationService.swift`)
- **`DuplicateFinderViewModel` progress guard tests a value, not an identity** — callbacks check `vm?.phase == .scanning`, so callbacks queued by a superseded scan pass the *new* scan's guard and write stale `scannedFiles`/`hashedFiles`. Close the duplicate finder mid-scan and reopen on another folder: the counter briefly shows the previous scan's numbers. Tag each scan with a token and compare that. (`ViewModels/DuplicateFinderViewModel.swift`)

## Clarifications
none


## Pending

---

## Done
### Build 393 — UI/doc fixes: duplicate-scan cancellation, Settings Escape, UserGuide layout, README name (2026-09-08)

- **Duplicate scan now cancels promptly** — `fnv1a64` and `filesHaveSameContents` read loops check `Task.isCancelled` per 1 MB chunk, so hitting Cancel during a long scan stops mid-hash instead of waiting for the scan to finish. The completion path guards on `!Task.isCancelled` and re-checks `phase == .scanning` inside the `MainActor.run` block, so a cancelled scan can no longer resurrect `phase` to `.done` or publish stale results. The Duplicate Finder Cancel button also responds to `Esc` (`.cancelAction`). (`ViewModels/DuplicateFinderViewModel.swift`, `Views/DuplicateFinderView.swift`)
- **Settings window closes with Escape** — a hidden `.keyboardShortcut(.escape)` button calls `NSWindow.performClose`. (`Views/SettingsView.swift`)
- **UserGuide layout fix** — `body { min-width: 760px }`, reduced hero padding, widened hero paragraph so the page no longer renders in an over-narrow column. Added an `Esc` row to the shortcuts reference. (`Docs/UserGuide.html`)
- **README name cleanup** — removed the "modelled on Directory Opus" reference; DuPane is the only project name. (`Docs/README.md`)
- **Tests** — new `Build379BugTests.swift` with 3 tests covering cancel→idle, cancelled-scan-does-not-complete-to-done, and uncancelled-scan-reaches-done. 289 unit tests pass, 0 failures.

### Build 392 — 10 bug fixes (2026-09-07)

- **`PaneState` sortPref UserDefaults leak fixed** — `SortPreference.save()` now maintains a `sortPrefKeysList` order array capped at 200 entries with LRU eviction; oldest key is removed from UserDefaults when the limit is exceeded. (`ViewModels/PaneState.swift`)
- **`ContentView.showToast` race fixed** — `asyncAfter` closure now captures the message at scheduling time and only clears `toastMessage` if it still matches, preventing a second toast from being prematurely cleared by the first's timer. (`Views/ContentView.swift`)
- **Dead `lastLeftURL`/`lastRightURL` UserDefaults writes removed** — both `onChange` handlers in `ContentView` no longer write these keys; they were never read (tab-state JSON takes over first). (`Views/ContentView.swift`)
- **`finderTagColor` duplication eliminated** — extracted to a shared `Color.finderTag(_:)` extension in `FileRowView.swift`; private copies removed from `SidebarView` and `PropertiesView`. (`Views/FileRowView.swift`, `Views/SidebarView.swift`, `Views/PropertiesView.swift`)
- **`SidebarView.connectToServer` no longer clears suppressed paths** — unconditional `clearSuppressedPaths()` call removed; volumes the user deliberately hid are no longer restored on every server connect. (`Views/SidebarView.swift`)
- **`PaneState.rename`/`duplicate` weak self capture added** — `[weak self]` added to `Task.detached` closures and inner `MainActor.run` blocks; closed tabs no longer stay alive through an in-progress operation. (`ViewModels/PaneState.swift`)
- **`PaneState.duplicate()` at Computer root now surfaces error** — nil `currentURL` check sets `errorMessage = "Duplicate is not available at the Computer level."` rather than silently returning. (`ViewModels/PaneState.swift`)
- **`networkBonjourDiscovery` Settings label updated** — label changed from "Bonjour discovery in Connect sheet" to "Bonjour discovery (Connect sheet and sidebar)" to accurately reflect the setting's scope. (`Views/SettingsView.swift`)
- **`AppLaunchConfiguration.url()` existence check added** — `guard FileManager.default.fileExists(atPath:isDirectory:)` returns nil for non-existent command-line paths; downstream code no longer receives a URL pointing to a missing directory. (`Models/AppLaunchConfiguration.swift`)
- **`TabbedPaneState` pinned-path migration guard added** — `pinnedPathsConsistent` check ensures `savedPinnedPaths` is only used when its count matches `savedPaths`; count divergence (e.g. crash mid-save) falls back to `savedPaths` instead of restoring metadata to wrong tabs. (`ViewModels/TabbedPaneState.swift`)
- **9 new tests** in `Build392BugTests.swift`: `SortPreferenceKeyPruningTests` (2), `AppLaunchConfigurationURLExistenceTests` (3), `PaneStateDuplicateAtRootTests` (2), `TabbedPinMigrationTests` (2). Updated 2 existing tests to match corrected behaviour.
- **286 tests, 0 failures.**

### Build 391 — 8 bug fixes (2026-09-07)

- **`SmartMetadataService` unbounded cache fixed** — `cacheOrder: [URL]` tracks insertion order; when `cache` exceeds 500 entries the oldest entry is evicted. (`Models/SmartMetadataService.swift`)
- **`ProcessRunner.run` no longer blocks thread pool** — `waitUntilExit()` replaced with `withCheckedThrowingContinuation` + `terminationHandler`; pipe drains run in detached tasks to prevent buffer-full deadlocks. (`Models/FileOperationService.swift`)
- **`FolderSizeViewModel` cancellation added** — `Task.isCancelled` checked inside the `directorySize` enumeration loop; scan stops promptly on sheet dismiss. (`ViewModels/FolderSizeViewModel.swift`)
- **`DuplicateFinderViewModel` progress tasks guarded after cancel** — progress callbacks use `[weak vm]` capture and check `vm?.phase == .scanning` before mutating state; final `MainActor.run` also uses `[weak vm]` with a nil guard. (`ViewModels/DuplicateFinderViewModel.swift`)
- **`SidebarModel.removeRecent(_ url:)` added** — targeted O(1) removal without rebuilding the list via `recordVisit`. (`Models/SidebarModel.swift`)
- **`FileRowView.formatDate` static `DateFormatter` cache** — 8 `DateFormatter` instances promoted to `static` properties; no longer allocated per row per render. (`Views/FileRowView.swift`)
- **`AppLaunchConfiguration` command-line URL `isDirectory` fixed** — `fileExists(atPath:isDirectory:)` now determines the correct flag instead of always passing `true`. (`Models/AppLaunchConfiguration.swift`)
- **`SmartMetadataService.lineCount` returns `nil` for binary files** — chunk scan returns `nil` on first null byte, preventing wrong line counts for binary files with code extensions. (`Models/SmartMetadataService.swift`)
- **277 tests, 0 failures.**

### Build 389 — 5 bug fixes: directory compare, line count, tab metadata, subtree guard, archive conflicts (2026-09-07)

- **`FolderCompareService` directory kind mismatch fixed** — `status()` no longer checks `kind` when both items are directories. iCloud Drive reports "iCloud Folder" vs "Folder" for the same directory; this caused false `.different` results. (`Models/FolderCompareService.swift`)
- **`SmartMetadataService.lineCount` off-by-one fixed** — tracks `lastByte`; does not add +1 when the file already ends with a newline. Files like "line1\nline2\nline3\n" now correctly report "3 lines" instead of "4 lines". (`Models/SmartMetadataService.swift`)
- **`TabbedPaneState.fallbackMetadataIndex` guard fixed** — OR condition changed to only check `savedPaths.count == tabs.count`. Previously, matching `savedLabels` or `savedPins` count alone (without `savedPaths`) could stamp metadata onto the wrong tabs after a tab-count change. (`ViewModels/TabbedPaneState.swift`)
- **`FileOperationService.moveOrCopy` subtree guard fixed** — guard moved inside the main loop with `continue` instead of early `return`. Other items in the batch now proceed when one folder is self-referential. (`Models/FileOperationService.swift`)
- **`ArchiveExtractionSafety` subdirectory conflict detection fixed** — `conflicts()` now also checks intermediate path components; detects the case where an intermediate component exists as a file (not a directory), which `fileExists` on the leaf path missed. (`Models/ArchiveExtractionSafety.swift`)
- **New tests added** — `FileOperationSubtreeGuardTests` (2 tests) and `ArchiveExtractionSafetyConflictTests` (3 tests) in `Build381BugTests.swift`. Updated `Build42BugFixTests` expected lineCount value.
- **277 tests, 0 failures.**

### Build 380 — E2E rename test fix, CI hardening, .xcodeproj cleanup (2026-09-07)

- **`testCriticalRenameFileThroughToolbarSheet` fixed** — replaced unreliable `typeKey("a", modifierFlags: .command)` (⌘A) with `typeKey(.rightArrow, modifierFlags: .command)` + `typeKey(.leftArrow, modifierFlags: [.command, .shift])` to navigate to end then select back to beginning, guaranteeing the pre-filled filename is replaced before typing the new name.
- **CI red since Build 377 resolved** — `CustomActionsModelTests` (4 orphaned tests referencing the deleted `CustomActionsModel`) removed from `DuPaneFunctionTests.swift`; class renamed `ProcessRunnerTests` preserving the 2 surviving `ProcessRunner` tests. Unit suite 234 tests, 0 failures.
- **Stale `.xcodeproj` cleaned** — `project.pbxproj` references to the two deleted CustomActions source files removed (8 lines). Clean Xcode clones now build correctly.
- **CI hardened** — `.github/workflows/ci.yml` uses `--scratch-path` outside iCloud to avoid codesign failures; `.gitignore` tightened.
- **234 tests, 0 failures.**

### Build 377 — Menu cleanup, Actions removal, Escape in dialogs, HTML bundling (2026-09-06)

- **Duplicate Settings menu item removed** — the manual `Button("Settings…")` in `CommandGroup(replacing: .appSettings)` was removed; the `Settings { }` scene now provides the single Settings… entry with ⌘, automatically.
- **⌘, opens Settings** — fixed as a consequence of removing the conflicting manual button above.
- **Services menu removed** — `CommandGroup(replacing: .systemServices) {}` added to `DuPaneApp` suppresses the built-in Services menu.
- **Edit, View, Window menus removed** — `AppDelegate.applicationDidFinishLaunching` removes these three menus from `NSApp.mainMenu` at launch.
- **Actions feature removed entirely** — `CustomActionsModel.swift` and `CustomActionsSettingsView.swift` deleted. Toolbar button, context menu entries, alert, `requestCustomActionRun`/`executeCustomAction` functions, and the "Show custom shell command notice" Settings toggle all removed from `GlobalToolbar`, `ContentView`, `PaneView`, and `SettingsView`.
- **Escape dismisses dialog panels** — Cancel button in `TextPromptSheet` gains `.keyboardShortcut(.escape, modifiers: [])` so Escape works in copy-conflict and other prompt dialogs.
- **Help Guide and FAQ load on all machines** — `openDoc` in `DuPaneApp` now resolves via `Bundle.main.url(forResource:withExtension:)` first. `UserGuide.html` and `FAQs.html` added to the DuPane target's Copy Bundle Resources so they ship inside the app bundle.

### Build 368 — GitHub CI, contributor infrastructure, .app launch, 12h+seconds time format, iCloud Drive sidebar, menu order fix (2026-09-06)

- **Double-click .app launches app** — `PaneView.open()` intercepts `.app` extension before the `isDir` check and calls `NSWorkspace.shared.open()`, so app bundles launch rather than navigate into the package.
- **12-hour + seconds time format** — `TimeFormatStyle` gains `.twelveWithSeconds` ("h:mm:ss a") as a 5th option between the existing 12h and 24h options. Settings picker and `FileRowView.formatDate` updated. `Build268Tests.swift` updated to new `timeStyle:` API.
- **DuPane menu order fix** — Settings… now appears above Export/Import Settings. Achieved by switching to `CommandGroup(replacing: .appSettings)` and emitting Settings first, then a Divider, then Export/Import.
- **iCloud Drive in sidebar settings** — conditional toggle in Settings > Sidebar places appears only when `~/Library/Mobile Documents/com~apple~CloudDocs` exists. Default `enabledPlaces` set now includes "iCloud Drive" and "OneDrive".
- **GitHub Actions CI** — `.github/workflows/ci.yml` runs `swift build` + `swift test --filter DuPaneUITests` on `macos-15` on every push/PR to main, plus `workflow_dispatch` for manual triggers. `workflow_dispatch` trigger added (Build 368) so runs can be started from the GitHub web UI.
- **PR validation workflow** — `.github/workflows/pr-check.yml` blocks PRs with empty descriptions (strips HTML template comments before checking).
- **Issue templates** — Bug Report and Feature Request YAML forms with required fields. `config.yml` disables blank issues and links to User Guide + FAQs.
- **PR template** — `.github/pull_request_template.md` with summary, changes, test plan, and checklist sections.
- **CONTRIBUTING.md** — requirements, getting-started steps, before-submit checklist, code conventions, what won't be merged.
- **CI type-checker timeout fix** — extracted `panesArea(snapshot:)` and `keyboardButtons` as `@ViewBuilder` helpers from `ContentView.coreView()` so Swift's type-checker processes each piece independently (CI's compiler is marginally slower than local).
- **Docs consistency** — UserGuide and FAQs footer updated to Version 1.0 / Build 367. iCloud Drive and OneDrive added to sidebar documentation. 12h+seconds option added to time format table. Dark mode settings path corrected.
- **189 tests, 0 failures.**

### Build 313 — Advanced network features (2026-08-29)

- **Mounted network volumes** — the Network sidebar section now enumerates all mounted network shares (SMB, AFP, NFS, etc.) detected via `statfs`/`MNT_LOCAL` flag. Each entry shows the share name with a green status dot (when status indicator is on) and an Eject button that calls `NSWorkspace.unmountAndEjectDevice`. The list auto-refreshes on `NSWorkspace.didMountNotification` / `didUnmountNotification`.
- **Bonjour discovery** — the Connect to Server sheet shows a "Discovered Servers" list populated by `NetServiceBrowser` scanning `_smb._tcp` and `_afpovertcp._tcp` on the local network. Clicking a discovered server fills the URL field. Browsing starts when the sheet opens and stops on close.
- **Pinned network locations** — in the Connect sheet a "Pin this server" toggle (when Settings > Network > Show pinned servers is on) adds the URL to a persistent list (`pinnedNetworkURLs` in UserDefaults). Pinned servers appear in the Network sidebar section with a pin icon and gray status dot. Tapping connects; right-click offers Connect Now / Remove from Pinned.
- **Auto-reconnect on launch** — when Settings > Network > Auto-reconnect pinned servers on launch is on (default off), `NetworkVolumeMonitor` calls `NSWorkspace.open` for each pinned URL at startup. Credentials in Keychain allow silent reconnection.
- **Status indicator** — a 7 pt coloured dot precedes network entries: green for mounted volumes, gray for pinned-but-unmounted servers. Toggled via Settings > Network > Show status indicator.
- **Settings > Network section** — five individual toggles under the Network heading (only shown when Show Network section is on): Mounted volumes, Status indicator, Pinned servers, Bonjour discovery, Auto-reconnect.
- **`NetworkVolumeMonitor` model** — new `ObservableObject` (`NetworkVolumeMonitor.swift`) encapsulating all the above logic. Types: `NetworkVolume` (Identifiable by URL), `BonjourServer` (Identifiable by scheme+host).
- **20 new tests** in `Build310Tests.swift`: 5 × `NetworkVolume`, 5 × `BonjourServer`, 7 × `AppSettings` network defaults & persistence, 3 × `NetworkVolumeMonitor` unit.
- **238 tests, 0 failures.**

### Build 309 — Connect to Server (2026-08-29)

- **Connect to Server** — a "Network" section appears in the sidebar (when Settings > Sidebar > "Show Network section" is on). The "Connect to Server…" row opens a sheet with a URL text field (pre-filled "smb://"). On confirm, `NSWorkspace.shared.open(url)` sends the URL to macOS, which prompts for credentials and mounts the share. Basic URL validation is shown inline.
- **218 tests, 0 failures.**

### Build 307 — Sidebar row hover highlights (2026-08-29)

- **Sidebar hover highlight** — hovering over any Places, Recents, or Bookmarks row now shows a subtle rounded-rectangle background, making it clear which item is under the cursor when right-clicking for the context menu. All three row types share a unified `hoveredURL` state; Bookmarks retain the existing hover-reveal xmark button behaviour.
- **218 tests, 0 failures.**

### Build 269 — 21 new tests, [optional] tagging across all test files (2026-08-28)

- **21 new [must] tests in Build268Tests.swift** — `PaneState.duplicate()` (4 tests: extension, no-extension, auto-increment, multi-item), `SidebarModel` recents (4: prepend, dedup, cap-12, clearRecents), `FileRowView.formatDate(showTime:)` (6: nil→"—", medium no-time, medium+time, ISO date-only, ISO+time, relative today+time), `PaneState.foldersFirst=false` (2), `TabbedPaneState.foldersFirst` propagation (2), `AppSettings` new defaults (1: all 4 new bool fields), `PaneState` new flag defaults (2).
- **`[optional]` tags added** to 17 tests across 4 files: 6 latency, 2 slow-metadata (Build42), 2 slow-metadata (FunctionTests), 3 FolderSizeViewModel, 4 misc trivial/internal. Convention: all tests are [must] unless marked [optional]; see Build268Tests.swift header.
- **210 tests, 0 failures.**

### Build 268 — UserGuide v1.50 update (2026-08-28)

- **UserGuide.html updated to v1.50** — all Build 250 changes reflected: new Settings rows (Sort folders before files, Show time in date modified, Show Places/Recents section toggles), full keyboard shortcut table (⌘↓, ⌘W, ⌘⇧G/H/D/O/C/A/U navigation, ⌘C copy, ⌘V move, ⌘D duplicate, ⌘I get info, ⌘F focus filter). Footer and sidebar version bump to v1.50 Build 268.
- **189 tests, 0 failures.**

### Build 250 — Sidebar section toggles, folders-first setting, time in date, keyboard shortcuts, panel consistency (2026-08-28)

- **Sidebar section toggles** — Settings > Sidebar: "Show Places section" and "Show Recents section" toggles. Both default on. `AppSettings.showSidebarPlaces` / `showSidebarRecents` persisted to UserDefaults. `SidebarView` gates each section on the respective flag.
- **Sort folders before files** — Settings > Display: "Sort folders before files" toggle (default on = current behaviour). `AppSettings.foldersFirst` propagated via `TabbedPaneState.foldersFirst` → all tabs. `PaneState.displayedItems` sort respects the flag.
- **Show time in date modified** — Settings > Display: "Show time in date modified" toggle (default on). `FileRowView.formatDate` gains `showTime: Bool` parameter; all five date format styles updated to include or omit time accordingly. Default Modified column width widened from 110pt to 150pt to accommodate time strings.
- **Keyboard shortcuts** — Added and corrected: ⌘W close tab (was ⌘⇧W), ⌘↓ open selected, ⌘⇧G go to folder, ⌘⇧H home, ⌘⇧D desktop, ⌘⇧O documents, ⌘⇧C computer, ⌘⇧A applications, ⌘⇧U utilities, ⌘C copy to other pane, ⌘V move to other pane (changed from ⌘⌥V), ⌘D duplicate, Space quick look, ⌘I get info, ⌘F focus filter. `PaneState` gains `requestGetInfo` and `requestFocusFilter` flags; `PaneView` handles them with `@FocusState` on the filter field. `PaneState.duplicate()` extracted from PaneView for keyboard access.
- **Panel consistency** — `DuplicateFinderView` sheet moved from `Color.clear.background{}` workaround to direct `.sheet` chain, giving it the same window chrome (traffic lights) as other panels. Done button gains `.keyboardShortcut(.defaultAction)` (⌘Return).
- **189 tests, 0 failures** — updated 1 test for new Modified default width (150pt).

### Build 249 — DuPane rename, themes, date format, icon toggle, first-launch defaults, Recents, Places, Go to Path, type-ahead (2026-08-23)

- **App renamed to DuPane** — `Info.plist` CFBundleName and CFBundleDisplayName updated to "DuPane". All user-visible strings in menus, usage descriptions, and documentation updated. Code identifiers unchanged. Bundle ID unchanged.
- **Window size persistence** — First launch: window maximises to fill the screen. Subsequent launches: window frame restored from `mainWindowFrame` UserDefaults key (saved in `applicationWillTerminate`). Implemented in `AppDelegate`.
- **First-launch defaults** — Default font size 14pt (was 12pt). Default visible columns: Name, Size, Modified (Kind and Info hidden by default). Default column widths: Size 80pt, Modified 110pt.
- **5 new themes** — `AppColorScheme` gains `.ocean`, `.country`, `.earth`, `.fire`, `.vivid` cases. Ocean: dark/cyan, Country: light/forest-green, Earth: light/terracotta, Fire: dark/fire-red, Vivid: light/purple.
- **Date format setting** — `DateFormatStyle` enum added (short/medium/long/iso/relative). `AppSettings.dateFormatStyle` persisted to UserDefaults. `FileRowView.formatDate(_:style:)` takes style parameter.
- **File icon show/hide** — "Icon" added to column toggle system. `FileRowView` conditionally renders `iconView` based on `!settings.hiddenColumns.contains("Icon")`.
- **Sidebar Recents** — `SidebarModel.recentURLs: [URL]` (up to 12, persisted in UserDefaults). `recordVisit(_:)` called from `ContentView.onChange` for both pane URLs.
- **Sidebar Places** — `AppSettings.enabledPlaces: Set<String>` (UserDefaults key `enabledPlaces`, default: Home/Applications/Desktop/Documents/Downloads). `SidebarView` shows a "Places" section filtered by `settings.enabledPlaces`.
- **189 tests, 0 failures** — updated 3 tests to match new defaults.
- **UserGuide and FAQs** — fully updated: DuPane rename, Places/Recents sidebar sections, date format setting, icon toggle, themes table, Go to Path ⌘L shortcut, type-ahead note, first-launch defaults.

### Build 51 — Type-ahead file navigation (2026-08-21)

- **Typing selects first matching item** — when a pane is active and no text input has focus, typing any printable character jumps the selection to the first visible item whose name starts with the typed string. Multi-character prefix accumulated within 600ms. Implemented via `TypeAheadController`.
- **110 tests, 0 failures** — no new tests (AppKit event monitor + UI scroll, not unit-testable).

### Build 50 — Go to Path (2026-08-21)

- **⌘L opens "Go to Folder" sheet** — pressing ⌘L on either pane opens a sheet pre-filled with the pane's current path. Tilde expansion supported. Path validated as existing directory on confirm.
- **110 tests, 0 failures** — no new tests.

### Build 49 — Show hidden folders setting (2026-08-21)

- **"Show hidden folders (dot-folders)" toggle in Settings → Display** — independent of the existing "Show hidden files" toggle.
- **110 tests, 0 failures** — no new tests.

### Build 48 — Subfolder deep search (2026-08-21)

- **NSMetadataQuery-based subfolder search** — filter box gains a magnifying glass button triggering `PaneState.beginDeepSearch(query:)`. Search banner shows progress. File operations work on search results.
- **Rename returns task for testability** — `PaneState.rename(item:to:)` changed to `@discardableResult func → Task<Void, Never>?`.
- **189 tests, 0 failures** — 17 new tests in `DeepSearchTests.swift`.

### Build 47 — iCloud Drive in sidebar (2026-08-21)

- **iCloud Drive appears in sidebar system locations** — `SidebarModel.init` checks for `~/Library/Mobile Documents/com~apple~CloudDocs`. If present, an "iCloud Drive" entry with `icloud.fill` icon is inserted between Downloads and OneDrive.
- **172 tests, 0 failures** — no new tests.
