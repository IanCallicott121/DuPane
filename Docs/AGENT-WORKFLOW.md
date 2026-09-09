# Agent Workflow

This workflow covers bugs, requested changes, enhancements, documentation, and
infrastructure. Quality gates are proportional to risk so small changes remain fast.

## Start once

Read `CLAUDE.md`, this file, and the relevant TODO section once, then acquire the lock:

```sh
./Scripts/workflow-start.sh acquire <agent-or-task>
```

It rejects an iCloud checkout, verifies Git/project state, and prevents concurrent edits.
A filesystem lock replaces visual polling of Xcode or another agent. Do not repeatedly
reread instructions or rerun preflight during one logical batch.

## Scope and inner loop

Re-verify the TODO item against current `HEAD`. For a bug, prove reachability and define
a regression test. For a requested change or enhancement, define acceptance criteria.
Documentation and operational work can use targeted inspection. Batch related edits into
one verification cycle.

During implementation run the smallest relevant test. Preserve build caches. Use a clean
build only for build-system diagnosis, release validation, or an explicit benchmark.

## Verification lanes

| Lane | Use for | Final gate |
|---|---|---|
| `docs` | Markdown/HTML text, plans, comments | diff validation |
| `logic` | Models, algorithms, isolated refactors | unit + app build |
| `service` | Filesystem, persistence, processes, concurrency | unit + app build |
| `ui` | SwiftUI or cross-process behavior | unit + app build + e2e |
| `project` | XcodeGen, targets, resources, dependencies | regenerate + unit + build + e2e |
| `release` | Release candidate or requested full gate | unit + build + e2e |

```sh
./Scripts/verify-change.sh docs
./Scripts/verify-change.sh logic --filter SidebarModelRecentsTests
./Scripts/verify-change.sh release --clean
./Scripts/run-e2e.sh --only testMethodName
```

The final command reports per-stage and total timing. E2E remains mandatory where listed,
but is not a tax on docs or isolated logic.

## Implementation

Follow `CLAUDE.md`. Make a focused test fail for the expected reason before a behavioral
fix when practical. Run `xcodegen generate` once after `project.yml` changes. Prefer CLI
builds/tests; Xcode may remain open but must not concurrently edit this checkout.

If coordination takes more than about three minutes, stop polling and state the exact
owner, command, or permission blocking progress. Request narrowly scoped reusable command
approval when a required build tool writes outside the sandbox.

## Version, docs, and finish

Builds read and stamp `BuildNumber.txt` but never change it. Run
`./Scripts/bump-build-number.sh` once before final verification only when an
implementation/release needs a new visible number. Pure docs/workflow changes do not.

Update TODO for completed/new work and verified counts. Update the user guide only for
user-visible behavior or a deliberate number change. Inspect the diff, commit logical
changes, push, then:

```sh
./Scripts/workflow-start.sh release
./Scripts/handoff-check.sh --finish
```

Reopen Xcode if files were added/removed or the generated project changed.

Codex desktop actions can expose these scripts in the toolbar. Create them through the
project's local-environment settings so Codex generates supported `.codex` configuration;
do not hand-author an undocumented format.
