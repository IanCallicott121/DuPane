# DuPane — TODO


## Handover — next agent starts here

**State:** Build 420. Unit suite **336 passed, 0 failed**. E2E suite **14 passed, 0
failed** — re-run 2026-09-09 at Build 420 (`f64ef4e`) through `./Scripts/run-e2e.sh`,
with a current machine-readable PASS log.

### How to run the tests
- **Unit (336):** open the **DuPane folder** (not the `.xcodeproj`) for the
  `DuPane-Package` scheme, then ⌘U. Or `swift test --filter DuPaneUITests`.
- **E2E (14):** `./Scripts/run-e2e.sh`, or open **`DuPane.xcodeproj`** and press ⌘U.
- **Shell-readable e2e results** — the wrapper extracts `TestResultLog` marker lines into
  `.test-results/DuPaneEndToEndUITests.log` (gitignored): `PASS`/`SKIP`/`FAIL <name> ::
  <issue>`. The wrapper is required because the UI-test sandbox cannot write directly to
  the checkout.
- `./Scripts/handoff-check.sh` before and after. `Docs/AGENT-WORKFLOW.md` has the process.
- **Fast workflow:** use `./Scripts/verify-change.sh docs` for text-only edits; choose
  `logic`, `service`, `ui`, `project`, or `release` for code and build changes.

### Remaining work
No confirmed outstanding bugs remain in this list. Continue auditing before assuming the
repository is defect-free.

### Change of direction — read before resuming (2026-09-09)

**Bobby: you have in-flight uncommitted work in the tree** (`BuildNumber.txt`,
`Docs/UserGuide.html`, `Sources/DuPane/Models/SidebarModel.swift`). Ian has decided a
change of direction and **you can back those changes out** — nothing was wrong with them,
they are simply overtaken. Keep anything you judge still useful; discard the rest. Your
call on the mechanics; nobody else will touch your working tree.

**What changed:** the two-edition plan (Direct + Mac App Store) is **dropped**. DuPane
ships as **one sandboxed free App Store app**. The unrestricted build is preserved as the
**v1.0.0 tag**, not as a second product. Full background, the reasoning behind the
decision, and the phased action list are under **Next items → Distribution — single free
Mac App Store edition**. Start with Phase 0; it is blocking.


## Next items

### Enhancements

#### Distribution — single free Mac App Store edition

**Status: decided. This is not a proposal and it is not open for re-litigation.** Ian has
made this decision. Work through the phases below in order. If any phase produces evidence
that contradicts the plan, record the evidence and raise it — but do not substitute a
different approach on your own initiative.

##### Background — why this replaces the two-edition plan

Read this before touching anything; the previous plan in this file said something else.

- **What was previously planned.** An earlier revision of this section (see git history,
  commit `f9e3872`) described **two editions built from one codebase**: `DuPane-Direct`
  (unsandboxed, full feature set, Developer ID signed, notarized DMG, possibly Sparkle)
  and `DuPane-MAS` (sandboxed, reduced), separated by `DIRECT_BUILD` / `MAS_BUILD`
  compile-time conditions, with per-edition Info.plist, entitlements, bundle IDs, schemes
  and release channels. It ran to eleven dependency-ordered work packets, WP0–WP10.
- **That approach has been dropped.** Reasons of record:
  - It doubles the *permanent* cost of the project — two targets, two signing paths, two
    release channels, two support streams, an edition tag on every bug report, doubled CI
    time, and every future bug fix verified in two configurations — for an app that is 36
    Swift files and roughly 9,100 lines.
  - It ordered the work backwards. The genuinely unknown question — whether a sandboxed
    DuPane is still a usable file manager — sat in WP7, *behind* a from-scratch ZIP
    reimplementation (WP4) and a from-scratch security-scoped access layer (WP5/WP6). A
    negative answer in WP7 would have wasted all of it.
  - "Keep Direct as it is" was never free. The repository has no Developer ID signing and
    no notarization today (`project.yml` uses `CODE_SIGN_STYLE: Automatic` with no
    distribution identity), so the Direct edition would have needed its own new signing,
    notarization, stapling, Gatekeeper and DMG pipeline before it could be given to
    anyone.
- **What replaces it: one app, sandboxed, free on the Mac App Store.** One target, one
  bundle ID, one product, one release channel. No Direct edition, no DMG, no Developer ID,
  no notarization pipeline, no Sparkle, no edition flags, no per-edition Info.plist or
  entitlements files, no capability matrix, no runtime edition switch.
- **The unrestricted build is preserved as source, not as a second product.** Before any
  sandboxing work begins, `main` is tagged and published as **v1.0** — the last stable
  fully-capable unsandboxed build. Anyone who wants unrestricted DuPane, Ian included,
  clones that tag and builds it locally in an unrestricted environment. This is why Phase 0
  is first and blocking: once sandboxing lands, that build only exists as a tag.
- **Objective.** Ship DuPane free on the Mac App Store with the largest feature set the
  sandbox genuinely allows, without maintaining a second edition. The goal is distribution,
  discovery and installation without Gatekeeper friction. There is **no revenue model**:
  free, no IAP, no subscription, no trial, no receipt check, no license gate. Store
  receipts must never control capabilities.

**Do not restart the two-edition work.** If you find yourself adding a build flag to keep a
feature "for the Direct build", stop — there is no Direct build. Cut the feature, or prove
it works sandboxed.

##### Phase 0 — release and tag v1.0 first. Blocking; nothing else starts until this is done

1. Bring `main` to a clean, green state: `./Scripts/handoff-check.sh` with zero blocking
   issues, full unit suite and e2e suite passing, working tree clean, in sync with
   `origin/main`.
2. Confirm `MARKETING_VERSION` is `1.0` in `project.yml` and record the current
   `BuildNumber.txt` value in the release notes.
3. Tag the commit `v1.0.0` (annotated, not lightweight) with a message stating this is the
   final unsandboxed, fully-capable build, and push the tag.
4. Create a **GitHub Release** from that tag. In the release notes, state plainly:
   - This is the last release with Command Runner, Terminal integration, `.sh` execution,
     volume eject and unrestricted whole-disk browsing.
   - It is source-only — build locally with Xcode to run it unrestricted.
   - Subsequent releases are App Store builds and are sandboxed.
5. Only source is released. Do **not** attach a built `.app`, `.zip` or `.dmg` — the app is
   not signed for distribution and shipping an unsigned binary is not on the plan.
6. Record the tag and release URL in this file under Done.

##### Phase 1 — sandbox feasibility spike. Throwaway branch, target ~2 days

Purpose: establish what actually survives the sandbox *before* any production refactor.
This branch is deleted afterwards. Do not refactor, do not introduce protocols, do not
build anything reusable.

Setup (target: half a day):

- Branch `spike/sandbox` off the v1.0.0 tag.
- `Resources/DuPane.entitlements`: set `com.apple.security.app-sandbox` to `true` and add
  `com.apple.security.files.user-selected.read-write` and
  `com.apple.security.files.bookmarks.app-scope`. Add nothing else — no network, no
  temporary exceptions, no iCloud container entitlements.
- Add one crude "Grant Folder…" button anywhere convenient that runs `NSOpenPanel`, stores
  the resulting `.withSecurityScope` bookmark data in `UserDefaults`, and resolves it at
  launch.
- Wrap the pane directory load in balanced
  `startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()`.
