#!/usr/bin/env bash
# Phase 3 parent orphan sweep (issue #711): a killed wrapper never runs its
# cleanup trap, so the parent review start sweeps orphaned snapshots — a
# managed sandbox whose marker is past the orphan age is removed through the
# same path-guarded, evidence-checking delete the creating run uses. Anything
# younger, anything without a marker, and anything the evidence rules retain
# stays. Fully offline: real git, no network, no provider calls.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/bin/ai-review-sandbox"
FRONT="$REPO_ROOT/bin/ai-review"
PASS=0; FAIL=0
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export AI_REVIEW_SANDBOX_DIR="$TMP/sandboxes"
export AI_REVIEW_EVENT_DIR="$TMP/reviewer-events"
unset AI_KEEP_SANDBOX 2>/dev/null || true
unset AI_DEVOPS_TEST_MODE 2>/dev/null || true

MAIN="$TMP/main"
mkdir -p "$MAIN"
git -C "$MAIN" init -q
git -C "$MAIN" config user.email t@example.com
git -C "$MAIN" config user.name Test
echo base > "$MAIN/a.txt"
git -C "$MAIN" add -A
git -C "$MAIN" commit -qm init

# plant NAME [AGE] [EXTRA-MARKER-LINE] -> a managed snapshot directory whose
# marker (real format) carries the given age and optional owner lines.
SCRIPT_MARKER=".ai-review-sandbox"
plant() {
  local d="$AI_REVIEW_SANDBOX_DIR/$1" age="${2:-}" extra="${3:-}"
  mkdir -p "$d"
  printf '%s\nsource_digest=%s\nevidence_format=1\n' "$MAIN" "0000000000000000000000000000000000000000" > "$d/$SCRIPT_MARKER"
  [ -z "$extra" ] || printf '%s\n' "$extra" >> "$d/$SCRIPT_MARKER"
  [ -z "$age" ] || touch -d "$age" "$d/$SCRIPT_MARKER"
  printf '%s' "$d"
}

echo '== ai-review-sandbox sweep-orphans'

# --- the age rule: old orphan removed, young sandbox kept (default 2 hours) ---
OLD="$(plant orphan-old '3 hours ago')"
YOUNG="$(plant orphan-young '10 minutes ago')"
SWEEP_ERR="$TMP/sweep.err"
set +e
"$SCRIPT" sweep-orphans 2> "$SWEEP_ERR"
SWEEP_RC=$?
set -e
check "sweep_exits_zero"                 "[ '$SWEEP_RC' -eq 0 ]"
check "old_orphan_removed"               "[ ! -d '$OLD' ]"
check "young_sandbox_kept"               "[ -d '$YOUNG' ]"
check "old_orphan_delete_logged"         "grep -q 'deleted review snapshot $OLD' '$SWEEP_ERR'"
rmdir "$YOUNG" 2>/dev/null || rm -rf "$YOUNG"

# --- custom threshold: only entries past the given age are removable ---------
OLD2="$(plant cutoff-old '10 seconds ago')"
FRESH="$(plant cutoff-fresh)"
"$SCRIPT" sweep-orphans --max-age-seconds 5 >/dev/null 2>&1
check "custom_threshold_removes_old"     "[ ! -d '$OLD2' ]"
check "custom_threshold_keeps_fresh"     "[ -d '$FRESH' ]"
rm -rf "$FRESH"

# --- evidence retention beats age: an owned sandbox with no reconciled -------
# --- evidence is refused, reported, and the sweep still continues ------------
EV_OLD="$(plant orphan-evidence '3 hours ago' 'evidence_owner=muse:00000000000000000000000000000000')"
NEXT_OLD="$(plant orphan-next '3 hours ago')"
EV_ERR="$TMP/evidence.err"
set +e
"$SCRIPT" sweep-orphans 2> "$EV_ERR"
EV_RC=$?
set -e
check "unreconciled_evidence_retained"   "[ -d '$EV_OLD' ]"
check "unreconciled_evidence_reported"   "grep -qi 'evidence' '$EV_ERR'"
check "refusal_does_not_end_sweep"       "[ ! -d '$NEXT_OLD' ]"
check "evidence_run_exits_zero"          "[ '$EV_RC' -eq 0 ]"
rm -rf "$EV_OLD"

# --- only managed snapshots: no marker, no touch ------------------------------
FOREIGN="$AI_REVIEW_SANDBOX_DIR/foreign-dir"
LOCKDIR="$AI_REVIEW_SANDBOX_DIR/orphan-old.lock"
mkdir -p "$FOREIGN" "$LOCKDIR"
touch -d '3 hours ago' "$FOREIGN" "$LOCKDIR"
"$SCRIPT" sweep-orphans >/dev/null 2>&1
check "unmarked_directory_kept"          "[ -d '$FOREIGN' ]"
check "lock_directory_kept"              "[ -d '$LOCKDIR' ]"
rm -rf "$FOREIGN" "$LOCKDIR"

