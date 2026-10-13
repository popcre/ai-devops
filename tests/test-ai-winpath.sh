#!/usr/bin/env bash
# ai-winpath — resolve Windows mount points so SSH sessions can read memory.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
check() { # check <name> <cmd...>
  local name="$1"; shift
  if "$@"; then echo "ok $name"; else fail "$name"; fi
}

check "syntax" bash -n "$ROOT/bin/ai-winpath"

plain="$TMP/plain"
mkdir -p "$plain"
got="$(bash "$ROOT/bin/ai-winpath" "$plain")"
check "plain path unchanged" test "$got" = "$plain"

missing="$TMP/does-not-exist"
got="$(bash "$ROOT/bin/ai-winpath" "$missing")"
check "missing path unchanged" test "$got" = "$missing"

# Junction coverage only where the OS can create one (Windows).
if command -v cmd >/dev/null 2>&1; then
  target="$TMP/real-target"
  link="$TMP/junction-link"
  mkdir -p "$target"
  echo keep > "$target/keep.txt"
  win_target="$(cygpath -w "$target" 2>/dev/null || echo "$target")"
  win_link="$(cygpath -w "$TMP/junction-link" 2>/dev/null || echo "$TMP/junction-link")"
  if MSYS2_ARG_CONV_EXCL='*' cmd /c mklink /J "$win_link" "$win_target" >/dev/null 2>&1 && [[ -e "$link" || -e "$win_link" ]]; then
    got="$(bash "$ROOT/bin/ai-winpath" "$link")"
    # Accept either unixified or windows target; both identify the same place.
    if [[ "$got" == *real-target* || "$(cd "$got" 2>/dev/null && pwd -W)" == *real-target* ]]; then
      echo "ok junction resolves to target ($got)"
    else
      fail "junction did not resolve to real-target: $got"
    fi
    # Physical path must expose the same content without walking the junction.
    test -f "$got/keep.txt" || fail "resolved path lost keep.txt"
    echo "ok junction target still holds data"
  else
    echo "skip junction resolve (mklink /J unavailable)"
  fi
else
  echo "skip junction resolve (no cmd)"
fi

echo "PASS test-ai-winpath"
