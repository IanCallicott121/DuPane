# DuPane — TODO


## Next items

  


## Clarifications



## Pending
- SMB network shares
- Bug - no icloud on the mac air


---

## Done
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

- **App renamed to DuPane** — `Info.plist` CFBundleName and CFBundleDisplayName updated to "DuPane". All user-visible strings in menus ("Open DOpusMac User Guide" → "Open DuPane User Guide"), usage descriptions, and documentation updated. Code identifiers unchanged (user will relocate project later). Bundle ID unchanged.
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
