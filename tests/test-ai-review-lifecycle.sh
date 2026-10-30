#!/usr/bin/env bash
# Offline hostile tests for provider-neutral review ownership and accounting.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PY3="$(command -v python3 || command -v python)"
SCRIPT="$REPO_ROOT/bin/ai-review-lifecycle"
PASS=0; FAIL=0
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"

# The existing cases below are about lifecycle ownership, not task gates, so the
# gate is switched off for them. The gate has its own cases at the end of this
# file, where it is switched back on.
export AI_DEVOPS_TEST_MODE=1
export AI_TASK_GATES_MODE=none
# Fixture provenance is explicit; CI must not inherit a desktop engine identity.
unset AI_IMPLEMENTER_ENGINE CODEX_THREAD_ID CODEX_SANDBOX CLAUDECODE AI_REVIEW_IMPLEMENTER

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
R="$TMP/repo"; mkdir -p "$R"; git -C "$R" init -q
git -C "$R" config user.name Test; git -C "$R" config user.email t@example.com
printf 'base\n' > "$R/a.txt"; git -C "$R" add a.txt; git -C "$R" commit -qm init
git -C "$R" remote add origin 'https://user:secret@GitHub.COM/Owner/Repo.git'

PREFLIGHT="$TMP/preflight"
cat > "$PREFLIGHT" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$AI_TEST_PREFLIGHT_LOG"
if [ "${1:-}" = status ]; then printf '%s\n' "${AI_TEST_PREFLIGHT_STATUS:-{\"status\":\"installed-healthy\"\}}"; exit 0; fi
[ "${AI_TEST_PREFLIGHT_FAIL:-0}" != 1 ] || { printf '%s\n' "${AI_TEST_PREFLIGHT_TEXT:-preflight failed}"; exit "${AI_TEST_PREFLIGHT_RC:-1}"; }
EOF
SCOREBOARD="$TMP/scoreboard"
cat > "$SCOREBOARD" <<'EOF'
#!/usr/bin/env bash
[ "${AI_TEST_SCOREBOARD_FAIL:-0}" != 1 ] || exit 9
printf '%s\n' "$*" >> "$AI_TEST_SCOREBOARD_LOG"
cp "$3" "$AI_TEST_SCOREBOARD_META"
EOF
chmod +x "$PREFLIGHT" "$SCOREBOARD"

export AI_REVIEW_LIFECYCLE_DIR="$TMP/state"
export AI_REVIEW_PREFLIGHT_BIN="$PREFLIGHT"
export AI_REVIEW_SCOREBOARD_BIN="$SCOREBOARD"
export AI_TEST_PREFLIGHT_LOG="$TMP/preflight.log"
export AI_TEST_SCOREBOARD_LOG="$TMP/scoreboard.log"
export AI_TEST_SCOREBOARD_META="$TMP/scoreboard-meta.json"

echo '== ai-review-lifecycle'
IDENTITY="$($SCRIPT identity "$R")"
check "identity_normalizes_github_upstream" \
  "[ \"\$(jq -r .normalized_upstream <<<'$IDENTITY')\" = 'https://github.com/Owner/Repo' ]"
check "identity_never_retains_remote_credential" "! grep -q secret <<<'$IDENTITY'"
check "identity_has_exact_head_and_source_digest" \
  "[ \"\$(jq -r .head <<<'$IDENTITY')\" = \"\$(git -C '$R' rev-parse HEAD)\" ] && jq -e '.source_digest|test(\"^[0-9a-f]{64}$\")' <<<'$IDENTITY'"

