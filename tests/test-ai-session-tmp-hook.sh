#!/usr/bin/env bash
# Offline suite for bin/ai-session-tmp-hook (Claude Code SessionStart/SessionEnd).
set -u
PASS=0; FAIL=0
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/lib-test-harness.sh"
hook="$here/../bin/ai-session-tmp-hook"; sweep="$here/../bin/ai-session-tmp-sweep"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
export AI_SESSION_TMP_BASE="$work/base" AI_SESSION_TMP_FORCE=1 AI_SESSION_TMP_LOG_DIR="$work/logs" \
  AI_SESSION_TMP_CLAUDE_DIR="$work/none" AI_SESSION_TMP_CLAUDE_PROJECTS="$work/none"
sid=11111111-2222-3333-4444-555555555555; in="{\"session_id\":\"$sid\"}"
root="$AI_SESSION_TMP_BASE/claude-$sid"; envf="$work/env"

printf '%s' "$in" | CLAUDE_ENV_FILE="$envf" bash "$hook" start
check "start creates the root" '[ -f "$root/owner.json" ]'
check "start exports TMPDIR" 'grep -q "export TMPDIR=$root" "$envf"'
printf '%s' "$in" | CLAUDE_ENV_FILE="$envf" bash "$hook" start
check "repeated start does not grow the env file" '[ "$(grep -c AI_SESSION_TMP_ROOT "$envf")" = 1 ]'

# Crash then resume > 2 h later: owner.json names a dead pid with an old start.
dead=999999; while [ -d "/proc/$dead" ]; do dead=$((dead - 1)); done
printf '{"pid":%s,"pid_start_ticks":"","engine":"claude","session_id":"x","started_utc":"","started_epoch":%s,"cwd":"/"}\n' \
  "$dead" "$(( $(date +%s) - 10800 ))" > "$root/owner.json"
touch "$root/live-work"
sleep 300 & holder=$!
printf '%s' "$in" | CLAUDE_ENV_FILE="$envf" bash -c 'exec "$@"' _ bash "$hook" start
check "resume refreshes owner.json" '! grep -q "\"pid\":$dead," "$root/owner.json"'
# The refreshed owner is the hook's ancestor chain; make it a live process for the sweep.
sed -i "s/\"pid\":[0-9]*/\"pid\":$holder/; s/\"pid_start_ticks\":\"[0-9]*\"/\"pid_start_ticks\":\"$(awk '{print $22}' /proc/$holder/stat)\"/" "$root/owner.json"
bash "$sweep" --min-age 0 >/dev/null
check "sweeper keeps a resumed live session's root" '[ -f "$root/live-work" ]'
kill "$holder" 2>/dev/null

printf '%s' "$in" | bash "$hook" end
check "end removes the root" '[ ! -e "$root" ]'
printf 'not json' | bash "$hook" start; check "bad input never fails the session" '[ $? -eq 0 ]'
printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]
