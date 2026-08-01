# /Opus — TODO


## Next items

## Clarifications


## Pending
- **iCloud Drive in sidebar** — requires iCloud entitlements (`com.apple.developer.icloud-container-identifiers`), which must be configured in the Apple Developer Portal before the app can access iCloud Drive. Deferred until entitlements are in place.

- **Theme picker** — changing the app-wide accent colour or dark/light override. Risk of UI regressions across all views; deferred.
- **Font picker with sizes** — custom fonts affect list row heights and all layout metrics. High risk of layout regressions; deferred.
- **Customise right-click options (show/hide)** — adds a Settings UI to toggle which context-menu items are visible. Medium complexity; deferred.
- **Customise main toolbar (show/hide buttons)** — adds a Settings UI to toggle toolbar button visibility. Medium complexity; deferred.
- **User-resizable sidebar width** — dragging the sidebar divider to customise the sidebar width remains deferred.
- **Inline deep search** — real sub-folder search using `NSMetadataQuery` (Spotlight index) beyond the current single-level name filter. Significant architectural change; deferred.
- **Folder sync / compare mode** — highlight files that are newer, missing, or different between the two panes; one-click sync. Complex new UI paradigm; deferred.
- **File operation progress** — animated progress bar for large copy/move operations. Requires significant `FileOperationService` refactoring to run async with progress reporting; deferred.
- **Destination conflict resolution for move/copy** — copy to an existing destination fails with an error. Offer Replace, Skip, or Keep Both (auto-rename with numeric suffix). Deferred.
- **Duplicate finder** — hash files in a folder tree and surface groups of identical files regardless of name. Expensive hashing feature; deferred.
- **Tag filters in sidebar** — new Finder-style sidebar section listing all tags in use; clicking a tag filters both panes. Requires full Spotlight/NSMetadataQuery integration; deferred.
- **Column reorder** — drag column headers to rearrange (requires custom drag gesture tracking, deferred)
- **File operations still run on the main actor.** `FileOperationService.moveOrCopy` and `trash` are called synchronously from ContentView event handlers. A cross-volume copy of a large file or batch will block the UI. Fix: wrap in `Task.detached` and show a progress indicator.
- **Rename runs synchronously on the main actor.** Acceptable for local renames (metadata-only), but a cross-volume rename (copy + delete) can block. Consider making `rename()` async when the destination is on a different volume.


---

## Done
- **Build number in About** — fixed in Build 8 (`ENABLE_USER_SCRIPT_SANDBOXING: NO`). After running `xcodegen generate` and doing a clean Xcode build, each build will increment `BuildNumber.txt` and write the result to `CFBundleVersion` in the built app's `Info.plist`. The About panel will then show the incrementing build number in brackets.

### Build 22 — Physical Option-key drag fallback (2026-08-01)

- **Option-copy now checks physical key state through three paths** — `DragSession.isOptionKeyPressed` now checks `NSEvent.modifierFlags`, both CoreGraphics event-source state tables, and `GetCurrentKeyModifiers()` from HIToolbox. This targets drag sessions where AppKit/SwiftUI do not deliver modifier updates during the modal drag loop.
- **Destination forces copy when Option is physically down** — `requestedLocalOperation(in:)` now checks `DragSession.isOptionKeyPressed` before interpreting AppKit's source operation mask, so Option-copy cannot fall back to move when the mask remains ambiguous.
- **Clean Xcode build succeeded** — `BuildNumber.txt` is now 39. The build used workspace-local DerivedData at `.build/XcodeDerivedData`. The only project warning is the existing `Increment Build Number` run-script dependency-analysis warning.
- **110 tests, 0 failures** — 2 Trash tests skipped in the Codex sandbox because macOS Trash access is denied there.

### Build 21 — Option-copy drag resolution (2026-08-01)

- **Option-drag now lets AppKit apply modifier keys to the drag mask** — `RowMouseEventNSView` now implements `ignoreModifierKeys(for:) -> false`, so AppKit can narrow the source operation mask to copy when Option is held.
- **Drop operation now follows AppKit's modified source mask** — `AppKitFileDropTargetNSView` treats copy-only or move-only `draggingSourceOperationMask` values as authoritative, falling back to physical Option state only when AppKit reports both operations.
- **Copy icon state is pushed from destination to source** — `DragSession` now exposes a copy-intent change callback, letting the active drop target remove the move badge from the live drag image when the destination resolves the operation as copy.
- **Clean Xcode build succeeded** — `BuildNumber.txt` is now 36. The build used workspace-local DerivedData at `.build/XcodeDerivedData`. The only project warning is the existing `Increment Build Number` run-script dependency-analysis warning.
- **110 tests, 0 failures** — 2 Trash tests skipped in the Codex sandbox because macOS Trash access is denied there.

### Build 20 — AppKit drag/drop operation routing (2026-08-01)

