# DuPane — Functional Review

**Build reviewed:** 421.6 (Internal Test) · **Date:** 16 September 2026 · **Revision:** 3
**Findings:** 47 — 11 defects, 7 test-coverage items, 29 documentation and process items
**Scope:** behavioural defects first; test coverage second; `Docs/UserGuide.html` corrections third

---

## Terms of reference — changed mid-review

This began as a review of `Docs/UserGuide.html`. It is now primarily a **functional and defect
review**, with guide corrections as a secondary output. The change happened because of what the
work turned up.

The guide describes, in precise terms, what DuPane is supposed to do: what each toolbar button
does, what each dialog offers, what each shortcut is bound to, what each setting defaults to. That
makes it an unusually good **test script**. Walking its claims against the Swift source and then
against the running app — rather than proofreading the prose — turned every documented promise into
an assertion, and eleven of those assertions failed against the app rather than against the prose.

Priority order:

1. **Defects** (`BUG-01`…`BUG-11`) — behaviour that is wrong, unsafe, or contradicts a documented
   promise. Code changes.
2. **Test coverage** (`TEST-01`…`TEST-07`) — working surface that no test touches, so nobody knows
   whether it still works. Test-writing tasks, not fixes.
3. **Guide corrections** (`DOC-`, `WEB-`) and **process** (`PROC-`) — worth doing, lower priority.
   In several cases the right fix is to change the app so the guide becomes true, rather than to
   soften the guide.

### Revision history

**Revision 1** was a documentation review (`Docs/UserGuide-Review.md`).

**Revision 2** re-scoped to a functional review and renumbered: former section A → `BUG-`,
B → `DOC-`, C → `WEB-`, D → `PROC-`. It also carried a correction. Revision 1 had claimed the
right-click menu surface had no test coverage — inferred from test *filenames* rather than checked.
That was wrong: `DuPaneEndToEndUITests.swift` drives context menus in two places and holds 26 XCUI
cases. Checking properly **retracted part of `BUG-05`** (the Undo control is a real, identified,
already-tested button) and **narrowed `BUG-04`** (the shortcut-versus-text-field boundary is
deliberate and tested for sheet fields).

**Revision 3** (this one):

- The coverage gap, previously a bare table plus a single `PROC-03`, is now a **`TEST-` series** of
  seven items, each recommending **UI tests, unit tests, or both**, and each living in Part 2 where
  the coverage analysis is. `PROC-03` no longer exists.
- Part 5 retitled from "Coverage and process" to "Process", since coverage moved out.
- Every finding gained an **In plain terms** line — one sentence, no jargon — so the report can be
  skimmed by someone who isn't going to read the code.
- Part 2 gained a **harness reference**: the accessibility identifiers, helper functions and
  fixtures that already exist, so a developer or agent can write the proposed tests without
  re-deriving the conventions.
- Consistency sweep: finding counts corrected throughout (47, not 40 or 41); the regression-test
  count in the summary corrected from "eight end-to-end, three contingent" to four writable now and
  four contingent on a fix; `BUG-05`'s severity is 5 in both copies of this report.

### How each finding is annotated

| Field | Meaning |
| --- | --- |
| **In plain terms** | One sentence, no jargon. What it means for someone using DuPane. |
| **Status** | `Confirmed` — reproduced directly. `Needs manual confirmation` — observed through background accessibility automation, which can behave differently from a real mouse. |
| **Confirm by** | The manual test to run before committing effort, where one is needed. |
| **Regression test** | The automated test to add once fixed, and where it belongs. |
| **Test type** (`TEST-` items only) | UI, unit, or both — and any prerequisite. |

---

## Executive summary

DuPane is in better shape than a 47-item list implies. Nothing here suggests the architecture is
wrong, and several things the guide describes loosely turned out to be *more* rigorous in the code
than in the prose. What the review found is a cluster of safety gaps around destructive actions,
plus one class of problem the guide could never catch alone: promises about behaviour nobody has
tested since the behaviour changed.

The five that matter most:

1. **`BUG-01` — The Duplicate Finder can trash files it has not proved are duplicates**, with no
   confirmation and no undo. It matches on a 64-bit non-cryptographic hash and never compares
   bytes, while `FolderCompareService` — in the same codebase — already does the byte comparison
   properly.
2. **`BUG-03` — The Command Runner's shell never reads `.zshrc`**, so aliases and shell functions
   silently do not exist. The guide promises them by name.
3. **`BUG-02` — Sidebar clicks appear to do nothing while the right pane is active.** Reproduced
   three times; needs thirty seconds of manual confirmation before anyone chases it.
4. **`BUG-04` — ⌘V performs a move, not a paste**, and the pane-level text fields may not be
   protected from the global shortcuts.
5. **`BUG-05` — Delete's undo has no menu equivalent and expires silently** — and the confirmation
   dialog is off on this profile, so that fading toast is the only protection there is.

**Numbers.** Two of the eleven defects need manual confirmation first (`BUG-02`, `BUG-04`); nine
are confirmed. Eleven regression tests are proposed against the defects — four writable now
(`BUG-02`, `BUG-04`, `BUG-07`, `BUG-09`), four contingent on a fix landing first (`BUG-01`,
`BUG-05`, `BUG-06`, `BUG-10`), and three at service level (`BUG-01`, `BUG-03`, `BUG-08`). Separately,
seven `TEST-` items cover surface that has no test at all.

---

# Part 1 — Defects

## BUG-01 — Duplicate Finder trashes files it has not verified, with no confirmation and no undo
**Severity 9/10 — Critical · Status: Confirmed**

**In plain terms.** The tool that finds duplicate files can delete them on one click, with no "are
you sure", no undo, and without having fully checked that the files really are identical.

**Confirm by:** not required — reproduced directly.
**Regression test:** *Unit* — assert `DuplicateFinderViewModel` never groups two files whose
contents differ (same-size, different-content fixtures → empty group set), and that verification
runs on every candidate pair. *E2E* — assert the row trash icon and Keep First both present a
confirmation sheet, and that cancelling leaves the file on disk. **Prerequisite:**
`DuplicateFinderView.swift` contains no `accessibilityIdentifier` calls at all, so the E2E test
needs identifiers added to the group header, the row trash button and the Keep First button first.

**Observation.** `DuplicateFinderView.swift:140` calls `viewModel.moveToTrash(url)` straight from
the row's trash icon; `Button("Keep First", action: onKeepFirst)` at line 215 trashes every copy in
a group but the first. Neither path presents an alert, and the file contains no undo. Matching comes
from `fnv1a64` (`DuplicateFinderViewModel.swift:212`) over same-size files, with no byte comparison
anywhere. Live test: the scan correctly found a three-copy group including one copy in a subfolder,
and correctly ignored two same-size files with different contents — but every row carried a
one-click trash icon and the footer read "2 duplicates · 74 bytes wasted".

**Recommendation.** Add a byte-for-byte verification pass over candidates sharing a hash —
`FolderCompareService.contentsMatch` (line 258) already implements exactly this in 1 MB chunks and
can be lifted. Then put a confirmation sheet listing full paths in front of both the trash icon and
Keep First, and reuse the delete path's toast-undo mechanism.

