#!/usr/bin/env bash
set -euo pipefail
repo_dir=$(cd "$(dirname "$0")/.." && pwd -P)
lock_dir="$repo_dir/.dupane-agent.lock"
action="${1:-acquire}"
show_lock() { [ -f "$lock_dir/owner" ] && sed 's/^/  /' "$lock_dir/owner" || echo "  owner metadata unavailable"; }

case "$action" in
  acquire)
    owner="${2:-agent-$$}"
    git_root=$(git -C "$repo_dir" rev-parse --show-toplevel)
    [ "$repo_dir" = "$git_root" ] || { echo "Repository path mismatch: $repo_dir != $git_root" >&2; exit 1; }
    case "$repo_dir" in *'/Library/Mobile Documents/'*) echo "Refusing iCloud checkout: $repo_dir" >&2; exit 1 ;; esac
    "$repo_dir/Scripts/handoff-check.sh" --start
    if ! mkdir "$lock_dir" 2>/dev/null; then
      echo "Checkout lock is already held:" >&2
      show_lock >&2
      exit 1
    fi
    {
      printf 'owner: %s\n' "$owner"
      printf 'pid: %s\n' "$$"
      printf 'started_utc: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    } > "$lock_dir/owner"
    echo "Checkout lock acquired by $owner"
    ;;
  release)
    if [ ! -d "$lock_dir" ]; then echo "Checkout lock is not held"; exit 0; fi
    rm -f "$lock_dir/owner"
    rmdir "$lock_dir"
    echo "Checkout lock released"
    ;;
  status)
    if [ -d "$lock_dir" ]; then echo "Checkout lock is held:"; show_lock; exit 1; fi
    echo "Checkout lock is free"
    ;;
  *) echo "Usage: $0 {acquire [owner]|release|status}" >&2; exit 2 ;;
esac
