# DuPane — TODO


## Next items

## Clarifications
none


## Pending

---

## Done
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

- **App renamed to DuPane** — `Info.plist` CFBundleName and CFBundleDisplayName updated to "DuPane". All user-visible strings in menus ("Open DuPaneMac User Guide" → "Open DuPane User Guide"), usage descriptions, and documentation updated. Code identifiers unchanged (user will relocate project later). Bundle ID unchanged.
- **Window size persistence** — First launch: window maximises to fill the screen. Subsequent launches: window frame restored from `mainWindowFrame` UserDefaults key (saved in `applicationWillTerminate`). Implemented in `AppDelegate`.
- **First-launch defaults** — Default font size 14pt (was 12pt). Default visible columns: Name, Size, Modified (Kind and Info hidden by default, stored as "Info,Kind" in `hiddenColumnsRaw`). Default column widths: Size 80pt, Modified 110pt (was 74/92pt) — wide enough for "31 Dec 2025" at 14pt monospaced.
- **5 new themes** — `AppColorScheme` gains `.ocean`, `.country`, `.earth`, `.fire`, `.vivid` cases. Each defines `preferredColorScheme` (light or dark) and `accentColor`. Applied via `.accentColor()` and `.preferredColorScheme()` on the root WindowGroup view. Ocean: dark/cyan, Country: light/forest-green, Earth: light/terracotta, Fire: dark/fire-red, Vivid: light/purple. Settings picker changed to `.menu` style to accommodate 8 items.
- **Date format setting** — `DateFormatStyle` enum added (short/medium/long/iso/relative). `AppSettings.dateFormatStyle` persisted to UserDefaults. `FileRowView.formatDate(_:style:)` takes style parameter, called with `settings.dateFormatStyle`. Medium format changed from `.dateStyle = .medium` to `"d MMM yyyy"` custom format for consistent day-first layout.
- **File icon show/hide** — "Icon" added to column toggle system. `columnToggleButton("Icon")` in sort-header context menu. `FileRowView` conditionally renders `iconView` based on `!settings.hiddenColumns.contains("Icon")`. Sort-header leading padding and `metadataColumnBudget` both adjusted dynamically: 0 when icon hidden, 28pt when shown — so Name column aligns correctly in header and rows in both states.
- **Right-click rename** — "Show Folder Sizes" → "Show Folder / File Sizes" in file context menu.
- **Sidebar Recents** — `SidebarModel.recentURLs: [URL]` (up to 12, persisted in UserDefaults as `sidebar.recentURLs`). `recordVisit(_:)` called from `ContentView.onChange` for both pane URLs. `clearRecents()` clears the list. `SidebarView` shows a "Recents" section with clock icons; right-click removes individual items; "Clear Recents" button at the bottom.
- **Sidebar Places** — `AppSettings.enabledPlaces: Set<String>` (UserDefaults key `enabledPlaces`, default: Home/Applications/Desktop/Documents/Downloads). `SidebarModel.systemLocations` gains Applications (`/Applications`). `SidebarView` shows a "Places" section (above Recents) filtered by `settings.enabledPlaces`. `SettingsView` has a "Sidebar places" section with five toggles.
- **189 tests, 0 failures** — updated 3 tests to match new defaults (font 14, column widths 80/110, hidden column defaults).
- **UserGuide and FAQs** — fully updated: DuPane rename, Places/Recents sidebar sections, date format setting, icon toggle, themes table, Go to Path ⌘L shortcut, type-ahead note, first-launch defaults.

### Build 51 — Type-ahead file navigation (2026-08-21)

- **Typing selects first matching item** — when a pane is active and no text input has focus, typing any printable character (letters, digits, punctuation) jumps the selection to the first visible item whose name starts with the typed string. Typing quickly (within 600ms) accumulates a multi-character prefix (e.g. typing "r", "e" selects the first item starting with "re"). After 600ms of inactivity the buffer resets. The matched item is scrolled into view. Implemented via `TypeAheadController` (an `@MainActor` class using `NSEvent.addLocalMonitorForEvents`) installed per pane, with `isActive` flag updated via `onChange`. The file list `ScrollView` is wrapped in `ScrollViewReader` for programmatic scrolling. Keypresses are ignored when a text field/text view has first responder (filter box, rename sheet, etc.), or when any modifier beyond Shift/CapsLock is held, or when a special key (arrows, F-keys, delete, etc.) is pressed.
- **110 tests, 0 failures** — no new tests (AppKit event monitor + UI scroll, not unit-testable).