**Reason.** This is the only destructive action in DuPane with neither a confirmation nor an undo,
and it acts on a match the app has not proved. FNV-1a is a 64-bit non-cryptographic hash. The
ordinary Delete button has both safety nets, so the riskiest bulk operation is the least protected
one.

## BUG-02 — Sidebar navigation does nothing while the right pane is active
**Severity 9/10 — Critical · Status: Needs manual confirmation**

**In plain terms.** Click a shortcut in the sidebar — Home, Documents — while the right-hand pane is
the active one, and nothing happens. It only seems to work for the left pane.

**Confirm by:** click a row in the right pane to make it active, then click **Places → Home** in the
sidebar. Expected: the right pane navigates home. Observed here: neither pane moves. Repeat with the
left pane active as a control — that works.
**Regression test:** *E2E* — activate the right pane, click a sidebar place, assert the right pane's
breadcrumb changed and the left pane's did not; then the mirror case. **Prerequisite:** sidebar
place rows have no accessibility identifiers (see `TEST-01`), so this needs one added, or the row
must be located by its label.

**Observation.** With the right pane active (focus ring visible on the right), clicking Places →
Home and Places → Documents navigated neither pane. Reproduced three times, using both an
accessibility press and a positional click, with and without a row selected. The same clicks drive
the left pane normally. The wiring reads correctly — `ContentView.swift:341` passes
`onNavigate: { url in active.navigate(to: url) }`, and `active` resolves through `activePane` at
line 63 (`activePane == .left ? leftTabs.activePaneState : rightTabs.activePaneState`) — so the
cause is not visible from the source alone.

**Recommendation.** Confirm manually first. If it reproduces, log `activePane` and the resolved
`PaneState` identity (`ObjectIdentifier`) inside the sidebar closure at the moment it fires, and
check whether `SidebarView` is holding a closure captured against an earlier pane rather than
re-reading `activePane` on each evaluation.

**Reason.** The guide promises "Click any location to navigate the active pane there instantly." If
the sidebar drives only one of two panes, the headline navigation affordance is half broken — and in
a dual-pane app the right pane is usually the destination.

## BUG-03 — The Command Runner's shell is non-interactive, so `.zshrc` aliases and functions never load
**Severity 8/10 — Critical · Status: Confirmed**

**In plain terms.** The built-in command bar doesn't know about your shell shortcuts. Type an alias
you use every day and it says "command not found", even though the same alias works in Terminal.

**Confirm by:** not required — reproduced directly.
**Regression test:** *Unit* — extract the shell invocation into a testable function and assert the
argument list contains both `-l` and `-i`. A shell-behaviour E2E test would be flaky; test the
arguments, not the output.

**Observation.** Run inside the Command Runner:

```
tmpclaudesource $ [[ -o login ]] && echo IS-LOGIN || echo NOT-LOGIN; \
                  [[ -o interactive ]] && echo INTERACTIVE || echo NON-INTERACTIVE

IS-LOGIN
NON-INTERACTIVE
```

`$PATH` came back fully populated (Homebrew, cryptexd, Chrome), so login files such as `.zprofile`
are read. `.zshrc` — where virtually everyone defines aliases and functions — is not, because zsh
sources it only for interactive shells. The guide states commands run in a login shell "so aliases,
path settings, and shell functions all work."

**Recommendation.** Either launch with `-i` as well as `-l` so `.zshrc` is sourced (accepting the
startup cost and the risk of interactive-only rc lines writing to stdout), or correct the guide to
say PATH and login-shell configuration apply but aliases and functions defined in `.zshrc` do not.

**Reason.** Aliases are the main reason a power user wants a shell inside the file manager, and the
guide promises them by name. The user's first `gst` or `ll` fails and the feature reads as broken
rather than limited.

## BUG-04 — ⌘C/⌘V are bound to pane transfers, and the pane-level text fields may not be protected
**Severity 8/10 — Critical · Status: bindings Confirmed; field conflict Needs manual confirmation**

**In plain terms.** ⌘V moves your files to the other pane instead of pasting. And typing in the
filter box, ⌘A selected every file in the folder rather than the text you'd typed.

**Confirm by:** click into a pane's **Filter…** field, type a few characters, then press ⌘A.
Expected: the field's text is selected. Observed here (in the Command Runner field): all files in
the pane were selected instead. Then, with the caret still in the field, press ⌘C and watch for a
copy toast — if one appears, the hijack extends to the destructive shortcuts.
**Regression test:** *E2E* — focus `<side>-filter-field` and `command-runner-field`, send ⌘A, assert
the pane's selection count is unchanged; repeat for ⌘C asserting no file operation ran. Model it on
`testCriticalCommandVPastesIntoCreationAndGoToFolderFields`, which already does exactly this for the
*sheet* fields.

**Narrowed in revision 2.** `testCriticalCommandVPastesIntoCreationAndGoToFolderFields` asserts that
⌘V pastes into `text-prompt-name-field` and `go-to-path-field` rather than moving files — so the
global-shortcut-versus-text-field boundary is a deliberate, tested design, not an oversight. The
gap, if it is one, is narrower than first stated: it concerns the **pane-level** fields
(`<side>-filter-field`, `command-runner-field`), which that test does not cover, not text fields in
general.

**Observation.** `ContentView.swift:427–429` binds ⌘C to "Copy to Other Pane" and ⌘V to "Move to
Other Pane". The guide separately documents right-click → **Copy** as placing files on the macOS
clipboard, so ⌘C and the menu item named Copy do different things, and ⌘V performs a move rather
than a paste. Separately: with the caret in the Command Runner field, ⌘A selected all 17 files in
the pane instead of the field's text.

**Recommendation.** Move pane transfers onto F5/F6 (already wired at `DuPaneApp.swift:221–224` via
`keyCode` 96/97/98/100) and/or ⌥⌘→ / ⌥⌘←, and give ⌘C/⌘V their standard clipboard meanings. If the
bindings stay, scope the hidden shortcut buttons so they do not fire while a `TextField` has focus,
and add an explicit warning callout to the shortcuts chapter.

**Reason.** Every Mac user has ⌘V wired in as a non-destructive paste. Having it move files is the
kind of surprise that costs someone data once and is never forgiven. A shortcut that steals ⌘A from
a text field also makes the filter and command fields feel subtly broken.

## BUG-05 — Delete's undo has no menu equivalent and expires silently
**Severity 5/10 — Medium · Status: Confirmed (reduced in scope in revision 2)**

**In plain terms.** After deleting a file you get an "Undo" message that disappears after a few
seconds. Miss it and there's no other way back — ⌘Z does nothing, and there's no Edit menu.

**Confirm by:** delete a scratch file and time how long the toast stays up before it fades.
**Regression test:** already covered for the core behaviour by
`testCriticalUndoAfterDeleteRestoresTheFile`. Add one case asserting Edit ▸ Undo performs the same
restore, once that menu exists (`BUG-06`).

**Partly retracted in revision 2.** Revision 1 claimed the Undo control was `AXStaticText` with no
accessibility action, and therefore unreachable by keyboard or VoiceOver. That was wrong.
`UITests/DuPaneEndToEndUITests/DuPaneEndToEndUITests.swift:526` addresses it as
`app.buttons["toast-undo-button"]`, waits for it to be enabled and hittable, clicks it, and asserts
the file returns both to the list and to disk. It is a real button with an identifier, and it works.
The automation click that reported `AXStaticText` landed on the toast's message label, not on the
button beside it.

