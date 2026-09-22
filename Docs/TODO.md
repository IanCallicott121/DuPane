# DuPane — TODO

## Current state

**Main build: 421.** A local build is being prepared on 2026-09-22; manual confirmation is
pending. Column-picker behavior, Cmd-V routing and repeated Escape dismissal for New File,
New Folder and Go to Folder were previously verified on a local build.

## Action Items
### App

### Manual

## Decisions

- **Accessibility labels and metadata — do not implement (2026-09-21).** Leave the current decorative icon, keyboard-symbol, language, and metadata markup unchanged.
- **App behavior planning — 2026-09-21.**
  - Permission recovery: plan a minimal `Open Privacy & Security` action for restricted folders and refresh the pane when DuPane returns to the foreground.
  - Compare/Sync: retain current-folder-only comparison and make the shallow scope explicit.
  - Sync safety: retain the current overwrite behavior, but warn that overwritten files cannot be recovered through DuPane.
  - Command Runner: retain the current non-interactive login-shell model and document its limitations clearly.
  - Toolbar: retain the current visible buttons, labels, help text, disabled states, and context-menu actions without adding shortcuts or controls.

## Pending items

- Mac App Store submission is on hold due to the friction involved for this type of app.
  Revisit only when explicitly requested; no distribution work or code changes are
  currently authorized.


## Verification reference

- Unit tests: `swift test --filter DuPaneUITests`.
- E2E tests: `./Scripts/run-e2e.sh`.
- Repository workflow: `AGENTS.md`.

## Done

### FAQ consistency corrections — 2026-09-22

- Aligned the FAQ with the application and User Guide for pane-transfer destinations,
  bookmarked shell scripts, comparison behavior, duplicate verification, breadcrumb
  navigation, and standard macOS copy/paste shortcuts.

### App behavior planning implementation — 2026-09-21

- Added `Open Privacy & Security Settings…` to restricted-folder context menus and refreshes both active panes when DuPane returns to the foreground.
- Made the current-folder-only Compare scope explicit in the toolbar help and guide.
- Added a Sync confirmation warning that overwritten files cannot be recovered through DuPane.
- Documented the Command Runner's non-interactive login-shell behavior and limitations.
- Kept the existing toolbar affordances unchanged as planned.

### Hidden-item settings interaction — 2026-09-21

- Documented how the independent hidden-file and hidden-folder settings combine in both panes, including the fact that showing hidden files already includes hidden folders.

### Locked-folder permission wording — 2026-09-21

- Clarified that the red lock indicates missing read access, while write access may still allow copying or moving items into the folder.

### Guide section comment cleanup — 2026-09-21

- Replaced stale numeric HTML section comments with stable descriptive labels so future insertions cannot create duplicate or missing numbers.

### Overview callout cleanup — 2026-09-21

- Removed the redundant Finder comparison callout from the overview while retaining the actionable developer workflow examples.

### Application shortcut group — 2026-09-21

- Renamed the “Developer Tools” shortcut group to “Application” so its heading matches the Settings and User Guide entries it contains.

### Show Folder Sizes terminology — 2026-09-21

- Renamed the guide navigation and section heading to match the app's `Show Folder Sizes` context-menu command.

### Command Runner terminology — 2026-09-21

- Standardized the guide's feature name as “Command Runner” while retaining “Terminal” only for the existing toolbar button and separate macOS Terminal app.

### Network settings documentation — 2026-09-21

- Added a Network settings table covering mounted volumes, status indicators, pinned servers, Bonjour discovery, and auto-reconnect behavior.
- Standardized guide menu paths to match the app's visible section names, including `Settings → Sidebar places` and `Settings → Startup folders`.

### GitHub issue feedback link — 2026-09-21

- Added a footer link to the repository's standard GitHub issue chooser for bug reports and feature requests.

### In-page guide search — 2026-09-21

- Added a search field to the table of contents that filters guide sections and navigation links, reports the result count, and provides a clear action.

### Guide contrast and navigation — 2026-09-21

- Changed tip callout body text to the normal guide colour for readable contrast while retaining the accent for callout styling.
- Stabilized the scroll-spy so it keeps the last visible section active and updates immediately when a navigation link is clicked.

### Printable User Guide — 2026-09-21

- Added print styles that hide the sidebar, remove desktop margins, preserve the title and contents, and keep sections, callouts, and reference tables together where possible.

