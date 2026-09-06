# Contributing to DuPane

DuPane is a native macOS dual-pane file manager built with SwiftUI. Contributions are welcome — please read this before opening a PR.

## Requirements

- macOS 13 or later
- Xcode 15 or later
- Swift 5.9+

## Getting started

```bash
git clone https://github.com/IanCallicott121/DuPane.git
cd DuPane
open DuPane.xcodeproj
```

Set your signing team in Xcode (project target → Signing & Capabilities → Team).

## Before you submit

1. **Run the tests** — all must pass:
   ```bash
   swift test --filter DuPaneUITests
   ```
2. **Build and run the app** in Xcode (⌘R) and manually test the affected feature.
3. **Write tests** for any non-trivial logic change. Pure UI layout changes don't need tests.
4. **Update the docs** if the UI or any user-facing behaviour changed:
   - `Docs/UserGuide.html`
   - `Docs/FAQs.html`

## Code conventions

- No comments unless the *why* is non-obvious.
- No force-unwraps (`!`) on optionals that could realistically be nil.
- No dead code, backwards-compat shims, or feature flags.
- `@MainActor` on ViewModels; `Task.detached` for filesystem/IO work.
- `onChange(of:perform:)` form for macOS 13 compatibility.
- Follow the existing naming: PascalCase for types, camelCase for properties/methods.

## What we won't merge

- Features that duplicate macOS Finder capabilities without adding clear value.
- Changes that break the existing 189 unit tests without a documented reason.
- PRs without a description explaining *what* changed and *why*.

## Reporting bugs

Use the [Bug Report](.github/ISSUE_TEMPLATE/bug_report.yml) issue template. Include your macOS version and DuPane build number (DuPane menu → About DuPane).
