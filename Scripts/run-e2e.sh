#!/bin/zsh
set -euo pipefail

repo_dir="${0:A:h:h}"
result_dir="$repo_dir/.test-results"
captured_output="$(mktemp /tmp/DuPane-e2e-output.XXXXXX)"
negative_validation_path="/tmp/DuPane-e2e-negative-validation"
typeset -a xcode_args
xcode_args=()
priority=""
negative_validation=0

typeset -a high_priority_tests medium_priority_tests low_priority_tests
high_priority_tests=(
  testCriticalRenameFileThroughToolbarSheet
  testCriticalRepeatedEscapeDismissesCreationSheets
  testCriticalCommandVPastesIntoCreationAndGoToFolderFields
  testCriticalDateAddedColumnCanBeShown
  testCriticalMenuShowsInternalTestBuildMarker
  testCriticalCopySelectedFileBetweenPanes
  testCriticalMoveSelectedFileBetweenPanes
  testCriticalCommandVMovesSelectedFileBetweenPanes
  testCriticalCreatesFileAndFolderThroughToolbarSheets
  testCriticalArchiveRoundTripThroughContextMenu
  testCriticalDuplicateFinderScansAndShowsDuplicateGroup
  testCriticalCopyConflictDialogResolvesOverwriteSkipAndKeepBoth
  testCriticalTypeAheadStillWorksAfterClosingTheActiveTab
  testCriticalProgressOverlayIsNotLeftOnScreenAfterACopy
  testCriticalUndoAfterDeleteRestoresTheFile
  testCriticalSyncCopiesLeftOnlyFilesToTheRightPane
  testLaunchShowsFixtureRows
)
medium_priority_tests=(
  testSingleClickSelectsRowInRealApp
  testDoubleClickFolderOpensFolderInRealApp
  testCommandClickAddsSecondRowToSelection
  testShiftClickExtendsSelectionToRange
  testMediumCommandRunnerPanelCanBeOpenedAndClosed
  testMediumFilterNarrowsVisibleRows
  testMediumPropertiesAndFolderSizePanelsOpen
)
low_priority_tests=(
  testRightClickShowsContextMenu
)

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
    --priority)
      [[ $# -ge 2 ]] || { print -u2 "--priority requires high, medium, or low"; exit 2; }
      priority="$2"
      case "$priority" in
        high|medium|low) ;;
        *) print -u2 "--priority must be high, medium, or low"; exit 2 ;;
      esac
      shift 2
      ;;
    --negative-validation)
      negative_validation=1
      shift
      ;;
    *) xcode_args+=("$1"); shift ;;
  esac
done

if [[ -n "$priority" ]]; then
  typeset -a priority_tests
  case "$priority" in
    high) priority_tests=("${high_priority_tests[@]}") ;;
    medium) priority_tests=("${high_priority_tests[@]}" "${medium_priority_tests[@]}") ;;
    low) priority_tests=("${high_priority_tests[@]}" "${medium_priority_tests[@]}" "${low_priority_tests[@]}") ;;
  esac
  for test_name in "${priority_tests[@]}"; do
    xcode_args+=("-only-testing:DuPaneEndToEndUITests/DuPaneEndToEndUITests/$test_name")
  done
fi

cleanup() {
  rm -f "$captured_output" "$negative_validation_path"
}
trap cleanup EXIT
rm -f "$negative_validation_path"

if (( negative_validation )); then
  : > "$negative_validation_path"
  export DUPANE_E2E_NEGATIVE_VALIDATION=1
fi

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
if (( negative_validation )); then
  if (( build_status == 0 )); then
    print -u2 "Negative E2E validation unexpectedly passed"
    exit 1
  fi
  if grep -q '^PASS ' "$result_dir/DuPaneEndToEndUITests.log"; then
    print -u2 "Negative E2E validation found one or more PASS results"
    exit 1
  fi
  if grep -q '^SKIP ' "$result_dir/DuPaneEndToEndUITests.log"; then
    print -u2 "Negative E2E validation found one or more SKIP results"
    exit 1
  fi
  if ! grep -q '^FAIL ' "$result_dir/DuPaneEndToEndUITests.log"; then
    print -u2 "Negative E2E validation found no FAIL results"
    exit 1
  fi
  print "Negative E2E validation passed: every emitted test result was FAIL as expected"
  exit 0
fi
if grep -q '^FAIL ' "$result_dir/DuPaneEndToEndUITests.log"; then
  print -u2 "E2E tests emitted one or more FAIL results"
  exit 1
fi
print "E2E result log: $result_dir/DuPaneEndToEndUITests.log"
exit "$build_status"