**What survives.** There is no Edit ▸ Undo, because there is no Edit menu at all (`BUG-06`), so ⌘Z
does nothing after a delete and the only route to undo is a toast that fades. Note also that no
confirmation dialog appeared on either delete, meaning "Skip confirmation when deleting files" is on
for this profile; the guide documents that default as Off. For anyone running with that setting, a
fading toast is the entire safety net.

**Recommendation.** Add an Edit menu with Undo on ⌘Z bound to the same action, state the toast's
time limit in the guide, and consider keeping the toast up until dismissed when the deletion
confirmation is switched off.

**Reason.** The undo works and is tested; what it lacks is a second route. A safety net that exists
only for a few seconds, in one place, is one mis-timed click from being no safety net.

## BUG-06 — The menu bar is nearly empty, so no command in the app is discoverable
**Severity 7/10 — High · Status: Confirmed**

**In plain terms.** DuPane's menus are almost bare — no Edit, no Go. Every keyboard shortcut it has
is invisible unless you read the manual, and macOS can't find or remap them either.

**Confirm by:** not required — the menus were enumerated directly.
**Regression test:** *E2E* — assert `app.menuBarItems["Edit"]` and `["Go"]` exist and that a
representative item under each (Undo, Go to Folder) is enabled with the expected key equivalent.

**Observation.** The menus are: DuPane, File (New Window / Close / Close All), View (Enter Full
Screen), Window, Help. There is no Edit menu and no Go menu. Every documented ⌘ shortcut is a hidden
SwiftUI `Button` in `ContentView.keyboardButtons` (lines 383–441), so none appear in a menu and
macOS's own Help-menu command search finds nothing.

**Recommendation.** Add Edit, Go and File menus via `CommandGroup` mirroring the existing hidden
buttons — the actions already exist and need only menu entries.

**Reason.** On macOS the menu bar is where users learn an app, discover shortcuts, and where System
Settings ▸ Keyboard lets them remap keys. Without it, every feature lacking a toolbar button is
invisible unless the user reads the guide — whose shortcut table is itself incomplete (`DOC-07`).

## BUG-07 — The conflict dialog names no files and offers no way out
**Severity 6/10 — High · Status: Confirmed**

**In plain terms.** When a copy would overwrite something, DuPane asks what to do but doesn't tell
you *which* file, and there's no Cancel — you have to pick one of the three options.

**Confirm by:** not required. One open question remains — whether a single Overwrite choice applies
to a whole batch or is asked per file.
**Regression test:** *E2E* — extend `testCriticalCopyConflictDialogResolvesOverwriteSkipAndKeepBoth`
(which already covers all three buttons for the single-file case) with a multi-file case, using the
multi-select pattern from `testCommandClickAddsSecondRowToSelection`: assert the sheet names the
conflicting files, offers Cancel, and that the stated count matches the files actually affected.

**Observation.** Copying a conflicting file produced a sheet titled "Items Already Exist", reading
"1 item already exists in 'tempclaudetarget'. Choose how to handle the conflict.", with
**Overwrite**, **Skip** and **Keep Both**. No filenames, no Cancel. Keep Both produced
`conflict 2.txt`, exactly as documented.

**Recommendation.** List the conflicting names (scrolling for large batches), add a Cancel button,
and bind Escape to it. If a batch choice applies to every conflict at once, say so in the sheet's
copy.

**Reason.** Overwrite is irreversible — it does not go through the Trash — and the user is asked to
choose it without being shown what they are about to replace, with no way to abort an operation
already started.

## BUG-08 — Compare reads every byte of every same-size pair, with no progress indication
**Severity 5/10 — Medium · Status: Confirmed (in source)**

**In plain terms.** Comparing two folders full of large files will read every byte of both, with
nothing on screen to say it's working. On a big folder it will look frozen.

**Confirm by:** compare two folders holding several same-sized large files (a few hundred MB each)
and time it. The fixture folders were far too small to show the cost.
**Regression test:** *Unit* — `FolderCompareServiceTests.swift` already covers this service; add a
case asserting a cancellation token stops `contentsMatch` mid-file, and one asserting comparison is
skipped when sizes differ.

**Observation.** `FolderCompareService.contentsMatch` (line 258) reads both files in 1 MB chunks via
`FileHandle.readData(ofLength:)` for every same-name, same-size, same-kind pair before deciding
newer/older. Instant on the fixture folders; on two folders of large media files it reads both
folders end to end.

**Recommendation.** Keep the accuracy — it is the right call — but show progress while it runs (the
folder-size scanner already has a pattern) and allow cancellation. Say in the guide that Compare
verifies contents, not just metadata.

**Reason.** Users expect Compare to be a metadata operation and therefore instant. A silent
multi-gigabyte read reads as a hang, and someone will force-quit during it.

## BUG-09 — Compare mode truncates the toolbar to unreadable stubs
**Severity 4/10 — Medium · Status: Confirmed**

**In plain terms.** Turn on Compare and the toolbar buttons get squeezed into unreadable fragments —
including the two new buttons that copy files between folders.

**Confirm by:** repeat manually at three window widths (1,100 / 1,470 / full screen) to find the
threshold before choosing a fix.
**Regression test:** *E2E* — at a fixed narrow window size, enter Compare mode and assert
`toolbar-sync-left-to-right-button` and `toolbar-sync-right-to-left-button` expose their full labels
to accessibility.

**Observation.** Entering Compare adds **Sync L→R** and **Sync R→L**. At a 1,470-point window the
labels degrade to "New Fo…", "Compa…", "Sync L-…", "Bookma…", "Termi…" — two truncated far enough
that the accessibility layer reported no usable title.

**Recommendation.** Below a width threshold, collapse to icons with tooltips, or move the least-used
buttons (Bookmark, Follow) into an overflow menu so the Sync pair keeps full labels.

**Reason.** The two buttons appearing only in Compare mode are the ones a user has never seen, they
are directional, and they write files — precisely the wrong labels to clip.

## BUG-10 — Panes do not notice changes made outside the app
**Severity 4/10 — Medium · Status: Confirmed**

**In plain terms.** If something else on your Mac adds or removes a file in a folder DuPane is
showing, DuPane won't notice until you hit refresh.

**Confirm by:** not required — reproduced directly.
**Regression test:** *E2E* — with a folder open, create a file in it from outside the app and assert
it appears within a few seconds without user action. Only meaningful once a watcher exists.

**Observation.** A file created in an open folder by another process did not appear until Refresh
was clicked. The guide documents ⌘R and the refresh button but never says the view is a snapshot.

**Recommendation.** Add an `FSEvents` watcher per `PaneState` with coalesced reloads; failing that,
say plainly in the guide that panes show a snapshot and name ⌘R as the way to update it.

**Reason.** DuPane ships a shell that changes files in the folder being displayed. A stale list next
to a live terminal is a contradiction users hit within minutes.

## BUG-11 — The Settings window opens far smaller than its content
**Severity 3/10 — Low · Status: Confirmed**

**In plain terms.** The Settings window opens too short for what's in it, so a lot of the options
are below the fold and easy to miss entirely.

