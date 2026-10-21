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

# The real cleanup block from the wrapper.
block="$(sed -n '/^  if \[ -n "\$REVIEWER_HOME_DIR" \]; then$/,/^  fi$/p' "$ROOT/bin/ai-codex-review")"
check 'cleanup unlinks sandbox links before removing the home' '[ -n "$block" ] && printf "%s" "$block" | grep -q rmdir'

user="$TMP/user-codex"; home="$TMP/reviewer-home"; mkdir -p "$home"
for d in .sandbox .sandbox-bin .sandbox-secrets; do
  mkdir -p "$user/$d"; echo keep > "$user/$d/state"
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) MSYS2_ARG_CONV_EXCL='*' cmd /c mklink /J "$(cygpath -w "$home/$d")" "$(cygpath -w "$user/$d")" >/dev/null ;;
    *) ln -s "$user/$d" "$home/$d" ;;
  esac
done
check 'fixture links point into the user home' '[ -f "$home/.sandbox/state" ]'
REVIEWER_HOME_DIR="$home"
eval "$block"
check 'reviewer home is removed' '[ ! -e "$home" ]'
check 'user sandbox state survives' '[ -f "$user/.sandbox/state" ] && [ -f "$user/.sandbox-bin/state" ] && [ -f "$user/.sandbox-secrets/state" ]'
printf 'codex-reviewer-home-cleanup: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