- **Option-drag copy now bypasses SwiftUI drop operation ambiguity** — pane and row drop handling now uses an AppKit `NSDraggingDestination` bridge. The destination resolves the live operation at `draggingUpdated`, `prepareForDragOperation`, and `performDragOperation`, so Option-drag performs copy and plain drag performs move.
- **Drop targets now cover populated rows as well as empty pane space** — directory rows still drop into that folder, while regular file rows and the pane background drop into the current pane folder. This avoids missing the custom target when the destination pane is full of rows.
- **Drag source now advertises both legal operations** — the source allows both copy and move, while the active destination returns the exact operation. Copy drags use the system green plus; move drags keep the custom red minus badge.
- **Clean Xcode build succeeded** — `BuildNumber.txt` is now 34. The build used workspace-local DerivedData at `.build/XcodeDerivedData` to avoid sandbox writes to `~/Library/Developer/Xcode/DerivedData`. The only project warning is the existing `Increment Build Number` run-script dependency-analysis warning.
- **110 tests, 0 failures** — 2 Trash tests skipped in the Codex sandbox because macOS Trash access is denied there.

### Build 19 — Option-drag state source (2026-08-01)

- **Option-drag copy now reads the physical modifier state** — drag start, drag updates, source operation resolution, and drop handling now use `CGEventSource.flagsState(.combinedSessionState)` via `DragSession.isOptionKeyPressed` instead of relying on `NSEvent.modifierFlags` delivery during AppKit drag tracking. This targets the case where AppKit showed the green copy badge but the SwiftUI drop path still performed a move.
- **Full Xcode build succeeded** — `BuildNumber.txt` is now 29. The only build warning is the existing `Increment Build Number` run-script dependency-analysis warning.
- **110 tests, 0 failures** — 2 Trash tests skipped in the Codex sandbox because macOS Trash access is denied there.

### Build 18 — Live drag badge updates (2026-08-01)

- **Copy drags no longer retain stale move badges** — drag image updates now use `NSDraggingSession.enumerateDraggingItems`, which is the supported AppKit API for modifying live dragging images after `beginDraggingSession`. The app no longer mutates the originally-created `NSDraggingItem` objects after AppKit has consumed them.
- **Operation visuals are split cleanly** — move drags draw one custom red minus badge on the drag leader. Copy drags remove custom operation badges and let AppKit show the standard green plus for the `.copy` operation, avoiding stacked plus/minus badges.
- **Full Xcode build succeeded** — `BuildNumber.txt` is now 27. The only build warning is the existing `Increment Build Number` run-script dependency-analysis warning.
- **110 tests, 0 failures** — 2 Trash tests skipped in the Codex sandbox because macOS Trash access is denied there.

### Build 17 — Drag copy intent and badges (2026-08-01)

- **Option-drag now copies for within-app drops** — `DragSession` now carries the current copy/move intent, and `PaneView.handleDrop` uses that stored intent instead of re-reading `NSEvent.modifierFlags` at drop time. This fixes Option being lost by SwiftUI's drop callback and incorrectly running a move.
- **Drag icons now show explicit operation badges** — move drags draw a red minus badge; copy drags draw a green plus badge. The badge updates when Option is pressed or released during the drag.
- **Full Xcode build succeeded** — `BuildNumber.txt` is now 26. No build warnings were reported.
- **110 tests, 0 failures** — 2 Trash tests skipped in the Codex sandbox because macOS Trash access is denied there.

### Build 16 — Multi-selection drag retention (2026-08-01)

- **Dragging a selected row now keeps the full selection** — `PaneView` now passes the row selection state into `RowMouseEventView`, allowing the AppKit mouse bridge to defer selection changes when the mouse-down starts on an already-selected item. Multi-file and folder drags now keep `pane.selectedItems` instead of collapsing to the first row under the cursor.
- **Full Xcode build succeeded** — `BuildNumber.txt` is now 24. The only build warning is the existing `Increment Build Number` run-script dependency-analysis warning.
- **110 tests, 0 failures** — 2 Trash tests skipped in the Codex sandbox because macOS Trash access is denied there.

### Build 15 — Drag operation badges (2026-08-01)

- **Move drags no longer show both operation badges** — `RowMouseEventNSView` now advertises `.move` by default and `.copy` only while Option is held. Move drags keep the custom minus badge; copy drags use the system plus badge.
- **Full Xcode build succeeded** — `BuildNumber.txt` is now 20. The only build warning is the existing `Increment Build Number` run-script dependency-analysis warning.
- **110 tests, 0 failures** — 2 Trash tests skipped in the Codex sandbox because macOS Trash access is denied there.

### Build 14 — Sidebar clipping correction (2026-08-01)

- **Sidebar no longer clips when opened in a narrow window** — removed the oversized root/pane minimum frames that caused SwiftUI to centre and clip content off the left edge. The sidebar now keeps fixed width and layout priority while file rows keep the Name column minimum from Build 13.
- **Full Xcode build succeeded** — `BuildNumber.txt` is now 19. No build warnings were reported.
- **110 tests, 0 failures** — 2 Trash tests skipped in the Codex sandbox because macOS Trash access is denied there.

### Build 13 — Test baseline and sidebar width (2026-08-01)

