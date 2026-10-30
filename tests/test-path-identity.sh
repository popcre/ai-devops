#!/usr/bin/env bash
# path-identity.sh — never compare filesystem paths as raw strings (#1835).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
. "$ROOT/tools/lib/path-identity.sh"

PASS=0
ok(){ PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
fail(){ printf '  FAIL %s\n' "$1" >&2; exit 1; }

mkdir -p "$TMP/repo"
git -C "$TMP/repo" init -q -b main
git -C "$TMP/repo" config user.name Test; git -C "$TMP/repo" config user.email t@example.com
echo x > "$TMP/repo/f"
git -C "$TMP/repo" add f; git -C "$TMP/repo" commit -qm base
TOP="$(cd "$TMP/repo" && pwd -P)"

ai_git_toplevel "$TOP" && ok 'pwd -P top level accepted' || fail 'pwd -P top level accepted'
ai_git_toplevel "$TOP/" && ok 'trailing slash top level accepted' || fail 'trailing slash top level accepted'
if ai_git_toplevel "$TOP/f"; then fail 'a file is not a top level'; else ok 'a file is not a top level'; fi
if ai_git_toplevel "$TMP"; then fail 'parent of the repo is not a top level'; else ok 'parent of the repo is not a top level'; fi

# Mixed spelling of the same place must compare equal (Windows: /c vs C:/).
mkdir -p "$TMP/spot"
a="$TMP/spot"
# Build a second spelling when cygpath exists; otherwise use trailing-dot form.
if command -v cygpath >/dev/null 2>&1; then
  b="$(cygpath -w "$TMP/spot")"
else
  b="$TMP/./spot"
fi
ai_same_path "$a" "$b" && ok 'ai_same_path accepts alternate spelling' || fail "ai_same_path accepts alternate spelling ($a vs $b)"
ai_same_path "$TMP/spot" "$TMP/other" && fail 'ai_same_path rejects distinct paths' || ok 'ai_same_path rejects distinct paths'

# CR-terminated path from native Windows tools must not break identity.
ai_same_path "$(printf '%s\r' "$TMP/spot")" "$TMP/spot" && ok 'trailing CR ignored' || fail 'trailing CR ignored'

# Native Windows tools often print a %TEMP% path in 8.3 short form
# (C:\Users\RUNNER~1\...); it names the same place as the long form.
if command -v cygpath >/dev/null 2>&1; then
  short="$(cygpath -d "$TMP/spot" 2>/dev/null)"
  if [ -n "$short" ]; then
    ai_same_path "$short" "$TMP/spot" && ok '8.3 short name matches long name' || fail "8.3 short name matches long name ($short)"
    # A not-yet-created child under a short-named parent is the same place too.
    ai_same_path "$short/not-yet/made" "$TMP/spot/not-yet/made" && ok '8.3 parent of a missing path matches' || fail "8.3 parent of a missing path matches ($short/not-yet/made)"
  fi
fi

printf 'path-identity: %d checks passed\n' "$PASS"
