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
mkdir -p "$AI_SESSION_TMP_CLAUDE_DIR/proj/$sid" "$AI_SESSION_TMP_CLAUDE_DIR/proj/$sid2" "$AI_SESSION_TMP_CLAUDE_PROJECTS/proj"
touch -d "@$old" "$AI_SESSION_TMP_CLAUDE_DIR/proj/$sid" "$AI_SESSION_TMP_CLAUDE_DIR/proj/$sid2"
touch -d "@$old" "$AI_SESSION_TMP_CLAUDE_PROJECTS/proj/$sid.jsonl"
touch "$AI_SESSION_TMP_CLAUDE_PROJECTS/proj/$sid2.jsonl"
bash "$sweep" >/dev/null
check "idle Claude scratch folder -> deleted" '[ ! -e "$AI_SESSION_TMP_CLAUDE_DIR/proj/$sid" ]'
check "active Claude session scratch -> kept" '[ -d "$AI_SESSION_TMP_CLAUDE_DIR/proj/$sid2" ]'

kill "$live" 2>/dev/null
printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]