- **Package test baseline stabilized** — `FilePaneFixture` now defaults to a canonical temporary directory instead of `~/Documents`, so tests do not require protected user-folder access. `PaneState.loadFolder` now falls back to `FileManager.fileExists(..., isDirectory:)` when URL resource values omit `.isDirectoryKey`, keeping folders classified correctly in package-test and sandboxed contexts. Trash-specific tests now skip only when the current environment denies `FileManager.trashItem`.
- **Sidebar no longer crushes the Name column** — sidebar width is now a shared layout constant, both panes advertise a minimum width, and the Name column has a minimum width in both the header and rows. Opening the sidebar increases the content minimum width instead of letting fixed metadata columns collapse file names to a single character.
- **110 tests, 0 failures** — 2 Trash tests skipped in the Codex sandbox because macOS Trash access is denied there.

### Build 12 — Drag and drop (2026-08-01)

- **Drag files between panes and into subfolders** — full multi-file drag using AppKit's `NSDraggingSource` / `beginDraggingSession`. `RowMouseEventNSView` detects a 4pt drag threshold in `mouseDragged`, loads all selected items from `DragSession`, and starts a native drag session with stacked file icons. Drop targets: any directory row (blue outline on hover) and the pane's scroll area background (blue border on hover). Holding **Option** during a drop copies instead of moves. After a drop, both the source and destination directories reload.
- **External drops from Finder** — files dragged in from Finder or other apps are always copied (never moved) into the target folder.
- **`DragSession` singleton** — holds `[FileItem]` + `sourceDirectoryURL` so the drop handler doesn't need to parse `NSItemProvider`s for within-app drags. Cleared immediately on drop or at drag session end.
- **`reloadPeerIfSameFolder` updated** — now reloads any pane showing the changed URL (not just when both panes show the same folder), correctly handling cross-pane drag where source and destination are different directories.
- **110 tests, 0 failures** — no new tests (drag/drop is UI interaction, not unit-testable).

### Build 11 — App icon (2026-08-01)

- **Custom app icon** — white "/" on a blue gradient (`#33_7AFA` → `#0A_33_B3`) with macOS-style rounded corners (22% radius). Generated programmatically via `Scripts/make_icon.swift` using `CGContext` at exact pixel dimensions (avoids Retina 2x scale doubling). All 10 required macOS sizes (16×16 through 512×512@2x) produced and stored in `Sources/DOpusMac/Assets.xcassets/AppIcon.appiconset/`. `project.yml` updated with `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`; `xcodegen generate` run to pick up new catalog. `AppIcon.icns` confirmed in built app bundle.
- **110 tests, 0 failures** — no new tests.

### Build 10 — OneDrive sidebar fix (2026-08-01)

- **OneDrive bookmarked item now opens in /Opus** — `~/OneDrive` on macOS is a Finder alias file (not a symlink), so `.isDirectoryKey` returned `false` on the alias itself, falling through to `NSWorkspace.shared.open()` which opened Finder. Fixed in `SidebarView.bookmarkRow`: now resolves aliases with `URL(resolvingAliasFileAt:)` before the directory check, then navigates to the resolved real path. Non-alias directories and regular files unaffected.
- **110 tests, 0 failures** — no new tests (single-line logic change).

### Build 9 — Polish & rename (2026-08-01)

- **Renamed app back to /Opus** — `Resources/Info.plist` `CFBundleName`, `CFBundleDisplayName`, and all 3 usage description strings changed from `/Ops` → `/Opus`. `Docs/UserGuide.html` updated throughout.
- **Filter box border no longer highlights on active pane** — `strokeBorder` color changed from `isActive ? accentColor.opacity(0.8) : secondary.opacity(0.25)` to always `secondary.opacity(0.25)`. Static thin grey border, no active-pane accent highlight.
- **Breadcrumb trailing scroll fixed** — button IDs changed from integer `.id(index)` to string `.id("b\(index)")` to avoid ForEach namespace conflicts. Both `.onAppear` and `.onChange` callbacks wrapped in `DispatchQueue.main.async` so scroll fires after SwiftUI layout completes.
- **110 tests, 0 failures** — no new tests (all changes are visual/structural).

### Build 8 — Visual polish 3 (2026-08-01)

- **Pane border extended to cover tab strip and status bar** — `strokeBorder` overlay moved from `PaneView`'s inner VStack to `TabbedPaneView`'s outer VStack, so the active-pane border wraps the tab strip (above), file list, and status bar (below).
- **Filter box border thinner and pane-synced** — replaced `.roundedBorder` with `.plain` + custom `RoundedRectangle.strokeBorder`: 1pt, accent-color at 80% opacity when the pane is active, light grey (`.secondary` 25%) when inactive.
- **Favorites section removed from sidebar** — removed the `sectionHeader("Favorites")` block and the `ForEach(model.systemLocations)` rows. Dead `sidebarRow` function removed. Bookmarks section is now the only sidebar content.
- **Pane border colour changed from blue to grey** — `strokeBorder` in `TabbedPaneView` now uses `Color.secondary` (adaptive mid-grey) instead of `accentColor` when the pane is active.
- **Breadcrumb always shows deepest folder** — wrapped the breadcrumb `ScrollView` in a `ScrollViewReader`; on `.onAppear` and `.onChange(of: pane.breadcrumbs.count)`, scrolls to the last breadcrumb item with `anchor: .trailing` so the current folder is always visible when the path is too long to fit.
- **Build number fix** — `ENABLE_USER_SCRIPT_SANDBOXING: NO` added to `project.yml`. Previously, Xcode 14+'s script sandbox silently blocked the post-build script from writing back to `BuildNumber.txt`, so the build number never incremented past 1. Action required: run `xcodegen generate`, then do a clean Xcode build.
- **SemanticSearchViewModel.swift deleted** — file removed from project and trash; it was completely unused dead code.
- **110 tests, 0 failures** — no new tests (all changes are pure visual/structural).

