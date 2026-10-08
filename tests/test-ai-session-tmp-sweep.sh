#!/usr/bin/env bash
# Offline suite for bin/ai-session-tmp-sweep (plan_session-temp-cleanup.md §10).
set -u
PASS=0; FAIL=0
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/lib-test-harness.sh"
sweep="$here/../bin/ai-session-tmp-sweep"

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
export AI_SESSION_TMP_BASE="$work/base" AI_SESSION_TMP_LOG_DIR="$work/logs" \
  AI_SESSION_TMP_CLAUDE_DIR="$work/claude-tmp" AI_SESSION_TMP_CLAUDE_PROJECTS="$work/projects"
mkdir -p "$AI_SESSION_TMP_BASE"
old=$(( $(date +%s) - 3 * 3600 )); new=$(date +%s)
sleep 300 & live=$!
dead=999999; while [ -d "/proc/$dead" ]; do dead=$((dead - 1)); done
mk() {  # name pid epoch [ticks]
  mkdir -p "$AI_SESSION_TMP_BASE/$1"
  printf '{"pid":%s,"pid_start_ticks":"%s","engine":"t","session_id":"x","started_utc":"","started_epoch":%s,"cwd":"/"}\n' \
    "$2" "${4:-}" "$3" > "$AI_SESSION_TMP_BASE/$1/owner.json"
}
mk t-dead-old "$dead" "$old"
mk t-live-old "$live" "$old" "$(awk '{print $22}' /proc/$live/stat)"
mk t-dead-new "$dead" "$new"
mk t-reused "$live" "$old" 1
mkdir -p "$AI_SESSION_TMP_BASE/t-noowner"
mkdir -p "$AI_SESSION_TMP_BASE/t-bad"; echo garbage > "$AI_SESSION_TMP_BASE/t-bad/owner.json"
ln -s "$work" "$AI_SESSION_TMP_BASE/t-link"

bash "$sweep" --dry-run >/dev/null
check "dry run deletes nothing" '[ -d "$AI_SESSION_TMP_BASE/t-dead-old" ]'
out="$(bash "$sweep")"
check "dead pid + old -> deleted" '[ ! -e "$AI_SESSION_TMP_BASE/t-dead-old" ]'
check "live pid -> kept" '[ -d "$AI_SESSION_TMP_BASE/t-live-old" ]'
check "dead but young -> kept" '[ -d "$AI_SESSION_TMP_BASE/t-dead-new" ]'
check "reused pid (start ticks differ) -> deleted" '[ ! -e "$AI_SESSION_TMP_BASE/t-reused" ]'
check "missing owner.json -> kept and reported" '[ -d "$AI_SESSION_TMP_BASE/t-noowner" ] && grep -q "t-noowner (no owner.json)" <<<"$out"'
check "malformed owner.json -> kept" '[ -d "$AI_SESSION_TMP_BASE/t-bad" ]'
check "symlink entry -> kept, target intact" '[ -L "$AI_SESSION_TMP_BASE/t-link" ] && [ -d "$work/logs" ]'
check "log written" '[ -s "$work/logs/session-tmp-sweep.log" ]'

for i in $(seq 1 5); do mk "t-cap-$i" "$dead" "$old"; done
bash "$sweep" --max 3 >/dev/null
check "cap honoured" '[ "$(ls -d "$AI_SESSION_TMP_BASE"/t-cap-* 2>/dev/null | wc -l)" = 2 ]'

sid=aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee sid2=aaaaaaaa-bbbb-cccc-dddd-ffffffffffff
sid3=aaaaaaaa-bbbb-cccc-dddd-000000000000 sid4=aaaaaaaa-bbbb-cccc-dddd-111111111111
for s_ in "$sid" "$sid2" "$sid3" "$sid4"; do mkdir -p "$AI_SESSION_TMP_CLAUDE_DIR/proj/$s_"; done
mkdir -p "$AI_SESSION_TMP_CLAUDE_PROJECTS/proj"
mk "claude-$sid" "$dead" "$old"; mk "claude-$sid2" "$dead" "$old"
mk "claude-$sid3" "$live" "$old" "$(awk '{print $22}' /proc/$live/stat)"
for s_ in "$sid" "$sid2" "$sid3" "$sid4"; do
  touch -d "@$old" "$AI_SESSION_TMP_CLAUDE_DIR/proj/$s_" "$AI_SESSION_TMP_CLAUDE_PROJECTS/proj/$s_.jsonl"
done
touch "$AI_SESSION_TMP_CLAUDE_PROJECTS/proj/$sid2.jsonl"
out="$(bash "$sweep")"
check "dead owner + idle Claude scratch folder -> deleted" '[ ! -e "$AI_SESSION_TMP_CLAUDE_DIR/proj/$sid" ]'
check "recently active Claude session scratch -> kept" '[ -d "$AI_SESSION_TMP_CLAUDE_DIR/proj/$sid2" ]'
check "idle but live-owner Claude scratch -> kept (inactivity is not death)" '[ -d "$AI_SESSION_TMP_CLAUDE_DIR/proj/$sid3" ]'
check "idle Claude scratch with no owner record -> kept and reported" '[ -d "$AI_SESSION_TMP_CLAUDE_DIR/proj/$sid4" ] && grep -q "$sid4 (no owner record)" <<<"$out"'
check "Claude root kept while its scratch folder remains" '[ -d "$AI_SESSION_TMP_BASE/claude-$sid2" ]'
check "Claude root of a removed scratch folder -> deleted" '[ ! -e "$AI_SESSION_TMP_BASE/claude-$sid" ]'

kill "$live" 2>/dev/null
printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]
