#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source_root="$(cd "$script_dir/.." && pwd -P)"
destination="${1:-$HOME/Developer/DuPane}"

if [[ "${2:-}" != "" ]]; then
    echo "Usage: $(basename "$0") [destination]"
    exit 2
fi

if ! git -C "$source_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: $source_root is not a Git working tree."
    exit 1
fi

if [[ "$source_root" == "$destination" ]]; then
    echo "Error: the destination must differ from the current checkout."
    exit 1
fi

if [[ -e "$destination" ]]; then
    echo "Error: destination already exists: $destination"
    echo "Choose an empty destination or move the existing directory first."
    exit 1
fi

timestamp="$(date +%Y%m%d-%H%M%S)"
backup_dir="$(dirname "$destination")/DuPane-migration-backup-$timestamp"
patch_file="$backup_dir/tracked-changes.patch"
untracked_file="$backup_dir/untracked-files.txt"
origin_url="$(git -C "$source_root" config --get remote.origin.url || true)"

echo "Source:      $source_root"
echo "Destination: $destination"
echo "Backup:      $backup_dir"
echo
echo "Current Git state:"
git -C "$source_root" status --short --branch
echo
read -r -p "Create a clean local clone and preserve this working state? [y/N] " reply
if [[ ! "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]; then
    echo "Cancelled. Nothing changed."
    exit 0
fi

mkdir -p "$backup_dir"

# A binary diff against HEAD includes both staged and unstaged tracked changes.
git -C "$source_root" diff --binary HEAD > "$patch_file"
git -C "$source_root" ls-files --others --exclude-standard -z > "$untracked_file"

untracked_count=0
while IFS= read -r -d '' relative_path; do
    untracked_count=$((untracked_count + 1))
done < "$untracked_file"

if (( untracked_count > 0 )); then
    echo "Found $untracked_count untracked file(s); they will be copied after cloning."
fi

mkdir -p "$(dirname "$destination")"
git clone --no-local "$source_root" "$destination"

if [[ -n "$origin_url" ]]; then
    git -C "$destination" remote set-url origin "$origin_url"
fi

if [[ -s "$patch_file" ]]; then
    git -C "$destination" apply --binary "$patch_file"
fi

# Copy untracked content without Finder/resource-fork metadata. Tracked files are
# recreated by Git, which is what avoids the iCloud codesigning problem.
while IFS= read -r -d '' relative_path; do
    mkdir -p "$destination/$(dirname "$relative_path")"
    cp -R -X "$source_root/$relative_path" "$destination/$relative_path"
done < "$untracked_file"

echo
echo "Migration complete. The iCloud checkout has not been modified."
echo "New checkout: $destination"
echo "Safety backup: $backup_dir"
echo
echo "New Git state:"
git -C "$destination" status --short --branch

read -r -p "Run the Swift package tests in the new checkout now? [y/N] " test_reply
if [[ "$test_reply" =~ ^[Yy]([Ee][Ss])?$ ]]; then
    (cd "$destination" && swift test --filter DuPaneUITests)
else
    echo "Next: open $destination/DuPane.xcodeproj in Xcode and verify a build there."
fi