DIAG="$($SCRIPT observe --provider grok --repo "$R" --run-id diagnostic-one --session-id session-one --caller codex --phase launch --observation provider-started --elapsed 0)"
check "diagnostic envelope records exact join identity without begin" "jq -e '.provider==\"grok\" and .run_id==\"diagnostic-one\" and .session_id==\"session-one\" and .caller==\"codex\" and (.events|length)==1' '$DIAG'"
check "diagnostic observation acquires no assignment lock" "test -z \"\$(find '$AI_REVIEW_LIFECYCLE_DIR/locks' -type d -name '*diagnostic-one*' -print -quit 2>/dev/null)\""
$SCRIPT observe --provider grok --repo "$R" --run-id diagnostic-one --session-id session-one --caller codex --phase terminal --observation provider-completed --elapsed 4 --terminal-reason end-turn --cancellation-initiator provider --cancellation-confirmation not-requested >/dev/null
check "terminal diagnostic preserves launch and terminal summaries" "jq -e '.launch_summary.phase==\"launch\" and .terminal_summary.phase==\"terminal\" and .current.provider_terminal_reason==\"end-turn\"' '$DIAG'"
check "foreign diagnostic join is rejected" "! $SCRIPT observe --provider grok --repo '$R' --run-id diagnostic-one --session-id other --caller codex --phase terminal --observation provider-completed --elapsed 5"
check "invalid diagnostic enum is rejected" "! $SCRIPT observe --provider grok --repo '$R' --run-id invalid-enum --caller codex --phase invented --observation provider-started --elapsed 0"
check "diagnostic path traversal is rejected" "! $SCRIPT observe --provider grok --repo '$R' --run-id ../escape --caller codex --phase launch --observation provider-started --elapsed 0"
$SCRIPT observe --provider kimi --repo "$R" --run-id capped --caller codex --phase awaiting-provider --observation provider-waiting --elapsed 1 >/dev/null
CAPPED="$(find "$AI_REVIEW_LIFECYCLE_DIR/diagnostics" -type f -path '*/kimi/codex/capped.json' -print -quit)"
SEED="$TMP/capped-seed.json"
jq '.events=[range(0;64) as $i | (.current + {elapsed_seconds:$i})] | .truncated=false' "$CAPPED" > "$SEED" && mv "$SEED" "$CAPPED"
$SCRIPT observe --provider kimi --repo "$R" --run-id capped --caller codex --phase awaiting-provider --observation provider-waiting --elapsed 65 >/dev/null
check "diagnostic history is capped and marked truncated" "jq -e '.truncated==true and (.events|length)<=64 and (.events|length)>1' '$CAPPED'"
check "diagnostic envelope remains below 32 KiB" "test \"\$(wc -c < '$CAPPED')\" -le 32768"
CONCURRENT="$($SCRIPT observe --provider glm --repo "$R" --run-id concurrent --caller codex --phase launch --observation provider-started --elapsed 0)"
$SCRIPT observe --provider glm --repo "$R" --run-id concurrent --caller codex --phase terminal --observation provider-completed --elapsed 2 --cancellation-confirmation not-requested >/dev/null & CONCURRENT_ONE=$!
$SCRIPT observe --provider glm --repo "$R" --run-id concurrent --caller codex --phase terminal --observation wrapper-cancelled --elapsed 2 --cancellation-initiator signal --cancellation-confirmation unconfirmed >/dev/null & CONCURRENT_TWO=$!
wait "$CONCURRENT_ONE"; CONCURRENT_ONE_RC=$?; wait "$CONCURRENT_TWO"; CONCURRENT_TWO_RC=$?
check "concurrent diagnostic updates are serialized without lost evidence" "test '$CONCURRENT_ONE_RC' -eq 0 -a '$CONCURRENT_TWO_RC' -eq 0 && jq -e '([.events[].last_observation_type]|index(\"provider-completed\")!=null) and ([.events[].last_observation_type]|index(\"wrapper-cancelled\")!=null)' '$CONCURRENT'"
SHIM_BIN="$TMP/mkdir-shim"; mkdir -p "$SHIM_BIN"
SHIM_FIRST="$TMP/shim-first"; SHIM_SECOND="$TMP/shim-second"; SHIM_DONE="$TMP/shim-done"
cat > "$SHIM_BIN/mkdir" <<'SHIMEOF'
#!/usr/bin/env bash
if [ "$#" -eq 1 ] && [ "$1" = "$AI_TEST_TARGET_LOCK" ]; then
  if [ -d "$1" ]; then
    if [ ! -e "$AI_TEST_SHIM_FIRST" ]; then
      : > "$AI_TEST_SHIM_FIRST"
      exit 0
    fi
    : > "$AI_TEST_SHIM_SECOND"
    exit 0
  fi