### Build 50 — Go to Path (2026-08-21)

- **⌘L opens "Go to Folder" sheet** — pressing ⌘L (or wiring via ContentView's hidden-button group) on either pane opens a sheet pre-filled with the pane's current path. The user can type or paste any absolute path (tilde expansion supported). On confirm, the path is validated as an existing directory; if not, an error is shown in the status bar. On success the pane navigates to the typed folder. Implemented via `PaneState.requestGoToPath: Bool` (mirrors `requestRename`), handled in `PaneView.onChange` which sets `showGoToPath = true` and seeds the text field, with `commitGoToPath()` doing the validation and navigation.
- **110 tests, 0 failures** — no new tests (UI sheet + navigation, mirrors rename pattern).

### Build 49 — Show hidden folders setting (2026-08-21)

- **"Show hidden folders (dot-folders)" toggle in Settings → Display** — independent of the existing "Show hidden files" toggle. When enabled, hidden directories (names starting with `.`) are shown while hidden files remain hidden. When both are enabled, everything is shown. When both are off, all dot-items are hidden. Implemented by passing `showHiddenFolders` through `AppSettings` → `ContentView.onChange` → `TabbedPaneState.showHiddenFolders` (propagates to all tabs) → `PaneState.showHiddenFolders` → `PaneState.loadFolder`. The loader fetches all items when either flag is on, then filters out hidden non-directories when only `showHiddenFolders` is set.
- **110 tests, 0 failures** — no new tests (UI toggle + filter logic, mirrors existing `showHiddenFiles` pattern).

### Build 48 — Subfolder deep search (2026-08-21)

- **NSMetadataQuery-based subfolder search** — the filter box gains a magnifying glass button (next to the existing × clear button) that appears whenever there is filter text. Clicking it triggers `PaneState.beginDeepSearch(query:)`, which runs an `NSMetadataQuery` scoped to the current folder with a `LIKE[cd]` wildcard predicate. A search banner below the sort header shows "Searching subfolders…" (spinner) while gathering, then "N results in subfolders" when complete. The file list switches to the Spotlight results (bypassing the normal items/filter pipeline). Navigating away, pressing Back/Forward, or clearing the filter text automatically ends search mode (`endDeepSearch`). File operations — open, copy, move, delete — all work on search results. `displayedItems`, `selectedItems`, and `selectedFileItems` all fall back to `searchResults` when in search mode.
- **Rename returns task for testability** — `PaneState.rename(item:to:)` changed from `func → Void` to `@discardableResult func → Task<Void, Never>?`. Callers that don't care (SwiftUI sheet) ignore the return value; tests can `await` the returned task. Fixed two pre-existing test failures where the rename tests didn't properly await the async operation.
- **189 tests, 0 failures** — 17 new tests in `DeepSearchTests.swift` covering state machine (isInSearchMode, isSearching, searchResults), navigation exits search mode (navigate/goBack/goForward), displayedItems uses searchResults, selectedItems reads from searchResults, endDeepSearch is idempotent.

### Build 47 — iCloud Drive in sidebar (2026-08-21)

- **iCloud Drive appears in sidebar system locations** — `SidebarModel.init` now checks for `~/Library/Mobile Documents/com~apple~CloudDocs` (the standard on-disk path for iCloud Drive on macOS). If present, an "iCloud Drive" entry with `icloud.fill` icon is inserted between Downloads and OneDrive. Alias resolution via `URL(resolvingAliasFileAt:)` is applied as with OneDrive. No entitlements needed — the app is non-sandboxed and can read this path directly.
- **172 tests, 0 failures** — no new tests (existence check mirrors the existing OneDrive pattern).
