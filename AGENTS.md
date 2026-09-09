# DuPane repository instructions

Read `CLAUDE.md` and `Docs/AGENT-WORKFLOW.md` once at the start of a task. They are
authoritative for architecture, conventions, verification, documentation, and handoff.

Before editing, acquire the checkout lock with `./Scripts/workflow-start.sh acquire
<agent-or-task>`. Do not edit this checkout if another owner holds the lock.

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
`./Scripts/bump-build-number.sh` only when required. Commit and push, release the lock,
then run `./Scripts/handoff-check.sh --finish`. Reopen Xcode after structural project
changes; content-only edits reload normally.