fi
exec "$AI_TEST_REAL_MKDIR" "$@"
SHIMEOF
chmod +x "$SHIM_BIN/mkdir"
SHIM_CONCURRENT="$($SCRIPT observe --provider glm --repo "$R" --run-id shim-concurrent --caller codex --phase launch --observation provider-started --elapsed 0)"
SHIM_LOCK="$SHIM_CONCURRENT.update-lock"; SHIM_DIGEST="$(sha256sum "$SHIM_CONCURRENT" | cut -d' ' -f1)"
mkdir "$SHIM_LOCK"; printf '%s\n' "$$" > "$SHIM_LOCK/pid"
export AI_TEST_REAL_MKDIR="$(command -v mkdir)" AI_TEST_TARGET_LOCK="$SHIM_LOCK" AI_TEST_SHIM_FIRST="$SHIM_FIRST" AI_TEST_SHIM_SECOND="$SHIM_SECOND"
PATH="$SHIM_BIN:$PATH" "$SCRIPT" observe --provider glm --repo "$R" --run-id shim-concurrent --caller codex --phase terminal --observation wrapper-cancelled --elapsed 2 --cancellation-initiator signal --cancellation-confirmation unconfirmed >/dev/null && : > "$SHIM_DONE" & SHIM_ONE=$!
for _ in $(seq 1 100); do [ -e "$SHIM_SECOND" ] || [ -e "$SHIM_DONE" ] && break; sleep 0.01; done
check "hostile mkdir cannot clobber a live diagnostic lock owner" "test \"\$(cat '$SHIM_LOCK/pid' 2>/dev/null)\" = \"$$\" -a \"\$(sha256sum '$SHIM_CONCURRENT' | cut -d' ' -f1)\" = '$SHIM_DIGEST' -a ! -e '$SHIM_DONE' -a -e '$SHIM_SECOND'"
rm -f "$SHIM_LOCK/pid"; rmdir "$SHIM_LOCK"
wait "$SHIM_ONE"; SHIM_ONE_RC=$?
check "hostile mkdir observer completes after fixture-owned lock release" "test '$SHIM_ONE_RC' -eq 0 && jq -e '([.events[].last_observation_type]|index(\"provider-started\")!=null) and ([.events[].last_observation_type]|index(\"wrapper-cancelled\")!=null)' '$SHIM_CONCURRENT'"
mkdir "$CONCURRENT.update-lock"; printf '99999999\n' > "$CONCURRENT.update-lock/pid"
$SCRIPT observe --provider glm --repo "$R" --run-id concurrent --caller codex --phase finalizing --observation stale-lock-recovered --elapsed 3 >/dev/null
check "dead diagnostic lock owner is reclaimed without losing the run" "test ! -e '$CONCURRENT.update-lock' && jq -e '[.events[].last_observation_type]|index(\"stale-lock-recovered\")!=null' '$CONCURRENT'"
DIAG_LINK="$(dirname "$DIAG")/symlinked.json"
if ln -s "$DIAG" "$DIAG_LINK" 2>/dev/null && [ -L "$DIAG_LINK" ]; then
  check "linked diagnostic record is rejected" "! $SCRIPT observe --provider grok --repo '$R' --run-id symlinked --session-id session-one --caller codex --phase terminal --observation provider-completed --elapsed 1"
  rm -f "$DIAG_LINK"
else
  ok "linked diagnostic record rejection is platform-gated"
fi

STATE="$($SCRIPT begin --provider grok --repo "$R" --run-id run-one --session-id session-one --caller codex)"
check "begin_runs_mandatory_preflight" "grep -q '^check grok ' '$AI_TEST_PREFLIGHT_LOG'"
check "begin_records_running_state" "[ \"\$(jq -r .status '$STATE')\" = running ]"
check "begin_records_exact_join_fields" \
  "jq -e '.run_id==\"run-one\" and .session_id==\"session-one\" and .caller==\"codex\"' '$STATE'"
LOCK="$(jq -r .lock_path "$STATE")"
check "begin_holds_assignment_lock" "[ -d '$LOCK' ]"
check "duplicate_run_is_rejected" \
  "! '$SCRIPT' begin --provider grok --repo '$R' --run-id run-one --caller codex >/dev/null 2>&1"

REPORT="$TMP/report.md"
cat > "$REPORT" <<'REPEOF'
# Review

Read every changed hunk against the stated intent. The lock release path is
correct, the digest is recomputed at the terminal transition, and no path
writes outside managed storage. The scoreboard append is checked and an
accounting failure keeps the lock for recovery rather than reporting success.
No blocking findings.
REPEOF
$SCRIPT finish --state "$STATE" --verdict APPROVE --report "$REPORT" --elapsed 12 >/dev/null
check "finish_records_terminal_state" "[ \"\$(jq -r .status '$STATE')\" = completed ]"
check "finish_releases_owned_lock" "[ ! -d '$LOCK' ]"
check "finish_appends_scoreboard" "grep -q '^append grok ' '$AI_TEST_SCOREBOARD_LOG'"
check "scoreboard_metadata_carries_source_digest" "jq -e '.source_digest|test(\"^[0-9a-f]{64}$\")' '$AI_TEST_SCOREBOARD_META'"
check "incident_join_is_exact" \
  "'$SCRIPT' join '$STATE' | jq -e '.run_id==\"run-one\" and .session_id==\"session-one\" and .caller==\"codex\" and .status==\"completed\"'"