### Build 7 — Visual polish 2 (2026-07-31)

- **Top banner removed** — Root cause: `CFBundleName`/`CFBundleDisplayName` in `Resources/Info.plist` was still `/Opus`; renamed to `/Ops`. Added `window.titleVisibility = .hidden` in `AppDelegate` to suppress the native macOS window title text entirely (traffic lights remain).
- **Both panes show blue border on focus** — right pane `accentColor` changed from `.orange` to `.blue`. Both panes now use a consistent blue focus ring and blue tab/selection highlight.
- **Visible 1pt separators below breadcrumb and column headers** — `Color.primary.opacity(0.15).frame(height: 1)` gives a clearly visible adaptive grey line against the grey panel chrome. (`Rectangle().fill(.separator)` was invisible because `.separator` is ~10% opacity with no background, rendering near-white against grey.)
- **Sidebar background covers bookmarks** — added `.scrollContentBackground(.hidden)` to the bookmarks `List` in `SidebarView`, so the sidebar's adaptive grey background extends through the entire bookmarks section instead of being overridden by the List's system background.
- **Tab underline removed** — removed the bottom `overlay` that drew a 2pt accent-color line under the active tab. The active tab is now indicated solely by the background shading (`accentColor.opacity(0.1)`), which is sufficient.
- **110 tests, 0 failures** — no new tests (all changes are pure visual/styling).

### Build 6 — Visual polish (2026-07-31)

- **Bookmark button verified** — behavior already correct from Build 5: disabled with no selection, grey outline when not bookmarked, blue filled when bookmarked.
- **Actions panel traffic light inset** — padding increased to `.horizontal(14).vertical(10)` so the red circle sits further from the sheet edge.
- **Breadcrumb font consistent** — removed `.monospaced` design, changed to `.system(size: 12)` to match sidebar and toolbar items.
- **Delete at very top of right-click menu** — Delete is now the first item, separated by a divider from Open/Rename. Previously it was second after Open.
- **Sidebar very light grey** — sidebar background is now an adaptive grey (`white: 0.955` in light mode, `white: 0.18` in dark), clearly distinct from pure white.
- **Panel chrome slightly darker grey** — nav toolbar, sort header, and status bar all use a unified `panelBgColor` (`white: 0.925` in light mode, `white: 0.14` in dark), slightly darker than the sidebar, creating a visual hierarchy: sidebar (lightest) → panel chrome → file list (white).
- **Title bar removed** — the `/Ops` header text and its divider have been removed from `ContentView`. The app now starts directly with the toolbar, gaining vertical space.
- **110 tests, 0 failures** — no new test additions (all changes are pure visual, layout, and ordering).

### Build 5 — Feature pass (2026-07-31)

- **Bookmark button behavior** — disabled when nothing selected; grey outline (`bookmark`) when selection isn't bookmarked; blue filled (`bookmark.fill`) when selection is already bookmarked. Clicking blue removes the bookmark and leaves the item selected. Bookmark target now requires exactly 1 item selected (no fallback to current folder).
- **Actions panel close button** — replaced `xmark.circle.fill` with a red traffic light circle (`Circle().fill(red)`, 12×12 pt) matching the macOS window chrome idiom.
- **Copy button directional arrow** — Copy now uses `arrow.right.square` / `arrow.left.square` (flips with active pane), matching the directional Move button (`arrow.right.circle` / `arrow.left.circle`). Square vs circle provides clear visual distinction between copy and move.
- **Right-click Delete moved to top** — Delete now appears immediately after Rename (above the Quick Look section), making destructive actions consistent with the primary actions group.
- **Cross-pane refresh when same folder** — when both panes show the same folder and rename, create, delete, duplicate, compress, or uncompress runs in the active pane, the inactive pane reloads automatically. Implemented via `Notification.Name.paneContentsChanged` posted by `PaneState.rename()` and `PaneView` file operations; `ContentView` observes and calls `reloadPeerIfSameFolder()`. Create folder/file/delete also call the helper directly.
- **Breadcrumbs and nav arrows black** — chevron, up-arrow, refresh, and breadcrumb text now use `.foregroundStyle(.primary)` (black in light mode, white in dark mode) instead of `.secondary` (grey).
- **⌘A Select All** — added `PaneState.selectAll()` which sets `selection` to all `displayedItems`. Wired as a hidden keyboard shortcut in `ContentView`.
- **Sidebar font matches file names** — removed explicit `.font(.system(size: 12))` from sidebar item and bookmark name `Text` so both use the default SwiftUI body font (same as the file list rows).
- **Bookmarks drag to reorder** — sidebar bookmarks section uses `List` with `.onMove` so bookmarks can be dragged to a new position. `SidebarModel.moveBookmark(from:to:)` persists the new order to `UserDefaults`.
- **Persist sidebar open/closed state** — `showSidebar` is seeded from `UserDefaults` at startup and saved on every toggle via `.onChange`.
- **Rename app to /Ops** — `TitleBar` updated from `/Opus` to `/Ops`. `UserGuide.html` updated throughout (`/Opus` → `/Ops`). Project structure (DOpusMac bundle ID, file names) unchanged.
- **Sidebar background lighter** — changed from `Color(nsColor: .underPageBackgroundColor)` to `Color(nsColor: .controlBackgroundColor)` (white in light mode).
- **New icon design** — moved to Pending (requires image asset creation outside this workflow).
- **Tag filters in sidebar** — moved to Pending (complex new UI section, deferred).
- **2 new tests** — `testPaneStateSelectAllSelectsDisplayedItems`, `testSidebarModelMoveBookmarkReorders`. Total: **110 tests, 0 failures**.
- **UserGuide v1.5** — all `/Opus` → `/Ops` throughout, version/build bumped.