**Confirm by:** open Settings on a clean profile to check the default frame — the window may have
remembered a size here.
**Regression test:** none worth writing; this is a layout constant, better caught by looking at it.

**Observation.** The window opens around 450 pt tall against roughly 1,650 pt of form content
(`SettingsView` sets `.frame(width: 460)` with no height), presented as one long scroll.

**Recommendation.** Give the window a taller default height, or split the form into tabs (Files,
Display, Appearance, Sidebar, Startup) — which would also make the guide's "Settings → …" phrasing
true (`DOC-02`).

**Reason.** Startup Folders, one of the most-referenced settings in the guide, sits at the bottom of
a scroll most users will not realise is there.

---

# Part 2 — Test coverage

## What the suite already covers

Worth stating first, because it changes what is actually missing.
`UITests/DuPaneEndToEndUITests/DuPaneEndToEndUITests.swift` holds 26 XCUI cases and drives
**right-click context menus** in two places (`rightClick()` at lines 172 and 684). It already
asserts:

- the context menu opening on a file row with Open, Rename…, Reveal in Finder
  (`testRightClickShowsContextMenu`);
- Compress → Uncompress as a full round trip through that menu
  (`testCriticalArchiveRoundTripThroughContextMenu`);
- Get Info… and Show Folder / File Sizes opening their panels
  (`testMediumPropertiesAndFolderSizePanelsOpen`);
- the column-header menu listing every column with state-aware Move Left / Move Right / Minimum
  Width / Maximum Width including disabled states
  (`testMediumColumnPickerListsAllColumnsAndStateAwareActions`);
- ⌘-click and ⇧-click multi-selection (`testCommandClickAddsSecondRowToSelection`,
  `testShiftClickExtendsSelectionToRange`);
- the copy-conflict dialog resolving through Overwrite, Skip and Keep Both;
- undo after delete, asserting the row returns *and* the file is back on disk;
- ⌘V pasting into sheet text fields rather than moving files;
- Compare → Sync L→R; and the Duplicate Finder scanning and grouping.

Service-level coverage in `Tests/DuPaneUITests/` includes `FolderCompareServiceTests`,
`ArchiveCompressionServiceTests`, `FollowModeTests`, `DeepSearchTests`, `KeyboardNavigationTests`,
tag filtering (`DuPaneFunctionTests:200`), bookmark model operations (`DuPaneFunctionTests:1162`)
and network-volume eject logic (`BugAuditTests:249`), plus per-build regression files from
Build 268 through Build 418.

## Harness reference

For whoever writes the tests below.

**Two targets.** Service-level tests are plain XCTest with `@testable import DuPane`, base class
`DuPaneTestCase`, fixtures `FilePaneFixture` / helper `makeItem(name:pane:size:modified:)` — see
`FolderCompareServiceTests.swift`. End-to-end tests are `bundle.ui-testing`
(`UITests/DuPaneEndToEndUITests`, `TEST_TARGET_NAME: DuPane`), run through the DuPane scheme in
Xcode; under SPM they `XCTSkipUnless` cleanly when `DuPane.app` isn't built alongside the bundle.

**Existing E2E helpers** (all `private` in `DuPaneEndToEndUITests.swift`): `launchApp(additionalArguments:)`,
`row(named:in:)`, `waitForRow(named:in:)`, `waitForMissingRow(named:in:)`, `clickRow`,
`doubleClickRow`, `rightClickRow`, `clickToolbarButton(_ identifier:)`, `goToPath(_:in:)`,
`expectSelected(_:in:)`, `replaceText(in:with:)`, `copyConflictingFile(named:choosing:)`,
`waitForSelection`, `waitForSheetToDismiss`, `waitForCreationPromptToDismiss`.

**Accessibility identifiers that exist.** Panes and rows: `<side>-pane`, `<side>-pane-file-list`,
`<side>-pane-status`, `<side>-file-row-<name>`, `<side>-column-header`, `<side>-column-<title>`,
`<side>-filter-field`, `<side>-deep-search-button`, `<side>-tab-<index>`,
`<side>-close-tab-<index>`, `<side>-new-tab-button`. Toolbar: `toolbar-new-folder-button`,
`-new-file-button`, `-move-button`, `-copy-button`, `-compare-button`, `-compare-summary`,
`-delete-button`, `-rename-button`, `-duplicates-button`, `-bookmark-button`, `-terminal-button`,
`-follow-button`, `-sync-left-to-right-button`, `-sync-right-to-left-button`. Sheets and chrome:
`text-prompt-name-field`, `text-prompt-confirm-button`, `text-prompt-cancel-button`,
`creation-prompt-overlay`, `go-to-path-field`, `go-to-path-confirm-button`,
`go-to-path-cancel-button`, `go-to-path-overlay`, `command-runner-field`,
`command-runner-run-button`, `file-op-progress`, `toast-undo-button`, `sidebar-tag-<name>`.

**Identifier gaps that block tests below.** `SidebarView.swift` has exactly one identifier
(`sidebar-tag-<name>`) — place rows, bookmark rows, Recents rows, Locations rows and Network rows
have none. `DuplicateFinderView.swift` has none at all. Both need identifiers before their UI tests
can be written; that is the first task in `TEST-01` and `TEST-04`.

## Regression tests for the defects

Prove a fix and stop it regressing. Suggested home: `Tests/DuPaneUITests/Build422BugTests.swift`
for service-level, `UITests/DuPaneEndToEndUITests/` for the rest.

**Writable now:** `BUG-02` (sidebar drives the active pane, both directions), `BUG-04` (⌘A/⌘C in the
pane-level fields), `BUG-07` (multi-file conflict sheet), `BUG-09` (Sync labels at a narrow width).

**Contingent on the fix landing first:** `BUG-01` (confirmation sheet), `BUG-05` (Edit ▸ Undo),
`BUG-06` (Edit and Go menus exist), `BUG-10` (external change appears without user action).

**Service level:** `BUG-01` (grouping never spans differing content), `BUG-03` (shell invocation
includes `-l` and `-i`), `BUG-08` (`contentsMatch` honours cancellation; skipped when sizes differ).

---

The seven items below are different: they are not tied to a defect. They are working surface that
no test touches, so nobody knows whether it still works. Each recommends **UI tests, unit tests, or
both**.

## TEST-01 — Sidebar context menus have no UI coverage at all
**Severity 6/10 — High · Test type: UI · Verified by grep against `Tests/` and `UITests/`**

**In plain terms.** The right-click menus in the sidebar — eject a drive, remove a saved server,
rename a bookmark — are never tested. If one of them broke, nothing would catch it.

**Observation.** `SidebarView.swift` contains five `.contextMenu` blocks (lines 356, 425, 522, 560,
603) covering **Open in Pane**, **Pin to Network Sidebar**, **Eject**, **Connect Now**, **Rename…**,
**Remove from Pinned**, plus bookmark **Move Up / Move Down / Remove Bookmark** and Recents removal.
No test references any of them. `NetworkVolumeMonitorEjectTests` (`BugAuditTests:249`) covers the
monitor logic beneath Eject, and `DuPaneFunctionTests:1162` covers `addBookmark` at the model layer,
but neither exercises a menu.

