# DuPane — Claude Code Instructions

## Project overview
macOS dual-pane file manager built with SwiftUI. Sources live in `Sources/DuPane/`
(used by both Xcode via `project.yml`/XcodeGen and SPM tests via `Package.swift`).
`DuPane/DuPane/` in the Xcode project navigator maps to the same physical files.
Use the CLI workflow in `Docs/AGENT-WORKFLOW.md`; `project.yml` is the source of
truth for the generated Xcode project.

## After every session — always do these
- Update `Docs/TODO.md`:
  - Move completed items into the **Done** section with the build number and date.
  - Remove stale "Next items" that are now done.
  - Add any new issues discovered to **Next items**.
- Update `Docs/UserGuide.html` to reflect any UI or feature changes made this session
  (keyboard shortcuts, settings, new features, removed features, corrected descriptions).
- Save relevant memories (patterns, decisions, user preferences) using the memory system.

## Build & test workflow
- Verification: use the appropriate `./Scripts/verify-change.sh` lane from
  `Docs/AGENT-WORKFLOW.md`; documentation-only changes use `docs`.
- Tests: `swift test --filter DuPaneUITests` (SPM unit tests). All 336 tests pass; 0 failures.
  In Xcode, open the DuPane **folder** (not the .xcodeproj) to get the `DuPane-Package`
  scheme — ⌘U there runs the unit tests. The .xcodeproj scheme only runs the 14 e2e UI tests.
- E2E from a terminal: `./Scripts/run-e2e.sh` (14 tests). The wrapper writes
  `.test-results/DuPaneEndToEndUITests.log`.
- Fix all build errors before declaring work done.
- Bump the build number only for an implementation or release that needs a new visible
  number; documentation-only edits do not require a bump.

## Producing the runnable .app (and explicit build numbering)
- The `BuildProject` MCP tool / the open `.swiftpm/xcode` workspace build the
  **`DuPane-Package`** SPM scheme. That compiles the library + tests but does not
  produce `DuPane.app` and does not stamp `CFBundleVersion`.
- The real app comes from the xcodegen-generated `DuPane.xcodeproj` (`DuPane` scheme):
  `xcodebuild -project DuPane.xcodeproj -scheme DuPane -configuration Debug build`
  (regenerate first with `xcodegen generate` if `project.yml` changed).
- The read-only `postBuildScripts` "Stamp Build Number" phase stamps the value in
  `BuildNumber.txt`; builds never modify the repository. Run
  `./Scripts/bump-build-number.sh` once when a completed implementation or release needs
  a new number. Settings › About reads `CFBundleVersion`; `Docs/UserGuide.html` is hardcoded.
- Output goes to `SYMROOT = ~/Library/Developer/DuPane-build/<Config>/DuPane.app`
  (overridden in `project.yml` to stay out of iCloud), **not** DerivedData.
- Convenience symlink to the latest Debug build:
  `~/Applications/DuPane.app -> ~/Library/Developer/DuPane-build/Debug/DuPane.app`.
  Recreate with `ln -sfn <target> ~/Applications/DuPane.app` if it dangles. The `SYMROOT`
  path is stable (no hash), so it only breaks if that build dir is deleted.
- Builds are ad-hoc signed (`Signature=adhoc`, no Team). Fine on your own Macs; after
  copying to another Mac clear quarantine with
  `xattr -dr com.apple.quarantine /path/to/DuPane.app`.

## Post-build checklist — run after every build that completes a feature or fix
1. **Run the appropriate verification lane** from `Docs/AGENT-WORKFLOW.md`. Fix failures before proceeding.
2. **Update `Docs/UserGuide.html`** — reflect every UI or feature change: new/removed settings, changed keyboard shortcuts, corrected descriptions, new sections. Update the version string in the sidebar and footer only when the build number changes.
3. **Update `Docs/TODO.md`** — move every completed "Next items" entry into the **Done** section under the relevant build number and today's date; record documentation-only work separately. Remove the completed entries from "Next items". Add any new issues discovered during this build to "Next items".

## Code conventions
- No comments unless the WHY is non-obvious.
- No backwards-compat shims, no dead code left behind.
- `@MainActor` on ViewModels. `Task.detached` for filesystem/IO work.
- `onChange(of:perform:)` form (macOS 13-compatible). Avoid `onKeyPress` unless
  guarded with `#available(macOS 14.0, *)`.
- `@EnvironmentObject` for shared models such as `AppSettings` and `SidebarModel`.
- Singleton services (SmartMetadataService) observed via `@ObservedObject`.
- New tests for every non-trivial feature. No tests for pure UI layout changes.

## Architecture notes
- `TabbedPaneState` wraps multiple `PaneState` tabs; Combine forwards child
  `objectWillChange` to parent.
- `ContentView` owns `leftTabs`, `rightTabs`, `sidebarModel`, `duplicateFinderViewModel`
  and `fileOpProgress` as `@StateObject`.
- `PaneView` gets `settings` and `sidebarModel` via `@EnvironmentObject`.
- `SmartMetadataService.shared` loads metadata lazily in background tasks.
- `QuickLookCoordinator.shared` — class-level `@MainActor` removed to avoid
  ObjC protocol conflict with `QLPreviewPanelDataSource`.

## User preferences
- Quality over speed. No regressions. Performance matters on hot paths (selection, sort).
- Minimal tokens in responses — direct, no trailing summaries of what was just done.
- Always fix build errors before reporting completion.
- The app targets macOS 13+ but runs on macOS 26 (developer machine).