# record-tests writes machine-readable test evidence into a running review record
# (the local-tests gate reads it) and refuses a failing run or a bad digest.
STATE_TESTS="$($SCRIPT begin --provider grok --repo "$R" --run-id tests-one --caller codex)"
H64="$(printf 'a%.0s' {1..64})"
check "record_tests_writes_passing_evidence" "'$SCRIPT' record-tests --state '$STATE_TESTS' --command 'bash tests/x.sh' --exit 0 --output-sha256 '$H64' && jq -e '.tests.exit==0 and .tests.output_sha256==\"$H64\" and .tests.command==\"bash tests/x.sh\"' '$STATE_TESTS' >/dev/null"
check "record_tests_refuses_a_failing_run" "! '$SCRIPT' record-tests --state '$STATE_TESTS' --command 'bash tests/x.sh' --exit 1 --output-sha256 '$H64' >/dev/null 2>&1"
check "record_tests_refuses_a_bad_digest" "! '$SCRIPT' record-tests --state '$STATE_TESTS' --command 'bash tests/x.sh' --exit 0 --output-sha256 nothex >/dev/null 2>&1"
# The usage text documents the record-tests entry, and a refused attempt cleans
# up after itself: it never overwrites or partially writes the recorded evidence.
check "usage_lists_record-tests" "'$SCRIPT' --help | grep -q 'record-tests'"
check "a_refused_record-tests_leaves_the_recorded_evidence_untouched" \
  "! '$SCRIPT' record-tests --state '$STATE_TESTS' --command 'bash tests/bad.sh' --exit 1 --output-sha256 '$H64' >/dev/null 2>&1 && jq -e '.tests.command==\"bash tests/x.sh\" and .tests.exit==0 and .tests.output_sha256==\"$H64\"' '$STATE_TESTS' >/dev/null"
STATE_STALE="$($SCRIPT begin --provider qwen --repo "$R" --run-id stale-one --caller codex)"
printf 'changed\n' >> "$R/a.txt"
$SCRIPT finish --state "$STATE_STALE" --verdict APPROVE --report "$REPORT" --elapsed 3 >/dev/null
check "source_change_forces_blocked_verdict" "[ \"\$(jq -r .verdict '$STATE_STALE')\" = BLOCKED ]"
check "source_change_records_stale_failure" \
  "jq -e '.stale==true and .failure_class==\"stale-source\"' '$STATE_STALE'"
git -C "$R" checkout -q -- a.txt

AI_TEST_PREFLIGHT_FAIL=1 "$SCRIPT" begin --provider kimi --repo "$R" --run-id unhealthy --caller codex >/dev/null 2>&1 || true
FAILED_STATE="$(find "$AI_REVIEW_LIFECYCLE_DIR/runs" -type f -path '*/kimi/codex/unhealthy.json' -print -quit)"
check "preflight_failure_is_terminally_recorded" "[ \"\$(jq -r .status '$FAILED_STATE')\" = preflight_failed ]"
check "preflight_failure_releases_lock" "[ ! -d \"\$(jq -r .lock_path '$FAILED_STATE')\" ]"

# #1562: a held provider's refusal carries its truthful class into the record.
AI_TEST_PREFLIGHT_FAIL=1 AI_TEST_PREFLIGHT_RC=3 AI_TEST_PREFLIGHT_TEXT='qwen is quarantined until epoch 9 (out-of-credit).' \
  AI_TEST_PREFLIGHT_STATUS='{"provider":"qwen","status":"quarantined","failure_class":"out-of-credit"}' \
  "$SCRIPT" begin --provider qwen --repo "$R" --run-id held --caller codex >/dev/null 2>"$TMP/held.err" || true
HELD_STATE="$(find "$AI_REVIEW_LIFECYCLE_DIR/runs" -type f -path '*/qwen/codex/held.json' -print -quit)"
check "held_provider_refusal_records_out_of_credit_class" "jq -e '.status==\"preflight_failed\" and .failure_class==\"out-of-credit\" and .preflight.failure_class==\"out-of-credit\"' '$HELD_STATE'"
check "held_provider_refusal_names_class_on_stderr" "grep -q 'out-of-credit' '$TMP/held.err'"
check "unclassified_preflight_failure_keeps_null_class" "jq -e '.failure_class==null' '$FAILED_STATE'"

