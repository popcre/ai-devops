#!/usr/bin/env bash
# Offline tests for ai-blocker-watch reap (B1 task/orphan TTL + reap, #1116).
#
# Named gates from the child brief:
#   1. an orphaned task/session past TTL is reaped
#   2. a live/recent one is not reaped
#   3. a reviewer lease is NEVER freed on age alone (negative test)
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; SCRIPT="$ROOT/bin/ai-blocker-watch"
PASS=0; FAIL=0; ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }; bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# Minimal fixture config: reap is local-only and never calls GitHub, but the
# script still needs a valid config file and a harness map.
jq '.repos=["o/r"] | del(.propagate_on_host) | .stuck_watchdog_enabled=false
  | .fixer_enabled=false | .orphan_ttl_hours=24 | .reap_max_per_run=64
  | .transcript_glob={claude:"",codex:"",zcode:"",mimo:""}' \
  "$ROOT/config/blocker-watch.json" > "$TMP/config.json"
export AI_BLOCKER_WATCH_HOME="$TMP/home" AI_BLOCKER_WATCH_CONFIG="$TMP/config.json" AI_DEVOPS_TEST_MODE=1
unset CLAUDE_CODE_SESSION_ID CODEX_THREAD_ID ZCODE_SESSION_ID 2>/dev/null || true
BW(){ "$SCRIPT" "$@"; }
WAITS="$TMP/home/waits"; REAPED="$TMP/home/reaped"; REAPLOG="$TMP/home/reap.log"
mkdir -p "$WAITS" "$TMP/home/logs" "$TMP/work-clean" "$TMP/work-dirty"
# A dirty worktree with unique uncommitted work (preserve rule).
( cd "$TMP/work-dirty" && git init -q && git commit -q --allow-empty -m init && echo unique > newfile.txt )
# A clean worktree (no uncommitted work).
( cd "$TMP/work-clean" && git init -q && git commit -q --allow-empty -m init )

ts_ago(){ date -u -d "$1 ago" +%Y-%m-%dT%H:%M:%SZ; }

# --- fixtures ----------------------------------------------------------------
# 1. Orphaned (terminal) past TTL — must be reaped.
jq -n --arg at "$(ts_ago '30 hours')" --arg cwd "$TMP/work-clean" \
  '{id:"orphan-old", state:"orphaned", harness:"claude", session:"s-orphan",
    cwd:$cwd, registered_at:$at, checked_at:$at, attempts:1}' > "$WAITS/orphan-old.json"
# 2. Failed terminal past TTL — must be reaped.
jq -n --arg at "$(ts_ago '48 hours')" --arg cwd "" \
  '{id:"failed-old", state:"failed", harness:"zcode", session:"s-failed",
    cwd:$cwd, registered_at:$at, checked_at:$at, attempts:3}' > "$WAITS/failed-old.json"
# 3. Woken terminal past TTL — must be reaped.
jq -n --arg at "$(ts_ago '26 hours')" \
  '{id:"woken-old", state:"woken", harness:"codex", session:"s-woken",
    cwd:"", registered_at:$at, woken_at:$at, attempts:1}' > "$WAITS/woken-old.json"
# 4. LIVE waiting record, ancient — must NOT be reaped (wake/resume intact).
jq -n --arg at "$(ts_ago '100 hours')" --arg cwd "$TMP/work-clean" \
  '{id:"waiting-live", state:"waiting", harness:"claude", session:"s-live",
    cwd:$cwd, registered_at:$at, attempts:0}' > "$WAITS/waiting-live.json"
# 5. Recent terminal record (inside TTL) — must NOT be reaped.
jq -n --arg at "$(ts_ago '2 hours')" \
  '{id:"woken-recent", state:"woken", harness:"claude", session:"s-recent",
    cwd:"", registered_at:$at, woken_at:$at, attempts:1}' > "$WAITS/woken-recent.json"
# 6. Interrupted waking past TTL — must be reaped.
jq -n --arg at "$(ts_ago '30 hours')" \
  '{id:"waking-stuck", state:"waking", harness:"claude", session:"s-stuck",
    cwd:"", registered_at:$at, last_attempt_at:$at, attempts:1}' > "$WAITS/waking-stuck.json"
# 7. Recent waking (may still be running) — must NOT be reaped.
jq -n --arg at "$(ts_ago '1 hour')" \
  '{id:"waking-fresh", state:"waking", harness:"claude", session:"s-fresh",
    cwd:"", registered_at:$at, last_attempt_at:$at, attempts:1}' > "$WAITS/waking-fresh.json"
# 8. Orphaned past TTL whose cwd worktree is DIRTY — record reaped, work preserved.
jq -n --arg at "$(ts_ago '30 hours')" --arg cwd "$TMP/work-dirty" \
  '{id:"orphan-dirty", state:"orphaned", harness:"claude", session:"s-dirty",
    cwd:$cwd, registered_at:$at, checked_at:$at, attempts:1}' > "$WAITS/orphan-dirty.json"