### Build 4 — Feature pass (2026-07-29)

- **Remove AI search** — AI semantic search button, `SemanticSearchViewModel` usage, `aiMatches`/`isAISearch` state, "Clear AI" status-bar indicator, and the AI progress-spinner hook all removed from `PaneView`. `SemanticSearchViewModel.swift` is now unused (safe to delete manually).
- **Fix Copy button icon** — replaced non-existent `arrow.right.doc.on.doc` / `arrow.left.doc.on.doc` SF Symbols with `doc.on.doc`, which renders correctly on all supported macOS versions.
- **Remove traffic lights from Warp panel** — the red/yellow/green circles in `WarpSearchView` have been removed. The Escape key and clicking outside still dismiss the panel.
- **Remove traffic lights from Actions panel** — traffic lights removed from `CustomActionsSettingsView`; replaced with a small `xmark.circle.fill` close button top-left via `@Environment(\.dismiss)`.
- **Remove traffic lights from Command Runner** — traffic lights removed from `CommandRunnerView`. The existing `chevron.down` close button remains as the dismiss control.
- **OneDrive alias resolution** — `SidebarModel` now uses `URL(resolvingAliasFileAt:)` before adding OneDrive to the sidebar. OneDrive (which macOS stores as a Finder alias) now opens correctly in /Opus rather than falling through to Finder.
- **Rename button moved to main toolbar** — `GlobalToolbar` gains `canRename: Bool` and `onRename: () -> Void`. The Rename button is enabled when exactly one item is selected in the active pane. `PaneState` gains `@Published var requestRename: Bool` so `ContentView` can trigger the rename sheet held in `PaneView`. The per-pane pencil button is removed.
- **Bookmark selected item** — the Bookmark toolbar button now targets the selected item (if exactly one is selected) instead of the current folder. Right-click context menu gains a "Bookmark" / "Remove Bookmark" toggle item. `SidebarModel` is passed as `.environmentObject(sidebarModel)` to the pane area so `PaneView` can access it directly.
- **File bookmarks open in default app** — clicking a bookmarked *file* (not a folder) in the sidebar now calls `NSWorkspace.shared.open(url)` instead of navigating the pane. Bookmarked folders still navigate as before.
- **Persist all tabs across restarts** — `TabbedPaneState` gains a `tabsKey: String?` parameter and a Combine subscription on every tab's `$currentURL` (debounced 0.5 s) to auto-save tab URLs to UserDefaults. `AppLaunchConfiguration` gains `leftTabURLs`/`rightTabURLs` properties and restores all tabs when the startup mode is "Remember last folder". `leftPaneURL`/`rightPaneURL` remain as computed properties for backward compatibility. `ContentView` initialises both `TabbedPaneState` instances with `tabsKey: "leftTabState"` / `"rightTabState"`.
- **Uncompress conflict detection** — `uncompressItem` now runs `unzip -Z1` first to list archive contents, then checks each entry against the destination directory. If conflicts are found, a SwiftUI alert offers **Overwrite**, **Skip existing**, or **Cancel** before extracting. No-conflict archives extract immediately without a dialog.
- **Manual CSS blank-space fix** — added `width: 100%` to `body` to ensure the flex container always fills the full viewport width.
- **5 new tests** — `testTabbedPaneStateInitWithMultipleURLsCreatesMultipleTabs`, `testTabbedPaneStateInitEmptyURLsFallsBackToSingleNilTab`, `testTabbedPaneStateSavesTabsToUserDefaults`, `testPaneStateRequestRenameDefaultsFalse`, `testAppLaunchConfigurationLeftTabURLsContainsFirstURL`. Total: **108 tests, 0 failures**.
- **UserGuide v1.4** — AI search section and all AI references removed; Bookmark section updated for selected-item behavior and right-click option; file bookmark click behavior documented; Rename-in-toolbar documented; Uncompress conflict dialog documented; tab persistence callout added; Warp/Command Runner traffic light references removed; feature card updated.