# #1562: a review whose owner process is gone must not stay "running" forever.
sleep 300 & LIVE_OWNER=$!
STATE_LIVE="$(AI_REVIEW_LIFECYCLE_OWNER_PID=$LIVE_OWNER "$SCRIPT" begin --provider muse --repo "$R" --run-id owner-live --caller codex)"
sh -c 'exit 0' & DEAD_OWNER=$!; wait "$DEAD_OWNER"
STATE_DEAD="$(AI_REVIEW_LIFECYCLE_OWNER_PID=$LIVE_OWNER "$SCRIPT" begin --provider muse --repo "$R" --run-id owner-dead --caller codex)"
row="$(jq --argjson pid "$DEAD_OWNER" '.owner_pid=$pid|.owner_start=null' "$STATE_DEAD")"; printf '%s\n' "$row" > "$STATE_DEAD"
check "begin_records_the_review_owner" "jq -e --argjson pid $LIVE_OWNER '.owner_pid==\$pid' '$STATE_LIVE'"
"$SCRIPT" join "$STATE_DEAD" > "$TMP/join-dead.json"
check "join_reconciles_dead_owner_to_interrupted" "jq -e '.status==\"interrupted\" and .verdict==\"BLOCKED\" and .failure_class==\"interrupted\"' '$TMP/join-dead.json' && jq -e '.interruption.detected_by==\"join\" and .finished_at!=null' '$STATE_DEAD'"
check "reconciled_interruption_releases_lock" "[ ! -d \"\$(jq -r .lock_path '$STATE_DEAD')\" ]"
"$SCRIPT" join "$STATE_LIVE" >/dev/null
check "join_leaves_live_owner_running" "jq -e '.status==\"running\"' '$STATE_LIVE'"
STATE_DEAD2="$(AI_REVIEW_LIFECYCLE_OWNER_PID=$LIVE_OWNER "$SCRIPT" begin --provider muse --repo "$R" --run-id owner-dead-2 --caller codex)"
row="$(jq --argjson pid "$DEAD_OWNER" '.owner_pid=$pid' "$STATE_DEAD2")"; printf '%s\n' "$row" > "$STATE_DEAD2"
STATE_NEXT="$(AI_REVIEW_LIFECYCLE_OWNER_PID=$LIVE_OWNER "$SCRIPT" begin --provider muse --repo "$R" --run-id owner-next --caller codex)"
check "next_run_reconciles_dead_owner_to_interrupted" "jq -e '.status==\"interrupted\" and .interruption.detected_by==\"begin\"' '$STATE_DEAD2'"
check "next_run_leaves_live_owner_running" "jq -e '.status==\"running\"' '$STATE_LIVE'"
row="$(jq --argjson pid "$LIVE_OWNER" '.owner_pid=$pid|.owner_start="1"' "$STATE_NEXT")"; printf '%s\n' "$row" > "$STATE_NEXT"
"$SCRIPT" join "$STATE_NEXT" >/dev/null
if [ -r "/proc/$LIVE_OWNER/stat" ]; then
  check "reused_pid_with_different_start_is_interrupted" "jq -e '.status==\"interrupted\"' '$STATE_NEXT'"