- Sign with an Apple Development identity, build **Release**, and **launch the built `.app`
  by double-clicking it**. Running from Xcode inherits debugger privileges and will produce
  false passes on almost every check below. Test in a normal user session, with Full Disk
  Access **off**.

Then grant it `~/Documents` and one external drive and work down this table. Record OS
version, signing identity, effective entitlements, steps and actual result for each row.

| # | Check | Pass criterion |
|---|---|---|
| 1 | Quick Look a granted file | Panel opens, arrow-keys between selection, closes without leaking access |
| 2 | Drag a file **from Finder** into a pane | Copy/move completes correctly |
| 3 | Drag **out** to Finder, and between panes | Same |
| 4 | Reveal in Finder | Correct file selected |
| 5 | Open With, and double-click a `.app` | Opens in the expected app |
| 6 | Read and write a Finder tag | Tag visible in Finder afterwards |
| 7 | Global Tags sidebar | Populates across the disk — **expected to fail**, the query uses `NSMetadataQueryIndexedLocalComputerScope` |
| 8 | Deep / Spotlight search inside a granted folder | Returns results |
| 9 | Browse an already-mounted SMB share | Grant `/Volumes/<share>`, list and copy files |
| 10 | `smb://` Connect to Server | Finder mounts it; share can then be granted |
| 11 | Bonjour discovery (`_smb._tcp`, `_afpovertcp._tcp`) | Servers appear after the local-network prompt |
| 12 | Trash a file, then undo | File returns to its original parent folder |
| 13 | External drive after granting it | Full read and write |
| 14 | Relaunch the app | Stored bookmarks still resolve; granted folders still accessible |

Write the results to `Docs/SandboxSpikeResults.md` — one row per check, with actual
observed behaviour, not expectations. That file is the evidence base for every later
decision in this section, and it is the deliverable of this phase. Then delete the branch.

##### Phase 2 — go/no-go against the spike results

Assess against the recorded evidence, not against expectations.

- **Stop and escalate to Ian if** check 2 or 3 (Finder drag) fails, or check 12
  (trash/undo) cannot be made safe. Without Finder drag-and-drop or a trustworthy undo,
  a sandboxed DuPane is not the app it set out to be, and the App Store plan should be
  reconsidered rather than pushed through.
- **Any other single failure narrows that one feature** and the plan continues. Move the
  affected feature into the dropped list in Phase 3 and update this section.
- A capability that could not be tested — no server available, no suitable hardware — is
  recorded as **unverified**, not as a failure and not as a pass. Unverified capabilities
  block submission until tested.
- Once Phase 2 is signed off, update this section so the Phase 3/4/5 lists reflect the
  actual evidence, and note in Done what changed.

##### Phase 3 — features to remove

These are cut unconditionally. Remove the code, the UI, the menu items, the keyboard
shortcuts, the settings keys, the tests and the documentation. Do not gate them behind a
flag; do not leave them reachable from saved state or the keyboard.

| Feature | Where it lives |
|---|---|
| Command Runner panel | `Views/CommandRunnerView.swift`; `showCommandRunner` in `ViewModels/`; toolbar button in `Views/GlobalToolbar.swift` (~L11, L28, L126–128); wiring in `Views/ContentView.swift` (~L371, L388) |
| Open in Terminal — pane | `Views/PaneView.swift` (~L1005–1007, `/usr/bin/open -a Terminal`) |
| Open in Terminal — sidebar | `Views/SidebarView.swift` (~L270–272) |
| Executing `.sh` files | The open/launch path in `Views/PaneView.swift`; MAS must not fall through to execution via a generic-open handler |
| Eject volumes (external and network) | `Models/NetworkVolumeMonitor.swift` — `ejectExternal` (~L118) and `NSWorkspace.shared.unmountAndEjectDevice` (~L38–41). Keep mount/unmount **notifications** and volume enumeration |
| `ProcessRunner` and all process spawning | `Models/FileOperationService.swift` — `ProcessRunner`, `ProcessExecutionResult`, `Process()` (~L477). Remove once Phase 4 lands |
| Self-update | Nothing exists in the repo today. Do not add Sparkle or any updater. Updates come from the App Store |

Acceptance for this phase: no `Process`, `NSTask`, `NSAppleScript` or `osascript` reference
remains anywhere in `Sources/`; no menu item, context-menu entry, toolbar control or
keyboard shortcut reaches a removed feature; imported settings from a v1.0 install cannot
re-enable any of them.

##### Phase 4 — features to rework

| Feature | Required change |
|---|---|
| ZIP create / inspect / extract | Replace the four `/usr/bin/zip` and `/usr/bin/unzip` calls in `Views/PaneView.swift` (~L1116, L1144, L1163, L1212) with an in-process implementation. Select and pin a maintained ZIP library compatible with macOS 13, both SPM and XcodeGen, and App Store distribution licensing; confirm it does real ZIP read *and* write. Preserve every existing safety behaviour in `Models/ArchiveExtractionSafety.swift`: zip-slip rejection (absolute paths, traversal, empty and dot components, backslashes, NUL), archive-symlink rejection, intermediate-file conflicts, overwrite/skip/cancel, collision-safe output names, and `PaneState.pendingArchiveConflict` stability across tab switches. Keep cancellation and error reporting; integrate entry/byte progress with `ViewModels/FileOperationProgressModel.swift` |
| Home and standard folder paths | In a sandbox, `FileManager.default.homeDirectoryForCurrentUser` and `NSHomeDirectory()` return the **container**, not the real home. Fix all call sites to resolve the real home (`NSHomeDirectoryForUser(NSUserName())`) and treat the result as a *path hint that still requires a grant*: `Models/SidebarModel.swift` (~L122 Home, L128 iCloud Drive, L130 OneDrive), `Models/AppLaunchConfiguration.swift` (~L45 Downloads default), `Views/SettingsView.swift` (~L68, L71 iCloud/OneDrive detection), `Views/ContentView.swift` (~L331–335 Go Home / Go Desktop / Go Documents) |
| Breadcrumb and Computer-root navigation | `ViewModels/PaneState.swift` builds the breadcrumb by walking up from `/` (~L77–86) and special-cases `/Volumes` (~L240–245). Rework so unreadable ancestors render without failing, and the Computer root shows granted roots and mounted volumes rather than an unrestricted listing of `/` |
| Global Tags sidebar | `Models/SidebarModel.swift` (~L109, L160–161) queries `NSMetadataQueryIndexedLocalComputerScope`. Narrow to granted roots, and make the empty/partial state explicit in the UI rather than silently showing nothing |
| Deep / Spotlight search | `ViewModels/PaneState.swift` (~L376+). Scope queries to granted roots; handle unindexed roots and inaccessible results; never present results as whole-disk when only granted roots were searched |
| Duplicate Finder, Folder Size, Folder Compare & Sync | `ViewModels/DuplicateFinderViewModel.swift`, `ViewModels/FolderSizeViewModel.swift`, `Models/FolderCompareService.swift`. Operate only within granted roots; hold access leases for the whole scan including async completion; report inaccessible subtrees rather than silently skipping them |
| Volume enumeration | `ViewModels/PaneState.swift` (~L463) and `Models/NetworkVolumeMonitor.swift` (~L99) use `mountedVolumeURLs`. Enumeration is fine; **listing a volume's contents needs a grant.** Present ungranted volumes as needing access, not as empty |
| Background metadata | `Models/SmartMetadataService.swift` must acquire and hold a lease for the lifetime of its work and release it on every success, error and cancellation path |