# 9. REVIEWER LEASE fixture — held far past TTL. This is NOT a wait record.
#    Lease liveness forbids freeing a slot on age alone (plan_reviewer_lease_liveness.md).
jq -n --arg at "$(ts_ago '500 hours')" \
  '{lease_state:"held", reviewer:"muse", slot:2, sequence:9,
    issue:1234, pr:5678, headSha:"deadbeef", held_since:$at,
    note:"fixture held reviewer lease; reap must never free this"}' \
  > "$WAITS/reviewer-lease-old.json"
# 10. Dead fixer pid file — must be reaped (process is gone).
mkdir -p "$TMP/home/fixers"
printf '999999999\n' > "$TMP/home/fixers/dead-task.pid"

# --- 1. dry-run reaps nothing ------------------------------------------------
BW reap --dry-run >/dev/null 2>&1
check 'dry-run leaves every wait record in place' \
  "[ -f '$WAITS/orphan-old.json' ] && [ -f '$WAITS/failed-old.json' ] && [ -f '$WAITS/orphan-dirty.json' ]"
check 'dry-run creates no archive' "[ ! -d '$REAPED' ] || [ -z \"\$(ls -A '$REAPED' 2>/dev/null)\" ]"

# --- 2. the real reap --------------------------------------------------------
REAP_OUT="$TMP/reap.out"
BW reap >"$REAP_OUT" 2>"$TMP/reap.err" || true

# --- named gate 1: orphaned task/session past TTL is reaped -------------------
check 'orphaned task past TTL is reaped' \
  "[ ! -f '$WAITS/orphan-old.json' ] && [ -f '$REAPED/orphan-old.json' ]"
check 'failed task past TTL is reaped' \
  "[ ! -f '$WAITS/failed-old.json' ] && [ -f '$REAPED/failed-old.json' ]"
check 'woken task past TTL is reaped' \
  "[ ! -f '$WAITS/woken-old.json' ] && [ -f '$REAPED/woken-old.json' ]"
check 'interrupted wake past TTL is reaped' \
  "[ ! -f '$WAITS/waking-stuck.json' ] && [ -f '$REAPED/waking-stuck.json' ]"

# --- named gate 2: a live/recent one is not reaped ---------------------------
check 'live waiting record is not reaped even when ancient' \
  "[ -f '$WAITS/waiting-live.json' ]"
check 'recent terminal record is not reaped' \
  "[ -f '$WAITS/woken-recent.json' ]"
check 'recent waking record is not reaped' \
  "[ -f '$WAITS/waking-fresh.json' ]"

# --- named gate 3: a reviewer lease is NEVER freed on age alone --------------
check 'reviewer lease is never freed on age alone' \
  "[ -f '$WAITS/reviewer-lease-old.json' ] && jq -e '.lease_state==\"held\" and .slot==2' '$WAITS/reviewer-lease-old.json'"

# --- audit and recoverability -----------------------------------------------
check 'reap writes one audit line per reaped record' \
  "grep -q 'reaped orphan-old' '$REAPLOG' && grep -q 'reaped failed-old' '$REAPLOG' && grep -q 'reaped woken-old' '$REAPLOG'"
check 'audit line names the reason and age' \
  "grep -q \"terminal state 'orphaned' idle 30h\" '$REAPLOG'"
check 'archived JSON is recoverable' \
  "jq -e '.id==\"orphan-old\" and .state==\"orphaned\"' '$REAPED/orphan-old.json'"

# --- unique work is preserved ------------------------------------------------
check 'dirty worktree is preserved and noted' \
  "[ -d '$TMP/work-dirty' ] && [ -f '$TMP/work-dirty/newfile.txt' ] && grep -q 'preserved unique work' '$REAPLOG'"
check 'dirty-work record itself is still reaped (archive only)' \
  "[ ! -f '$WAITS/orphan-dirty.json' ] && [ -f '$REAPED/orphan-dirty.json' ]"

# --- dead fixer pid files ----------------------------------------------------
check 'dead fixer pid file is reaped' "[ ! -f '$TMP/home/fixers/dead-task.pid' ]"
check 'fixer pid reap is logged' "grep -q 'fixer-pid' '$REAPLOG'"

# --- live fixer pid is kept --------------------------------------------------
# A real live process: the test shell itself.
printf '%s\n' "$$" > "$TMP/home/fixers/live-task.pid"
BW reap >/dev/null 2>&1
check 'live fixer pid file is kept' "[ -f '$TMP/home/fixers/live-task.pid' ]"
rm -f "$TMP/home/fixers/live-task.pid"

# --- reap is idempotent: a second run reaps nothing new ----------------------
BEFORE="$(ls "$REAPED" | wc -l)"
BW reap >/dev/null 2>&1
AFTER="$(ls "$REAPED" | wc -l)"
check 'second reap is a no-op' "[ \"$BEFORE\" = \"$AFTER\" ]"

# --- invalid TTL is refused --------------------------------------------------
jq '.orphan_ttl_hours=0' "$TMP/config.json" > "$TMP/bad.json"
check 'invalid orphan_ttl_hours is refused' \
  "! AI_BLOCKER_WATCH_CONFIG='$TMP/bad.json' BW reap"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