fi
STATE_LEGACY="$("$SCRIPT" begin --provider muse --repo "$R" --run-id owner-legacy --caller codex)"
"$SCRIPT" join "$STATE_LEGACY" >/dev/null
check "record_without_owner_is_never_guessed_interrupted" "jq -e '.status==\"running\"' '$STATE_LEGACY'"
# #1691: the sweep closes only ownerless records older than its bound.
"$SCRIPT" sweep >/dev/null 2>&1
check "sweep_spares_fresh_ownerless_record" "jq -e '.status==\"running\"' '$STATE_LEGACY'"
"$SCRIPT" sweep --older-than 0 --dry-run > "$TMP/sweep-dry.txt" 2>/dev/null
check "sweep_dry_run_lists_without_changing" "grep -qF '$STATE_LEGACY' '$TMP/sweep-dry.txt' && jq -e '.status==\"running\"' '$STATE_LEGACY'"
STATE_OLD="$("$SCRIPT" begin --provider muse --repo "$R" --run-id owner-legacy-old --caller codex)"
row="$(jq '.updated_at="2026-01-01T00:00:00Z"' "$STATE_OLD")"; printf '%s\n' "$row" > "$STATE_OLD"
LOCK_OLD="$(jq -r .lock_path "$STATE_OLD")"
"$SCRIPT" sweep >/dev/null 2>&1
check "sweep_interrupts_stale_ownerless_record" "jq -e '.status==\"interrupted\" and .verdict==\"BLOCKED\" and .interruption.detected_by==\"sweep\" and .interruption.reason==\"ownerless-stale\"' '$STATE_OLD' && [ ! -e '$LOCK_OLD' ]"
check "sweep_leaves_fresh_record_after_real_run" "jq -e '.status==\"running\"' '$STATE_LEGACY'"
check "sweep_rejects_bad_bound" "! '$SCRIPT' sweep --older-than x >/dev/null 2>&1"
kill "$LIVE_OWNER" 2>/dev/null; wait "$LIVE_OWNER" 2>/dev/null
STATE_ACCOUNT="$($SCRIPT begin --provider glm --repo "$R" --run-id accounting --caller codex)"
AI_TEST_SCOREBOARD_FAIL=1 "$SCRIPT" fail --state "$STATE_ACCOUNT" --elapsed 4 --failure provider-timeout >/dev/null 2>&1 || true
check "scoreboard_failure_is_visible" "[ \"\$(jq -r .status '$STATE_ACCOUNT')\" = accounting_failed ]"
check "scoreboard_failure_retains_lock_for_recovery" "[ -d \"\$(jq -r .lock_path '$STATE_ACCOUNT')\" ]"

check "unsafe_run_id_is_rejected" \
  "! '$SCRIPT' begin --provider grok --repo '$R' --run-id '../escape' --caller codex >/dev/null 2>&1"
check "unknown_provider_is_rejected" \
  "! '$SCRIPT' begin --provider fake --repo '$R' --run-id fake --caller codex >/dev/null 2>&1"
check "claude_is_a_supported_governed_provider" \
  "AI_DEVOPS_TEST_MODE=1 '$SCRIPT' begin --provider claude --repo '$R' --run-id claude-test --caller codex --preflight none >/dev/null"
check "unknown_command_is_rejected" "! '$SCRIPT' nonsense"

EMPTY_REPORT="$TMP/empty-report.md"
cat > "$EMPTY_REPORT" <<'EMPTYEOF'
# Review

APPROVE
EMPTYEOF
STATE_EMPTY="$($SCRIPT begin --provider muse --repo "$R" --run-id empty-report --caller codex)"
$SCRIPT finish --state "$STATE_EMPTY" --verdict APPROVE --report "$EMPTY_REPORT" --elapsed 5 >/dev/null
check "approval with an empty report is rejected as malformed"   "jq -e '.verdict==\"BLOCKED\" and .failure_class==\"empty-report\"' '$STATE_EMPTY'"

STATE_NOREPORT="$($SCRIPT begin --provider deepseek --repo "$R" --run-id no-report --caller codex)"
$SCRIPT finish --state "$STATE_NOREPORT" --verdict APPROVE --elapsed 5 >/dev/null
check "approval with no report at all is rejected as malformed"   "jq -e '.verdict==\"BLOCKED\" and .failure_class==\"empty-report\"' '$STATE_NOREPORT'"

STATE_THIN_REJECT="$($SCRIPT begin --provider glm --repo "$R" --run-id thin-reject --caller codex)"
$SCRIPT finish --state "$STATE_THIN_REJECT" --verdict REJECT --report "$EMPTY_REPORT" --elapsed 5 >/dev/null
check "rejection with an empty report is also rejected as malformed"   "jq -e '.verdict==\"BLOCKED\" and .failure_class==\"empty-report\"' '$STATE_THIN_REJECT'"

STATE_SUBSTANTIVE="$($SCRIPT begin --provider kimi --repo "$R" --run-id substantive --caller codex)"
$SCRIPT finish --state "$STATE_SUBSTANTIVE" --verdict APPROVE --report "$REPORT" --elapsed 5 >/dev/null
check "an approval backed by a substantive report still completes"   "jq -e '.verdict==\"APPROVE\" and .status==\"completed\"' '$STATE_SUBSTANTIVE'"

# Keep the terminal lifecycle contract from the retired GLM pool suite.
STATE_REVISE="$($SCRIPT begin --provider glm --repo "$R" --run-id revise --caller codex)"
sed 's/APPROVE/REVISE/g' "$REPORT" > "$TMP/revise.md"
$SCRIPT finish --state "$STATE_REVISE" --verdict REVISE --report "$TMP/revise.md" --elapsed 1 >/dev/null
check "a substantive REVISE completes the lifecycle" \
  "jq -e '.verdict==\"REVISE\" and .status==\"completed\"' '$STATE_REVISE'"


