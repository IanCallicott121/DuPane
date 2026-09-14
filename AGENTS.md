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
- Number every implemented item in implementation summaries so the user can refer to it
  unambiguously.

Use standard Codex file-editing and version-control practices; do not require a
repository-wide checkout lock or block changes because unrelated files are modified.

## Scope and inner loop

- Re-verify TODO items against current code.
- Treat `Docs/TODO.md`'s `Action Items` as active, authorized work candidates.
- Treat `Pending items` as deferred discussion or decisions; do not implement them
  unless the user explicitly authorizes the work.
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
- Interim E2E runs may use `./Scripts/run-e2e.sh --priority high`; use `--priority medium`
  to include medium-priority coverage. Final verification runs the full suite with no
  priority filter.
- `./Scripts/run-e2e.sh --negative-validation` intentionally fails otherwise-passing
  tests and succeeds only when every emitted result is `FAIL`; missing, `PASS`, or
  `SKIP` results fail the validation.
- Report the actual test result when tests are run; do not preserve fixed expected test counts in guidance.
- E2E result logging must fail closed: XCTest failures and unexpected exceptions must not
  be emitted or accepted as `PASS`, and the wrapper must reject any emitted `FAIL` result.
- Fix known build errors before reporting completion.
- Bump the build number only for implementation or release work that needs a new visible number.
- Before every build used for manual testing, increment the temporary internal test build marker to a new unique value, include that value in the app menu and its verification test, and never reuse a marker from an earlier build.
- After every such build, report the verification results first and then give the user the exact temporary internal test build marker. The marker must be visible in the app menu, and the handoff must instruct the user to confirm that menu value before testing.
- A manual-test handoff is incomplete until the final verified app build contains the
  visible menu marker and the exact marker has been reported to the user.
- Keep the marker in place while manual testing and review are in progress. Remove it only after the user approves the completed change for commit; do not change `BuildNumber.txt` for this purpose.
- A source change is not present in the running app until it is rebuilt. Use `./Scripts/prepare-manual-build.sh` for manual-test builds; do not use `ln -sfn` to refresh the app symlink because directory symlinks may remain stale. The script clean-builds into external DerivedData, safely replaces the symlink, and verifies the target and timestamps.
- Before manual testing, quit any running instance, relaunch `~/Applications/DuPane.app`, and confirm the quoted internal test marker.

## Application builds

- SPM builds compile the library and tests but do not produce the runnable `DuPane.app`.
- Build the app with `xcodebuild -project DuPane.xcodeproj -scheme DuPane -configuration Debug build`.
- Run `xcodegen generate` first when `project.yml` changes.
- Verification builds use external DerivedData at `~/Library/Developer/DuPane-build`.
- The convenience symlink is `~/Applications/DuPane.app` to the latest Debug build.
- The final pre-handoff test is `swift test --filter DuPaneFunctionTests/testInstalledAppSymlinkDateMatchesLatestDebugBuild`; it must pass after the manual build script and before reporting the marker.

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
