#!/usr/bin/env bash
# Phase 3 parent orphan sweep (issue #711): parents drop abandoned review
# snapshots before starting a new one.
#
# Orphan rule:
#   - never touch anything younger than 15 minutes (concurrent reviews)
#   - recorded owner PID not running AND age >= 15 min -> remove
#   - no owner PID AND age >= 2 hours -> remove
#   - live owner PID keeps the snapshot even past 2 hours
#
# Fully offline: real git, no network, no provider calls.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/bin/ai-review-sandbox"
AI_REVIEW="$REPO_ROOT/bin/ai-review"
PASS=0; FAIL=0
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export AI_REVIEW_SANDBOX_DIR="$TMP/sandboxes"
export AI_REVIEW_EVENT_DIR="$TMP/reviewer-events"
unset AI_KEEP_SANDBOX 2>/dev/null || true

MAIN="$TMP/main"
mkdir -p "$MAIN"
git -C "$MAIN" init -q
git -C "$MAIN" config user.email t@example.com
git -C "$MAIN" config user.name Test
echo base > "$MAIN/a.txt"
git -C "$MAIN" add -A
git -C "$MAIN" commit -qm init

echo '== ai-review-sandbox orphan sweep (age + PID)'

# Plant a fake managed snapshot whose marker age is AGE_SECONDS.
# PID_RULE: empty -> no sandbox.pid (legacy); "dead" -> owner pid 99999999;
# "live" -> owner pid of the long-lived sleeper started below.
plant() { # plant NAME AGE_SECONDS PID_RULE
  local name="$1" age="$2" pid_rule="${3:-}" d marker_epoch now
  d="$AI_REVIEW_SANDBOX_DIR/$name"
  mkdir -p "$d"
  printf 'source\nsource_digest=deadbeef\nevidence_format=1\n' > "$d/.ai-review-sandbox"
  echo disposable > "$d/AI-REVIEW-SANDBOX.md"
  now="$(date +%s)"
  marker_epoch=$(( now - age ))
  touch -d "@$marker_epoch" "$d/.ai-review-sandbox"
  case "$pid_rule" in
    dead)
      printf 'kind=ensure-copy\npid=99999999\nwinpid=-\nstarted_at=%s\n' "$marker_epoch" > "$d/sandbox.pid"
      touch -d "@$marker_epoch" "$d/sandbox.pid"
      ;;
    live)
      printf 'kind=ensure-copy\npid=%s\nwinpid=-\nstarted_at=%s\n' "$LIVE_PID" "$marker_epoch" > "$d/sandbox.pid"
      touch -d "@$marker_epoch" "$d/sandbox.pid"
      ;;
    none) : ;;
    *)
      printf 'kind=ensure-copy\npid=%s\nwinpid=-\nstarted_at=%s\n' "$pid_rule" "$marker_epoch" > "$d/sandbox.pid"
      touch -d "@$marker_epoch" "$d/sandbox.pid"
      ;;
  esac
  printf %s "$d"
}

# Long-lived owner process for the "live PID keeps the snapshot" case.
sleep 120 &
LIVE_PID=$!
trap 'kill "$LIVE_PID" 2>/dev/null || true; rm -rf "$TMP"' EXIT

# --- 10-minute-old sandbox is never touched --------------------------------
YOUNG="$(plant sweep-young 600 dead)"
check "young_10min_exists_before"            "[ -d '$YOUNG' ]"
"$SCRIPT" sweep-orphans >/dev/null 2>&1 || true
check "young_10min_kept"                     "[ -d '$YOUNG' ]"

# --- dead owner PID + age > 15 min is an orphan ---------------------------
KILLED="$(plant sweep-killed 960 dead)"   # 16 minutes
"$SCRIPT" sweep-orphans >/dev/null 2>&1 || true
check "killed_wrapper_16min_removed"         "[ ! -d '$KILLED' ]"

# --- live owner PID keeps the snapshot even past 2h -----------------------
ALIVE="$(plant sweep-alive 10800 live)"  # 3 hours
"$SCRIPT" sweep-orphans >/dev/null 2>&1 || true
check "live_pid_3h_kept"                     "[ -d '$ALIVE' ]"

# --- no owner PID: only the 2-hour rule -----------------------------------
NOPID_YOUNG="$(plant sweep-nopid-young 1800 none)"  # 30 minutes
NOPID_OLD="$(plant sweep-nopid-old 7500 none)"      # 2h 5 min
"$SCRIPT" sweep-orphans >/dev/null 2>&1 || true
check "no_pid_30min_kept"                    "[ -d '$NOPID_YOUNG' ]"
check "no_pid_2h5min_removed"                "[ ! -d '$NOPID_OLD' ]"

# --- with-copy records its own live PID; ensure-copy without owner does not
WITHCOPY_OUT="$TMP/withcopy.out"
set +e
"$SCRIPT" with-copy "$MAIN" sweepwc -- sh -c 'cp "$AI_REVIEW_SNAPSHOT/sandbox.pid" "$1"; sleep 0' sh "$WITHCOPY_OUT"
set -e
check "with_copy_writes_sandbox_pid"         "[ -s '$WITHCOPY_OUT' ]"
check "with_copy_pid_kind"                   "grep -q '^kind=with-copy\$' '$WITHCOPY_OUT'"
check "with_copy_records_live_pid"           "grep -q '^pid=[0-9]' '$WITHCOPY_OUT'"

NOPID_SNAP="$("$SCRIPT" ensure-copy "$MAIN" sweepnopid)"
check "ensure_copy_writes_sandbox_pid"       "[ -f '$NOPID_SNAP/sandbox.pid' ]"
check "ensure_copy_without_owner_has_empty_pid" "grep -q '^pid=\$' '$NOPID_SNAP/sandbox.pid'"
"$SCRIPT" remove-copy "$MAIN" sweepnopid >/dev/null 2>&1 || true

OWNED_SNAP="$(AI_REVIEW_SANDBOX_OWNER_PID=$LIVE_PID "$SCRIPT" ensure-copy "$MAIN" sweepowned)"
check "ensure_copy_records_exported_owner"   "grep -q '^pid=$LIVE_PID\$' '$OWNED_SNAP/sandbox.pid'"
"$SCRIPT" remove-copy "$MAIN" sweepowned >/dev/null 2>&1 || true

# --- parent start sweeps orphans (bin/ai-review front door) ----------------
PARENT_OLD="$(plant parent-old 9000 none)"   # 2.5 hours
PARENT_YOUNG="$(plant parent-young 500 none)"
check "parent_old_exists_before"             "[ -d '$PARENT_OLD' ]"
check "parent_young_exists_before"           "[ -d '$PARENT_YOUNG' ]"
set +e
"$AI_REVIEW" >/dev/null 2>&1
PARENT_RC=$?
set -e
check "parent_usage_still_works"             "[ '$PARENT_RC' -eq 0 ]"
check "parent_start_removes_old_orphan"      "[ ! -d '$PARENT_OLD' ]"
check "parent_start_keeps_young"             "[ -d '$PARENT_YOUNG' ]"

# cleanup planted leftovers
rm -rf "$YOUNG" "$ALIVE" "$NOPID_YOUNG" "$PARENT_YOUNG" 2>/dev/null || true

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
