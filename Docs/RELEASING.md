# Releasing DuPane

This guide is for DuPane maintainers. Contributors do not need to create or publish
releases.

## Build numbers

DuPane uses one implementation build number:

| Identifier | Purpose | Source and usage |
|---|---|---|
| Main build number, for example `421` | Identifies the implementation/release build | `BuildNumber.txt`; stamped into the built app's `CFBundleVersion` by `project.yml`. The User Guide and FAQs display this number. |

- Increment the main build number explicitly with `Scripts/bump-build-number.sh` only
  when implementation or release work needs a new visible number. Builds do not increment it.
- Follow the manual-build and verification sequence in [AGENTS.md](../AGENTS.md).
  The preparation script verifies the installed app's target and timestamps before testing.
- To leave a validated UI change ready in `~/Applications/DuPane.app`, run
  `./Scripts/verify-change.sh ui --prepare-manual-build`. The installed-app preparation
  runs only after the unit and E2E stages pass.

The public release version, such as `1.0.0` from tag `v1.0.0`, is a separate marketing
version. It is separate from the implementation build number.

## Before releasing

1. Make sure the release changes are committed on `main`.
2. Run the release verification lane:

   ```bash
   ./Scripts/verify-change.sh release
   ```

3. Choose a new semantic version in `vMAJOR.MINOR.PATCH` form, such as `v1.0.0`.

## Publish a release

From the repository directory:

```bash
git switch main
git pull --ff-only origin main
git tag -a v1.0.0 -m "DuPane 1.0.0"
git push origin v1.0.0
```

Pushing the tag starts the **Release** GitHub Actions workflow. The workflow checks out
that tag, builds the app in Release configuration on macOS, and sets the marketing version
from the tag.

It then creates these assets:

- `DuPane-1.0.0.zip`, containing `DuPane.app`.
- `DuPane-1.0.0.dmg`, containing the app and an Applications shortcut.
- `SHA256SUMS`, containing SHA-256 checksums for the release assets.

Finally, it creates the GitHub Release, generates release notes, and uploads the assets.
The workflow requires the tag to already exist and to match the release version.

## Manual workflow dispatch

An existing tag can also be built from GitHub:

1. Open the repository’s **Actions** tab.
2. Select the **Release** workflow.
3. Choose **Run workflow**.
4. Enter the existing tag, such as `v1.0.0`.

## Release limitations

The current workflow produces unsigned, non-notarized builds. GitHub records download
counts for each asset, but no app-launch telemetry is collected.
