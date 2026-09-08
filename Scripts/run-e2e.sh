#!/bin/zsh
set -euo pipefail

repo_dir="${0:A:h:h}"
result_dir="$repo_dir/.test-results"
captured_output="$(mktemp /tmp/DuPane-e2e-output.XXXXXX)"

cleanup() {
  rm -f "$captured_output"
}
trap cleanup EXIT

set +e
xcodebuild test \
  -project "$repo_dir/DuPane.xcodeproj" \
  -scheme DuPane \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/DuPane-e2e-dd \
  "$@" 2>&1 | tee "$captured_output"
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