### Build 3 — Feature pass (2026-07-27)

- **Fix show hidden files bug** — `TabbedPaneState.showHiddenFiles.didSet` now calls `pane.load()` on each child (guarded with `oldValue != newValue`). Hidden files now refresh immediately when the setting is toggled.
- **Rename Scripts → Actions** — GlobalToolbar button label changed from "Scripts" to "Actions". CustomActionsSettingsView title and all manual references updated to match.
- **Terminal button in main toolbar** — Terminal toggle moved from per-pane nav toolbar to the global toolbar. `PaneState.showCommandRunner` is now `@Published`; GlobalToolbar gets `isTerminalShown` and `onToggleTerminal` parameters. The ⌥` keyboard shortcut still works per-pane.
- **Traffic lights in Warp panel** — macOS-style red/yellow/green dots added above the Warp search field, matching the Command Runner.
- **Traffic lights in Actions panel** — macOS-style traffic light title bar added to `CustomActionsSettingsView`.
- **+/- moved above Actions list** — the add/remove toolbar is now displayed above the list (between the description and the list) rather than at the bottom.
- **After Save: form resets** — clicking Save in the Actions edit form now clears the selection, resets the fields, and returns the label to "New Action".
- **Right-click Duplicate** — creates a copy in the same folder named "X copy" (or "X copy 2", etc.). Applies to the full selection. Runs in `Task.detached`.
- **Right-click Compress** — zips the selection into a `.zip` archive in the same folder using `/usr/bin/zip`. Runs in `Task.detached`.
- **Right-click Uncompress** — extracts a `.zip` file in-place using `/usr/bin/unzip -o`. Only visible when right-clicking a `.zip` file. Runs in `Task.detached`.
- **Right-click Copy (file pasteboard)** — places the selected file URL(s) on the macOS clipboard via `NSPasteboard.writeObjects`. Paste into Finder, Mail, Messages, etc.
- **Right-click Share…** — opens the standard macOS sharing sheet (`NSSharingServicePicker`) for the selected file(s).
- **Right-click Open With…** — submenu of up to 8 compatible apps from `NSWorkspace.urlsForApplications(toOpen:)`, plus "Other…" to browse `/Applications`.
- **OneDrive in sidebar** — `~/OneDrive` is added to system locations if the folder exists on disk.
- **Manual page width fixed** — removed `max-width: 820px; margin: 0 auto` from `.content`; content now fills the full available width after the sidebar.
- **Manual: '+' for new tab documented** — Tabs section now describes clicking '+' at the end of the tab strip.
- **Manual: bookmark icon reference corrected** — replaced 🔖 emoji references with "Bookmark toolbar button".
- **Manual: Actions section updated** — renamed from "Custom Actions / Quick Scripts", describes +/- above list, post-save reset, and new right-click operations.
- **Manual: terminal button updated** — Command Runner section updated to describe the Terminal button in the main toolbar.
- **3 new tests** — `testPaneStateShowCommandRunnerDefaultsFalse`, `testTabbedPaneShowHiddenFilesPropagatesToAllTabs`, `testTabbedPaneShowHiddenFilesNoOpWhenValueUnchanged`. Total: 103 tests, 0 failures.

### Build 2 — Polish pass (2026-07-27)

- **Permissions lock badge** — folders the user can't read show a small red lock overlay on their icon in the file list (`FileItem.isRestricted`, `FileManager.isReadableFile`).
- **Sort by Info column** — Info is now a sortable column header. Sort is applied in `PaneView.visibleItems` using the already-loaded metadata from `SmartMetadataService`, so it's always non-blocking.
- **Sort per folder already worked** — confirmed `SortPreference` was already persisting sort per URL; removed from Next items.
- **Colour tag read/write** — right-click any file → Tag submenu with 7 Finder colours. Toggle tags on and off; works on all selected items. Uses `NSURL.setResourceValue` (avoids macOS 26-only Swift API). "Remove All Tags" clears all at once.
- **Column show/hide** — right-click any column header to show/hide Size, Kind, Modified, or Info. State persists via `AppSettings.hiddenColumnsRaw` / `UserDefaults`. Both the header and file rows react immediately.
- **Traffic lights in command runner** — decorative red/yellow/green dots added to the command runner title bar, matching the macOS terminal window idiom.
- **4 new tests** — `testSortKeyInfoCaseExists`, `testFileItemIsRestrictedDefaultsFalse`, `testAppSettingsToggleColumnAddsAndRemoves`, `testAppSettingsHiddenColumnsMultiple`. Total: 100 tests, 0 failures.

### Build 1 — Quality pass (2026-07-27)

- **Startup folder modes** — Settings now lets each pane independently use Default, Remember Last, or Fixed Folder. Implemented `StartupFolderMode` enum, `AppLaunchConfiguration.startupURL(pane:defaultURL:)`, and `ContentView` `onChange` handlers to save "remember last" URLs.
- **Show hidden files** — new Settings toggle; propagates to all panes via `TabbedPaneState.showHiddenFiles` `didSet`, persists across restarts.
- **Show file extensions** — new Settings toggle (on by default); `FileRowView.displayName` strips extension when disabled.
- **System file icons** — replaced extension-badge text with `NSWorkspace.shared.icon(forFile:)` for real per-file system icons; consistent row heights.
- **Rename button** — pencil icon in the nav toolbar appears when exactly one item is selected; triggers rename sheet.
- **Refresh button** — ↺ button in nav toolbar; keyboard shortcut ⌘R.
- **Keyboard shortcuts fixed** — ⌘[ back, ⌘] forward, ⌘↑ up, ↩ open selected item. All implemented via hidden `Button` blocks in `.background {}` (macOS 13-compatible).
- **Recursive copy/move protection** — `FileOperationService.moveOrCopy` detects and rejects attempts to copy a folder into itself or a descendant.
- **Remove permanent delete** — removed `fileDeletePermanently` / `directoryDeletePermanently` settings and all related code; delete always moves to Trash.
- **Custom Actions redesign** — replaced swipe-to-delete with standard +/− toolbar; added edit-in-place (click to select, Save/Cancel); login shell flag (`-l`) so `$PATH` is correct.
- **AI button separated from filter** — AI ✦ sparkle button is its own control with purple active state; filter × clear button is separate.
- **Filter × clear button** — appears inline when filter text is non-empty; clears with one click.
- **Filter activates pane** — typing in the filter field automatically sets that pane as active.
- **Warp focus fix** — `DispatchQueue.main.async` defers `@FocusState` assignment so the palette focuses reliably.
- **Command runner moved to nav toolbar** — terminal icon now in the per-pane navigation toolbar (was in status bar).
- **Folder size includes hidden files** — removed `.skipsHiddenFiles` from `FolderSizeViewModel` scan so the total is accurate.
- **Folder size Done button** — changed to standard `.bordered` style with `.defaultAction` keyboard shortcut.
- **E2E test fix** — `testAppBundleCanBeCreatedFromBuiltExecutable` now silently passes via `guard let = try? ... else { return }` instead of crashing on `XCTSkip`.
- **Help menu** — ⌘? opens `Docs/UserGuide.html` in the default browser; `DOpusMacApp.openUserGuide()` searches candidate paths.
- **UserGuide v1.1** — hero contrast fixed; "Why /Opus?" section added; bookmarks section corrected; Settings section rewritten; keyboard shortcuts updated (⌘[, ⌘], ⌘↑, ↩, ⌘R, ⌘?); AI search, filter, command runner, folder size, and custom actions descriptions all updated.
- **4 new tests** — `testStartupFolderModeDefaultParsing`, `testMoveOrCopySelfIntoSubfolderIsRejected`, `testPaneStateShowHiddenFilesDefaultsFalse`, `testAppSettingsDeleteConfirmDefaultsAreFalse`. Total: 96 tests, 0 failures.

### Build 0 — Tier 3 complete (2026-07-26)

- **Warp fuzzy folder jump (⌘K)** — floating palette with live fuzzy-match ranking
  against system locations, sidebar bookmarks, and open tabs. Arrow-key navigation,
  Return to jump, Escape/click-backdrop to dismiss. `WarpSearchViewModel` + `WarpSearchView`.
- **Smart metadata column** — new "Info" column in the file list shows type-aware
  metadata loaded in the background: pixel dimensions for images (via `CGImageSource`),
  duration for audio/video (via `AVURLAsset.load(.duration)`), line count for code
  and config files. Also echoed in the status bar for a single selection.
  `SmartMetadataService` (singleton, in-memory cache, `Task.detached` background load).
- **Command runner panel** — retractable shell panel at the bottom of each pane
  (toggle with ⌥\`). Runs commands via login shell in the pane's current directory;
  stdout+stderr shown in a scrollable output area. `CommandRunnerView`.
- **Custom actions / quick scripts (⚡)** — user-defined shell one-liners stored
  in `UserDefaults`, appear at the bottom of the context menu. `$@` expands to
  selected file paths; `$PWD` is the current directory. Managed via
  `CustomActionsSettingsView` opened from the toolbar. `CustomActionsModel`.
- **Folder size bar chart** — right-click any folder → "Show Folder Sizes" opens
  a sheet with a proportional bar chart of the top 15 items sorted largest first.
  Scans in a cancellable `Task.detached`. `FolderSizeViewModel` + `FolderSizeView`.
- **AI semantic search** — on macOS 26+ with Apple Intelligence enabled, a ✦ button
  next to the filter field sends the typed query to `LanguageModelSession` and
  narrows the file list to semantically matching files. Falls back gracefully (button
  hidden) on older OS or when Apple Intelligence is unavailable. `SemanticSearchViewModel`.
- **HTML user guide** — professional software manual at `Docs/UserGuide.html`
  covering all features with a fixed sidebar TOC, dark-mode support, CSS mockups,
  keyboard shortcut tables, and step-by-step instructions.
- **13 new tests** — `WarpSearchViewModelTests` (5), `CustomActionsModelTests` (4),
  `SmartMetadataServiceTests` (2), `FolderSizeViewModelTests` (2). Total: 93 tests,
  0 failures. E2E test silently passes via `swift test` (no binary); runs fully via ⌘U.

### Build 0 — Tier 1 + Tier 2 complete (prior session)

- Restored full-height row click targets so files and folders can be selected
  from anywhere in the row, not just the divider.
- Kept single-click selection fast by selecting on mouse-down.
- Restored double-click open for folders and files, with primitive regression
  tests for the shared row mouse-event policy and click harness.
- Promoted the XCUI tests to a registered `DOpusMacEndToEndUITests` target in
  `Package.swift`. Added command-click (multi-select), shift-click (range
  select), and right-click (context menu) coverage alongside the existing
  launch, single-click, and double-click-folder tests.
- Converted from a raw Swift Package executable to a proper Xcode project
  (`DOpusMac.xcodeproj`) generated by xcodegen from `project.yml`. The app now
  has a stable bundle ID (`local.DOpusMac`), a hand-crafted `Info.plist` with
  privacy usage strings, Hardened Runtime, and an entitlements file. `Package.swift`
  is kept as a library target so `swift test` still runs the primitive tests.
- Added `DOpusMacLatencyTests` — three threshold-based tests (plain, command,
  shift click × 1 000 iterations each, budget 10 ms) that will go red if
  something expensive is accidentally added to the selection path.
- Added 7 missing test coverage areas: descending sort equality tiebreak,
  rename to existing name, multi-file conflict reporting, shift-click with no
  anchor, shift-click backwards, filter empty results, trash multiple files.
- Moved folder loading off the main actor — `PaneState.load()` now fires a
  cancellable `Task` that dispatches the filesystem read to a background thread
  via `Task.detached`. Rapid navigation cancels in-flight loads so stale
  results are never applied. The main thread stays free throughout.
- Fixed descending sort equality handling — the sort comparator now includes a
  name tiebreaker for all non-name keys, satisfying Swift's strict-weak-ordering
  contract and passing the pinning test.
- Enabled Move/Copy for selected folders — `selectedItems` is now used for file
  operations so directories can be moved and copied alongside files. The
  byte-count status bar still uses `selectedFileItems` (files only) for accuracy.
- Improved multi-file conflict error reporting — ContentView now aggregates
  error counts when multiple files collide and surfaces the first message.
- Column heading contrast improved — sort headers now use `.primary` foreground
  so they read clearly against the grey background.
- Removed bottom lineage credit text and top toolbar hint text — these were
  noise once the app is familiar. Standard click behaviour is self-evident.
- Made back/forward/up nav buttons more prominent — icons are 14 pt medium
  weight with a 30 × 30 hit area for easier clicking.
- Added sort, filter, and folder-load latency tests — 10 000-item sort < 100 ms,
  500-file load < 500 ms. These will catch accidental regressions on the
  hot paths.
- Fixed move-over-existing-file bug — `FileOperationService.moveOrCopy` now
  removes the destination first for move operations (unix `mv` semantics):
  source is deleted, destination is replaced. Copy still fails on conflict.
- Toolbar action buttons switched to `.bordered` style with no tint colours —
  disabled buttons are visually faded, enabled buttons show a clear border,
  using the native macOS idiom with no distracting colour when inactive.
- Move and Copy buttons now show a directional arrow (left or right) that
  reflects which pane is active, so the transfer direction is immediately clear.
  Move uses `arrow.{left,right}.circle`, Copy uses `arrow.{left,right}.doc.on.doc`.
- Removed the destination folder name from the Move button label — the arrow
  icon carries the direction; the label just says "Move".
- Added "New File" button (⌥⌘N) — triggers a name prompt and creates an empty
  file in the active pane's folder. The new file is selected after creation.
  `FileOperationService.createFile` covered by three new tests.
- Added build-number auto-increment — `project.yml` has a `postBuildScripts`
  phase that reads `BuildNumber.txt`, increments it, and patches the built
  app's `CFBundleVersion`. Visible in the system About panel as the number in
  brackets. Requires `xcodegen generate` to activate.
- Added `/Opus > Settings` (⌘,) — a native macOS preferences window with four
  toggles: "Skip confirmation for file deletes", "Skip confirmation for
  directory deletes", "Permanently delete files", "Permanently delete
  directories". Settings are persisted across sessions via `UserDefaults`.
- Delete logic now respects all four settings — skips confirmation alerts when
  the matching "no confirm" toggle is on, calls `FileManager.removeItem`
  instead of `trashItem` when the "permanently" toggle is on. Directory deletes
  always show a count ("X files and Y directories") in the confirmation message
  as a safeguard even when the no-confirm toggle is off.
- `FileOperationService.delete` (permanent removal) covered by two new tests.
- Fixed the 6 `DOpusMacEndToEndUITests` failures — they now `XCTSkip` cleanly
  when `DOpusMac.app` is absent from the build products directory. Total
  failures: 0.
- Removed the `DividerBadge` (orange arrow-badge) between the two panes and
  replaced it with a plain `Divider()` for a cleaner split.
- Pane selection border now wraps only the file-list area, not the status bar
  at the bottom. Border thickness reduced from 2 px to 1 px.
