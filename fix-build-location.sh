#!/bin/bash
# Moves SYMROOT outside iCloud Drive to fix "resource fork" codesign failures.
# Run with Xcode CLOSED.

set -e

PBXPROJ="/Users/iancallicott/Library/Mobile Documents/com~apple~CloudDocs/Coding/xcode/DuPane/DuPane.xcodeproj/project.pbxproj"
OLD='SYMROOT = "$(SRCROOT)/build";'
NEW='SYMROOT = "$(HOME)/Library/Developer/DuPane-build";'

if pgrep -x Xcode > /dev/null; then
    echo "ERROR: Xcode is running. Close Xcode first, then re-run this script."
    exit 1
fi

if grep -qF "$OLD" "$PBXPROJ"; then
    sed -i '' "s|SYMROOT = \"\$(SRCROOT)/build\";|SYMROOT = \"\$(HOME)/Library/Developer/DuPane-build\";|g" "$PBXPROJ"
    echo "Done. SYMROOT updated to \$(HOME)/Library/Developer/DuPane-build"
    echo "You can delete the old build folder if you want:"
    echo "  rm -rf \"/Users/iancallicott/Library/Mobile Documents/com~apple~CloudDocs/Coding/xcode/DuPane/build\""
else
    echo "SYMROOT already updated (or not found) — no changes made."
fi
