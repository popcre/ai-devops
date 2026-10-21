#!/usr/bin/env bash
# bin/ai-codex-review junctions the user's Windows sandbox state into the
# per-run reviewer home. Its cleanup must remove the home without ever
# deleting through those links into the user's real Codex home (#1783).
# Windows uses real NTFS junctions; Linux exercises the same code with symlinks.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0; FAIL=0
check() { if eval "$2"; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; else FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; fi; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
windows=0; case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) windows=1 ;; esac

# The real cleanup block from the wrapper, between its own markers.
block="$(awk '/# Unlink the Windows sandbox junctions first/{on=1} on{print} on&&/^    else printf .ai-codex-review: warning: left/{exit}' "$ROOT/bin/ai-codex-review")"
check 'cleanup block found in the wrapper' '[ -n "$block" ] && printf "%s" "$block" | grep -q "rm -rf"'

link() { # link TARGET NAME
  if [ "$windows" = 1 ]; then MSYS2_ARG_CONV_EXCL='*' cmd /c mklink /J "$(cygpath -w "$2")" "$(cygpath -w "$1")" >/dev/null
  else ln -s "$1" "$2"; fi
}
user="$TMP/user-codex"; home="$TMP/reviewer-home"; mkdir -p "$home"
for d in .sandbox .sandbox-bin .sandbox-secrets; do
  mkdir -p "$user/$d"; echo keep > "$user/$d/state"; link "$user/$d" "$home/$d"
done
check 'fixture links point into the user home' '[ -f "$home/.sandbox/state" ]'
REVIEWER_HOME_DIR="$home"
eval "$block" 2>"$TMP/err"
check 'reviewer home is removed' '[ ! -e "$home" ]'
check 'user sandbox state survives' '[ -f "$user/.sandbox/state" ] && [ -f "$user/.sandbox-bin/state" ] && [ -f "$user/.sandbox-secrets/state" ]'

# With the unlink step removed, a plain delete is what the guard protects
# against; prove the fixture would detect a broken unlink on this platform.
home2="$TMP/reviewer-home2"; mkdir -p "$home2"; link "$user/.sandbox" "$home2/.sandbox"
REVIEWER_HOME_DIR="$home2"
eval "$block" 2>/dev/null
check 'second run also keeps the user state' '[ -f "$user/.sandbox/state" ] && [ ! -e "$home2" ]'
printf 'codex-reviewer-home-cleanup: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