### Responsive User Guide layout — 2026-09-21

- Added a sub-900px breakpoint that turns the fixed sidebar into a horizontally scrollable top navigation bar and lets the guide use the full window width.

### User Guide reference and build-token cleanup — 2026-09-21

- Generated the table of contents from the guide's `<section id>` elements, so Duplicate Finder and future sections are included automatically.
- Fixed the Duplicate Finder note's callout class and restored its icon styling.
- Replaced hardcoded guide version/build text with `{{VERSION}}` and `{{BUILD}}` tokens. The Xcode build phase substitutes the values in the bundled guide from `MARKETING_VERSION` and `BuildNumber.txt` without modifying the source copy.
- Added Installation & Permissions, Troubleshooting, and Toolbar Reference sections, including the fact that Show Folder Sizes is a folder context-menu action rather than a global toolbar button.

### Standard copy/paste shortcuts — 2026-09-21

- Removed DuPane's app-specific `⌘C`/`⌘V` pane-transfer bindings. Standard macOS copy/paste
  behavior is no longer intercepted; F5/F6 remain the shortcuts for copying or moving
  selections between panes.
- Updated the User Guide shortcut table and added E2E coverage proving `⌘C`/`⌘V` do not
  transfer selected files between panes.

### Internal test menu marker removed — 2026-09-22

- Removed the temporary internal build number from the Help menu and its obsolete E2E
  assertion. Manual builds are identified by the verified installed-app target and
  timestamps instead.

### Build-number convention documented — 2026-09-20