**Recommendation.** **UI tests.** The model layer is already covered, so what is missing is the
wiring. First add accessibility identifiers to the sidebar rows — `sidebar-place-<name>`,
`sidebar-bookmark-<name>`, `sidebar-network-<name>` would match the existing `sidebar-tag-<name>`
convention. Then add a `rightClickSidebarRow` helper beside the existing `rightClickRow`, after
which each case costs roughly a line. Cover at minimum: Eject on a mounted volume, Remove from
Pinned, Rename… on a bookmark, and Open in Pane.

**Reason.** These are the only untested actions in the app that change persistent state or detach
hardware — Eject unmounts a volume, Remove from Pinned deletes a saved server, Rename… rewrites a
stored label. They are also the least likely to be noticed if they silently stop working, because
nobody uses them daily.

## TEST-02 — Setting and clearing colour tags is untested
**Severity 5/10 — Medium · Test type: Both**

**In plain terms.** DuPane can colour-tag files. Filtering *by* tag is tested; actually applying or
removing a tag is not.

**Observation.** `DuPaneFunctionTests:200` (`testDisplayedItemsFiltersByActiveFinderTag`) covers the
read side. The write side — the Tag submenu's seven colours and **Remove All Tags**, which the guide
says applies to the whole selection — has no reference in either test directory.

**Recommendation.** **Both.** *Unit*: the function that writes `NSURL` tag names to a set of items,
asserting it toggles rather than replaces, applies across a multi-item selection, and that Remove
All Tags clears every tag. *UI*: the Tag submenu on a two-file selection, asserting both rows show
the colour dot afterwards, then Remove All Tags clears them.

**Reason.** Tags are written into the filesystem and are visible in Finder afterwards, so a bug here
leaves persistent, user-visible mess outside the app. The toggle-across-a-multi-selection behaviour
in particular is the kind of thing that breaks quietly.

## TEST-03 — Quick Look is untested on both of its routes
**Severity 5/10 — Medium · Test type: Both**

**In plain terms.** Pressing Space to preview a file — a headline feature with its own chapter in
the guide — has no test at all, by either route.

**Observation.** Neither "Quick Look" nor the Space binding appears anywhere in `Tests/` or
`UITests/`. The binding is `ContentView.swift:437` (`.keyboardShortcut(" ", modifiers: [])` calling
`QuickLookCoordinator.shared.toggle(urls:)`), and the context-menu item is in `PaneView`.

**Recommendation.** **Both.** *Unit*: `QuickLookCoordinator` is a singleton with an exposed
`previewURLs` array and a `ToggleAction` enum (`.hide` / `.show`), so its toggle logic can be tested
without a `QLPreviewPanel` — assert that toggling with the same selection hides, that toggling with
a changed selection re-shows with the new URLs, and that an empty selection is a no-op. *UI*: Space
opens the panel, Space closes it, and the context-menu item opens it.

**Reason.** The guide gives Quick Look a chapter and promises specific behaviour — same selection
dismisses, changed selection refreshes — that nothing verifies. The coordinator's hide/show branch
is exactly the sort of state machine that drifts.

## TEST-04 — The Duplicate Finder's destructive controls are untested
**Severity 6/10 — High · Test type: Both**

**In plain terms.** The duplicate scan is tested; the buttons that actually delete the duplicates
are not.

**Observation.** `testCriticalDuplicateFinderScansAndShowsDuplicateGroup` covers the scan and the
grouping. Neither the per-row trash icon (`DuplicateFinderView.swift:140`) nor **Keep First**
(line 215) has any test. `DuplicateFinderView.swift` contains no `accessibilityIdentifier` calls, so
the view is not addressable from XCUI at all.

**Recommendation.** **Both**, and it overlaps `BUG-01`. *Unit*: `DuplicateFinderViewModel` never
groups files whose contents differ, and `moveToTrash` removes exactly the URL passed and nothing
else. *UI*: add identifiers (`dupe-group-<n>`, `dupe-row-trash-<n>`, `dupe-keep-first-<n>`,
`dupe-done-button`), then assert Keep First trashes every copy but the first *within its own group*
and leaves other groups untouched — the guide implies a single global button, so this is worth
pinning down.

**Reason.** This is the app's only bulk-delete path. `BUG-01` argues it needs a confirmation; either
way it needs a test, because the failure mode is deleting the wrong file and not finding out.

## TEST-05 — Context-menu routes to already-tested actions
**Severity 4/10 — Medium · Test type: UI**

**In plain terms.** Some actions can be reached from both the toolbar and the right-click menu. Only
the toolbar route is tested.

**Observation.** Copy, Move and Duplicate are tested through the toolbar
(`testCriticalCopySelectedFileBetweenPanes`, `testCriticalMoveSelectedFileBetweenPanes`, `⌘D`), but
the context-menu equivalents — **Duplicate**, **Move to \<folder\>**, **Copy to \<folder\>** and
**Bookmark** — have no test. Bookmark's model call is unit-tested; the menu item is not.

**Recommendation.** **UI tests only.** The underlying behaviour is already covered at both the model
and toolbar level, so these assert the menu path reaches the same code. Cheap: `rightClickRow` then
`app.menuItems["…"].click()`, then reuse the existing assertions.

**Reason.** Two routes to one action is two chances for one to rot. The guide documents both routes
as equivalent, so a divergence would contradict the documentation as well as the user's expectation.

## TEST-06 — Read-only conveniences and column-menu extras
**Severity 3/10 — Low · Test type: Both**

**In plain terms.** Small helpers — copy a file's path, share it, open it in another app, reset the
column widths — are untested. Low risk, but cheap to cover once the harness is there.