##### Phase 5 — folder-access approval UI. This is new work, not a refactor

The app has **zero** security-scoped bookmark code today. All of the following is
greenfield.

1. **Access service.** A single service owning grant storage and leases. Persist
   `.withSecurityScope` bookmark data (not paths — `Models/SidebarModel.swift` currently
   persists paths). Resolve with security scope, refresh stale bookmarks, and acquire and
   release access in balanced, concurrency-safe leases. A lease must cover async work,
   callbacks, enumeration, previews, file coordination and cleanup.
2. **First-run onboarding.** On first launch, explain in plain language that DuPane can
   only see folders the user grants it, and offer to grant one. Cancelling must leave a
   usable app, not a dead one.
3. **"Add Folder Access…" command.** Permanently available from the menu and Settings, via
   `NSOpenPanel`. Granting a folder grants its descendants.
4. **Grant management UI in Settings.** List granted folders; allow removing a grant;
   show grants that have gone stale, offline or unresolvable, and offer re-authorisation.
   Never silently prune a grant because the location is temporarily unavailable.
5. **Inline access prompts.** When navigation lands somewhere ungranted — a restored tab,
   a Place, a Recent, Go to Folder, a sidebar entry, a launch argument, an imported
   setting, a mounted volume — show an in-pane "grant access to this folder" affordance
   rather than an error or an empty list. Cancelling leaves the current pane intact.
6. **Grants are separate from navigation.** Pins, tabs, history, Recents and Places are
   *hints*. A successful `fileExists` or a path-prefix match is **not** proof of access.
   Resolve symlink targets and volume boundaries explicitly rather than assuming a grant
   on the parent covers them.
7. **Honest error reporting.** Distinguish missing grant, read-only media, TCC denial,
   unavailable provider and missing file. Never promise that granting Home, `/`, or
   enabling Full Disk Access unlocks the filesystem — **Full Disk Access is a separate
   macOS privacy permission, not a sandbox escape, and must never be presented as one.**
8. **Settings import/export** uses panel-authorised files and never exports or transfers
   bookmark authority.

