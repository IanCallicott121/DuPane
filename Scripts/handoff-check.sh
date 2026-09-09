#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
mode="${1:---finish}"
case "$mode" in --start|--finish) ;; *) echo "Usage: $0 [--start|--finish]" >&2; exit 2 ;; esac

pbx="DuPane.xcodeproj/project.pbxproj"
issues=0
warnings=0
issue() { printf '  ! %s\n' "$1"; issues=$((issues + 1)); }
warn() { printf '  ? %s\n' "$1"; warnings=$((warnings + 1)); }
ok() { printf '  ok %s\n' "$1"; }
info() { printf '  i  %s\n' "$1"; }

printf '\n%s check — %s on %s\n\n' "${mode#--}" "$(basename "$PWD")" "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
echo "Git"
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  issue "working tree is dirty"
  git status --short | sed 's/^/       /'
else
  ok "working tree clean"
fi
upstream=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || true)
if [ -n "$upstream" ]; then
  ahead=$(git rev-list --count "$upstream"..HEAD 2>/dev/null || echo 0)
  behind=$(git rev-list --count HEAD.."$upstream" 2>/dev/null || echo 0)
  if [ "$ahead" -gt 0 ]; then
    [ "$mode" = "--finish" ] && issue "$ahead commit(s) not pushed to $upstream" || warn "$ahead local commit(s) not pushed"
  elif [ "$behind" -gt 0 ]; then
    warn "$behind commit(s) behind $upstream (remote refs may be stale)"
  else
    ok "in sync with $upstream"
  fi
else
  warn "no upstream configured"
fi

echo
echo "Xcode project"
if [ ! -f "$pbx" ]; then
  issue "$pbx not found"
else
  missing=""
  for name in $(grep -oE '[A-Za-z0-9_+-]+\.swift' "$pbx" | sort -u | grep -v '^sourcecode\.swift$'); do
    find . -name "$name" -not -path './.git/*' -not -path './build/*' -not -path './.build/*' -print -quit 2>/dev/null | grep -q . || missing="$missing $name"
  done
  [ -z "$missing" ] && ok "every referenced source exists" || issue "project references missing sources:$missing"

  unreferenced=""
  while IFS= read -r file; do
    base=$(basename "$file")
    [ "$base" = "DuPaneApp.swift" ] && continue
    grep -q "$base" "$pbx" || unreferenced="$unreferenced $base"
  done < <(find Sources -name '*.swift' 2>/dev/null)
  [ -z "$unreferenced" ] && ok "every source is referenced" || issue "sources absent from project:$unreferenced"

  if [ -f project.yml ] && [ project.yml -nt "$pbx" ]; then
    info "project.yml is newer than generated project (mtime heuristic)"
  else
    ok "generated project is current"
  fi
fi

echo
echo "Build location"
if [ -d build ] && find build -type f -print -quit 2>/dev/null | grep -q .; then
  issue "build products exist inside checkout; use external SYMROOT"
else
  ok "no build products inside checkout"
fi

echo
if [ "$issues" -gt 0 ]; then
  printf '%d blocking issue(s); %d warning(s).\n' "$issues" "$warnings"
  exit 1
fi
printf 'Check passed; %d warning(s).\n' "$warnings"