# --------------------------------------------------------------------------
# Task gate. A review the change set does not call for must be refused BEFORE
# any assignment lock, any state file, or any provider call exists.
# --------------------------------------------------------------------------
GR="$TMP/gated"; mkdir -p "$GR"; git -C "$GR" init -q --initial-branch=main
git -C "$GR" config user.name Test; git -C "$GR" config user.email t@example.com
git -C "$GR" remote add origin 'https://github.com/popcre/ai-devops.git'
printf 'base\n' > "$GR/README.md"; git -C "$GR" add -A; git -C "$GR" commit -qm init
printf 'a note\n' > "$GR/docs.md"

export AI_TASK_GATES_DIR="$TMP/gates"
export AI_TASK_GATES_BIN="$REPO_ROOT/bin/ai-task-gates"
( cd "$GR" && "$AI_TASK_GATES_BIN" start --class prose --reason 'documentation only' ) >/dev/null 2>&1

GATE_LOG="$TMP/gate-preflight.log"
gated_begin(){
  local run="$1"; shift
  ( cd "$GR" && AI_TASK_GATES_MODE=standard AI_TEST_PREFLIGHT_LOG="$GATE_LOG" \
      "$SCRIPT" begin --provider grok --repo "$GR" --run-id "$run" --caller codex "$@" )
}

GATE_OUT="$(gated_begin gate-blocked 2>&1)"; GATE_RC=$?
check "a documentation-only change does not start a paid review" "[ '$GATE_RC' -ne 0 ]"
check "the refusal explains which gate applies" "printf '%s' \"\$GATE_OUT\" | grep -q ai-task-gates"
check "no provider preflight ran for the refused review" "[ ! -s '$GATE_LOG' ]"
check "no lifecycle state was created for the refused review" \
  "[ -z \"\$(find '$AI_REVIEW_LIFECYCLE_DIR/runs' -type f -name 'gate-blocked.json' -print -quit 2>/dev/null)\" ]"

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-reviewer-approval.sh"
LIB_REVIEWER_APPROVAL_BIN="$REPO_ROOT/bin"
appr_file(){ mint_reviewer_approval "$TMP" "$1" plan-review; }
GATE_STATE="$(gated_begin gate-owner --reviewer-approval "$(appr_file "$GR" review "$REPO_ROOT/bin/ai-task-gates")")"
check "a reviewer-approved review still runs the full gates" "[ -f \"\$GATE_STATE\" ]"
check "the reviewer-approved review ran its provider preflight" "grep -q '^check grok ' '$GATE_LOG'"
REC_STATE="$( cd "$GR" && AI_REVIEW_GATE_MODE=plan-review AI_REVIEW_IMPLEMENTER=claude AI_TASK_GATES_MODE=standard AI_TEST_PREFLIGHT_LOG="$GATE_LOG" "$SCRIPT" begin --provider grok --repo "$GR" --run-id gate-recorded --caller codex )"
check "begin records the review mode and implementing engine for gate independence" \
  "jq -e '.review_mode==\"plan-review\" and .implementer_engine==\"claude\" and .caller==\"codex\"' \"\$REC_STATE\""
REC_REPORT="$TMP/grok-plan-review-gate-recorded.md"
{ printf '# grok plan review\n\n'; for n in 1 2 3 4 5 6; do printf 'The documentation change is accurate, scoped, and consistent with the surrounding contract; finding %s is none.\n' "$n"; done; printf '\n## Verdict\nAPPROVE\n'; } > "$REC_REPORT"
"$SCRIPT" finish --state "$REC_STATE" --verdict APPROVE --report "$REC_REPORT" --elapsed 5 >/dev/null 2>&1
check "a finished lifecycle APPROVE lifts the forbidden review for its exact head end to end" \
  "( cd '$GR' && AI_REVIEW_LIFECYCLE_DIR='$AI_REVIEW_LIFECYCLE_DIR' '$REPO_ROOT/bin/ai-task-gates' check --before review --reviewer-approval '$REC_REPORT' )"

cp "$REC_STATE" "$TMP/unscoped-state-before"
jq '.evidence_scope="selected-code"|.code_only={paths:["README.md"]}' "$TMP/unscoped-state-before" > "$REC_STATE"
check "selected README scope cannot release generic whole-repository gate" \
  "! ( cd '$GR' && AI_REVIEW_LIFECYCLE_DIR='$AI_REVIEW_LIFECYCLE_DIR' '$REPO_ROOT/bin/ai-task-gates' check --before review --reviewer-approval '$REC_REPORT' ) >/dev/null 2>&1"