Apple references: [App Sandbox](https://developer.apple.com/documentation/security/app-sandbox),
[Accessing files from the macOS App Sandbox](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox),
[App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).

##### Phase 6 — identity, licensing and repository housekeeping

Items here are easy to forget and each one blocks submission.

1. **Bundle identifier.** `project.yml` currently uses `local.DuPane` (~L36), which is not
   a registrable reverse-DNS identifier. Choose a real vendor prefix and set one permanent
   ID. It cannot be changed after the first submission.
2. **Settings migration.** The app uses no custom `UserDefaults` suite, so preferences are
   keyed by bundle ID. Changing away from `local.DuPane` **orphans every existing user's
   settings.** Implement a one-time first-launch migration that reads the old
   `local.DuPane` domain and copies it forward. Do not rely on a manual export/import as
   the answer.
3. **LICENSE file.** The repository is public, has a `CONTRIBUTING.md`, and has **no
   licence** — which currently means all rights reserved. Ian must choose a licence and add
   it. Being the copyright holder is what permits App Store submission of open source, so
   the licence chosen must not conflict with App Store distribution terms.
4. **Privacy manifest.** Add `PrivacyInfo.xcprivacy` for the app, plus any privacy
   declaration required by the ZIP dependency chosen in Phase 4.
5. **Build numbering.** Remove the mutating "Stamp Build Number" post-build script from
   `project.yml` (~L27–32). Make `BuildNumber.txt` the checked-in shared value, incremented
   once per release candidate by an explicit release-prep step and consumed read-only by
   builds and CI. Never reuse a build number that has been submitted.
6. **Entitlements.** Start from `app-sandbox`, `files.user-selected.read-write`,
   `files.bookmarks.app-scope` only. Add `com.apple.security.network.client` or
   `.network.server` **only** with recorded evidence from Phase 1 that a retained feature
   needs it. If Bonjour is retained, add `NSLocalNetworkUsageDescription` and
   `NSBonjourServices` per
   [TN3179](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy).
   No speculative entitlements — every one must be justifiable to App Review.
7. **App name and icon** must not imply a Finder or Apple affiliation.
8. **Documentation.** Update `Docs/UserGuide.html`, `Docs/FAQs.html`, `Docs/README.md` and
   the root `README.md`: remove the dropped features, document folder grants and grant
   recovery, and state that the unrestricted build is available as the v1.0.0 tag for local
   building.

##### Phase 7 — tests and CI

- Retain every existing regression test that still applies. Delete tests for removed
  features rather than leaving them skipped.
- New unit coverage: grant store with stale/failed resolution, overlapping leases,
  cancellation, relaunch, revoked and offline grants; ZIP round-trip and the full hostile-
  archive fixture set; every removed feature proven unreachable from UI, keyboard and
  imported settings.
- New e2e coverage in `UITests/DuPaneEndToEndUITests/`: first-run with an empty container
  and no grants, deny, cancel, grant one folder, browse its descendants, deny a sibling,
  grant a second root, transfer files between panes across two roots, relaunch and confirm
  grants survive.
- Signed acceptance: repeat the Phase 1 table against the real signed sandboxed build
  before submission. **A passing SPM or unsigned test is not sandbox proof.** A required
  skip counts as unresolved.
- CI (`.github/workflows/ci.yml`) must regenerate and verify the XcodeGen project, build
  Debug and Release, run the unit suite, and assert the effective signed entitlements and
  the absence of process-spawning symbols — without dirtying Git.
- Update `Scripts/handoff-check.sh`, `Scripts/verify-change.sh`, `Scripts/run-e2e.sh`,
  `CLAUDE.md` and `Docs/AGENT-WORKFLOW.md` to match the single-target reality.

##### Phase 8 — App Store Connect and submission

1. Confirm Apple Developer Program enrolment and Team ID.
2. Register the bundle ID; create the App Store Connect record; set price to **free**;
   configure **no** in-app purchases.
3. Prepare screenshots, description, keywords, support URL, privacy policy URL, App
   Privacy answers, and review notes that explain the folder-grant model with reproducible
   sample-folder steps.
4. Archive and export with Mac App Store distribution signing, validate, upload,
   distribute via TestFlight.
5. Prove that a fresh install and an update both retain identity, settings and bookmarks.
6. Repeat the critical signed tests on the TestFlight build, then submit for review.
   TestFlight success does not guarantee approval. Resolve every validation and review
   finding before release; do not describe the app as shipped until it is approved and
   live.

##### Decisions still needed from Ian

- **Vendor / reverse-DNS prefix and Apple Team ID** for the permanent bundle ID.
- **Licence** for the public repository.
- **App Store display name** (recommend keeping **DuPane**).

##### Explicitly not in this plan

Two build targets or schemes. `DIRECT_BUILD` / `MAS_BUILD` compilation conditions. A second
bundle ID. Per-edition Info.plist or entitlements files. Developer ID signing,
notarization, stapling or DMG packaging. Sparkle or any self-update mechanism. A capability
matrix or runtime edition switch. Any paid tier, IAP, trial, licence key or receipt check.
Any helper process, XPC shell, or AppleScript workaround to restore a removed feature.

**No implementation, build increment or test result is claimed by this planning entry.**
Baseline at the time of writing remains Build 420: 336 unit / 14 e2e passed, 0 failed.


## Clarifications
none


## Pending

---

## Done
### Build 420 — sort tiebreak consistency for the Info column (2026-09-09)

- **Info-column name tiebreak now follows the sort direction** — `PaneView.visibleItems` sorts the async-loaded Info column; its primary comparison already honored `sortAscending`, but the equal-value name tiebreak was hardcoded ascending. Aligned it with the Build 403 decision already applied to Size/Kind/Modified in `PaneState` (and to `PaneState`'s own `.info` fallback), so a descending Info sort breaks ties in descending name order. (`Views/PaneView.swift`)
- **Provenance** — surfaced by a stale external handover; that handover's other findings (duplicate-scan generation refactor, the size/kind/modified tiebreak revert, TODO/build-number/migration-script drift) were already resolved by Builds 403/404/418 or deliberately decided the other way, so only this one view-layer inconsistency remained.
- **Tests: 336 unit passed, 0 failed; e2e 14 passed, 0 failed (re-run 2026-09-09 at this build)** — full SPM unit suite plus a fresh `./Scripts/run-e2e.sh` run against `f64ef4e`. No new unit test: no test asserts `visibleItems` ordering, and this is a pure view-layer sort refinement consistent with the existing `testDescendingSortEqualValuesTieBreakByName` behavior.

### Build 418 — outstanding bug closure and lifecycle hardening (2026-09-08)

- **Pane and tab performance/lifecycle** — `displayedItems` is cached and invalidated only when one of its inputs changes; switching tabs no longer forces an unnecessary directory load; closing a tab now cancels its load and explicitly tears down Spotlight observers/query state. (`ViewModels/PaneState.swift`, `ViewModels/TabbedPaneState.swift`, `Views/TabbedPaneView.swift`)
- **Sidebar filesystem checks moved off the main actor** — bookmark, recent, iCloud, and OneDrive existence validation now runs in a cancellable utility task with generation checks, so stale validation snapshots cannot overwrite newer UI mutations. (`Models/SidebarModel.swift`)
- **Process lifecycle hardened** — `ProcessRunner` redirects stdin to `/dev/null`, enforces a five-minute default timeout, terminates on task cancellation, and still drains stdout/stderr concurrently. Collapsing the Command Runner cancels its active task. (`Models/FileOperationService.swift`, `Views/CommandRunnerView.swift`)
- **Archive conflict state survives tab switches** — pending uncompress URL/conflicts now live on the stable `PaneState`, not an orphanable `PaneView` state box. (`ViewModels/PaneState.swift`, `Views/PaneView.swift`)
- **Delete navigation handles nested and partial-success cases** — peer recovery walks outside every successfully trashed ancestor and ignores failed deletions. (`Models/FileOperationService.swift`, `Views/ContentView.swift`)
- **Quick Look updates an already-visible panel when selection changes** — Space still closes the panel for the same selection, while a new selection reloads it immediately. (`Views/QuickLookCoordinator.swift`)
- **Column drag cleanup covers missed mouse-up events** — local/global mouse-up monitors plus window/app deactivation observers terminate the drag and restore cursor state. (`Views/ColumnResizeHandle.swift`)
- **Test infrastructure repaired** — the flaky PNG metadata test polls for resolution; `Scripts/run-e2e.sh` captures structured UI-test stdout markers into the gitignored repo-local log, avoiding the UI runner's source-tree sandbox. E2E actions now wait for enabled, hittable controls, and delete confirmation is pinned by launch arguments so machine preferences cannot consume the Undo toast lifetime. (`Tests/DuPaneUITests/DuPaneFunctionTests.swift`, `UITests/DuPaneEndToEndUITests/TestResultLog.swift`, `UITests/DuPaneEndToEndUITests/DuPaneEndToEndUITests.swift`, `Scripts/run-e2e.sh`)
- **Audit: two reported races were unreachable** — history navigation and `endDeepSearch()` are synchronous `@MainActor` operations with no suspension point; queued Spotlight callbacks re-check the cleared query. No defensive code was added for impossible interleavings.
- **Tests: 336 passed, 0 failed; e2e: 14 passed, 0 failed** — 13 new unit regressions in `Build418BugTests.swift`; the full wrapper run proved `.test-results/DuPaneEndToEndUITests.log` contains 14 current PASS results.

### Build 404 — Duplicate Finder scan identity and Codex workflow (2026-09-08)

- **Low: superseded Duplicate Finder scans can no longer publish stale progress or results** — every scan now carries a monotonically increasing generation. Progress and completion callbacks update the view model only when their generation is still current and the scan is active, so reopening the finder on another folder cannot briefly show counters or groups from the previous scan. The detached task also captures the view model weakly. (`ViewModels/DuplicateFinderViewModel.swift`, `Tests/DuPaneUITests/Build404BugTests.swift`)
- **Audit: the reported resolved-group UI bug was already fixed** — `moveToTrash` removes groups with fewer than two remaining files, so the view never retains a one-file “resolved” group. Re-verified with the existing four-test `DuplicateFinderMoveToTrashTests` suite and removed the stale TODO entry. (`ViewModels/DuplicateFinderViewModel.swift`, `Tests/DuPaneUITests/BugAuditTests.swift`)
- **Repository workflow: added Codex-native instructions** — root `AGENTS.md` directs Codex to the complete project conventions and agent workflow, including handoff checks, regression tests, documentation/build updates, XcodeGen handling, and clean sync requirements. (`AGENTS.md`)
- **Tests: 323 passed, 0 failed** — full SPM unit suite, including the new deterministic superseded-scan regression. Existing Duplicate Finder group-cleanup tests passed 4/4. No e2e run was needed because this build changes internal scan-state isolation and repository guidance only; the previous Build 403 e2e result remains 14 passed, 0 failed.

### Build 403 — network ejection consistency and descending sort tiebreaks (2026-09-08)

- **Medium: a failed network-volume eject now leaves the sidebar unchanged** — `NetworkVolumeMonitor.ejectAndRemove` now attempts the unmount before suppressing or removing the volume. If macOS rejects the eject, the still-mounted share remains visible and can be retried. The unmount operation is injected for deterministic regression coverage. (`Models/NetworkVolumeMonitor.swift`, `Tests/DuPaneUITests/BugAuditTests.swift`)
- **Medium: mounted-volume probing no longer blocks the UI** — `refresh()` snapshots its inputs and performs `mountedVolumeURLs`/`statfs` work on a serial utility queue, publishing only the newest completed generation back on the main queue. A stale network share can no longer beachball the app during sidebar refresh. (`Models/NetworkVolumeMonitor.swift`)
- **Medium: Bonjour discovery publishes on the main thread** — delegate callbacks now pass through `receiveBonjourServers`, which marshals background callbacks to the main queue before changing `bonjourServers`. (`Models/NetworkVolumeMonitor.swift`)
- **Low: descending sort now applies descending name tiebreaks** — equal values in Size, Kind, and Modified sorts now order names consistently with the selected descending direction. Updated `testDescendingSortEqualValuesTieBreakByName` to assert the intended behaviour. (`ViewModels/PaneState.swift`, `Tests/DuPaneUITests/DuPaneFunctionTests.swift`)
- **Tests: 322 passed, 0 failed** — full SPM unit suite, including four network-eject tests and two network-threading regression tests in `Build403BugTests.swift`.

### Repository tooling — local clone migration helper (2026-09-08)

- **iCloud-to-local migration script** — `Scripts/migrate-off-icloud.sh` creates a clean, metadata-free Git clone at `~/Developer/DuPane` by default, preserving tracked work through a binary patch and untracked files without Finder/resource-fork metadata. It leaves the iCloud checkout untouched, retains a local safety backup, restores the original `origin` URL, and optionally runs the SPM unit suite. Use it instead of copying the repository in Finder when iCloud metadata makes codesigning fail.

### Build 397 — 4 design-decision fixes: sync atomicity, trash undo, atomic settings import, metadata isolation (2026-09-08)

- **Medium: folder sync is now all-or-nothing** — `executeSyncPlan()` copied via `moveOrCopy` with per-item backups that were deleted the instant each item succeeded, so a failure partway through left earlier files overwritten with no rollback. New `FileOperationService.transactionalCopy(files:to:onProgress:)` backs up every existing destination, keeps all backups until the whole plan succeeds, and rolls the entire batch back (restoring overwritten files, removing newly-created ones) on any single failure. Sync-plan overwrite entries are files only (directories are excluded upstream in `FolderCompareService.overwritingEntry`), so no directory-merge rollback is needed. (`Models/FileOperationService.swift`, `Views/ContentView.swift`)
- **Medium: a partial or complete delete is now undoable** — `trash()` returns `[TrashedItem]` pairing each original URL with its Trash location, and `restoreFromTrash(_:)` moves them back (skipping any whose original path is occupied again, so a restore never overwrites a newer file). `performDelete` shows an **Undo** button in the toast that restores the items. (`Models/FileOperationService.swift`, `Views/ContentView.swift`, `Views/GlobalToolbar.swift` — added `toolbar-delete-button` id)
- **Low: Import Settings is now atomic** — `AppSettings.performBatchUpdate` collects each setting's `didSet` write while a batch is open and flushes them to `UserDefaults` in one pass; `applyImport` runs inside it, so a bulk import can no longer be observed in an inconsistent intermediate state. Single-setting writes stay immediate. Removed the now-unused `saveColumnWidths` helper. (`Models/AppSettings.swift`)
- **Low: metadata cache off-main access now fails loudly** — `SmartMetadataService` gains a `dispatchPrecondition(.onQueue(.main))` assertion at every `cache`/`cacheOrder`/`pending` access point, turning an accidental off-actor read into a debug crash instead of a silent data race. (`Models/SmartMetadataService.swift`)
- **14 new tests** — unit (`Build397BugTests.swift`): `TransactionalSyncCopyTests` (4), `TrashUndoTests` (4), `AppSettingsBatchWriteTests` (3), `SmartMetadataMainActorAccessTests` (1); e2e (`DuPaneEndToEndUITests.swift`): `testCriticalUndoAfterDeleteRestoresTheFile`, `testCriticalSyncCopiesLeftOnlyFilesToTheRightPane` (2). e2e added only where UI-observable — the atomic-import and metadata-assertion fixes stay unit-only (import consistency is unobservable through the UI; the metadata `dispatchPrecondition` would crash the runner, not assert). **Unit: 319 passed, 0 failed. E2E: 14 passed, 0 failed** (`xcodebuild` scheme `DuPane`, macOS 27.0, 2026-09-08). The delete-confirmation step in the Undo test is optional so it passes whether or not "delete without confirmation" is enabled.

### Build 395 — 2 High bug fixes with refactors for testability (2026-09-08)

- **High: concurrent file operations no longer clobber each other's progress UI** — `fileOpInfo` / `fileOpVisible` / `fileOpRevealTask` were one shared set of `@State` slots in `ContentView` with nothing serialising operations, so whichever finished first tore down the overlay and the one still running had no progress display for the rest of its life. Extracted to `FileOperationProgressModel` (`ViewModels/`), where every mutation is addressed by the token issued at `begin()`: a finished operation can only retire itself, the overlay hides only when the last operation completes, and a stale `update`/`reveal` is ignored. Both call sites (`executeMoveOrCopy`, `executeSyncPlan`) now go through it. (`ViewModels/FileOperationProgressModel.swift`, `Views/ContentView.swift`)
- **High: type-ahead no longer writes into a closed tab's `PaneState`** — `TabbedPaneView` keyed view identity on `activeTabIndex`, an `Int`. Closing the middle of three tabs leaves the index unchanged while it now refers to a different tab, so SwiftUI reused the view, `onAppear` did not re-run, and the type-ahead closure kept the `PaneState` of the tab that was gone — type-ahead silently dead in that pane, old `PaneState` retained. `Tab` already carried a stable `UUID`; added `TabbedPaneState.activeTabID` and keyed the view on it. (`ViewModels/TabbedPaneState.swift`, `Views/TabbedPaneView.swift`)
- **Testability** — accessibility identifiers added to the tab strip (`<side>-tab-<n>`, `<side>-close-tab-<n>`, `<side>-new-tab-button`), the Go-to-Folder sheet (`go-to-path-field`, `-confirm-button`, `-cancel-button`) and the progress overlay (`file-op-progress`). None of these were reachable from a UI test before.
- **8 new unit tests** in `Build394BugTests.swift`: `FileOperationProgressModelTests` (5), `ActiveTabIdentityTests` (3). **319 tests, 0 failures.**
- **2 new e2e tests** in `DuPaneEndToEndUITests.swift`: `testCriticalTypeAheadStillWorksAfterClosingTheActiveTab`, `testCriticalProgressOverlayIsNotLeftOnScreenAfterACopy`. **Not yet executed** — they need `xcodegen generate` first, because `FileOperationProgressModel.swift` is new and the `.xcodeproj` does not reference it yet.

### Build 394 — 4 bug fixes: folder-merge data loss, load cancellation, metadata re-spawn, progress reporting (2026-09-08)

- **Critical: "Overwrite" on a folder no longer destroys data** — `FileOperationService.moveOrCopy` now merges directory-into-directory rather than replacing. Previously it moved the existing destination aside, copied the source over it, then deleted the backup with `removeItem`, so every file present only in the destination was permanently gone — no Trash, no undo. Reachable from both the copy/move and drag-drop conflict alerts. New `mergeDirectory(from:to:isMove:)` recurses and overwrites colliding files while never removing a destination entry that has no counterpart in the source. Packages (`.app`, `.rtfd`) are detected via `isPackageKey` and still replace wholesale, since merging two bundle versions would produce a broken one. (`Models/FileOperationService.swift`)
- **High: cancelled directory loads now actually stop** — `PaneState.loadFolder` checks `Task.checkCancellation()` per entry. `load()` cancels the wrapper, but the inner `Task.detached` does not inherit cancellation and the enumeration had no checks, so a cancelled load kept a cooperative-pool thread busy until the read finished. Several tabs on an unresponsive SMB/NFS share could exhaust the pool and stall every `Task.detached` in the app — panes spinning forever, metadata stopped, copy/move/delete never starting — while the main thread stayed responsive so the app looked alive. (`ViewModels/PaneState.swift`)
- **`SmartMetadataService` no longer re-spawns a task per file on every reload** — `compute` returns nil for any extension outside its three lists, and nothing was recorded for a nil, so `loadIfNeeded` restarted the whole set on every `pane.items` change. Negative results are now cached as an empty sentinel through the existing LRU; `info(for:)` still returns nil for it so nothing changes in the UI. Added `hasResolved(_:)`. (`Models/SmartMetadataService.swift`)
- **`onProgress` now fires for items skipped by the subtree guard** — the `defer` was registered after the guard's `continue`, so a batch containing a self-referential folder never reached its progress total. (`Models/FileOperationService.swift`)
- **10 new tests** in `Build394BugTests.swift`: `FolderOverwriteMergeTests` (5, including the exact data-loss case and a regression guard that plain files still replace), `MoveOrCopyProgressReportingTests` (1), `LoadFolderCancellationTests` (2), `SmartMetadataNegativeCacheTests` (2).
- **309 tests, 0 failures.**

### Build 393 — UI/doc fixes: duplicate-scan cancellation, Settings Escape, UserGuide layout, README name (2026-09-08)

- **Duplicate scan now cancels promptly** — `fnv1a64` and `filesHaveSameContents` read loops check `Task.isCancelled` per 1 MB chunk, so hitting Cancel during a long scan stops mid-hash instead of waiting for the scan to finish. The completion path guards on `!Task.isCancelled` and re-checks `phase == .scanning` inside the `MainActor.run` block, so a cancelled scan can no longer resurrect `phase` to `.done` or publish stale results. The Duplicate Finder Cancel button also responds to `Esc` (`.cancelAction`). (`ViewModels/DuplicateFinderViewModel.swift`, `Views/DuplicateFinderView.swift`)
- **Settings window closes with Escape** — a hidden `.keyboardShortcut(.escape)` button calls `NSWindow.performClose`. (`Views/SettingsView.swift`)
- **UserGuide layout fix** — `body { min-width: 760px }`, reduced hero padding, widened hero paragraph so the page no longer renders in an over-narrow column. Added an `Esc` row to the shortcuts reference. (`Docs/UserGuide.html`)
- **README name cleanup** — removed the "modelled on Directory Opus" reference; DuPane is the only project name. (`Docs/README.md`)
- **Tests** — new `Build379BugTests.swift` with 3 tests covering cancel→idle, cancelled-scan-does-not-complete-to-done, and uncancelled-scan-reaches-done. 289 unit tests pass, 0 failures.

### Build 392 — 10 bug fixes (2026-09-07)

- **`PaneState` sortPref UserDefaults leak fixed** — `SortPreference.save()` now maintains a `sortPrefKeysList` order array capped at 200 entries with LRU eviction; oldest key is removed from UserDefaults when the limit is exceeded. (`ViewModels/PaneState.swift`)
- **`ContentView.showToast` race fixed** — `asyncAfter` closure now captures the message at scheduling time and only clears `toastMessage` if it still matches, preventing a second toast from being prematurely cleared by the first's timer. (`Views/ContentView.swift`)
- **Dead `lastLeftURL`/`lastRightURL` UserDefaults writes removed** — both `onChange` handlers in `ContentView` no longer write these keys; they were never read (tab-state JSON takes over first). (`Views/ContentView.swift`)
- **`finderTagColor` duplication eliminated** — extracted to a shared `Color.finderTag(_:)` extension in `FileRowView.swift`; private copies removed from `SidebarView` and `PropertiesView`. (`Views/FileRowView.swift`, `Views/SidebarView.swift`, `Views/PropertiesView.swift`)
- **`SidebarView.connectToServer` no longer clears suppressed paths** — unconditional `clearSuppressedPaths()` call removed; volumes the user deliberately hid are no longer restored on every server connect. (`Views/SidebarView.swift`)
- **`PaneState.rename`/`duplicate` weak self capture added** — `[weak self]` added to `Task.detached` closures and inner `MainActor.run` blocks; closed tabs no longer stay alive through an in-progress operation. (`ViewModels/PaneState.swift`)
- **`PaneState.duplicate()` at Computer root now surfaces error** — nil `currentURL` check sets `errorMessage = "Duplicate is not available at the Computer level."` rather than silently returning. (`ViewModels/PaneState.swift`)
- **`networkBonjourDiscovery` Settings label updated** — label changed from "Bonjour discovery in Connect sheet" to "Bonjour discovery (Connect sheet and sidebar)" to accurately reflect the setting's scope. (`Views/SettingsView.swift`)
- **`AppLaunchConfiguration.url()` existence check added** — `guard FileManager.default.fileExists(atPath:isDirectory:)` returns nil for non-existent command-line paths; downstream code no longer receives a URL pointing to a missing directory. (`Models/AppLaunchConfiguration.swift`)
- **`TabbedPaneState` pinned-path migration guard added** — `pinnedPathsConsistent` check ensures `savedPinnedPaths` is only used when its count matches `savedPaths`; count divergence (e.g. crash mid-save) falls back to `savedPaths` instead of restoring metadata to wrong tabs. (`ViewModels/TabbedPaneState.swift`)
- **9 new tests** in `Build392BugTests.swift`: `SortPreferenceKeyPruningTests` (2), `AppLaunchConfigurationURLExistenceTests` (3), `PaneStateDuplicateAtRootTests` (2), `TabbedPinMigrationTests` (2). Updated 2 existing tests to match corrected behaviour.
- **286 tests, 0 failures.**

### Build 391 — 8 bug fixes (2026-09-07)

- **`SmartMetadataService` unbounded cache fixed** — `cacheOrder: [URL]` tracks insertion order; when `cache` exceeds 500 entries the oldest entry is evicted. (`Models/SmartMetadataService.swift`)
- **`ProcessRunner.run` no longer blocks thread pool** — `waitUntilExit()` replaced with `withCheckedThrowingContinuation` + `terminationHandler`; pipe drains run in detached tasks to prevent buffer-full deadlocks. (`Models/FileOperationService.swift`)
- **`FolderSizeViewModel` cancellation added** — `Task.isCancelled` checked inside the `directorySize` enumeration loop; scan stops promptly on sheet dismiss. (`ViewModels/FolderSizeViewModel.swift`)
- **`DuplicateFinderViewModel` progress tasks guarded after cancel** — progress callbacks use `[weak vm]` capture and check `vm?.phase == .scanning` before mutating state; final `MainActor.run` also uses `[weak vm]` with a nil guard. (`ViewModels/DuplicateFinderViewModel.swift`)
- **`SidebarModel.removeRecent(_ url:)` added** — targeted O(1) removal without rebuilding the list via `recordVisit`. (`Models/SidebarModel.swift`)
- **`FileRowView.formatDate` static `DateFormatter` cache** — 8 `DateFormatter` instances promoted to `static` properties; no longer allocated per row per render. (`Views/FileRowView.swift`)
- **`AppLaunchConfiguration` command-line URL `isDirectory` fixed** — `fileExists(atPath:isDirectory:)` now determines the correct flag instead of always passing `true`. (`Models/AppLaunchConfiguration.swift`)
- **`SmartMetadataService.lineCount` returns `nil` for binary files** — chunk scan returns `nil` on first null byte, preventing wrong line counts for binary files with code extensions. (`Models/SmartMetadataService.swift`)
- **277 tests, 0 failures.**

### Build 389 — 5 bug fixes: directory compare, line count, tab metadata, subtree guard, archive conflicts (2026-09-07)

- **`FolderCompareService` directory kind mismatch fixed** — `status()` no longer checks `kind` when both items are directories. iCloud Drive reports "iCloud Folder" vs "Folder" for the same directory; this caused false `.different` results. (`Models/FolderCompareService.swift`)
- **`SmartMetadataService.lineCount` off-by-one fixed** — tracks `lastByte`; does not add +1 when the file already ends with a newline. Files like "line1\nline2\nline3\n" now correctly report "3 lines" instead of "4 lines". (`Models/SmartMetadataService.swift`)
- **`TabbedPaneState.fallbackMetadataIndex` guard fixed** — OR condition changed to only check `savedPaths.count == tabs.count`. Previously, matching `savedLabels` or `savedPins` count alone (without `savedPaths`) could stamp metadata onto the wrong tabs after a tab-count change. (`ViewModels/TabbedPaneState.swift`)
- **`FileOperationService.moveOrCopy` subtree guard fixed** — guard moved inside the main loop with `continue` instead of early `return`. Other items in the batch now proceed when one folder is self-referential. (`Models/FileOperationService.swift`)
- **`ArchiveExtractionSafety` subdirectory conflict detection fixed** — `conflicts()` now also checks intermediate path components; detects the case where an intermediate component exists as a file (not a directory), which `fileExists` on the leaf path missed. (`Models/ArchiveExtractionSafety.swift`)
- **New tests added** — `FileOperationSubtreeGuardTests` (2 tests) and `ArchiveExtractionSafetyConflictTests` (3 tests) in `Build381BugTests.swift`. Updated `Build42BugFixTests` expected lineCount value.
- **277 tests, 0 failures.**

### Build 380 — E2E rename test fix, CI hardening, .xcodeproj cleanup (2026-09-07)

- **`testCriticalRenameFileThroughToolbarSheet` fixed** — replaced unreliable `typeKey("a", modifierFlags: .command)` (⌘A) with `typeKey(.rightArrow, modifierFlags: .command)` + `typeKey(.leftArrow, modifierFlags: [.command, .shift])` to navigate to end then select back to beginning, guaranteeing the pre-filled filename is replaced before typing the new name.
- **CI red since Build 377 resolved** — `CustomActionsModelTests` (4 orphaned tests referencing the deleted `CustomActionsModel`) removed from `DuPaneFunctionTests.swift`; class renamed `ProcessRunnerTests` preserving the 2 surviving `ProcessRunner` tests. Unit suite 234 tests, 0 failures.
- **Stale `.xcodeproj` cleaned** — `project.pbxproj` references to the two deleted CustomActions source files removed (8 lines). Clean Xcode clones now build correctly.
- **CI hardened** — `.github/workflows/ci.yml` uses `--scratch-path` outside iCloud to avoid codesign failures; `.gitignore` tightened.
- **234 tests, 0 failures.**

### Build 377 — Menu cleanup, Actions removal, Escape in dialogs, HTML bundling (2026-09-06)

- **Duplicate Settings menu item removed** — the manual `Button("Settings…")` in `CommandGroup(replacing: .appSettings)` was removed; the `Settings { }` scene now provides the single Settings… entry with ⌘, automatically.
- **⌘, opens Settings** — fixed as a consequence of removing the conflicting manual button above.
- **Services menu removed** — `CommandGroup(replacing: .systemServices) {}` added to `DuPaneApp` suppresses the built-in Services menu.
- **Edit, View, Window menus removed** — `AppDelegate.applicationDidFinishLaunching` removes these three menus from `NSApp.mainMenu` at launch.
- **Actions feature removed entirely** — `CustomActionsModel.swift` and `CustomActionsSettingsView.swift` deleted. Toolbar button, context menu entries, alert, `requestCustomActionRun`/`executeCustomAction` functions, and the "Show custom shell command notice" Settings toggle all removed from `GlobalToolbar`, `ContentView`, `PaneView`, and `SettingsView`.
- **Escape dismisses dialog panels** — Cancel button in `TextPromptSheet` gains `.keyboardShortcut(.escape, modifiers: [])` so Escape works in copy-conflict and other prompt dialogs.
- **Help Guide and FAQ load on all machines** — `openDoc` in `DuPaneApp` now resolves via `Bundle.main.url(forResource:withExtension:)` first. `UserGuide.html` and `FAQs.html` added to the DuPane target's Copy Bundle Resources so they ship inside the app bundle.

### Build 368 — GitHub CI, contributor infrastructure, .app launch, 12h+seconds time format, iCloud Drive sidebar, menu order fix (2026-09-06)

- **Double-click .app launches app** — `PaneView.open()` intercepts `.app` extension before the `isDir` check and calls `NSWorkspace.shared.open()`, so app bundles launch rather than navigate into the package.
- **12-hour + seconds time format** — `TimeFormatStyle` gains `.twelveWithSeconds` ("h:mm:ss a") as a 5th option between the existing 12h and 24h options. Settings picker and `FileRowView.formatDate` updated. `Build268Tests.swift` updated to new `timeStyle:` API.
- **DuPane menu order fix** — Settings… now appears above Export/Import Settings. Achieved by switching to `CommandGroup(replacing: .appSettings)` and emitting Settings first, then a Divider, then Export/Import.
- **iCloud Drive in sidebar settings** — conditional toggle in Settings > Sidebar places appears only when `~/Library/Mobile Documents/com~apple~CloudDocs` exists. Default `enabledPlaces` set now includes "iCloud Drive" and "OneDrive".
- **GitHub Actions CI** — `.github/workflows/ci.yml` runs `swift build` + `swift test --filter DuPaneUITests` on `macos-15` on every push/PR to main, plus `workflow_dispatch` for manual triggers. `workflow_dispatch` trigger added (Build 368) so runs can be started from the GitHub web UI.
- **PR validation workflow** — `.github/workflows/pr-check.yml` blocks PRs with empty descriptions (strips HTML template comments before checking).
- **Issue templates** — Bug Report and Feature Request YAML forms with required fields. `config.yml` disables blank issues and links to User Guide + FAQs.
- **PR template** — `.github/pull_request_template.md` with summary, changes, test plan, and checklist sections.
- **CONTRIBUTING.md** — requirements, getting-started steps, before-submit checklist, code conventions, what won't be merged.
- **CI type-checker timeout fix** — extracted `panesArea(snapshot:)` and `keyboardButtons` as `@ViewBuilder` helpers from `ContentView.coreView()` so Swift's type-checker processes each piece independently (CI's compiler is marginally slower than local).
- **Docs consistency** — UserGuide and FAQs footer updated to Version 1.0 / Build 367. iCloud Drive and OneDrive added to sidebar documentation. 12h+seconds option added to time format table. Dark mode settings path corrected.
- **189 tests, 0 failures.**

### Build 313 — Advanced network features (2026-08-29)

- **Mounted network volumes** — the Network sidebar section now enumerates all mounted network shares (SMB, AFP, NFS, etc.) detected via `statfs`/`MNT_LOCAL` flag. Each entry shows the share name with a green status dot (when status indicator is on) and an Eject button that calls `NSWorkspace.unmountAndEjectDevice`. The list auto-refreshes on `NSWorkspace.didMountNotification` / `didUnmountNotification`.
- **Bonjour discovery** — the Connect to Server sheet shows a "Discovered Servers" list populated by `NetServiceBrowser` scanning `_smb._tcp` and `_afpovertcp._tcp` on the local network. Clicking a discovered server fills the URL field. Browsing starts when the sheet opens and stops on close.
- **Pinned network locations** — in the Connect sheet a "Pin this server" toggle (when Settings > Network > Show pinned servers is on) adds the URL to a persistent list (`pinnedNetworkURLs` in UserDefaults). Pinned servers appear in the Network sidebar section with a pin icon and gray status dot. Tapping connects; right-click offers Connect Now / Remove from Pinned.
- **Auto-reconnect on launch** — when Settings > Network > Auto-reconnect pinned servers on launch is on (default off), `NetworkVolumeMonitor` calls `NSWorkspace.open` for each pinned URL at startup. Credentials in Keychain allow silent reconnection.
- **Status indicator** — a 7 pt coloured dot precedes network entries: green for mounted volumes, gray for pinned-but-unmounted servers. Toggled via Settings > Network > Show status indicator.
- **Settings > Network section** — five individual toggles under the Network heading (only shown when Show Network section is on): Mounted volumes, Status indicator, Pinned servers, Bonjour discovery, Auto-reconnect.
- **`NetworkVolumeMonitor` model** — new `ObservableObject` (`NetworkVolumeMonitor.swift`) encapsulating all the above logic. Types: `NetworkVolume` (Identifiable by URL), `BonjourServer` (Identifiable by scheme+host).
- **20 new tests** in `Build310Tests.swift`: 5 × `NetworkVolume`, 5 × `BonjourServer`, 7 × `AppSettings` network defaults & persistence, 3 × `NetworkVolumeMonitor` unit.
- **238 tests, 0 failures.**

### Build 309 — Connect to Server (2026-08-29)

- **Connect to Server** — a "Network" section appears in the sidebar (when Settings > Sidebar > "Show Network section" is on). The "Connect to Server…" row opens a sheet with a URL text field (pre-filled "smb://"). On confirm, `NSWorkspace.shared.open(url)` sends the URL to macOS, which prompts for credentials and mounts the share. Basic URL validation is shown inline.
- **218 tests, 0 failures.**

### Build 307 — Sidebar row hover highlights (2026-08-29)

- **Sidebar hover highlight** — hovering over any Places, Recents, or Bookmarks row now shows a subtle rounded-rectangle background, making it clear which item is under the cursor when right-clicking for the context menu. All three row types share a unified `hoveredURL` state; Bookmarks retain the existing hover-reveal xmark button behaviour.
- **218 tests, 0 failures.**

### Build 269 — 21 new tests, [optional] tagging across all test files (2026-08-28)

- **21 new [must] tests in Build268Tests.swift** — `PaneState.duplicate()` (4 tests: extension, no-extension, auto-increment, multi-item), `SidebarModel` recents (4: prepend, dedup, cap-12, clearRecents), `FileRowView.formatDate(showTime:)` (6: nil→"—", medium no-time, medium+time, ISO date-only, ISO+time, relative today+time), `PaneState.foldersFirst=false` (2), `TabbedPaneState.foldersFirst` propagation (2), `AppSettings` new defaults (1: all 4 new bool fields), `PaneState` new flag defaults (2).
- **`[optional]` tags added** to 17 tests across 4 files: 6 latency, 2 slow-metadata (Build42), 2 slow-metadata (FunctionTests), 3 FolderSizeViewModel, 4 misc trivial/internal. Convention: all tests are [must] unless marked [optional]; see Build268Tests.swift header.
- **210 tests, 0 failures.**

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

- **App renamed to DuPane** — `Info.plist` CFBundleName and CFBundleDisplayName updated to "DuPane". All user-visible strings in menus, usage descriptions, and documentation updated. Code identifiers unchanged. Bundle ID unchanged.
- **Window size persistence** — First launch: window maximises to fill the screen. Subsequent launches: window frame restored from `mainWindowFrame` UserDefaults key (saved in `applicationWillTerminate`). Implemented in `AppDelegate`.
- **First-launch defaults** — Default font size 14pt (was 12pt). Default visible columns: Name, Size, Modified (Kind and Info hidden by default). Default column widths: Size 80pt, Modified 110pt.
- **5 new themes** — `AppColorScheme` gains `.ocean`, `.country`, `.earth`, `.fire`, `.vivid` cases. Ocean: dark/cyan, Country: light/forest-green, Earth: light/terracotta, Fire: dark/fire-red, Vivid: light/purple.
- **Date format setting** — `DateFormatStyle` enum added (short/medium/long/iso/relative). `AppSettings.dateFormatStyle` persisted to UserDefaults. `FileRowView.formatDate(_:style:)` takes style parameter.
- **File icon show/hide** — "Icon" added to column toggle system. `FileRowView` conditionally renders `iconView` based on `!settings.hiddenColumns.contains("Icon")`.
- **Sidebar Recents** — `SidebarModel.recentURLs: [URL]` (up to 12, persisted in UserDefaults). `recordVisit(_:)` called from `ContentView.onChange` for both pane URLs.
- **Sidebar Places** — `AppSettings.enabledPlaces: Set<String>` (UserDefaults key `enabledPlaces`, default: Home/Applications/Desktop/Documents/Downloads). `SidebarView` shows a "Places" section filtered by `settings.enabledPlaces`.
- **189 tests, 0 failures** — updated 3 tests to match new defaults.
- **UserGuide and FAQs** — fully updated: DuPane rename, Places/Recents sidebar sections, date format setting, icon toggle, themes table, Go to Path ⌘L shortcut, type-ahead note, first-launch defaults.

### Build 51 — Type-ahead file navigation (2026-08-21)

- **Typing selects first matching item** — when a pane is active and no text input has focus, typing any printable character jumps the selection to the first visible item whose name starts with the typed string. Multi-character prefix accumulated within 600ms. Implemented via `TypeAheadController`.
- **110 tests, 0 failures** — no new tests (AppKit event monitor + UI scroll, not unit-testable).

### Build 50 — Go to Path (2026-08-21)

- **⌘L opens "Go to Folder" sheet** — pressing ⌘L on either pane opens a sheet pre-filled with the pane's current path. Tilde expansion supported. Path validated as existing directory on confirm.
- **110 tests, 0 failures** — no new tests.

### Build 49 — Show hidden folders setting (2026-08-21)

- **"Show hidden folders (dot-folders)" toggle in Settings → Display** — independent of the existing "Show hidden files" toggle.
- **110 tests, 0 failures** — no new tests.

### Build 48 — Subfolder deep search (2026-08-21)

- **NSMetadataQuery-based subfolder search** — filter box gains a magnifying glass button triggering `PaneState.beginDeepSearch(query:)`. Search banner shows progress. File operations work on search results.
- **Rename returns task for testability** — `PaneState.rename(item:to:)` changed to `@discardableResult func → Task<Void, Never>?`.
- **189 tests, 0 failures** — 17 new tests in `DeepSearchTests.swift`.

### Build 47 — iCloud Drive in sidebar (2026-08-21)

- **iCloud Drive appears in sidebar system locations** — `SidebarModel.init` checks for `~/Library/Mobile Documents/com~apple~CloudDocs`. If present, an "iCloud Drive" entry with `icloud.fill` icon is inserted between Downloads and OneDrive.
- **172 tests, 0 failures** — no new tests.