**Observation.** No reference anywhere to **Copy Path**, **Share…**, **Open With…** (including the
guide's claim of "up to 8 compatible apps" and the **Other…** entry), **Reset Column Widths** or
**Hide Name**. `Share` matches only an unrelated `/tmp/FakeShare` fixture in `BugAuditTests`.

**Recommendation.** **Both, split by what is testable.** *Unit*: the pasteboard string Copy Path
produces for a selection; the app list Open With… builds, asserting the cap the guide documents;
the settings mutation behind Reset Column Widths. *UI*: the menu items exist and are enabled for a
selection, and Hide Name collapses the column. Skip a UI assertion on Share… — `NSSharingServicePicker`
is awkward to drive and the payoff is low; assert the item exists and stop there.

**Reason.** Individually minor, collectively a third of the context menu. The guide makes a specific
falsifiable claim about Open With… ("up to 8 compatible apps") that nothing checks.

## TEST-07 — The six themes have no smoke test
**Severity 2/10 — Low · Test type: UI**

**In plain terms.** DuPane ships six colour themes. Nothing checks that switching to one doesn't
break the display.

**Observation.** No test references `AppColorScheme` or any of `ocean`, `country`, `earth`, `fire`,
`vivid`. The enum is in `AppSettings.swift:5–10` with a separate `AppColorMode` for light/dark.

**Recommendation.** **UI smoke test.** One case that walks the six themes via the Settings picker
and asserts, after each, that a known file row is still present and hittable. Optionally a unit test
that every `AppColorScheme` case resolves a complete token set, so a newly added theme cannot ship
with a missing colour.

**Reason.** Lowest severity here, but the cheapest possible test: six iterations of one assertion
would catch a theme that renders text on its own background colour, which is the classic failure.

---

# Part 3 — Guide corrections

Lower priority than Parts 1 and 2 — and in several cases the better fix is to change the app so the
guide becomes true. Locations are given so each can be actioned without re-deriving it.

## DOC-01 — The Duplicate Finder section contradicts itself, and one version is false
**Severity 9/10 — Critical · Verified in source**

**In plain terms.** The manual explains the duplicate check two different ways in the space of ten
lines, and neither matches what the code does.

**Observation.** Line 1391: the scan compares "file content byte-for-byte". Line 1401: files are
"hashed with FNV-1a 64-bit. Two files whose hashes match are identical regardless of name, location,
or modification date." The code hashes and never compares bytes, so the first sentence is wrong;
FNV-1a is a non-cryptographic 64-bit hash, so the second is not true either.

**Recommendation.** If `BUG-01`'s verification pass lands, describe the scan as three stages: size
bucket → hash → byte-for-byte verification. If not, replace both claims with "files sharing a size
and a content hash are treated as duplicates" and add a warning to check before deleting.

**Reason.** The very next paragraph tells the user to trash files on the strength of this claim.
Documentation that overstates a guarantee in front of a delete button is worse than none.

## DOC-02 — Every "Settings → X → Y" path describes a UI that does not exist, and the labels do not match
**Severity 7/10 — High · Verified live and in source**

**In plain terms.** The manual sends you to Settings tabs that aren't there, and calls the options
by names the app doesn't use.

**Observation.** Settings is a single scrolling form with inline section headers — not tabbed panes
— yet the guide writes paths such as "Settings → Sidebar → Show Network section". Labels differ too:

| Guide says | App says (`SettingsView.swift:10–80`) |
| --- | --- |
| "Delete Behaviour" heading | Two sections: **Files** and **Folders** |
| Skip confirmation for files | Skip confirmation when deleting files |
| Skip confirmation for directories | Skip confirmation when deleting folders |
| Show hidden files | Show hidden files (dot-files) |
| Show file extensions | Show file name extensions |
| Settings → Sidebar Places | Section "Sidebar places" |
| Startup Folders | Section "Startup folders" |

**Recommendation.** Rewrite the Settings chapter to mirror the real section order and quote labels
verbatim from `SettingsView.swift`. Replace arrow paths with "in Settings, under Sidebar". The
*Default* column is accurate — every default was checked against `AppSettings.swift` and matches.

**Reason.** A reader hunting for a Network tab that was never built concludes the feature is missing
and files a bug, or gives up on it.

## DOC-03 — The pane mockup shows a column layout no new user has
**Severity 7/10 — High · Verified in source and live**

**In plain terms.** The picture at the top of the manual shows columns that are switched off by
default — including the one the manual spends a whole chapter selling.

**Observation.** The main mockup shows Name | Size | Kind | Modified | Info. `AppSettings.swift`
defaults `hiddenColumns` to `"Date Added,Info,Kind"`, with the comment "Default: hide Kind, Date
Added, and Info so only Name, Size, Modified show". The running app confirms it: Name | Modified |
Size. So the **Info** column — the headline Smart Metadata feature — is invisible until the user
discovers the column-header context menu.

**Recommendation.** Redraw the mockup as the genuine default, then add a second, smaller mockup
captioned "the same folder with the Info column switched on", with the enabling step beside it.
Alternatively ship Info visible by default and leave the mockup alone.

**Reason.** The feature the guide sells hardest is the one a new user cannot see. The current
illustration hides that gap rather than closing it.

## DOC-04 — The Compare status definitions are wrong
**Severity 6/10 — High · Verified in source and live**

**In plain terms.** The manual's explanation of the newer / older / different badges doesn't match
what the app actually decides — and the app is the more careful of the two.

**Observation.** The guide defines *newer* as name, kind and size matching with a newer date, and
*different* as kind, size or date conflicting. `FolderCompareService.status` returns `.different`
whenever contents differ — even at identical size — and a pure date difference yields
`newerLeft`/`newerRight`, never "different". Confirmed live: two 23-byte files, same name, different
contents, dates two years apart, were badged **different** on both sides.

**Recommendation.** Redefine: **different** — the name matches but kind, size or *file contents*
differ; **newer / older** — the files are byte-identical and this side has the later modification
date. Mention that comparison reads contents (`BUG-08`).

**Reason.** The app is more rigorous than its documentation. A user reading the current text
interprets "different" as a timestamp problem and syncs the wrong way.

## DOC-05 — The toolbar mockup is missing three buttons
**Severity 6/10 — High · Verified live**

**In plain terms.** The toolbar drawing in the manual is out of date — three buttons that exist in
the app aren't in the picture.

**Observation.** The real toolbar is: Sidebar · New Folder · New File · Move · Copy · **Compare** ·
Delete · **Rename** · **Dupes** · Bookmark · Terminal · Follow. The mockup omits Compare, Rename and
Dupes. The prose also writes the buttons as "Move →" and "Copy ⎘"; they are labelled plainly.

**Recommendation.** Redraw with all twelve buttons in order using exact labels, and note that Move,
Copy, Delete and Rename are disabled until something is selected — which the guide never says.

**Reason.** It is the first illustration in the guide and a new user counts buttons against it. Two
of the three missing ones have whole chapters elsewhere in the same document.

## DOC-06 — The guide never mentions the FAQ, and the FAQ never mentions the guide
**Severity 6/10 — High · Verified in source**

**In plain terms.** There are two help documents in the app and neither one tells you the other
exists.

**Observation.** Help ▸ **Open FAQs** opens `Docs/FAQs.html` (31 KB), whose sections mirror the
guide's almost one for one. Neither file references the other — grep returns zero matches in both
directions.

**Recommendation.** Fold the FAQ in as the guide's closing section and drop the second file, or give
each a clear remit (guide = how it works, FAQ = what to do when it does not) and cross-link them at
the top of both.

**Reason.** Two documents with overlapping scope and no links will drift apart, and a reader who
finds one has no way of knowing the other exists.

## DOC-07 — The shortcut reference is incomplete, and it is the only reference there is
**Severity 6/10 — High · Verified in source**

**In plain terms.** The shortcut list leaves out a third of the commands — and because the app has
no menus, that list is the only place they're written down.

**Observation.** No entries for Compress/Uncompress, Copy Path, Open With, Share, Tag, Reveal in
Finder, Dupes, Compare or Folder Sizes. ⌘C and ⌘V are listed with no indication that they do not
mean clipboard copy and paste (`BUG-04`). Because the app has no Edit or Go menu (`BUG-06`), this
table is the only place these commands are written down anywhere.

**Recommendation.** Audit every `keyboardShortcut` in `ContentView`, `GlobalToolbar`, `PaneView` and
`DuPaneApp`, plus every context-menu item in `PaneView`, and make the tables exhaustive. Add a
toolbar-button reference table alongside, including when each button is disabled.

**Reason.** In an app with no menu bar, an incomplete reference means shipped features are
permanently invisible to anyone who does not read the source.

## DOC-08 — Nothing documents the Duplicate Finder's controls or its lack of a safety net
**Severity 6/10 — High · Verified live**

**In plain terms.** The duplicate-finder chapter reads as reassuring about the one screen in the app
where a mis-click can't be undone.

**Observation.** **Keep First** sits in each *group* header — the guide implies a single global
button — and the footer reports "N duplicates · N bytes wasted", unmentioned. Nothing warns that the
trash icon and Keep First act immediately (`BUG-01`). There is no way to preview a file before
trashing it.

**Recommendation.** Document Keep First as per-group, document the footer summary, and add a warning
callout stating both actions take effect immediately with the Finder Trash as the only recovery. Add
Quick Look to the rows in the app.

**Reason.** "Reclaim wasted disk space in seconds" is the wrong tone for the least reversible screen
in the app.

## DOC-09 — There is no installation or permissions section
**Severity 6/10 — High · Gap in guide**

**In plain terms.** The manual never explains the permission prompts macOS shows on first launch, or
what to do if you accidentally click Deny.

**Observation.** First-run permission prompts get a single clause in Quick Start step 1. Nothing
covers Full Disk Access, what happens if the user clicks Deny, or how to recover in System Settings
▸ Privacy & Security.

**Recommendation.** Add a short "Installing and first run" section: which prompts appear, what each
unlocks, what breaks without it, and the recovery path. Tie it to the red lock badge already
described under Permission Indicator.

**Reason.** It is the first thing that goes wrong for any third-party Mac file manager, and the first
thing users will email about.

## DOC-10 — Version and build are hardcoded, and already stale
**Severity 5/10 — Medium · Verified live and in source**

**In plain terms.** The manual says Build 421; the app says 421.6. The number is typed in by hand in
two places, so it will always be out of date.

**Observation.** The sidebar reads "User Guide v1.0 Build 421" (line 586) and the footer "Version
1.0 · Build 421" (line 1611). The app's Help menu reads **Internal Test Build 421.6**.

**Recommendation.** Put `{{VERSION}}` and `{{BUILD}}` tokens in the HTML and substitute them in the
existing "Stamp Build Number" post-build script in `project.yml`, which already reads
`BuildNumber.txt` — a `sed` over the copied resource is a two-line addition to a script that runs
anyway.

**Reason.** A stale build number is the first thing that makes a reader distrust the rest of a
document.

## DOC-11 — The Settings chapter omits the Network toggles entirely
**Severity 5/10 — Medium · Verified in source**

**In plain terms.** Six network settings exist in the app but never appear in the manual's settings
chapter.

**Observation.** `SettingsView.swift:55–60` contains a nested Network section — mounted volumes,
status indicator, pinned servers, Bonjour discovery, auto-reconnect — plus a third Sidebar toggle,
"Show Network section". The guide's Settings ▸ Sidebar table lists only Places and Recents.

**Recommendation.** Add all six to the Settings tables with their defaults, keeping the Sidebar
chapter's prose as the explanation.

**Reason.** Someone auditing what they can turn off reads the Settings chapter, not the Sidebar
chapter.

## DOC-12 — The table of contents is missing Duplicate Finder
**Severity 5/10 — Medium · Verified in source**

**In plain terms.** One whole chapter is missing from the contents list.

**Observation.** The left-hand nav lists Duplicate Finder (line 612); the table of contents (lines
641–661) jumps from Folder Size View straight to Settings.

**Recommendation.** Generate both the nav and the TOC from the `<section id>` elements the scroll-spy
script already queries.

**Reason.** Two hand-maintained navigation lists have already fallen out of step once.

## DOC-13 — Multi-window support is undocumented
**Severity 4/10 — Medium · Verified live**

**In plain terms.** You can open more than one DuPane window. The manual never says so.

**Observation.** File ▸ New Window and "Quit and Close All Windows" both exist. The guide says only
that native macOS window tabs are disabled, never mentioning multiple windows or whether tabs,
startup folders and settings are per-window or shared.

**Recommendation.** Add a short subsection to the Tabs chapter.

**Reason.** A dual-pane user with two monitors looks for exactly this, and the only mention of
windows currently reads as "window management is disabled".

## DOC-14 — The completion toast is undocumented, and the guide claims it does not appear
**Severity 4/10 — Medium · Verified live**

**In plain terms.** The manual says small copies happen with no on-screen feedback. They don't —
there's a confirmation message, and it's the only sign the copy worked.

**Observation.** The guide says quick single-file copies "finish before the pill ever appears, so
there is no visual noise for routine operations." Copying a 23-byte file produced a toast reading
"Copied 1 file to tempclaudetarget".

**Recommendation.** Document the completion toast beside the progress pill, and drop the "no visual
noise" sentence.

**Reason.** For small copies the toast is the only confirmation the user gets that anything happened.

## DOC-15 — One feature, four names
**Severity 4/10 — Medium · Verified live**

**In plain terms.** The built-in command bar is called four different things across the manual and
the app, so searching for it fails.

**Observation.** "Integrated Terminal" (feature card, line 697), "Command Runner" (chapter heading),
"retractable shell panel" (prose) and **Terminal** (the toolbar button). The nav says "Folder Size
View" while the menu item is "Show Folder Sizes".

**Recommendation.** Pick **Command Runner** and use it everywhere including the toolbar button; align
"Folder Sizes" across nav, chapter and menu item.

**Reason.** In-document search and support conversations both fail when the reader does not know what
the thing is called.

## DOC-16 — The compare summary and difference count are undocumented
**Severity 3/10 — Low · Verified live**

**In plain terms.** Compare mode shows a running tally of the differences. The manual never mentions
it, so nobody looks for it.

**Observation.** In Compare mode the status bar appends "Compare: 15 left only, 2 right only, 2
different" and a "19 differences" badge appears at the right of the toolbar. Neither is mentioned;
nor is the fact that hidden items participate in the comparison.

**Recommendation.** Add both to the Compare chapter, and say hidden files participate.

**Reason.** The summary is the fastest read of a comparison result.

## DOC-17 — The sidebar chapter's order does not match the sidebar
**Severity 3/10 — Low · Verified live**

**In plain terms.** The manual describes the sidebar's sections in a different order from the one
they actually appear in, and never says where Bookmarks sits.

**Observation.** The app's order is Places, Bookmarks, Recents, Network. The guide covers Places →
Recents → Locations → Network, then discusses Bookmarks in separate later headings.

**Recommendation.** Reorder the chapter to match top-to-bottom, and introduce Bookmarks as a section
before explaining how to add them.

**Reason.** Reference chapters are read while looking at the thing they describe.

## DOC-18 — "Developer Tools" contains no developer tools
**Severity 2/10 — Low · Verified in source**

**In plain terms.** Settings and the user guide are filed under a heading called "Developer Tools",
so non-technical readers skip past them.

**Observation.** The shortcut group at line 1595 holds Toggle command runner, Open Settings and Open
User Guide.

**Recommendation.** Rename to "Application", or move Settings and User Guide into a General group.

**Reason.** ⌘, is the shortcut everybody needs, filed where nobody will look for it.

## DOC-19 — The overview callout restates the paragraph above it
**Severity 2/10 — Low · Verified in source**

**In plain terms.** A highlighted tip near the top just repeats the sentence above it.

**Observation.** "DuPane is a native macOS file manager built with SwiftUI, with dual panes and
keyboard shortcuts for everyday file operations" sits two inches below a lead paragraph making the
same point at greater length.

**Recommendation.** Cut it, or replace it with something actionable — the ⌘? shortcut that reopens
the guide, say.

**Reason.** A tip callout that teaches nothing trains readers to skip the callouts that do.

---

# Part 4 — The guide as a web page

Opened in a browser from the Help menu, so it carries a web page's obligations.

## WEB-01 — No print stylesheet
**Severity 5/10 — Medium · Verified in source**

**In plain terms.** Print the manual and you get the navigation sidebar's empty gutter on every
page, with tables split across page breaks.

**Observation.** The fixed 240 px sidebar is carried into print; sections break mid-table.
**Recommendation.** `@media print { .sidebar{display:none} .main,footer{margin:0} .section{break-inside:avoid} }`.
**Reason.** The shortcuts chapter is the most likely thing here to be printed and pinned up.

## WEB-02 — Tip callouts fall below the AA contrast threshold
**Severity 5/10 — Medium · Verified in source**

**In plain terms.** The blue tip boxes use blue text on a pale blue background — the hardest text in
the document to read, and it carries instructions.

**Observation.** `.callout.tip p` sets body text to `var(--accent)` on `var(--accent-light)` —
roughly 3.5:1 in light mode, under the 4.5:1 minimum.
**Recommendation.** Use `var(--text)` for the callout's body copy and keep the accent for the icon
and any bolded label.
**Reason.** Tips carry the only mention of some features.

## WEB-03 — Emoji icons and symbol-only keycaps are hostile to VoiceOver
**Severity 5/10 — Medium · Verified in source**

**In plain terms.** Read aloud by a screen reader, the manual announces decorative emoji in full and
turns keyboard shortcuts into strings of punctuation.

**Observation.** 🍎 ⚡ 📑 💡 ⚠️ ℹ️ are read as content; `<kbd>⌘[</kbd>` announces as punctuation.
**Recommendation.** `aria-hidden="true"` on decorative emoji; a visible or screen-reader-only label
on each callout ("Tip:", "Warning:"); `aria-label` on the common keycaps.
**Reason.** A keyboard-shortcut reference is exactly the document a keyboard-dependent user needs
most.

## WEB-04 — A hard 760 px floor forces horizontal scrolling
**Severity 4/10 — Medium · Verified in source**

**In plain terms.** Put the manual in a narrow window beside the app — the obvious way to use it —
and it scrolls sideways.

**Observation.** `body { min-width: 760px }` (line 56) plus a fixed 240 px sidebar, with no
breakpoint anywhere in the stylesheet.
**Recommendation.** One breakpoint below ~900 px collapsing the sidebar to a top bar, and drop the
`min-width`. The content is otherwise already fluid.
**Reason.** The guide is most useful side by side with the app.

## WEB-05 — No in-page search for a seventeen-section reference
**Severity 4/10 — Medium · Verified in source**

**In plain terms.** There's no way to search the manual — only a contents list and a sidebar.

**Observation.** Navigation is the sidebar and the TOC; there is no filter.
**Recommendation.** A search field above the nav that hides non-matching sections — about fifteen
lines against the existing `section[id]` list.
**Reason.** Readers arrive knowing a word — "Bonjour", "pinned", "Keep Both" — not a chapter.

## WEB-06 — One callout renders unstyled
**Severity 3/10 — Low · Verified in source**

**In plain terms.** One of the highlighted notes has a typo in its styling, so it renders as bare
text with no box or icon.

**Observation.** Line 1405 uses `<div class="tip">` where every other callout uses
`class="callout tip"`; there is no bare `.tip` rule.
**Recommendation.** One-character fix — and it is the note warning that Dupes is disabled at the
Computer root.
**Reason.** A visibly broken element in a shipped document undermines the rest of it.

## WEB-07 — The scroll-spy leaves no section highlighted
**Severity 3/10 — Low · Verified in source**

**In plain terms.** The sidebar often highlights nothing, so you can't tell which chapter you're in.

**Observation.** `rootMargin: '-30% 0px -60% 0px'` leaves a 10% detection band, so inside a long
section no nav item is active; clicking a nav link does not highlight it until the scroll settles.
**Recommendation.** Track the last intersecting section rather than clearing every item on each
callback, and set the active class immediately on click.
**Reason.** "Where am I?" is the sidebar's only job besides jumping.

## WEB-08 — Missing document metadata
**Severity 2/10 — Low · Verified in source**

**In plain terms.** Two one-line omissions in the page header.

**Observation.** No `<meta name="description">`; `lang="en"` despite consistent British spelling.
**Recommendation.** Add the meta, set `lang="en-GB"`.
**Reason.** Free correctness; lang also affects screen-reader pronunciation and spellcheck.

---

# Part 5 — Process

## PROC-01 — No single source of truth for user-facing strings
**Severity 5/10 — Medium · Analysis**

**In plain terms.** Every button label is typed out by hand in three places — the code, the manual
and the FAQ — so they drift apart with every change.

**Observation.** Toolbar labels, setting labels, shortcuts and context-menu items are each written
out by hand in the Swift source, in `UserGuide.html` and again in `FAQs.html`. Roughly half of
Part 3 is a label or list that changed in one place only.

**Recommendation.** Add a docs line to `CONTRIBUTING.md` — any change to a toolbar label, setting
label, shortcut or context-menu item updates the guide in the same commit — and consider generating
the shortcut tables from one Swift declaration. A CI grep failing when a `Toggle("…")` string has no
match in `Docs/` would catch most of Part 3 mechanically.

**Reason.** The guide is genuinely good; what it lacks is a way to stay that way through the next
twenty builds. And as this review showed, a guide that stays true is also a usable test script.

## PROC-02 — Section comment numbering has drifted
**Severity 1/10 — Trivial · Verified in source**

**In plain terms.** The numbered comments in the HTML source have got out of order. Invisible to
users.

**Observation.** The HTML comments run 1, 2, 3 … then two sections numbered 7, then 13, 15, 16, 17.
**Recommendation.** Drop the numbers from the comments and keep the section names.
**Reason.** The clearest sign of how the file has been edited piecemeal.

---

## What was not tested in this review

Right-click menus could not be opened through background automation, so the File Operations surface
was verified by source reading rather than by driving it — which is why Part 2 leans on the existing
suite for what is and is not covered. Multi-file selection was not available either, which is why
`BUG-07`'s batch question is still open. Quick Look, Follow mode, tab pinning and renaming, subfolder
search, the network features and the six themes were not exercised at all.

## Housekeeping

- Test fixtures were created in `~/tmpclaudesource` and `~/tempclaudetarget` and left in place — text
  files, two PNGs, a WAV, a zip, a shell script, hidden files, a `nested` subfolder and the duplicate
  set. They are a reasonable starting point for the manual checks in Part 1. Both folders can be
  deleted at any time.
- One file, `beta.txt`, is in the Trash from the delete test; a fresh copy was written back into the
  source folder, so nothing is missing.
- `conflict 2.txt` in the target folder is the Keep Both result, kept as evidence.
- Nothing outside those two scratch folders was created, modified or deleted.
- This file is `Docs/Review.md`, renamed from `Docs/UserGuide-Review.md` in revision 2. It is not in
  the app's resource list, so it ships nowhere near the bundle.
