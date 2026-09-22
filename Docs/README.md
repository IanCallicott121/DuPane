# DuPane

A native macOS dual-pane file manager for working with real files and folders.

## For users: download, install, and go

### Download

Download the latest version from the [GitHub Releases page](https://github.com/IanCallicott121/DuPane/releases).
The DMG is recommended; the ZIP is also available.

Release builds are currently unsigned and not notarized, so macOS may ask you to
confirm that you want to open the app. The first time you open a folder such as
Downloads or a removable volume, macOS may also ask for permission.

### Install

1. Open the downloaded DMG.
2. Drag `DuPane.app` to the Applications folder.
3. Open DuPane from Applications.
4. Allow access to the folders and volumes you want DuPane to manage.

If access is denied, use **System Settings → Privacy & Security → Files and Folders**
to grant permission and try again.

### Start using DuPane

DuPane opens with two independent panes. By default, the left pane starts at
`~/Downloads` and the right pane shows the mounted volumes available from
**Computer**.

The README is only a quick introduction. The [DuPane User Guide](https://github.com/IanCallicott121/DuPane/blob/main/Docs/UserGuide.html)
contains the full feature reference, including navigation, tabs, bookmarks, filters,
tags, metadata columns, file operations, Compare and Sync, Duplicate Finder, folder
sizes, settings, keyboard shortcuts, and troubleshooting. See the [FAQs](https://github.com/IanCallicott121/DuPane/blob/main/Docs/FAQs.html)
for common questions and safety details.

## For developers: build and modify DuPane

### Requirements

- macOS 13 (Ventura) or later.
- Xcode with the Swift toolchain.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) if you change `project.yml`.

Clone the repository and change into it:

```bash
git clone https://github.com/IanCallicott121/DuPane.git
cd DuPane
```

### Build and run

Open `DuPane.xcodeproj` in Xcode and press `⌘R`, or build from the command line:

```bash
xcodebuild -project DuPane.xcodeproj -scheme DuPane -configuration Debug build
```

`project.yml` is the source of truth for the Xcode project. After changing it,
regenerate the project:

```bash
xcodegen generate
```

Do not hand-edit the generated `DuPane.xcodeproj` for structural changes.

### Run tests

Run the unit tests without opening Xcode:

```bash
swift test --filter DuPaneUITests
```

Run the end-to-end UI tests:

```bash
./Scripts/run-e2e.sh
```

The verification wrapper provides the repository's standard lanes:

```bash
./Scripts/verify-change.sh docs
./Scripts/verify-change.sh logic
./Scripts/verify-change.sh service
./Scripts/verify-change.sh ui
```

To prepare a verified local app in `~/Applications/DuPane.app`, use the UI or
release lane with `--prepare-manual-build`. The app preparation runs after unit
and E2E verification:

```bash
./Scripts/verify-change.sh ui --prepare-manual-build
```

### Where to make changes

```text
Sources/DuPane/                 Application source
Tests/DuPaneUITests/            Unit and service tests
UITests/DuPaneEndToEndUITests/  Xcode UI and cross-process tests
Docs/UserGuide.html             Full user documentation
Docs/FAQs.html                  User FAQs
Docs/TODO.md                    Project work log
```

The generated app is unsandboxed. File-operation changes should therefore be
tested with care and should include the smallest relevant regression coverage.

### Releases and maintenance

Maintainers can find the commit, verification, tagging, and publishing procedure
in the [release guide](RELEASING.md). Contributors do not need to create releases.
