# DuPane repository instructions

Read `CLAUDE.md` and `Docs/AGENT-WORKFLOW.md` completely before changing the repository.
Those files are authoritative for architecture, conventions, tests, documentation, and
handoff requirements.

Before editing, run `./Scripts/handoff-check.sh`, inspect `git status`, and preserve all
existing work. Do not work concurrently with another coding agent in this checkout.

For bug fixes, re-verify the relevant `Docs/TODO.md` entry, add a regression test in
`Tests/DuPaneUITests/Build<N>BugTests.swift`, implement the smallest complete fix, then run:

```sh
swift test --filter DuPaneUITests
```

Use `project.yml` as the Xcode project source of truth. If it changes, run
`xcodegen generate` and rebuild. Run the Xcode UI-test scheme for user-visible or
cross-process changes.

Before handoff, update `BuildNumber.txt`, `Docs/TODO.md`, and `Docs/UserGuide.html` as
required by the repository workflow, commit and push completed work, and run
`./Scripts/handoff-check.sh` again. If files were added or removed outside Xcode, tell the
user to reopen Xcode so its project view refreshes.
