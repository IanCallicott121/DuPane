# DuPane repository instructions

At the start of a task, read `AGENTS.md` and the relevant TODO section once.

For bugs, re-verify the relevant TODO item, add a regression test, and implement the
smallest complete fix. Run the smallest relevant test during iteration, then the
appropriate final verification lane, for example:

```sh
./Scripts/verify-change.sh logic --filter SidebarModelRecentsTests
```

Use `project.yml` as the Xcode source of truth. Use CLI builds and risk-based verification;
opening or polling Xcode is not part of the workflow. E2E is required for UI,
cross-process, project, and release changes, or when explicitly requested.

Builds never change `BuildNumber.txt`. Bump it explicitly with
`./Scripts/bump-build-number.sh` only when required. Reopen Xcode after structural
project changes; content-only edits reload normally.

## Collaboration guidelines

- Work in small, turn-based steps.
- After each step, give concise feedback and ask only the next necessary question.
- Wait for the user's decision before expanding the work or making the next substantive change.
- Do not reuse superseded plans unless the user explicitly requests it.
- Keep responses concise and omit internal reasoning.
- Number questions so the user can refer to them directly.
- Use lettered choices only for true alternatives; use bullets for non-alternative lists.

## Scope and inner loop

- Re-verify TODO items against current code.
- For bugs, prove reachability and define a regression test.
- For requested changes or enhancements, define acceptance criteria.
- Use targeted inspection for documentation and operational work.
- Batch related edits into one verification cycle.

## Verification lanes

- `docs` — Markdown, HTML, plans, and comments.
- `logic` — models and algorithms.
- `service` — filesystem, persistence, and concurrency.
- `ui` — SwiftUI and cross-process behavior, including E2E.
- `project` — XcodeGen, targets, resources, and dependencies.
- `release` — full validation.

Use the corresponding `./Scripts/verify-change.sh` lane. Report actual test results when
tests are run; do not preserve fixed expected test counts in guidance.

## Implementation

- Make a focused test fail before a behavioral fix when practical.
- Run `xcodegen generate` after `project.yml` changes.
- Prefer CLI builds and tests.
- Reopen Xcode after structural project changes.

## Version and finish

- Inspect the diff before handoff.
- Commit when appropriate.
- Ask before pushing changes.
- Update TODO only when project or documentation status changes.
- Update the User Guide only for user-visible changes.

## Project overview

DuPane is a macOS dual-pane file manager built with SwiftUI. Sources live in
`Sources/DuPane/`, which is used by both Xcode via `project.yml`/XcodeGen and SPM tests
via `Package.swift`. `project.yml` is the source of truth for the generated Xcode project.

## Session updates

- Update `Docs/TODO.md` when project or documentation work changes its status.
- Update `Docs/UserGuide.html` when user-visible behavior or documentation changes.

## Build and test

- Use the appropriate verification lane described in this file; documentation-only changes use `docs`.
- Unit tests: `swift test --filter DuPaneUITests`.
- E2E tests: `./Scripts/run-e2e.sh`.
- Report the actual test result when tests are run; do not preserve fixed expected test counts in guidance.
- Fix known build errors before reporting completion.
- Bump the build number only for implementation or release work that needs a new visible number.

## Application builds

- SPM builds compile the library and tests but do not produce the runnable `DuPane.app`.
- Build the app with `xcodebuild -project DuPane.xcodeproj -scheme DuPane -configuration Debug build`.
- Run `xcodegen generate` first when `project.yml` changes.
- Application build output uses the external `SYMROOT` configured in `project.yml`.
- The convenience symlink is `~/Applications/DuPane.app` to the latest Debug build.

## Post-build checklist

- Run the appropriate verification lane after an implementation build.
- Update the User Guide only for user-visible changes.
- Update TODO only when project or documentation status changes.

## Code conventions

- No comments unless the WHY is non-obvious.
- No backwards-compatibility shims or dead code.
- Put `@MainActor` on ViewModels.
- Use `Task.detached` for filesystem and I/O work.
- Use the `onChange(of:perform:)` form for macOS 13 compatibility.
- Avoid `onKeyPress` unless guarded with `#available(macOS 14.0, *)`.
- Use `@EnvironmentObject` for shared models such as `AppSettings` and `SidebarModel`.
- Observe the shared `SmartMetadataService` singleton with `@ObservedObject`.
- Add tests for every non-trivial feature; do not add tests for pure UI layout changes.

## Architecture notes

- `TabbedPaneState` wraps multiple `PaneState` tabs, and Combine forwards child `objectWillChange` to the parent.
- `ContentView` owns `leftTabs`, `rightTabs`, `sidebarModel`, `duplicateFinderViewModel`, and `fileOpProgress` as `@StateObject`.
- `PaneView` receives `settings` and `sidebarModel` through `@EnvironmentObject`.
- `SmartMetadataService.shared` loads metadata lazily in background tasks.
- `QuickLookCoordinator.shared` is not class-level `@MainActor` because that conflicts with the Objective-C `QLPreviewPanelDataSource` protocol.

## User preferences

- Quality over speed. No regressions. Performance matters on hot paths such as selection and sorting.
- Minimal tokens in responses; be direct and avoid trailing summaries.
- Always fix build errors before reporting completion.
- The app targets macOS 13+ and runs on macOS 26 on the developer machine.
