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

### Remaining work
No confirmed outstanding bugs remain in this list. Continue auditing before assuming the
repository is defect-free.


## Next items

### Enhancements

#### Distribution — full Direct and free Mac App Store editions from one codebase

**Next: implementation plan, not a completed enhancement.** Keep one shared codebase
with two explicit compile-time application targets and schemes: `DuPane-Direct` and
`DuPane-MAS`. Direct retains the full feature set and remains unsandboxed; MAS enables
App Sandbox. Both editions are free to download. MAS has **no IAP, subscription, trial,
receipt-based feature unlock, license gate, or requirement to install Direct**. Store
receipts, if present, must never control capabilities. Pricing is settled.

Use separate, permanent bundle IDs so both apps install and run together with independent
preferences, containers, grants, and update channels. Recommended display names are
**DuPane** (MAS) and **DuPane Direct**. Compile forbidden implementations out of the MAS
binary and its embedded components; hiding a button or testing the edition at runtime
is insufficient. Retain every other existing feature unless a specific Apple rule
clearly prohibits it or a reproducible signed sandbox test proves it unreliable after
supported implementation alternatives have been tried. Another app's feature comparison
is not evidence that an API is prohibited. Command Runner, `.sh` execution in Terminal,
self-update, and initially eject are explicitly Direct-only in this plan.

**Re-verified starting point:** `project.yml` currently generates one `DuPane` app target,
uses `local.DuPane`, `Resources/Info.plist`, and sandbox-false
`Resources/DuPane.entitlements`, and increments `BuildNumber.txt` in a target post-build
script. `ProcessRunner` lives inside `Sources/DuPane/Models/FileOperationService.swift`;
ZIP and Terminal launching use processes in `Views/PaneView.swift`, with another Terminal
launcher in `Views/SidebarView.swift`. Eject and discovery share
`Models/NetworkVolumeMonitor.swift`. `Models/SidebarModel.swift` persists bookmark paths,
not security-scoped bookmark data. Source paths below are relative to `Sources/DuPane/`
unless a repository-root path is given. Proposed new files are explicitly identified.