- Recorded the main build number convention in [RELEASING.md](RELEASING.md#build-numbers).
  Corrected the latest TODO entry to `421.6` to match the deployed app, source and
  verification test. No app build labels or application code were changed.

### Duplicate Finder documentation — 2026-09-20

- Corrected the guide to describe size grouping, hashing and final byte-for-byte
  verification. Matching hashes alone do not establish equality. Verified that the
  final comparison already exists in `DuplicateFinderViewModel`; removed the stale
  request to add it. No application code or build labels changed.

### Documentation audit — 2026-09-15

- Audited the User Guide and FAQs against current settings, shortcuts, and operation
  behavior; corrected stale build, theme, path-navigation, and duplicate-scan details.
- Help documents are bundled into the app and open in a full-width in-app window.

### GitHub Releases — 2026-09-15

- Added a tag-triggered GitHub Actions workflow that builds the Release app and publishes
  ZIP and DMG assets plus SHA-256 checksums to a GitHub Release. GitHub records download
  counts per asset; no launch telemetry is collected. Moved maintainer publishing steps
  into `Docs/RELEASING.md` so contributor guidance does not imply that contributors make
  releases.

### E2E coverage expansion (2026-09-14)

- Expanded visible UI workflow coverage with high, medium, and low priorities, including
  high-priority-only interim runs and full final runs.
- Removed the excessively long multi-create and repeated Go To Folder stress workflows;
  the underlying edge case remains covered by focused unit and regular UI tests.
- Added negative validation that requires every emitted result to be `FAIL` and rejects
  missing or `PASS` results.
- Hardened result reporting so XCTest failures and unexpected exceptions emit `FAIL`,
  never `PASS`; the runner also rejects missing machine-readable results.
- Classified the active E2E coverage into high, medium, and low priority lanes; retired
  the Command Runner panel test from the suite.

### Column picker — 2026-09-15 (manual build 421.6)

- **Manual verification:** Ian confirmed this work as tested on 2026-09-20.

- Right-clicking a column heading lists every column with state-aware show/hide controls,
  visible-column movement, and minimum/maximum width actions.
- Hidden columns cannot be moved, and visible-column movement stops at the actual visible
  left and right boundaries.

### Build 421.4 — UI input routing and Escape dismissal (2026-09-14)

- Cmd-V pastes into New File and Go to Folder text fields while moving selected pane
  items between panes elsewhere; regression coverage verifies both behaviors.
- Repeated Escape dismisses New File, New Folder, and Go to Folder without locking the UI.
- Manual verification completed for all three dialogs, including Go to Folder.

### Date Added — 2026-09-14 (Build 420 unchanged)

- Added creation-date metadata, Date Added sorting, column display, column sizing, and
  migration for existing saved column orders.

### Data-integrity safeguards — 2026-09-14 (Build 420 unchanged)

- Folder overwrite merges now preserve destination-only entries and roll back safely when
  a merge fails.
- Copy, move, and Folder Sync revalidate destinations after confirmation; Folder Sync uses
  best-effort per-file copying, so successful files remain when a later file fails.
- Duplicate Finder blocks every action for a group when any member changed, then refreshes
  the scan results.
- Folder Compare verifies file contents when metadata alone is inconclusive.
- Added regression coverage for the safeguards and the six Duplicate Finder stale-group
  scenarios.

### Archive compression and extraction rewrite — 2026-09-13 (Build 420 unchanged)

- Replaced `/usr/bin/zip` and `/usr/bin/unzip` subprocesses with in-process ZIPFoundation handling.
- Preserved symbolic links and extended attributes, prevented partial destination archives, and added transactional extraction with rollback.
- Added regression coverage for option-like filenames, archive fidelity, and failed extraction cleanup.

### Follow mode and keyboard navigation — 2026-09-13

- Fixed Follow synchronization between Computer and regular folders in both directions.
- Added Up/Down selection movement and repeated Page Up/Page Down navigation without requiring a selected item; verified manually on internal and external keyboards.
- Added regression coverage for Follow mode and keyboard selection movement.

### Function-key and pane-focus shortcuts — 2026-09-12

- Added Fn+F5 copy, Fn+F6 move, Fn+F7 new folder, Fn+F8 delete, and Tab active-pane switching.
- Reused the existing action handlers and documented the shortcuts in the User Guide.

### Documentation cleanup — 2026-09-11 (Build 420 unchanged)

- Corrected stale project names, removed obsolete Custom Actions guidance and model
  references, and aligned test instructions with the current workflow. Documentation
  checks passed; application code and the existing verified test results are unchanged.

### Build 420 — sort tiebreak consistency for the Info column (2026-09-09)

- **Info-column name tiebreak now follows the sort direction** — `PaneView.visibleItems` sorts the async-loaded Info column; its primary comparison already honored `sortAscending`, but the equal-value name tiebreak was hardcoded ascending. Aligned it with the Build 403 decision already applied to Size/Kind/Modified in `PaneState` (and to `PaneState`'s own `.info` fallback), so a descending Info sort breaks ties in descending name order. (`Views/PaneView.swift`)
- **Provenance** — surfaced by a stale external handover; that handover's other findings (duplicate-scan generation refactor, the size/kind/modified tiebreak revert, TODO/build-number/migration-script drift) were already resolved by Builds 403/404/418 or deliberately decided the other way, so only this one view-layer inconsistency remained.
- **Tests: 336 unit passed, 0 failed; e2e 14 passed, 0 failed (re-run 2026-09-09 at this build)** — full SPM unit suite plus a fresh `./Scripts/run-e2e.sh` run against `f64ef4e`. No new unit test: no test asserts `visibleItems` ordering, and this is a pure view-layer sort refinement consistent with the existing `testDescendingSortEqualValuesTieBreakByName` behavior.

### Build 418 — outstanding bug closure and lifecycle hardening (2026-09-08)

- **Pane and tab performance/lifecycle** — `displayedItems` is cached and invalidated only when one of its inputs changes; switching tabs no longer forces an unnecessary directory load; closing a tab now cancels its load and explicitly tears down Spotlight observers/query state. (`ViewModels/PaneState.swift`, `ViewModels/TabbedPaneState.swift`, `Views/TabbedPaneView.swift`)
- **Sidebar filesystem checks moved off the main actor** — bookmark, recent, iCloud, and OneDrive existence validation now runs in a cancellable utility task with generation checks, so stale validation snapshots cannot overwrite newer UI mutations. (`Models/SidebarModel.swift`)
- **Process lifecycle hardened** — `ProcessRunner` redirects stdin to `/dev/null`, enforces a five-minute default timeout, terminates on task cancellation, and still drains stdout/stderr concurrently. Collapsing the Command Runner cancels its active task. (`Models/FileOperationService.swift`, `Views/CommandRunnerView.swift`)
- **Archive conflict state survives tab switches** — pending uncompress URL/conflicts now live on the stable `PaneState`, not an orphanable `PaneView` state box. (`ViewModels/PaneState.swift`, `Views/PaneView.swift`)
- **Delete navigation handles nested and partial-success cases** — peer recovery walks outside every successfully trashed ancestor and ignores failed deletions. (`Models/FileOperationService.swift`, `Views/ContentView.swift`)
- **Quick Look updates an already-visible panel when selection changes** — Space still closes the panel for the same selection, while a new selection reloads it immediately. (`Views/QuickLookCoordinator.swift`)
- **Column drag cleanup covers missed mouse-up events** — local/global mouse-up monitors plus window/app deactivation observers terminate the drag and restore cursor state. (`Views/ColumnResizeHandle.swift`)
- **Test infrastructure repaired** — the flaky PNG metadata test polls for resolution; `Scripts/run-e2e.sh` captures structured UI-test stdout markers into the gitignored repo-local log, avoiding the UI runner's source-tree sandbox. E2E actions now wait for enabled, hittable controls, and delete confirmation is pinned by launch arguments so machine preferences cannot consume the Undo toast lifetime. (`Tests/DuPaneUITests/DuPaneFunctionTests.swift`, `UITests/DuPaneEndToEndUITests/TestResultLog.swift`, `UITests/DuPaneEndToEndUITests/DuPaneEndToEndUITests.swift`, `Scripts/run-e2e.sh`)
- **Audit: two reported races were unreachable** — history navigation and `endDeepSearch()` are synchronous `@MainActor` operations with no suspension point; queued Spotlight callbacks re-check the cleared query. No defensive code was added for impossible interleavings.
- **Tests: 336 passed, 0 failed; e2e: 14 passed, 0 failed** — 13 new unit regressions in `Build418BugTests.swift`; the full wrapper run proved `.test-results/DuPaneEndToEndUITests.log` contains 14 current PASS results.

### Build 404 — Duplicate Finder scan identity and Codex workflow (2026-09-08)

- **Low: superseded Duplicate Finder scans can no longer publish stale progress or results** — every scan now carries a monotonically increasing generation. Progress and completion callbacks update the view model only when their generation is still current and the scan is active, so reopening the finder on another folder cannot briefly show counters or groups from the previous scan. The detached task also captures the view model weakly. (`ViewModels/DuplicateFinderViewModel.swift`, `Tests/DuPaneUITests/Build404BugTests.swift`)
- **Audit: the reported resolved-group UI bug was already fixed** — `moveToTrash` removes groups with fewer than two remaining files, so the view never retains a one-file “resolved” group. Re-verified with the existing four-test `DuplicateFinderMoveToTrashTests` suite and removed the stale TODO entry. (`ViewModels/DuplicateFinderViewModel.swift`, `Tests/DuPaneUITests/BugAuditTests.swift`)
- **Repository workflow: added Codex-native instructions** — root `AGENTS.md` directs Codex to the complete project conventions and agent workflow, including handoff checks, regression tests, documentation/build updates, XcodeGen handling, and clean sync requirements. (`AGENTS.md`)
- **Tests: 323 passed, 0 failed** — full SPM unit suite, including the new deterministic superseded-scan regression. Existing Duplicate Finder group-cleanup tests passed 4/4. No e2e run was needed because this build changes internal scan-state isolation and repository guidance only; the previous Build 403 e2e result remains 14 passed, 0 failed.

### Build 403 — network ejection consistency and descending sort tiebreaks (2026-09-08)

- **Medium: a failed network-volume eject now leaves the sidebar unchanged** — `NetworkVolumeMonitor.ejectAndRemove` now attempts the unmount before suppressing or removing the volume. If macOS rejects the eject, the still-mounted share remains visible and can be retried. The unmount operation is injected for deterministic regression coverage. (`Models/NetworkVolumeMonitor.swift`, `Tests/DuPaneUITests/BugAuditTests.swift`)
- **Medium: mounted-volume probing no longer blocks the UI** — `refresh()` snapshots its inputs and performs `mountedVolumeURLs`/`statfs` work on a serial utility queue, publishing only the newest completed generation back on the main queue. A stale network share can no longer beachball the app during sidebar refresh. (`Models/NetworkVolumeMonitor.swift`)
- **Medium: Bonjour discovery publishes on the main thread** — delegate callbacks now pass through `receiveBonjourServers`, which marshals background callbacks to the main queue before changing `bonjourServers`. (`Models/NetworkVolumeMonitor.swift`)
- **Low: descending sort now applies descending name tiebreaks** — equal values in Size, Kind, and Modified sorts now order names consistently with the selected descending direction. Updated `testDescendingSortEqualValuesTieBreakByName` to assert the intended behaviour. (`ViewModels/PaneState.swift`, `Tests/DuPaneUITests/DuPaneFunctionTests.swift`)
- **Tests: 322 passed, 0 failed** — full SPM unit suite, including four network-eject tests and two network-threading regression tests in `Build403BugTests.swift`.

### Repository tooling — local clone migration helper (2026-09-08)

- **iCloud-to-local migration script** — `Scripts/migrate-off-icloud.sh` creates a clean, metadata-free Git clone at `~/Developer/DuPane` by default, preserving tracked work through a binary patch and untracked files without Finder/resource-fork metadata. It leaves the iCloud checkout untouched, retains a local safety backup, restores the original `origin` URL, and optionally runs the SPM unit suite. Use it instead of copying the repository in Finder when iCloud metadata makes codesigning fail.

### Build 397 — 4 design-decision fixes: sync atomicity, trash undo, atomic settings import, metadata isolation (2026-09-08)

- **Medium: folder sync is now all-or-nothing** — `executeSyncPlan()` copied via `moveOrCopy` with per-item backups that were deleted the instant each item succeeded, so a failure partway through left earlier files overwritten with no rollback. New `FileOperationService.transactionalCopy(files:to:onProgress:)` backs up every existing destination, keeps all backups until the whole plan succeeds, and rolls the entire batch back (restoring overwritten files, removing newly-created ones) on any single failure. Sync-plan overwrite entries are files only (directories are excluded upstream in `FolderCompareService.overwritingEntry`), so no directory-merge rollback is needed. (`Models/FileOperationService.swift`, `Views/ContentView.swift`)
- **Medium: a partial or complete delete is now undoable** — `trash()` returns `[TrashedItem]` pairing each original URL with its Trash location, and `restoreFromTrash(_:)` moves them back (skipping any whose original path is occupied again, so a restore never overwrites a newer file). `performDelete` shows an **Undo** button in the toast that restores the items. (`Models/FileOperationService.swift`, `Views/ContentView.swift`, `Views/GlobalToolbar.swift` — added `toolbar-delete-button` id)
- **Low: Import Settings is now atomic** — `AppSettings.performBatchUpdate` collects each setting's `didSet` write while a batch is open and flushes them to `UserDefaults` in one pass; `applyImport` runs inside it, so a bulk import can no longer be observed in an inconsistent intermediate state. Single-setting writes stay immediate. Removed the now-unused `saveColumnWidths` helper. (`Models/AppSettings.swift`)
- **Low: metadata cache off-main access now fails loudly** — `SmartMetadataService` gains a `dispatchPrecondition(.onQueue(.main))` assertion at every `cache`/`cacheOrder`/`pending` access point, turning an accidental off-actor read into a debug crash instead of a silent data race. (`Models/SmartMetadataService.swift`)
- **14 new tests** — unit (`Build397BugTests.swift`): `TransactionalSyncCopyTests` (4), `TrashUndoTests` (4), `AppSettingsBatchWriteTests` (3), `SmartMetadataMainActorAccessTests` (1); e2e (`DuPaneEndToEndUITests.swift`): `testCriticalUndoAfterDeleteRestoresTheFile`, `testCriticalSyncCopiesLeftOnlyFilesToTheRightPane` (2). e2e added only where UI-observable — the atomic-import and metadata-assertion fixes stay unit-only (import consistency is unobservable through the UI; the metadata `dispatchPrecondition` would crash the runner, not assert). **Unit: 319 passed, 0 failed. E2E: 14 passed, 0 failed** (`xcodebuild` scheme `DuPane`, macOS 27.0, 2026-09-08). The delete-confirmation step in the Undo test is optional so it passes whether or not "delete without confirmation" is enabled.

### Build 395 — 2 High bug fixes with refactors for testability (2026-09-08)

- **High: concurrent file operations no longer clobber each other's progress UI** — `fileOpInfo` / `fileOpVisible` / `fileOpRevealTask` were one shared set of `@State` slots in `ContentView` with nothing serialising operations, so whichever finished first tore down the overlay and the one still running had no progress display for the rest of its life. Extracted to `FileOperationProgressModel` (`ViewModels/`), where every mutation is addressed by the token issued at `begin()`: a finished operation can only retire itself, the overlay hides only when the last operation completes, and a stale `update`/`reveal` is ignored. Both call sites (`executeMoveOrCopy`, `executeSyncPlan`) now go through it. (`ViewModels/FileOperationProgressModel.swift`, `Views/ContentView.swift`)
- **High: type-ahead no longer writes into a closed tab's `PaneState`** — `TabbedPaneView` keyed view identity on `activeTabIndex`, an `Int`. Closing the middle of three tabs leaves the index unchanged while it now refers to a different tab, so SwiftUI reused the view, `onAppear` did not re-run, and the type-ahead closure kept the `PaneState` of the tab that was gone — type-ahead silently dead in that pane, old `PaneState` retained. `Tab` already carried a stable `UUID`; added `TabbedPaneState.activeTabID` and keyed the view on it. (`ViewModels/TabbedPaneState.swift`, `Views/TabbedPaneView.swift`)
- **Testability** — accessibility identifiers added to the tab strip (`<side>-tab-<n>`, `<side>-close-tab-<n>`, `<side>-new-tab-button`), the Go-to-Folder sheet (`go-to-path-field`, `-confirm-button`, `-cancel-button`) and the progress overlay (`file-op-progress`). None of these were reachable from a UI test before.
- **8 new unit tests** in `Build394BugTests.swift`: `FileOperationProgressModelTests` (5), `ActiveTabIdentityTests` (3). **319 tests, 0 failures.**
- **2 new e2e tests** in `DuPaneEndToEndUITests.swift`: `testCriticalTypeAheadStillWorksAfterClosingTheActiveTab`, `testCriticalProgressOverlayIsNotLeftOnScreenAfterACopy`. **Not yet executed** — they need `xcodegen generate` first, because `FileOperationProgressModel.swift` is new and the `.xcodeproj` does not reference it yet.

### Build 394 — 4 bug fixes: folder-merge data loss, load cancellation, metadata re-spawn, progress reporting (2026-09-08)

- **Critical: "Overwrite" on a folder no longer destroys data** — `FileOperationService.moveOrCopy` now merges directory-into-directory rather than replacing. Previously it moved the existing destination aside, copied the source over it, then deleted the backup with `removeItem`, so every file present only in the destination was permanently gone — no Trash, no undo. Reachable from both the copy/move and drag-drop conflict alerts. New `mergeDirectory(from:to:isMove:)` recurses and overwrites colliding files while never removing a destination entry that has no counterpart in the source. Packages (`.app`, `.rtfd`) are detected via `isPackageKey` and still replace wholesale, since merging two bundle versions would produce a broken one. (`Models/FileOperationService.swift`)
- **High: cancelled directory loads now actually stop** — `PaneState.loadFolder` checks `Task.checkCancellation()` per entry. `load()` cancels the wrapper, but the inner `Task.detached` does not inherit cancellation and the enumeration had no checks, so a cancelled load kept a cooperative-pool thread busy until the read finished. Several tabs on an unresponsive SMB/NFS share could exhaust the pool and stall every `Task.detached` in the app — panes spinning forever, metadata stopped, copy/move/delete never starting — while the main thread stayed responsive so the app looked alive. (`ViewModels/PaneState.swift`)
- **`SmartMetadataService` no longer re-spawns a task per file on every reload** — `compute` returns nil for any extension outside its three lists, and nothing was recorded for a nil, so `loadIfNeeded` restarted the whole set on every `pane.items` change. Negative results are now cached as an empty sentinel through the existing LRU; `info(for:)` still returns nil for it so nothing changes in the UI. Added `hasResolved(_:)`. (`Models/SmartMetadataService.swift`)
- **`onProgress` now fires for items skipped by the subtree guard** — the `defer` was registered after the guard's `continue`, so a batch containing a self-referential folder never reached its progress total. (`Models/FileOperationService.swift`)
- **10 new tests** in `Build394BugTests.swift`: `FolderOverwriteMergeTests` (5, including the exact data-loss case and a regression guard that plain files still replace), `MoveOrCopyProgressReportingTests` (1), `LoadFolderCancellationTests` (2), `SmartMetadataNegativeCacheTests` (2).
- **309 tests, 0 failures.**

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
