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

# Packet/sandbox classification calls ai-task-gates; offline suites mock it
# (same contract as tests/test-ai-review-engine.sh) so no real gate run starts
# and the suite does not depend on host install state.
mkdir -p "$TMP/mockbin"
cat > "$TMP/mockbin/ai-task-gates" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '{"identity_resolved":true,"effective_class":"code","observed_class":"code"}'
EOF
chmod +x "$TMP/mockbin/ai-task-gates"
export PATH="$TMP/mockbin:$PATH"

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

# --- abort path: signal the with-copy WRAPPER itself; trap must still delete --
# kill -TERM $$ inside a plain sh -c only kills the child. The guarantee is
# about INT/TERM delivered to the creating run, so the wrapped command TERMs
# its parent (the with-copy shell) after publishing the snapshot path.
ABORT_OUT="$TMP/abort.out"
rm -f "$ABORT_OUT"
set +e
"$SCRIPT" with-copy "$MAIN" selfcabort -- bash -c 'printf %s "$AI_REVIEW_SNAPSHOT" > "$1"; kill -TERM "$PPID"; sleep 30' bash "$ABORT_OUT"
ABORT_RC=$?
set -e
SNAP_ABORT="$(cat "$ABORT_OUT" 2>/dev/null || true)"
check "abort_path_exposed_snapshot"          "[ -n '$SNAP_ABORT' ]"
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

# --- AI_KEEP_SANDBOX must be exactly 1; other values still delete ------------
for flagval in 0 empty yes true; do
  case "$flagval" in
    empty) KEEPENV="" ;;
    *) KEEPENV="$flagval" ;;
  esac
  OUT_F="$TMP/flag-$flagval.out"
  set +e
  AI_KEEP_SANDBOX="$KEEPENV" "$SCRIPT" with-copy "$MAIN" "selfcflag$flagval" -- sh -c 'printf %s "$AI_REVIEW_SNAPSHOT" > "$1"' sh "$OUT_F"
  set -e
  SNAP_F="$(cat "$OUT_F" 2>/dev/null || true)"
  check "keep_flag_rejects_${flagval}"        "[ -n '$SNAP_F' ] && [ ! -d '$SNAP_F' ]"
done

# --- foreign orphans must not block a fresh review (plan step 4) ------------
# A backlog of aged managed snapshots — including one holding unpublished
# paid evidence that removal must refuse — and more entries than the sweep's
# examination cap cannot prevent a new with-copy run or mutate its snapshot.
PYTHON_BIN="$(command -v python3 || command -v python)"
EVENTS_TOOL="$REPO_ROOT/tools/reviewer_events.py"
FOREIGN_TAG=foreign-orphan-held
FOREIGN_SNAP="$("$SCRIPT" ensure-copy "$MAIN" "$FOREIGN_TAG")"
FOREIGN_EVIDENCE_ID=""
if [ -n "$PYTHON_BIN" ] && [ -f "$EVENTS_TOOL" ]; then
  FOREIGN_EVIDENCE_ID="$(cd "$MAIN" && "$PYTHON_BIN" "$EVENTS_TOOL" begin grok 2>/dev/null || true)"
  if [ -n "$FOREIGN_EVIDENCE_ID" ]; then
    "$PYTHON_BIN" "$EVENTS_TOOL" require-report grok "$FOREIGN_EVIDENCE_ID" "$FOREIGN_SNAP" >/dev/null 2>&1 || true
  fi
fi
check "foreign_orphan_fixture_created"       "[ -d '$FOREIGN_SNAP' ] && [ -f '$FOREIGN_SNAP/.ai-review-sandbox' ]"
# Age every fixture marker past the default orphan age (2h).
find "$AI_REVIEW_SANDBOX_DIR" -mindepth 2 -maxdepth 2 -name .ai-review-sandbox \
  -exec touch -d '3 hours ago' {} + 2>/dev/null || \
  find "$AI_REVIEW_SANDBOX_DIR" -mindepth 2 -maxdepth 2 -name .ai-review-sandbox \
    -exec touch -t 202001010000 {} + 2>/dev/null || true
# Extra recoverable orphans beyond the 16-entry examination cap.
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18; do
  _extra="$AI_REVIEW_SANDBOX_DIR/orphan-extra-$i"
  mkdir -p "$_extra"
  printf '%s\nsource_digest=deadbeef\n' "$_extra" > "$_extra/.ai-review-sandbox"
done
FRESH_OUT="$TMP/fresh-amid-orphans.out"
set +e
"$SCRIPT" with-copy "$MAIN" freshamidorphans -- sh -c 'printf %s "$AI_REVIEW_SNAPSHOT" > "$1"; printf ok > "$1.done"' sh "$FRESH_OUT"
FRESH_RC=$?
set -e
FRESH_SNAP="$(cat "$FRESH_OUT" 2>/dev/null || true)"
check "foreign_orphans_do_not_block_fresh_review" \
  "[ '$FRESH_RC' -eq 0 ] && [ -n '$FRESH_SNAP' ] && [ ! -d '$FRESH_SNAP' ] && [ -f '$FRESH_OUT.done' ]"
# Sweep must stay best-effort and bounded: the held foreign evidence survives,
# and a subsequent fresh run still works after the sweep.
set +e
"$SCRIPT" sweep-orphans --max-age-seconds 7200 --max-removals 16 >/dev/null 2>"$TMP/sweep-amid.err"
SWEEP_RC=$?
set -e
check "orphan_sweep_stays_best_effort"       "[ '$SWEEP_RC' -eq 0 ]"
check "foreign_orphan_evidence_survives_sweep" "[ -d '$FOREIGN_SNAP' ]"
FRESH2_OUT="$TMP/fresh-after-sweep.out"
set +e
"$SCRIPT" with-copy "$MAIN" freshaftersweep -- sh -c 'printf %s "$AI_REVIEW_SNAPSHOT" > "$1"' sh "$FRESH2_OUT"
FRESH2_RC=$?
set -e
FRESH2_SNAP="$(cat "$FRESH2_OUT" 2>/dev/null || true)"
check "fresh_review_still_works_after_sweep" \
  "[ '$FRESH2_RC' -eq 0 ] && [ -n '$FRESH2_SNAP' ] && [ ! -d '$FRESH2_SNAP' ]"
if [ -n "$FOREIGN_EVIDENCE_ID" ] && [ -n "$PYTHON_BIN" ]; then
  printf '# Synthetic completed review\n' > "$TMP/foreign-orphan-report.md"
  "$PYTHON_BIN" "$EVENTS_TOOL" publish-report grok "$FOREIGN_EVIDENCE_ID" "$TMP/foreign-orphan-report.md" >/dev/null 2>&1 || true
  rm -f "$TMP/foreign-orphan-report.md"
  "$SCRIPT" remove-copy "$MAIN" "$FOREIGN_TAG" >/dev/null 2>&1 || true
fi
[ ! -d "$FOREIGN_SNAP" ] || "$SCRIPT" remove-copy "$MAIN" "$FOREIGN_TAG" >/dev/null 2>&1 || true
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18; do
  rm -rf "$AI_REVIEW_SANDBOX_DIR/orphan-extra-$i"
done

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