**Apple constraints and evidence:** MAS requires sandboxing and Store-delivered updates;
use [App Sandbox](https://developer.apple.com/documentation/security/app-sandbox),
[Accessing files from the macOS App Sandbox](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox),
and [App Review Guidelines, especially 2.4.5](https://developer.apple.com/app-store/review/guidelines/#software-requirements)
as the implementation/review references. User-selected directory access can cover its
descendants, but is not unrestricted disk access: protected locations, permissions,
symlink targets, other volumes and providers still need appropriate access handling.
**Full Disk Access is a separate macOS privacy permission, not an App Sandbox escape.**
Remove the previous recommendation to use it to widen MAS sandbox access; never promise
that selecting Home, `/`, or granting Full Disk Access unlocks the whole filesystem.
Persistent bookmarks can become stale or unusable; approvals are not guaranteed one-time.
For release signing use Apple's
[Developer ID](https://developer.apple.com/developer-id/) and
[notarization guidance](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).
Direct distribution still needs valid signing, hardened runtime, notarization and a
Gatekeeper-tested package; notarization does not guarantee MAS review approval.

##### Edition capability matrix — intended behavior and verification gates

“Retain / spike” means retain as the implementation goal and verify in WP7 before MAS
release; it is neither a claim of current sandbox support nor permission to drop it.

| Capability | Direct | Free MAS | Implementation / release gate |
|---|---|---|---|
| Dual panes, tabs/pins/history, sorting/filtering, themes, keyboard navigation, settings import/export | Retain all | Retain all | Grant-aware restored locations; unchanged core behavior (WP3, WP6, WP9). |
| Browse, create, rename, copy/move, duplicate, compare/sync, duplicate finder, folder size, metadata | Retain all | Retain all within authorized locations | Source/destination leases, conflict/rollback/partial-error behavior (WP6). |
| ZIP creation, inspection and extraction | Shared native implementation | Same shared native implementation | No shell-outs; archive safety, conflicts, progress and cancellation (WP4). |
| Command Runner | Retain | Compile out | Direct source membership and all invocation routes (WP5). |
| `.sh` execution via Terminal | Retain | Compile out | File browsing/copying remains; MAS must not fall through to execution (WP5). |
| Self-update / Sparkle | Direct only; initial inclusion undecided | Compile out; updates from Mac App Store | No MAS updater code, framework, helper or feed keys (WP5, WP10). |
| Eject network/removable volumes | Retain | Initially compile out | Keep enumeration/access; any later MAS eject requires its own documented policy and signed proof (WP5). |
| Quick Look and Finder reveal | Retain | Retain / spike | Granted files, preview lifetime and brokered reveal (WP7). |
| Open With, sharing, ordinary document opening and `.app` launch | Retain | Retain / spike | Supported workspace/share APIs, no shell/AppleScript workaround (WP7). |
| Finder tags and Spotlight/deep search | Retain | Retain / spike | Grant-scoped queries, read/write tags, inaccessible results (WP7). |
| iCloud Drive, OneDrive and removable-volume file management | Retain | Retain / spike | Provider/offline/reconnect/grant lifecycle; eject is separate (WP7). |
| Trash and undo; internal/external drag/drop | Retain | Retain / spike | Access lifetime, safe restore, partial failures and denied destinations (WP7). |
| Mounted shares, Connect to Server, SMB/AFP, pinned reconnect, Bonjour | Retain | Retain / spike, individually | Separate mount/access/discovery tests and minimum networking permissions (WP7). |
| Help/FAQs, remaining current features and OS-conditional features | Retain | Retain wherever supported | Inventory remaining source/UI paths; preserve existing OS availability checks (WP3, WP8, WP9). |

##### Dependency-ordered work packets

Implement serially in this checkout, with small reviewable commits. Dependency graph:
WP0 → WP1 → WP2 → WP3 → WP4 → WP5 → WP6 → WP7 → WP8 → WP9 → WP10.
WP1/WP2 share an integration gate: remove the mutating build phase in WP2 before
building the new app targets. Introduce WP9's SPM selector with WP1's compilation flags
and evolve its exclusions with WP5; grow all other checks with each packet.
Direct may ship after its applicable WP9/WP10 gates while MAS spikes/review continue;
MAS ships only after every MAS gate is resolved. No implementation, build bump or new
test result is claimed by this documentation-only plan.

**WP0 — identity, enrollment and signing prerequisites.**

- Areas: Apple Developer account/App Store Connect; future signing configuration in
  `project.yml`, and a proposed `Docs/Distribution.md` for non-secret identifiers and
  release instructions. Confirm developer-program enrollment and Team ID. Reserve distinct
  explicit IDs using the chosen vendor prefix, for example `<vendor>.DuPane` (MAS) and
  `<vendor>.DuPane.Direct` (Direct); these are placeholders, not final IDs.
- Provision Apple Development signing for development/sandbox tests; Developer ID
  Application for Direct; the Apple-supported Mac App Store application distribution
  identity/profile and installer identity where required by the upload/export method.
  Keep private keys, profiles and App Store Connect credentials out of Git and limit CI
  access to protected release jobs. Do not reuse Developer ID signing for MAS delivery.
- Verification / acceptance: verify installed signing identities against the chosen team;
  record bundle/profile/certificate mappings and expiry/renewal ownership. Both explicit
  IDs must be available and provisionable before signed testing. Separate identities and
  matching export methods are a release gate, not an ad-hoc-signing substitute.

**WP1 — two XcodeGen targets, schemes, settings, Info and entitlements. Depends on WP0.**

- Areas: `project.yml`, generated `DuPane.xcodeproj/project.pbxproj`,
  `Resources/Info.plist`, `Resources/DuPane.entitlements`; proposed
  `Resources/Direct/Info.plist`, `Resources/Direct/DuPane.entitlements`,
  `Resources/MAS/Info.plist`, `Resources/MAS/DuPane.entitlements`. Factor common XcodeGen
  settings/source definitions, with explicit per-edition overrides and separate products.
  Keep macOS 13+ support, shared assets and bundled HTML help. Remove obsolete resource
  files/references once the split is complete.
- Define mutually exclusive `DIRECT_BUILD` / `MAS_BUILD` Swift compilation conditions
  in Debug and Release; fail compilation if both or neither are set. Configure bundle
  IDs, names, Info paths, signing/profile settings and entitlements independently.
  MAS starts with `com.apple.security.app-sandbox`,
  `com.apple.security.files.user-selected.read-write`, and
  `com.apple.security.files.bookmarks.app-scope` true. Direct remains unsandboxed with
  hardened runtime. No blanket file-access, temporary-exception, automation or network
  entitlements by default. Privacy usage descriptions do not grant sandbox access.
- Verification / acceptance: `xcodegen generate`, inspect generated source membership and
  `xcodebuild -showBuildSettings` for both schemes/configurations; after WP2, rebuild both
  and inspect built Info plists and effective signed entitlements. Install/run both simultaneously;
  verify isolated defaults/container data and correct help resources. Generated project
  must match `project.yml`; MAS Release must actually be sandboxed. Reopen Xcode after
  structural edits when implementation resumes through the normal repository workflow.

**WP2 — deterministic shared build numbering. Depends on WP1.**

- Areas: `project.yml`, `BuildNumber.txt`, proposed `Scripts/prepare-release.sh` and
  generated build-settings file, `.github/workflows/ci.yml`, `Scripts/handoff-check.sh`,
  `CLAUDE.md`, `Docs/AGENT-WORKFLOW.md`. Remove the per-target “Increment Build Number”
  script and post-build Info stamping before building editions together.
- Make `BuildNumber.txt` the checked-in shared release value. One explicit release-prep
  operation increments it once per release candidate, atomically, and records it in the
  release commit. Preparation emits the same read-only `CURRENT_PROJECT_VERSION` input
  for both targets; Info plists use build settings before signing. Local/debug/no-op/
  clean builds and CI matrix jobs consume that value and never increment or rewrite it.
  A replacement upload uses a new shared number; never reuse a submitted build number.
- Verification / acceptance: script tests cover invalid/missing numbers, serialized
  allocation, idempotent consumption and failed preparation. Build Direct→MAS, MAS→Direct,
  repeat/no-op/clean and parallel CI consumers: both artifacts report the same version and
  build; Git stays clean and signatures remain valid. Release manifest records commit,
  marketing version and build. Update About/manual/workflow numbering during implementation
  releases only; **this plan keeps Build 420 and `BuildNumber.txt` unchanged**.

**WP3 — central edition/capability model and service seams. Depends on WP2.**

- Areas: proposed `Models/AppEdition.swift`, `Models/AppCapabilities.swift` and service
  protocol files; `DuPaneApp.swift`, `Models/AppLaunchConfiguration.swift`,
  `Models/AppSettings.swift`, `Views/ContentView.swift`, `Views/GlobalToolbar.swift`,
  `Views/PaneView.swift`, `Views/SidebarView.swift`, `Views/SettingsView.swift`.
- Select the edition at compile time at the composition root. Introduce focused protocols
  for file-access leases, archive operations, workspace actions, volume discovery/eject,
  command execution and update delivery. Inject production implementations and test fakes;
  keep ordinary file operations shared. Direct-only implementations must not enter the
  MAS compile/link inputs. Runtime capability states may express missing grants, OS or
  provider support, but cannot enable code absent from the edition.
- Inventory menus, toolbar/context actions, shortcuts, notifications, restored settings,
  launch paths and background work against the matrix. Use one capability source for UI
  and dispatch; absent commands must not remain reachable by keyboard or saved state.
  Preserve unrelated functionality rather than wrapping entire shared views in a flag.
- Verification / acceptance: build-specific tests in `Tests/DuPaneUITests/Build<N>Tests.swift`
  cover both capability sets, unavailable actions, fake service errors and persisted
  Direct settings imported into MAS. No settings/receipt/license flag can turn MAS into
  Direct. Both compile modes must type-check without referencing excluded implementations.

**WP4 — shared native ZIP service. Depends on WP3; precedes removing ProcessRunner from MAS.**

- Areas: `Views/PaneView.swift`, `Models/ArchiveExtractionSafety.swift`,
  `Models/FileOperationService.swift`, `ViewModels/PaneState.swift`,
  `ViewModels/FileOperationProgressModel.swift`, proposed `Models/NativeArchiveService.swift`,
  `Package.swift` and `project.yml`. Select and pin a maintained in-process ZIP library
  compatible with macOS 13, both build systems, distribution licenses and sandbox use;
  verify real ZIP read/write support rather than assuming compression APIs provide it.
- Replace `/usr/bin/zip` and all `/usr/bin/unzip` listing/extraction calls for both editions.
  Parse entry metadata directly. Preserve zip-slip rejection (absolute paths, traversal,
  empty/dot components, backslashes, NUL), rejection of archive symlinks, intermediate-file
  conflicts, overwrite/skip/cancel choices, collision-safe output names and the stable
  `PaneState.pendingArchiveConflict` behavior across tab switches. Recheck destination
  containment against existing symlinks and changes between inspection and extraction.
- Preserve operation error reporting and cancellation semantics, and integrate native
  byte/entry progress with the shared progress model; current archive UI has limited
  progress and must not be described as already providing full byte progress. Use bounded
  streaming, cancellation checks and temporary/staged output; clean partial new output
  and protect pre-existing content on failure/cancel. Keep scopes alive through cleanup.
- Verification / acceptance: fixtures cover nested/empty/Unicode/hidden files, large ZIPs,
  corrupt/truncated archives, hostile paths/symlinks, intermediate conflicts, tab switches,
  cancellation mid-read/write and existing-file preservation. Round-trip both editions
  and external ZIP tools; explicitly report unsupported formats/encryption. No runtime
  zip/unzip process remains; signed MAS round-trip within granted roots passes WP6/WP9.

**WP5 — isolate Direct-only code and dependencies. Depends on WP4.**

- Areas: split `ProcessRunner`, `ProcessExecutionResult` and errors out of
  `Models/FileOperationService.swift` into proposed `Direct/ProcessRunner.swift`; move
  `Views/CommandRunnerView.swift` and Terminal-launch implementations from
  `Views/PaneView.swift` / `Views/SidebarView.swift` into Direct source membership.
  Extract eject from `Models/NetworkVolumeMonitor.swift` into a Direct volume service,
  retaining shared enumeration, mount notifications and connection/discovery behavior.
  Update toolbar, menu, shortcut, state and service call sites via WP3.
- `project.yml` must exclude Direct files from MAS compilation and omit Sparkle linkage,
  embedding, helpers, resources, feed/public-key Info entries and updater startup there.
  If Sparkle is selected, add a Direct-only adapter/package product and preserve a manual
  download path. Do not add a MAS shell, external helper or Terminal/AppleScript workaround.
  MAS may view/copy `.sh` files but must not execute them through a generic-open fallback.
- Verification / acceptance: keep Direct process timeout/cancellation/output-drain tests
  and eject-failure sidebar tests. Add MAS UI/dispatch absence tests for every restricted
  action, including `.sh` in pane/sidebar and imported settings. Audit Debug and Release
  compile inputs, link maps, executable symbols/selectors and embedded bundles for
  ProcessRunner, process-launch calls, Terminal launch, eject and Sparkle. Strings alone
  are not proof of absence. A hidden-but-linked implementation fails the MAS release gate.

**WP6 — MAS grants, security-scoped bookmarks and all file operations. Depends on WP5.**

- Areas: proposed `MAS/FileAccessGrantStore.swift` and `MAS/SecurityScopedAccessService.swift`,
  Direct access adapter; `Models/SidebarModel.swift`, `Models/AppLaunchConfiguration.swift`,
  `ViewModels/PaneState.swift`, `ViewModels/TabbedPaneState.swift`,
  `Models/FileOperationService.swift`, `Models/FolderCompareService.swift`,
  `Models/SmartMetadataService.swift`, duplicate/folder-size view models, `Views/ContentView.swift`,
  `Views/PaneView.swift`, `Views/SidebarView.swift`, `Views/SettingsView.swift`, `DuPaneApp.swift`.
- Provide first-use and later **Add Folder Access** via `NSOpenPanel`, plus grant management
  and reauthorization. Persist `.withSecurityScope` bookmark data per edition; resolve
  with security scope, refresh stale data, and acquire/release access in balanced,
  concurrency-safe leases using `startAccessingSecurityScopedResource()` and matching
  `stopAccessingSecurityScopedResource()` for successful acquisitions. A lease covers
  async work, callbacks, enumeration, previews,
  file coordination and cleanup; every success, error and cancellation path releases it.
  Preserve unavailable/offline locations for retry instead of pruning them as nonexistent.
- Separate navigation bookmarks/pins from authority grants. Restored tabs, recents, Places,
  Go to Folder, Computer root, launch arguments and imported paths are hints, not grants.
  Offer a picker when access is missing; cancellation leaves the current pane usable.
  Do not treat a successful `fileExists` or prefix string match as proof of access. Resolve
  symlink targets and volume boundaries safely; explicitly authorize additional roots.
- Apply leases to source and destination/parent directories for create, rename, move/copy,
  duplicate, delete/undo, compare/sync and archive operations, plus background metadata,
  search and scans. Keep existing rollback/conflict/partial-success semantics. Distinguish
  missing grant, read-only media, TCC denial, unavailable provider and missing file;
  report failures without silently dropping entries or promising elevation. Settings
  import/export uses panel-authorized files and never exports/transfers bookmark authority.
- Verification / acceptance: fake grant-store tests cover stale/failed resolution, overlapping
  leases, cancellation, relaunch, move/revoke/offline and both-endpoint access. Signed MAS
  tests begin with empty container/no grants: deny, cancel, grant one folder, access its
  descendants, deny a sibling, then grant a second root and transfer between panes.
  Relaunch and upgrade must retain valid grants; invalid grants trigger recovery without
  data loss. Test with Full Disk Access off; it is never a prerequisite or sandbox bypass.

**WP7 — signed sandbox feature spikes and least privilege. Depends on WP6.**

- Areas: workspace/volume services from WP3; `Views/QuickLookCoordinator.swift`,
  `Views/PaneView.swift`, `Views/SidebarView.swift`, `Views/RowMouseEventView.swift`,
  `Models/DragSession.swift`, `Models/SidebarModel.swift`, `Models/SmartMetadataService.swift`,
  `Models/NetworkVolumeMonitor.swift`, `ViewModels/PaneState.swift`,
  `Models/FileOperationService.swift`, MAS Info/entitlements; proposed
  `Docs/SandboxFeatureEvidence.md` and signed integration fixtures.
- Run the actual Apple Development-signed, sandbox-entitled MAS app outside the debugger
  in a clean test account, then repeat critical cases with the TestFlight build. Cover
  macOS 13 where supported and the current release, fresh/remembered/denied grants,
  relaunch and asynchronous completion. An unsigned build or SPM test is not sandbox proof.
  Record OS, signing identity, effective entitlements, commit/build, steps, expected/actual
  results and relevant sandbox logs for each capability; redact personal file paths.
- Test each row separately; passing one brokered API does not prove another works:

| Spike | Required scenarios and acceptance |
|---|---|
| Quick Look | Single/multiple granted files, selection changes, close/reopen, cloud placeholder and denied file; retain scope for preview lifetime, no stuck panel or leaked leases. |
| Finder reveal | Reveal selected granted files and missing/offline files with `activateFileViewerSelecting`; correct selection or actionable failure. |
| Open With / share / `.app` launch | Default opening, enumerated and panel-selected apps, multiple documents, share completion/cancel and app double-click through supported APIs; successful brokered access without enabling `.sh` execution. |
| Tags | Read/add/remove tags, multi-selection, denied writes and provider support; UI reflects actual result and retains tag filters. |
| Spotlight / deep search | Scope queries to granted roots, handle unindexed roots and inaccessible results, cancel/close tabs safely; do not advertise whole-disk results when only granted roots are searchable. |
| iCloud / OneDrive | Discover/select provider roots without assuming `NSHomeDirectory()` is the real home; online-only hydration, offline errors, coordinated copy/rename/sync, reconnect and changed provider paths. Do not add iCloud container entitlements merely to browse user-selected files. |
| Removable volumes | Enumerate, grant, read/write/copy, read-only media, unplug during work, remount and restore grants; preserve sidebar stability. Eject remains Direct-only. |
| Trash / undo | Granted source to system Trash, undo to original parent, occupied destination, partial deletion and volume-specific Trash; prove authority survives for undo. Never substitute permanent delete. A failing undo needs a supported safe solution or documented evidence before narrowing capability. |
| Drag/drop | Between panes and from/to Finder or another sandboxed app, files/directories and supported promised-file paths, copy/move modifiers, denied destination and cancellation; hold brokered access through transfer without treating arbitrary pasted paths as grants. |
| SMB / AFP | Existing mounted-share enumeration and grant, `NSWorkspace.open` Connect to Server, cancel/failed authentication, pinned reconnect, offline timeout and file operations; test SMB and AFP separately using available servers. Missing test infrastructure is “unverified,” not evidence to remove a feature. |
| Bonjour | `_smb._tcp` and `_afpovertcp._tcp` discovery, resolve, denied/revoked local-network permission, stop/restart and disabled setting; no stalled UI or background browse after cancellation. |

- Start networking spikes without network entitlements; isolate what the app itself needs
  versus Finder/system services. Add `com.apple.security.network.client` only if a retained
  path needs outgoing sockets and signed evidence proves it; add
  `com.apple.security.network.server` only if necessary incoming behavior is demonstrated.
  Do not enable both speculatively. Local-network privacy declarations/consent are separate
  from App Sandbox entitlements: apply `NSLocalNetworkUsageDescription` and `NSBonjourServices`
  for proven local-network/Bonjour use on the relevant OS, following
  [TN3179: Understanding local network privacy](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy).
  No guessed “local network” or multicast entitlement; record each added permission's
  platform requirement, justification and denial test, and retest after removing extras.
- Acceptance / gate: every retained feature has signed passing evidence and graceful
  denial handling. A proposed restriction requires a cited Apple prohibition or recorded
  reproducible failure plus attempted supported alternatives, and narrows only the failing
  operation. Unverified capabilities block MAS release until tested; they are not silently
  cut. Update the matrix and review notes to match the evidence.

**WP8 — edition UX, migration and documentation. Depends on WP7.**

- Areas: `Views/SettingsView.swift`, `Views/GlobalToolbar.swift`, `Views/PaneView.swift`,
  `Views/SidebarView.swift`, `DuPaneApp.swift`, `Models/AppSettings.swift`,
  `Docs/UserGuide.html`, `Docs/FAQs.html`, `Docs/README.md`, root `README.md` as applicable,
  and proposed distribution/evidence docs. About shows edition, version and the shared
  build. MAS onboarding explains folder access and recovery; Direct keeps full commands.
- Describe free pricing, factual capability differences and Store versus Direct updates.
  Remove dead controls/shortcuts; avoid purchase/upgrade/license prompts. Explain grants,
  provider limitations and TCC separately, with no Full Disk Access sandbox workaround or
  promise of permanent approval. Settings export/import may transfer preferences and path
  hints between editions, but MAS reauthorizes access; changing from `local.DuPane` must
  not silently abandon existing users' settings without a documented export/import path.
- Verification / acceptance: inspect both editions' onboarding, menus, About, keyboard
  accessibility and bundled help from installed apps on a machine without the checkout.
  Every matrix difference and grant-recovery path is accurate; no inaccessible control
  remains. Update guide/build strings in implementation releases, not in this plan commit.

**WP9 — dual-target unit, e2e and CI gates. Depends on WP8; develop checks throughout.**

- Areas: `Package.swift`, `Tests/DuPaneUITests/Build<N>Tests.swift` (and
  `Build<N>BugTests.swift` for bug regressions), `UITests/DuPaneEndToEndUITests/`,
  `Scripts/run-e2e.sh`, `Scripts/handoff-check.sh`, `project.yml`, `.github/workflows/ci.yml`.
  Give SPM an explicit edition selector that sets the matching compilation condition and
  excludes Direct sources/dependencies for MAS; default/document Direct and reject invalid
  modes. Use distinct scratch paths and edition-conditional process/eject tests, preserving
  shared coverage in both runs. Fake-service tests do not replace signed acceptance.
- Run `swift test --filter DuPaneUITests` in each edition environment. Parameterize the
  e2e wrapper, UI-test host target/bundle identity, result logs, result bundles and build
  directories per scheme; retain exit-status propagation and machine-readable markers.
  Exercise the existing critical flows for both apps and add MAS picker/relaunch/denial,
  cross-root operations, archive safety, restricted-action absence and coexistence tests.
- CI must regenerate/check the XcodeGen project, build both schemes/configurations, run
  both unit modes, audit source/dependency/binary membership and effective entitlements,
  and verify shared version/build values without dirtying Git. Run signed e2e/integration
  on a suitable macOS runner with required user session, accounts/devices/providers;
  keep release credentials out of untrusted PR jobs. Unsigned PR compilation is useful
  but cannot satisfy the signed release gate. Required skips count as unresolved.
- Acceptance / gate: retain all relevant existing regressions, all new tests pass, no
  unexplained skips, no MAS forbidden code/dependencies, correct sandbox/signing and
  reproducible numbering; attach separate edition results to the release candidate.
  **Baseline remains Build 420: 336 unit / 14 e2e passed, 0 failed.** These are historical
  single-target results, not evidence that either proposed target has passed. This
  docs-only edit uses `git diff --check` and diff inspection, with no compilation/e2e rerun.

**WP10 — packaging and delivery. Depends on applicable WP9 gates.**

- Areas: proposed release scripts under `Scripts/`, protected release workflow under
  `.github/workflows/`, `project.yml` archive/export settings, distribution instructions,
  GitHub/website artifacts and App Store Connect. Archive both products from the same
  commit and WP2 version/build inputs; retain artifact checksums, signing information,
  test evidence and export/notarization logs.
- **Direct:** sign app and all embedded code with Developer ID Application and hardened
  runtime; package as a DMG, submit with `notarytool`, inspect successful completion,
  staple/validate the ticket on supported artifacts, and verify code signature and
  Gatekeeper assessment. Smoke-test a quarantined download on a clean Mac without
  clearing quarantine, including commands, ZIP, eject and grants/TCC error behavior.
  If Sparkle ships, sign update artifacts, validate feed/signature keys and test an actual
  old→new update; otherwise publish manual download/update instructions. App replacement
  must preserve Direct settings and cannot overwrite the MAS app.
- **MAS:** create the App Store Connect record for its own bundle ID, set price to free,
  configure no IAP products, prepare screenshots, support/privacy URLs, App Privacy
  answers, required dependency privacy declarations and review notes explaining grants.
  Archive/export with the correct Store signing/profile, validate/upload and distribute
  via TestFlight. Prove fresh install and update retain identity/settings/bookmarks;
  repeat critical signed tests, then submit for App Review with reproducible sample-folder
  steps and explanations for necessary entitlements. Resolve validation/review findings
  before release; TestFlight success does not guarantee App Review approval.
- Acceptance / release gates: Direct requires valid signatures, accepted notarization,
  stapling/Gatekeeper and clean-machine smoke tests; MAS requires upload validation,
  passing TestFlight evidence, approved review, free pricing/no gates and Store-only
  updating. Both require accurate edition docs, matrix/evidence closure, matching release
  manifest and clean handoff. A release blocked in one channel need not block a separately
  qualified Direct release, but must not be described as delivered.

##### Only remaining product/identity decisions

- **Vendor/reverse-DNS prefix and Apple Team ID** for the two permanent bundle IDs and signing.
- **Final display names** — recommend **DuPane** (MAS) and **DuPane Direct**.
- **Whether Sparkle ships in the first Direct release** or follows a manual-download launch.

All other items above are implementation tasks or evidence-based release gates, not open
pricing, edition-scope, licensing or distribution-model decisions.


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
