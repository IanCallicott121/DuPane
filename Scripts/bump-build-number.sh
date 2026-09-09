#!/usr/bin/env bash
set -euo pipefail
repo_dir=$(cd "$(dirname "$0")/.." && pwd -P)
build_file="$repo_dir/BuildNumber.txt"
[ -f "$build_file" ] || { echo "Missing $build_file" >&2; exit 1; }
current=$(tr -d '[:space:]' < "$build_file")
case "$current" in ''|*[!0-9]*) echo "Invalid build number: $current" >&2; exit 1 ;; esac
next=$((current + 1))
temp_file=$(mktemp "$repo_dir/.BuildNumber.XXXXXX")
trap 'rm -f "$temp_file"' EXIT
printf '%d\n' "$next" > "$temp_file"
mv "$temp_file" "$build_file"
trap - EXIT
echo "$current -> $next"
