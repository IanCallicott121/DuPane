#!/bin/zsh
set -euo pipefail

repo_dir="${0:A:h:h}"
derived_data="$HOME/Library/Developer/DuPane-build"
built_app="$derived_data/Build/Products/Debug/DuPane.app"
app_link="$HOME/Applications/DuPane.app"
source_file="$repo_dir/Sources/DuPane/DuPaneApp.swift"
binary_file="$built_app/Contents/MacOS/DuPane"

xcodebuild \
  -project "$repo_dir/DuPane.xcodeproj" \
  -scheme DuPane \
  -configuration Debug \
  -destination platform=macOS \
  -derivedDataPath "$derived_data" \
  CODE_SIGNING_ALLOWED=NO \
  clean build

test -x "$binary_file"

if [[ -L "$app_link" ]]; then
  unlink "$app_link"
elif [[ -e "$app_link" ]]; then
  print -u2 "Refusing to replace non-symlink: $app_link"
  exit 1
fi

mkdir -p "${app_link:h}"
ln -s "$built_app" "$app_link"

resolved_target="$(readlink "$app_link")"
[[ "$resolved_target" == "$built_app" ]]

source_mtime="$(stat -f %m "$source_file")"
binary_mtime="$(stat -f %m "$binary_file")"
link_mtime="$(stat -f %m "$app_link")"
(( binary_mtime > source_mtime ))
(( link_mtime >= binary_mtime ))

print "Manual build ready: $app_link -> $resolved_target"
print "Build timestamps: source=$source_mtime binary=$binary_mtime symlink=$link_mtime"
