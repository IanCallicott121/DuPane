#!/usr/bin/env bash
set -euo pipefail
repo_dir=$(cd "$(dirname "$0")/.." && pwd -P)
cd "$repo_dir"
lane="${1:-}"
[ -n "$lane" ] || { echo "Usage: $0 {docs|logic|service|ui|project|release} [--filter TestName] [--clean]" >&2; exit 2; }
shift
filter=""
clean=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --filter) filter="${2:?--filter requires a test name}"; shift 2 ;;
    --clean) clean=1; shift ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done
case "$lane" in docs|logic|service|ui|project|release) ;; *) echo "Unknown lane: $lane" >&2; exit 2 ;; esac

overall_start=$SECONDS
run_stage() {
  local label="$1"; shift
  local started=$SECONDS
  printf '\n== %s ==\n' "$label"
  "$@"
  printf 'TIMING %-24s %ss\n' "$label" "$((SECONDS - started))"
}
run_stage "diff-check" git diff --check
if [ "$lane" = "docs" ]; then printf 'TIMING total                    %ss\n' "$((SECONDS - overall_start))"; exit 0; fi
[ -z "$filter" ] || run_stage "focused-unit" swift test --filter "$filter"
run_stage "full-unit" swift test --filter DuPaneUITests
if [ "$lane" = "project" ]; then run_stage "xcodegen" xcodegen generate; fi
build_args=(-project DuPane.xcodeproj -scheme DuPane -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO)
if [ "$clean" -eq 1 ]; then
  run_stage "clean-app-build" xcodebuild "${build_args[@]}" clean build
else
  run_stage "app-build" xcodebuild "${build_args[@]}" build
fi
case "$lane" in ui|project|release) run_stage "full-e2e" "$repo_dir/Scripts/run-e2e.sh" ;; esac
printf '\nTIMING total                    %ss\n' "$((SECONDS - overall_start))"
