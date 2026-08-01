# /Opus — Claude Code Instructions

## Project overview
macOS dual-pane file manager built with SwiftUI. Sources live in `Sources/DOpusMac/`
(used by both Xcode via `project.yml`/XcodeGen and SPM tests via `Package.swift`).
`DOpusMac/DOpusMac/` in the Xcode project navigator maps to the same physical files.
Use `XcodeWrite` / `XcodeRead` MCP tools — they resolve paths correctly and keep the
Xcode project in sync.

## After every session — always do these
- Update `Docs/TODO.md`:
  - Move completed items into the **Done** section with the build number and date.
  - Remove stale "Next items" that are now done.
  - Add any new issues discovered to **Next items**.
- Update `Docs/UserGuide.html` to reflect any UI or feature changes made this session
  (keyboard shortcuts, settings, new features, removed features, corrected descriptions).
- Save relevant memories (patterns, decisions, user preferences) using the memory system.

## Build & test workflow
- Build: use `BuildProject` MCP tool targeting `DOpusMac`.
- Tests: `swift test --filter DOpusMacUITests` (SPM unit tests). All 100 tests pass; 0 failures.
- Fix all build errors before declaring work done.
- update the build number in settings > about and in the user manual

## Post-build checklist — run after every build that completes a feature or fix
1. **Run all tests** — `swift test --filter DOpusMacUITests`. All tests must pass, including any new ones written for this build. Fix failures before proceeding.
2. **Update `Docs/UserGuide.html`** — reflect every UI or feature change: new/removed settings, changed keyboard shortcuts, corrected descriptions, new sections. Bump the version string in the sidebar and footer.
3. **Update `Docs/TODO.md`** — move every completed "Next items" entry into the **Done** section under the new build number and today's date. Remove the completed entries from "Next items". Add any new issues discovered during this build to "Next items".

## Code conventions
- No comments unless the WHY is non-obvious.
- No backwards-compat shims, no dead code left behind.
- `@MainActor` on ViewModels. `Task.detached` for filesystem/IO work.
- `onChange(of:perform:)` form (macOS 13-compatible). Avoid `onKeyPress` unless
  guarded with `#available(macOS 14.0, *)`.
- EnvironmentObject for app-wide shared models (CustomActionsModel, etc.).
- Singleton services (SmartMetadataService) observed via `@ObservedObject`.
- New tests for every non-trivial feature. No tests for pure UI layout changes.

## Architecture notes
- `TabbedPaneState` wraps multiple `PaneState` tabs; Combine forwards child
  `objectWillChange` to parent.
- `ContentView` owns `leftTabs`, `rightTabs`, `sidebarModel`, `warpViewModel`,
  `customActionsModel` as `@StateObject`.
- `PaneView` gets `customActionsModel` via `@EnvironmentObject`.
- `SmartMetadataService.shared` loads metadata lazily in background tasks.
- `QuickLookCoordinator.shared` — class-level `@MainActor` removed to avoid
  ObjC protocol conflict with `QLPreviewPanelDataSource`.
- AI search: `SemanticSearchViewModel` uses `#if canImport(FoundationModels)` guards
  so it compiles on all SDK versions; `@available(macOS 26.0, *)` guards runtime use.

## User preferences
- Quality over speed. No regressions. Performance matters on hot paths (selection, sort).
- Minimal tokens in responses — direct, no trailing summaries of what was just done.
- Always fix build errors before reporting completion.
- The app targets macOS 13+ but runs on macOS 26 (developer machine).
