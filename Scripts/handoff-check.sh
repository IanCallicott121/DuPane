#!/usr/bin/env bash
# Is this repo safe to hand between agents (Cowork <-> Claude Agent in Xcode)?
#
# Checks the things git can tell you, plus proxies for the one thing it can't:
# Xcode caching the project structure in memory and disagreeing with disk.
#
# Editing file CONTENTS outside Xcode is safe — Xcode reloads those buffers.
# STRUCTURAL changes made outside Xcode are not: files added or removed, or
# project.yml / project.pbxproj rewritten. Restart Xcode after those.
#
# Run from the project root:  ./Scripts/handoff-check.sh
# Exit 0 = safe to hand over, 1 = something needs your attention.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

PBX="DuPane.xcodeproj/project.pbxproj"
issues=0
note() { printf '  \033[33m!\033[0m %s\n' "$1"; issues=$((issues + 1)); }
ok()   { printf '  \033[32mok\033[0m %s\n' "$1"; }

echo
echo "Handoff check — $(basename "$PWD") on $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
echo

# ---------------------------------------------------------------- git state
echo "Git"
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    note "working tree is dirty — read these before handing over:"
    git status --short | sed 's/^/       /'
else
    ok "working tree clean"
fi

upstream=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || true)
if [ -n "$upstream" ]; then
    ahead=$(git rev-list --count "$upstream"..HEAD 2>/dev/null || echo 0)
    if [ "$ahead" -gt 0 ]; then
        note "$ahead commit(s) not pushed to $upstream:"
        git log --format='       %h %s' "$upstream"..HEAD
    else
        ok "in sync with $upstream"
    fi
fi

# ------------------------------------------------- stale Xcode project state
echo
echo "Xcode project"
if [ ! -f "$PBX" ]; then
    note "$PBX not found"
else
    # Files the project references that no longer exist. This is the Build 377
    # failure mode: sources deleted, references left behind. A clean clone fails
    # to build; SPM never notices because it reads Package.swift instead.
    missing=""
    for name in $(grep -oE '[A-Za-z0-9_+-]+\.swift' "$PBX" | sort -u | grep -v '^sourcecode\.swift$'); do
        if ! find . -name "$name" -not -path './.git/*' -not -path './build/*' \
                    -not -path './.build/*' -print -quit 2>/dev/null | grep -q .; then
            missing="$missing $name"
        fi
    done
    if [ -n "$missing" ]; then
        note "project references files that don't exist:$missing"
        note "  -> run 'xcodegen generate'"
    else
        ok "every referenced source file exists"
    fi

    # Sources present on disk but absent from the project — a new file added by
    # the other agent that Xcode won't compile until the project is regenerated.
    unreferenced=""
    while IFS= read -r f; do
        base=$(basename "$f")
        [ "$base" = "DuPaneApp.swift" ] && continue   # excluded from the SPM target by design
        grep -q "$base" "$PBX" || unreferenced="$unreferenced $base"
    done < <(find Sources -name '*.swift' 2>/dev/null)
    if [ -n "$unreferenced" ]; then
        note "sources not referenced by the project:$unreferenced"
        note "  -> run 'xcodegen generate'"
    else
        ok "every source file is referenced"
    fi

    # project.yml is the source of truth; the pbxproj is generated from it.
    if [ -f project.yml ] && [ project.yml -nt "$PBX" ]; then
        note "project.yml is newer than the generated project"
        note "  -> run 'xcodegen generate'"
    else
        ok "generated project is up to date with project.yml"
    fi
fi

# ------------------------------------------------------- build location sanity
echo
echo "Build location"
if [ -d build ]; then
    files=$(find build -type f 2>/dev/null | wc -l | tr -d ' ')
    if [ "$files" -gt 0 ]; then
        note "build/ in the project directory holds $files build product(s)"
        note "  -> Xcode is using build settings that disagree with the file on disk;"
        note "     quit and reopen Xcode, then delete build/"
        if command -v xattr >/dev/null 2>&1; then
            tainted=$(xattr -r build 2>/dev/null | grep -c 'com.apple.FinderInfo' || true)
            [ "${tainted:-0}" -gt 0 ] && note "  -> $tainted item(s) carry iCloud xattrs; codesign will refuse these"
        fi
    else
        note "empty build/ directory left behind — safe to delete, but nothing built there"
    fi
else
    ok "no stray build/ in the project directory"
fi

# --------------------------------------------------------------------- verdict
echo
if [ "$issues" -eq 0 ]; then
    printf '\033[32mSafe to hand over.\033[0m\n\n'
    exit 0
fi
printf '\033[33m%d thing(s) to look at before handing over.\033[0m\n' "$issues"
echo "If anything OUTSIDE Xcode added or removed files, or rewrote project.yml or"
echo "project.pbxproj, quit and reopen Xcode regardless. It caches the project"
echo "structure and won't reliably re-read it. (Content edits outside Xcode are"
echo "fine — those it does reload. Changes made inside Xcode are already in sync.)"
echo
exit 1
