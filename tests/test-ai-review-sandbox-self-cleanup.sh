#!/usr/bin/env bash
# Phase 2 self-cleanup (issue #711): the run that creates a review snapshot
# deletes it before returning — on success, on failure, and on abort.
# AI_KEEP_SANDBOX=1 is the debugging exception and must keep the snapshot.
#
# Fully offline: real git, no network, no provider calls.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/bin/ai-review-sandbox"
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
echo uncommitted >> "$MAIN/a.txt"

echo '== ai-review-sandbox self-cleanup'

# --- success path: with-copy deletes the snapshot before returning ------------
SUCCESS_OUT="$TMP/success.out"
"$SCRIPT" with-copy "$MAIN" selfcok -- sh -c 'printf %s "$AI_REVIEW_SNAPSHOT" > "$1"' sh "$SUCCESS_OUT"
SUCCESS_RC=$?
SNAP_OK="$(cat "$SUCCESS_OUT" 2>/dev/null || true)"
check "success_path_exits_zero"              "[ '$SUCCESS_RC' -eq 0 ]"
check "success_path_exposed_snapshot"        "[ -n '$SNAP_OK' ]"
check "success_path_deletes_snapshot"        "[ ! -d '$SNAP_OK' ]"
check "success_path_leaves_no_sandbox_dir"   "[ -z \"\$(find '$AI_REVIEW_SANDBOX_DIR' -mindepth 1 -maxdepth 1 -type d 2>/dev/null)\" ]"

# --- failure path: the wrapped command fails, snapshot still goes away --------
FAIL_OUT="$TMP/fail.out"
set +e
"$SCRIPT" with-copy "$MAIN" selfcfail -- sh -c 'printf %s "$AI_REVIEW_SNAPSHOT" > "$1"; exit 7' sh "$FAIL_OUT"
FAIL_RC=$?
set -e
SNAP_FAIL="$(cat "$FAIL_OUT" 2>/dev/null || true)"
check "failure_path_propagates_command_rc"   "[ '$FAIL_RC' -eq 7 ]"
check "failure_path_exposed_snapshot"        "[ -n '$SNAP_FAIL' ]"
check "failure_path_deletes_snapshot"        "[ ! -d '$SNAP_FAIL' ]"

# --- abort path: the command is killed mid-run; trap must still delete --------
ABORT_OUT="$TMP/abort.out"
set +e
"$SCRIPT" with-copy "$MAIN" selfcabort -- sh -c 'printf %s "$AI_REVIEW_SNAPSHOT" > "$1"; kill -TERM $$; sleep 30' sh "$ABORT_OUT"
ABORT_RC=$?
set -e
SNAP_ABORT="$(cat "$ABORT_OUT" 2>/dev/null || true)"
check "abort_path_deletes_snapshot"          "[ -n '$SNAP_ABORT' ] && [ ! -d '$SNAP_ABORT' ]"

# --- AI_KEEP_SANDBOX=1 keeps the snapshot (debugging only) -------------------
KEEP_OUT="$TMP/keep.out"
set +e
AI_KEEP_SANDBOX=1 "$SCRIPT" with-copy "$MAIN" selfckeep -- sh -c 'printf %s "$AI_REVIEW_SNAPSHOT" > "$1"' sh "$KEEP_OUT"
KEEP_RC=$?
set -e
SNAP_KEEP="$(cat "$KEEP_OUT" 2>/dev/null || true)"
check "keep_flag_exits_zero"                 "[ '$KEEP_RC' -eq 0 ]"
check "keep_flag_exposed_snapshot"           "[ -n '$SNAP_KEEP' ]"
check "keep_flag_retains_snapshot"           "[ -d '$SNAP_KEEP' ]"
check "keep_flag_retains_marker"             "[ -f '$SNAP_KEEP/.ai-review-sandbox' ]"
"$SCRIPT" remove-copy "$MAIN" selfckeep >/dev/null 2>&1 || true
check "keep_flag_snapshot_removable_later"   "[ ! -d '$SNAP_KEEP' ]"

# --- ensure-copy + explicit remove-copy remains the session pattern ----------
SESSION_SNAP="$("$SCRIPT" ensure-copy "$MAIN" selfcsess)"
check "ensure_copy_still_creates"            "[ -d '$SESSION_SNAP' ]"
"$SCRIPT" remove-copy "$MAIN" selfcsess
check "remove_copy_still_deletes"            "[ ! -d '$SESSION_SNAP' ]"

# --- AI_KEEP_SANDBOX also blocks remove-copy (same exception) ----------------
KEEP2="$("$SCRIPT" ensure-copy "$MAIN" selfckeep2)"
set +e
AI_KEEP_SANDBOX=1 "$SCRIPT" remove-copy "$MAIN" selfckeep2 >/dev/null 2>&1
set -e
check "keep_flag_blocks_remove_copy"         "[ -d '$KEEP2' ]"
"$SCRIPT" remove-copy "$MAIN" selfckeep2 >/dev/null 2>&1 || true
check "keep2_removable_without_flag"         "[ ! -d '$KEEP2' ]"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