# --- AI_KEEP_SANDBOX=1 is the same debugging exception here -------------------
KEEP_OLD="$(plant orphan-keep '3 hours ago')"
AI_KEEP_SANDBOX=1 "$SCRIPT" sweep-orphans >/dev/null 2>&1
check "keep_flag_retains_orphan"         "[ -d '$KEEP_OLD' ]"
"$SCRIPT" sweep-orphans >/dev/null 2>&1
check "keep_flag_release_allows_sweep"   "[ ! -d '$KEEP_OLD' ]"

# --- a real snapshot from ensure-copy is swept once its marker ages out -------
REAL="$("$SCRIPT" ensure-copy "$MAIN" orphansweep)"
check "ensure_copy_creates_for_sweep"    "[ -d '$REAL' ]"
touch -d '3 hours ago' "$REAL/$SCRIPT_MARKER"
"$SCRIPT" sweep-orphans >/dev/null 2>&1
check "aged_real_snapshot_removed"       "[ ! -d '$REAL' ]"

# --- the sweep is bounded: a review start never blocks behind a mass cleanup --
CAP_YOUNG="$(plant cap-young)"
CAP_REMAIN=""
i=1
while [ "$i" -le 17 ]; do plant "cap-old-$i" '3 hours ago' >/dev/null; i=$(( i + 1 )); done
"$SCRIPT" sweep-orphans --max-removals 16 >/dev/null 2>&1
CAP_GONE=0; CAP_LEFT=0
i=1
while [ "$i" -le 17 ]; do
  if [ -d "$AI_REVIEW_SANDBOX_DIR/cap-old-$i" ]; then CAP_LEFT=$(( CAP_LEFT + 1 )); CAP_REMAIN="cap-old-$i"; else CAP_GONE=$(( CAP_GONE + 1 )); fi
  i=$(( i + 1 ))
done
check "cap_removes_at_most_the_cap"    "[ '$CAP_GONE' -eq 16 ]"
check "cap_leaves_the_overflow"        "[ '$CAP_LEFT' -eq 1 ]"
check "cap_keeps_young"                "[ -d '$CAP_YOUNG' ]"
"$SCRIPT" sweep-orphans --max-removals 16 >/dev/null 2>&1
check "next_sweep_takes_the_overflow"  "[ ! -d "$AI_REVIEW_SANDBOX_DIR/$CAP_REMAIN" ]"
rm -rf "$CAP_YOUNG"

# --- missing sandbox root is a quiet no-op ------------------------------------
set +e
AI_REVIEW_SANDBOX_DIR="$TMP/does-not-exist" "$SCRIPT" sweep-orphans >/dev/null 2>&1
MISSING_RC=$?
set -e
check "missing_root_exits_zero"          "[ '$MISSING_RC' -eq 0 ]"

# --- bad threshold is refused, nothing is touched -----------------------------
REFUSE="$(plant orphan-refuse '3 hours ago')"
set +e
"$SCRIPT" sweep-orphans --max-age-seconds notanumber >/dev/null 2>&1
BAD_RC=$?
set -e
check "invalid_threshold_refused"        "[ '$BAD_RC' -ne 0 ]"
check "invalid_threshold_touched_nothing" "[ -d '$REFUSE' ]"
rm -rf "$REFUSE"

echo '== ai-review front door sweeps at parent start'

# The wiring proof drives the approval-gate front door WITHOUT
# AI_DEVOPS_TEST_MODE (test mode skips the sweep by design, so offline suites
# never touch the machine-global root); the real task gate runs and passes on
# this clean throwaway repository, and the reviewer wrapper is stubbed so no
# provider call is attempted.
FRONT_STUB="$TMP/front-wrapper"
cat > "$FRONT_STUB" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$FRONT_STUB"

WIRE_OLD="$(plant wiring-old '3 hours ago')"
WIRE_YOUNG="$(plant wiring-young '10 minutes ago')"
set +e
(cd "$MAIN" && AI_CODEX_REVIEW_BIN="$FRONT_STUB" "$FRONT" codex final-check --tests 'true' >/dev/null 2>&1)
WIRE_RC=$?
set -e
check "front_door_exits_zero"         "[ '$WIRE_RC' -eq 0 ]"
check "front_door_removes_orphan"     "[ ! -d '$WIRE_OLD' ]"
check "front_door_keeps_young"        "[ -d '$WIRE_YOUNG' ]"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
