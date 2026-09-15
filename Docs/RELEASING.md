# Releasing DuPane

This guide is for DuPane maintainers. Contributors do not need to create or publish
releases.

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
