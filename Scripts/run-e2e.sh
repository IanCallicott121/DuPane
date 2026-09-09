#!/bin/zsh
set -euo pipefail

repo_dir="${0:A:h:h}"
result_dir="$repo_dir/.test-results"
captured_output="$(mktemp /tmp/DuPane-e2e-output.XXXXXX)"
typeset -a xcode_args
xcode_args=()

while (( $# > 0 )); do
  case "$1" in
    --only)
      [[ $# -ge 2 ]] || { print -u2 "--only requires a test method or identifier"; exit 2; }
      if [[ "$2" == */* ]]; then
        xcode_args+=("-only-testing:$2")
      else
        xcode_args+=("-only-testing:DuPaneEndToEndUITests/DuPaneEndToEndUITests/$2")
      fi
      shift 2
      ;;
    *) xcode_args+=("$1"); shift ;;
  esac
done

cleanup() { rm -f "$captured_output"; }
trap cleanup EXIT
set +e
xcodebuild test \
  -project "$repo_dir/DuPane.xcodeproj" \
  -scheme DuPane \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/DuPane-e2e-dd \
  "${xcode_args[@]}" 2>&1 | tee "$captured_output"
build_status=${pipestatus[1]}
set -e

mkdir -p "$result_dir"
sed -n 's/^DUPANE_TEST_RESULT //p' "$captured_output" > "$result_dir/DuPaneEndToEndUITests.log"
if [[ ! -s "$result_dir/DuPaneEndToEndUITests.log" ]]; then
  print -u2 "E2E tests completed but emitted no machine-readable results"
  exit 1
fi
print "E2E result log: $result_dir/DuPaneEndToEndUITests.log"
exit "$build_status"
