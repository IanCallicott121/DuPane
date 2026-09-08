# Agent Workflow

The standing process for a round of changes. Follow it in order; don't skip step 1.

---

## 1. Confirm no other agent is working

Two agents on this repo at once is how Build 377's stale `.xcodeproj` went unnoticed for
weeks. Before touching anything:

```sh
./Scripts/handoff-check.sh
```

Green is necessary but not sufficient — it reads the filesystem, not another agent's
session. Also check that the Xcode coding agent is idle (no spinner, input box empty) and
that nothing was committed in the last few minutes. If in doubt, ask before proceeding.

## 2. Analyse for bugs

Read `Docs/TODO.md` first so you report new findings rather than re-reporting known ones.
Re-verify open items against current `HEAD` — a previous build may have fixed or moved
them. Trace each candidate to specific lines and prove it is reachable before logging it.

### 2.1 Update TODO.md with bugs ordered by criticality

Log findings under `## Next items` in these sections, in this order:

```
### Bug fixes — Critical      data loss, corruption, crash
### Bug fixes — High          app-wide stall, silent wrong behaviour
### Bug fixes — Medium        wrong results, leaks, performance on hot paths
### Bug fixes — Low / Inconsistencies
```

Each entry: bolded symbol or summary, em-dash, the mechanism, a concrete failure
scenario, the suggested fix, and the file path in backticks at the end.

## 3. Write a failing unit test for each bug

One regression test per bug, in `Tests/DuPaneUITests/Build<N>BugTests.swift`. Write it to
**fail against current code** — a test that passes before the fix proves nothing.

Not every bug is unit-testable. View-layer bugs (SwiftUI `@State`, view identity, UI
affordances) need an e2e test or a refactor first. Say so plainly rather than writing a
test that exercises nothing.

## 4. Fix each bug

Follow `CLAUDE.md`: no comments unless the *why* is non-obvious, no dead code, no
backwards-compat shims, `@MainActor` on ViewModels, `Task.detached` for filesystem work.

## 5. Run all the unit tests again

Unit tests are **SPM-only** — `Tests/DuPaneUITests` is declared in `Package.swift` and is
not in the Xcode project. To run them in Xcode, open the **DuPane folder** (not the
`.xcodeproj`) to get the `DuPane-Package` scheme, then ⌘U. The `.xcodeproj` scheme runs
only the e2e UI tests.

From a terminal: `swift test --filter DuPaneUITests`.

Fix every failure before moving on. UI/e2e tests only on big changes.

## 6. Report status

Test counts, what was fixed, what wasn't, and what remains unverified. If a fix was
reasoned from source but never reproduced at runtime, say so — it matters.

## 7. Update the TODO

Move completed items into `## Done` under the new build number and today's date. Remove
them from `Next items`. Add anything newly discovered. Update the test count.

## 8. Commit, push, sync

One commit per fix so any can be reverted alone. End commit messages with the
`Co-Authored-By` / `Claude-Session` trailers.

Then push. A cloud (Cowork) session **cannot push** — it has no SSH keys — so it commits
locally and hands the push to you or to the Xcode agent, which runs as you and inherits
your SSH agent.

## 9. Hand off cleanly

```sh
./Scripts/handoff-check.sh
```

Must be green. Then: **if anything outside Xcode added or removed files, or rewrote
`project.yml` or `project.pbxproj`, quit and reopen Xcode.** It caches the project
structure and won't reliably re-read it, and there is no in-app indicator when that view
goes stale. Editing file *contents* outside Xcode is fine — those it does reload.

If `project.yml` changed, run `xcodegen generate` and rebuild before handing over.

## 10. Keep this file current

If the process changes, update this file in the same commit.

---

## Notes on the two agents

| | Claude Agent in Xcode | Cowork (cloud) |
|---|---|---|
| Toolchain | full — `swift test`, `xcodegen`, `git push` | none; cannot compile Swift |
| Test runs | seconds, real output | minutes, driven by clicking Xcode |
| Reads `.xcresult` | yes | no |
| Can push | yes | no |
| Blind spot | inherits Xcode's cached project state | can't see outside the connected folder |

Use the Xcode agent for the tight write-compile-test-push loop. Use Cowork for
investigation, cross-cutting audits, and work that should continue while you're away —
being *outside* Xcode is what let it spot the stale `pbxproj` and the iCloud codesign
failure that Xcode's own cached state was hiding.

**Never run both on this repo at the same time.**