cp "$TMP/unscoped-state-before" "$REC_STATE"

printf 'select 1;\n' > "$GR/migration.sql"
GATE_OUT2="$(gated_begin gate-escalated 2>&1)"; GATE_RC2=$?
check "work that outgrew its declared class refuses the review" "[ '$GATE_RC2' -ne 0 ]"
check "the refusal names the file that escalated the class" \
  "printf '%s' \"\$GATE_OUT2\" | grep -q migration.sql"
rm -f "$GR/migration.sql"

# --- packet identity on terminal finish (#1111, additive) ---------------------
# finish accepts --packet-dir and --packet-sha256, writes them into state, and
# join() surfaces them. Without the new args, finish still works unchanged.
PKT_SHA="$(printf 'a%.0s' $(seq 1 64))"
STATE_PKT="$($SCRIPT begin --provider grok --repo "$R" --run-id packet-run --caller codex)"
$SCRIPT finish --state "$STATE_PKT" --verdict APPROVE --report "$REPORT" --elapsed 5 \
  --packet-dir '/tmp/fake-packet' --packet-sha256 "$PKT_SHA" >/dev/null
check "finish_records_packet_dir_and_sha256" \
  "jq -e --arg s '$PKT_SHA' '.packet_dir==\"/tmp/fake-packet\" and .packet_sha256==\$s' '$STATE_PKT'"
check "join_includes_packet_identity" \
  "'$SCRIPT' join '$STATE_PKT' | jq -e --arg s '$PKT_SHA' '.packet_dir==\"/tmp/fake-packet\" and .packet_sha256==\$s'"
check "scoreboard_receives_packet_sha256" \
  "jq -e --arg s '$PKT_SHA' '.packet_sha256==\$s' '$AI_TEST_SCOREBOARD_META'"

STATE_NOPKT="$($SCRIPT begin --provider grok --repo "$R" --run-id no-packet-run --caller codex)"
$SCRIPT finish --state "$STATE_NOPKT" --verdict APPROVE --report "$REPORT" --elapsed 5 >/dev/null
check "finish_without_packet_args_still_works" \
  "[ \"\$(jq -r .status '$STATE_NOPKT')\" = completed ] && jq -e '.packet_dir==null and .packet_sha256==null' '$STATE_NOPKT'"
check "join_without_packet_args_still_works" \
  "'$SCRIPT' join '$STATE_NOPKT' | jq -e '.status==\"completed\" and .packet_dir==null'"

STATE_BADSHA="$($SCRIPT begin --provider grok --repo "$R" --run-id bad-sha-run --caller codex)"
check "invalid_packet_sha256_is_rejected" \
  "! $SCRIPT finish --state '$STATE_BADSHA' --verdict APPROVE --report '$REPORT' --elapsed 5 --packet-sha256 'not-hex' >/dev/null 2>&1"

echo '== per-session skip recorded by the lifecycle'
export AI_REVIEW_SESSION_SKIP_DIR="$TMP/session-skip"
STATE_SKIP="$(AI_CALLER_SESSION_ID=skip-session-a $SCRIPT begin --provider grok --repo "$R" --run-id skip-run-a --caller codex)"
AI_CALLER_SESSION_ID=skip-session-a $SCRIPT fail --state "$STATE_SKIP" --elapsed 3 --failure fast-fail-silent-start >/dev/null 2>&1
check "lifecycle_records_caller_session_id" "jq -e '.caller_session_id==\"skip-session-a\"' '$STATE_SKIP' >/dev/null"
check "lifecycle_failure_adds_provider_to_session_skip" "grep -q '\"provider\":\"grok\",\"reason\":\"fast-fail-silent-start\"' '$AI_REVIEW_SESSION_SKIP_DIR/skip-session-a.jsonl'"
STATE_SKIP_B="$(AI_CALLER_SESSION_ID=skip-session-b $SCRIPT begin --provider grok --repo "$R" --run-id skip-run-b --caller codex)"
AI_CALLER_SESSION_ID=skip-session-b $SCRIPT fail --state "$STATE_SKIP_B" --elapsed 3 --failure tests-command-failed >/dev/null 2>&1
check "caller_side_failure_does_not_skip_reviewer" "test ! -e '$AI_REVIEW_SESSION_SKIP_DIR/skip-session-b.jsonl'"
unset AI_REVIEW_SESSION_SKIP_DIR

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
