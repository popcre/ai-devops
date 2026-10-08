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

FRONT="$REPO_ROOT/bin/ai-review"
FRONT_STUB="$TMP/front-wrapper"
cat > "$FRONT_STUB" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$AI_TEST_FRONT_LOG"
EOF
chmod +x "$FRONT_STUB"
export AI_TEST_FRONT_LOG="$TMP/front.log"
# Shipped registry has Claude absent. A fixture is required to exercise the
# legacy Claude adapter path; membership refusal is asserted below.
printf '{"version":1,"providers":{"claude":{"registry_state":"registered","reason":"offline front-door fixture"}}}\n' > "$TMP/claude-registry.json"
(cd "$R" && AI_CODEX_REVIEW_BIN="$FRONT_STUB" "$FRONT" codex final-check --tests 'bash tests/focused.sh' --base origin/main --assert-head 0123456789012345678901234567890123456789)
check "approval front door forwards exact test and source options" \
  "printf '%s\n' final-check --tests 'bash tests/focused.sh' --base origin/main --assert-head 0123456789012345678901234567890123456789 | diff -u - '$AI_TEST_FRONT_LOG'"
if (cd "$R" && AI_CLAUDE_REVIEW_BIN="$FRONT_STUB" "$FRONT" claude final-check --tests 'bash tests/focused.sh' --base origin/main --assert-head 0123456789012345678901234567890123456789) >/dev/null 2>&1; then
  check "shipped registry refuses Claude reviews" "false"
else
  check "shipped registry refuses Claude reviews" "true"
fi
(cd "$R" && AI_REVIEW_REGISTRY_FILE="$TMP/claude-registry.json" AI_CLAUDE_REVIEW_BIN="$FRONT_STUB" "$FRONT" claude final-check --tests 'bash tests/focused.sh' --base origin/main --assert-head 0123456789012345678901234567890123456789)
check "approval front door forwards exact test and source options to Claude" \
  "printf '%s\n' final-check --tests 'bash tests/focused.sh' --base origin/main --assert-head 0123456789012345678901234567890123456789 | diff -u - '$AI_TEST_FRONT_LOG'"

PREFLIGHT="$TMP/preflight"
cat > "$PREFLIGHT" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$AI_TEST_PREFLIGHT_LOG"
[ "${AI_TEST_PREFLIGHT_FAIL:-0}" != 1 ]
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

# The wrappers call `begin` for every mode and cannot see the mode or the reviewer
# approval, so `bin/ai-review` hands both on. These cases run the real front door
# with a stub wrapper, which is the path the shipped code actually takes.
FRONT="$REPO_ROOT/bin/ai-review"
STUB="$TMP/stub-wrapper"
cat > "$STUB" <<STUBEOF
#!/usr/bin/env bash
AI_TASK_GATES_MODE=standard AI_TEST_PREFLIGHT_LOG="$GATE_LOG" \
  "$SCRIPT" begin --provider grok --repo "$GR" --run-id "front-\$1" --caller codex
STUBEOF
chmod +x "$STUB"

FRONT_OUT="$( cd "$GR" && AI_REVIEW_REGISTRY_FILE="$TMP/claude-registry.json" AI_CLAUDE_REVIEW_BIN="$STUB" AI_TASK_GATES_MODE=standard "$FRONT" claude diff-review 2>&1 )"; FRONT_RC=$?
check "the front door refuses a paid diff review of a documentation change" "[ '$FRONT_RC' -ne 0 ]"

FRONT_PLAN="$( cd "$GR" && AI_REVIEW_REGISTRY_FILE="$TMP/claude-registry.json" AI_CLAUDE_REVIEW_BIN="$STUB" AI_TASK_GATES_MODE=standard "$FRONT" claude plan-review 2>&1 )"; PLAN_RC=$?
check "a plan review still runs, because it is what decides the class" \
  "[ '$PLAN_RC' -eq 0 ] && [ -f \"\$FRONT_PLAN\" ]"

FRONT_OWNER="$( cd "$GR" && AI_REVIEW_REGISTRY_FILE="$TMP/claude-registry.json" AI_CLAUDE_REVIEW_BIN="$STUB" AI_TASK_GATES_MODE=standard "$FRONT" claude diff-review --reviewer-approval "$(appr_file "$GR" review "$REPO_ROOT/bin/ai-task-gates")" 2>&1 )"; OWNER_RC=$?
check "a reviewer approval reaches the gate the lifecycle runs" \
  "[ '$OWNER_RC' -eq 0 ] && [ -f \"\$FRONT_OWNER\" ]"

# The private review front door must hand a provider only the explicitly
# approved code export, while binding the result to the whole original source.
PRIVATE="$TMP/private-code"; mkdir -p "$PRIVATE/src" "$PRIVATE/evidence" "$PRIVATE/.ai-devops"
git -C "$PRIVATE" init -q
git -C "$PRIVATE" config user.name Test; git -C "$PRIVATE" config user.email t@example.com
git -C "$PRIVATE" remote add origin https://github.com/u2giants/licensor-source-data.git
printf 'print("base")\n' > "$PRIVATE/src/loader.py"
printf 'raw-row-sentinel\n' > "$PRIVATE/evidence/raw.csv"
# The sealed route only opens for a repository whose own declaration carries
# the synthetic-fixtures-only boundary, so the fixture models that opt-in.
printf '{"schema_version":1,"paths":[{"glob":"**","class":"private-evidence"}],"gates":{"private-evidence":{"required":["synthetic-fixtures-only"]},"private-tooling":{"required":["synthetic-fixtures-only"]}}}\n' > "$PRIVATE/.ai-devops/task-gates.json"
git -C "$PRIVATE" add src/loader.py evidence/raw.csv .ai-devops/task-gates.json
git -C "$PRIVATE" commit -qm 'history-raw-sentinel'
printf 'print("changed")\n' > "$PRIVATE/src/loader.py"
git -C "$PRIVATE" add src/loader.py; git -C "$PRIVATE" commit -qm code-change
printf 'untracked-prompt-sentinel\n' > "$PRIVATE/prompt.txt"
printf '["src/loader.py"]\n' > "$TMP/approved-paths.json"
export AI_TASK_GATES_FILE="$REPO_ROOT/config/task-gates.json"
export AI_TASK_GATES_DIR="$TMP/private-gates"
( cd "$PRIVATE" && "$AI_TASK_GATES_BIN" start --class private-evidence ) >/dev/null
PRIVATE_STUB="$TMP/private-review-stub"
cat > "$PRIVATE_STUB" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$AI_TEST_PRIVATE_ARGS"
git ls-files > "$AI_TEST_PRIVATE_TRACKED"
if git log --all -p --format=%B | grep -Eq 'raw-row-sentinel|history-raw-sentinel|untracked-prompt-sentinel'; then
  printf 'exposed\n' > "$AI_TEST_PRIVATE_EXPOSURE"
fi
if grep -Fq "$AI_TEST_PRIVATE_SOURCE" .ai-review-sandbox; then
  printf 'source-path-exposed\n' > "$AI_TEST_PRIVATE_EXPOSURE"
fi
if [ "${AI_TEST_MUTATE_SOURCE:-0}" = 1 ]; then
  printf 'drift\n' >> "$AI_TEST_PRIVATE_SOURCE/evidence/raw.csv"
fi
printf 'VERDICT: APPROVE %s\n' "$(git rev-parse HEAD)"
EOF
chmod +x "$PRIVATE_STUB"
export AI_TEST_PRIVATE_ARGS="$TMP/private-review-args"
export AI_TEST_PRIVATE_TRACKED="$TMP/private-review-tracked"
export AI_TEST_PRIVATE_EXPOSURE="$TMP/private-review-exposure"
export AI_TEST_PRIVATE_SOURCE="$PRIVATE"
PRIVATE_HEAD="$(git -C "$PRIVATE" rev-parse HEAD)"
PRIVATE_OUT="$(cd "$PRIVATE" && AI_DEEPSEEK_REVIEW_BIN="$PRIVATE_STUB" AI_TASK_GATES_MODE=standard "$FRONT" deepseek diff-review --implementer codex --code-only --paths-file "$TMP/approved-paths.json" --base HEAD~1 --assert-head "$PRIVATE_HEAD" 2>&1)"; PRIVATE_RC=$?
check "private stub reaches an exact export but cannot create approval authority" "[ '$PRIVATE_RC' -ne 0 ] && grep -qx 'src/loader.py' '$AI_TEST_PRIVATE_TRACKED' && [ \"\$(wc -l < '$AI_TEST_PRIVATE_TRACKED')\" -eq 1 ]"
check "private export hides raw rows, untracked prompts, Git history, and source path" "[ ! -e '$AI_TEST_PRIVATE_EXPOSURE' ]"
check "private review compares synthetic base and exact synthetic head" "grep -qx -- '--base' '$AI_TEST_PRIVATE_ARGS' && grep -qx 'HEAD~1' '$AI_TEST_PRIVATE_ARGS' && grep -qx -- '--assert-head' '$AI_TEST_PRIVATE_ARGS'"
rm -f "$AI_TEST_PRIVATE_ARGS"
UNKNOWN_OUT="$(cd "$PRIVATE" && AI_DEEPSEEK_REVIEW_BIN="$PRIVATE_STUB" AI_TASK_GATES_MODE=standard "$FRONT" deepseek diff-review --code-only --paths-file "$TMP/approved-paths.json" --base HEAD~1 --assert-head "$PRIVATE_HEAD" 2>&1)"; UNKNOWN_RC=$?
check "unknown implementing engine refuses before provider despite a valid selected export" "[ '$UNKNOWN_RC' -ne 0 ] && [ ! -e '$AI_TEST_PRIVATE_ARGS' ] && printf '%s' \"\$UNKNOWN_OUT\" | grep -q -- '--caller must be a safe non-empty identifier'"
MUTATE_OUT="$(cd "$PRIVATE" && AI_DEEPSEEK_REVIEW_BIN="$PRIVATE_STUB" AI_TEST_MUTATE_SOURCE=1 AI_TASK_GATES_MODE=standard "$FRONT" deepseek diff-review --implementer codex --code-only --paths-file "$TMP/approved-paths.json" --base HEAD~1 --assert-head "$PRIVATE_HEAD" 2>&1)"; MUTATE_RC=$?
check "private review refuses a verdict when unselected source changes during provider work" "[ '$MUTATE_RC' -ne 0 ] && printf '%s' \"\$MUTATE_OUT\" | grep -q 'verdict refused'"
check "a stale private result never prints an APPROVE token" "! printf '%s' \"\$MUTATE_OUT\" | grep -q 'VERDICT: APPROVE'"
TESTS_OUT="$(cd "$PRIVATE" && AI_DEEPSEEK_REVIEW_BIN="$PRIVATE_STUB" AI_TASK_GATES_MODE=standard "$FRONT" deepseek diff-review --implementer codex --code-only --paths-file "$TMP/approved-paths.json" --tests 'cat evidence/raw.csv' 2>&1)"; TESTS_RC=$?
check "private code-only route refuses arbitrary tests commands before provider" "[ '$TESTS_RC' -ne 0 ] && printf '%s' \"\$TESTS_OUT\" | grep -q 'does not accept a tests command'"
CLI_OUT="$(cd "$PRIVATE" && AI_REVIEW_REGISTRY_FILE="$TMP/claude-registry.json" AI_CLAUDE_REVIEW_BIN="$PRIVATE_STUB" AI_TASK_GATES_MODE=standard "$FRONT" claude diff-review --code-only --paths-file "$TMP/approved-paths.json" 2>&1)"; CLI_RC=$?
check "private code-only route refuses tool-capable CLI reviewers before provider" "[ '$CLI_RC' -ne 0 ] && printf '%s' \"\$CLI_OUT\" | grep -q 'attachment-only DeepSeek'"
rm -f "$AI_TEST_PRIVATE_ARGS"
# Grok is paused out of the registry (owner instruction 2026-10-07); a registered
# pool provider exercises the same private-source guard in its place.
for provider_mode in 'claude diff-review' 'claude plan-review' 'codex diff-review' 'qwen diff-review'; do
  set -- $provider_mode
  RAW_CLI_OUT="$(cd "$PRIVATE" && AI_REVIEW_REGISTRY_FILE="$TMP/claude-registry.json" AI_CLAUDE_REVIEW_BIN="$PRIVATE_STUB" AI_CODEX_REVIEW_BIN="$PRIVATE_STUB" AI_TASK_GATES_MODE=standard "$FRONT" "$1" "$2" 2>&1)"; RAW_CLI_RC=$?
  check "ordinary $provider_mode refuses private source before provider" "[ '$RAW_CLI_RC' -ne 0 ] && [ ! -e '$AI_TEST_PRIVATE_ARGS' ] && printf '%s' \"\$RAW_CLI_OUT\" | grep -q 'private source requires'"
done
printf '["evidence/raw.csv"]\n' > "$TMP/raw-paths.json"
rm -f "$AI_TEST_PRIVATE_ARGS"
RAW_OUT="$(cd "$PRIVATE" && AI_DEEPSEEK_REVIEW_BIN="$PRIVATE_STUB" AI_TASK_GATES_MODE=standard "$FRONT" deepseek diff-review --implementer codex --code-only --paths-file "$TMP/raw-paths.json" 2>&1)"; RAW_RC=$?
check "private code-only route refuses a raw-evidence selection before provider" "[ '$RAW_RC' -ne 0 ] && [ ! -e '$AI_TEST_PRIVATE_ARGS' ]"

# Exercise the real attachment-only DeepSeek wrapper without a network call.
# The mock transport captures the complete JSON body that would be transmitted.
mkdir -p "$TMP/private-mock-bin" "$TMP/private-mock-home"
mkdir -p "$TMP/private-mock-home/.config/ai-devops/secrets"
chmod 700 "$TMP/private-mock-home/.config/ai-devops/secrets"
printf 'synthetic-test-key\n' > "$TMP/private-mock-home/.config/ai-devops/secrets/deepseek-api-key"
chmod 600 "$TMP/private-mock-home/.config/ai-devops/secrets/deepseek-api-key"
# Windows ACL validation is a separate installer concern. This fixture tests
# the private code-only export without invoking a host ACL tool or 1Password.
cat > "$TMP/private-mock-bin/pwsh.exe" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMP/private-mock-bin/pwsh.exe"
cat > "$TMP/private-mock-bin/curl" <<'EOF'
#!/usr/bin/env bash
out=""; body=""
fixture_root="$(cd "$(dirname "$0")/.." && pwd -P)"
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o) out="$2"; shift 2 ;;
    -d) body="${2#@}"; shift 2 ;;
    *) shift ;;
  esac
done
cp "$body" "$fixture_root/private-request.json"
pwd -P > "$fixture_root/private-review-cwd"
synthetic_head="$(git rev-parse HEAD)"
PY3="$(command -v python3 || command -v python)"
"$PY3" - "$out" "$synthetic_head" <<'PY'
import json, sys
json.dump({"choices":[{"message":{"content":"The selected code change was reviewed against its attached packet. The selected file contents match the supplied change, the synthetic baseline isolates exactly the approved path, no raw evidence or historical content is attached, and the checked source identity binds this review to the original source.\nVERDICT: APPROVE " + sys.argv[2] + "\n\n"}}],"usage":None}, open(sys.argv[1], "w", encoding="utf-8"))
PY
printf 200
EOF
chmod +x "$TMP/private-mock-bin/curl"
DEEPSEEK_STUB_REQUEST="$TMP/private-request.json"; export DEEPSEEK_STUB_REQUEST
DEEPSEEK_STUB_CWD="$TMP/private-review-cwd"; export DEEPSEEK_STUB_CWD
NETWORK_OUT="$(cd "$PRIVATE" && HOME="$TMP/private-mock-home" PATH="$TMP/private-mock-bin:$PATH" AI_DEEPSEEK_TEST_DIR="$TMP" AI_REVIEW_EVENT_DIR="$TMP/private-review-events" AI_REVIEW_SANDBOX_DIR="$TMP/private-sandboxes" AI_TASK_GATES_MODE=standard "$FRONT" deepseek diff-review --implementer codex --code-only --paths-file "$TMP/approved-paths.json" --base HEAD~1 --assert-head "$PRIVATE_HEAD" 2>&1)"; NETWORK_RC=$?
[ "$NETWORK_RC" -eq 0 ] || printf 'private DeepSeek fixture: %s\n' "$(printf '%s' "$NETWORK_OUT" | grep -Ei 'error:|refused|failed|invalid|verdict|packet|code-only' | tail -8)" >&2
check "real private DeepSeek route completes with no network" "[ '$NETWORK_RC' -eq 0 ] && [ -s '$DEEPSEEK_STUB_REQUEST' ] && [ -s '$DEEPSEEK_STUB_CWD' ]"
check "outbound DeepSeek payload includes approved code only" "jq -e '.messages | map(.content) | join(\"\\n\") | contains(\"print(\\\"changed\\\")\") and (contains(\"raw-row-sentinel\")|not) and (contains(\"history-raw-sentinel\")|not) and (contains(\"untracked-prompt-sentinel\")|not)' '$DEEPSEEK_STUB_REQUEST' >/dev/null && ! grep -Fq '$PRIVATE' '$DEEPSEEK_STUB_REQUEST'"
if [ -s "$DEEPSEEK_STUB_CWD" ]; then
  NETWORK_SNAPSHOT="$(cat "$DEEPSEEK_STUB_CWD")"
  NETWORK_SYNTHETIC_HEAD="$(git -C "$NETWORK_SNAPSHOT" rev-parse HEAD 2>/dev/null || true)"
  NETWORK_META="$(find "$NETWORK_SNAPSHOT/.ai/deepseek-sessions" -maxdepth 1 -name '*.meta.json' -print -quit 2>/dev/null)"
  check "retained DeepSeek verdict binds original and synthetic source identity" "[ -n '$NETWORK_META' ] && jq -e --arg original '$PRIVATE_HEAD' --arg export '$NETWORK_SYNTHETIC_HEAD' --slurpfile marker '$NETWORK_SNAPSHOT/.ai-review-sandbox' '.status==\"complete\" and .verdict==\"APPROVE\" and .governed_head==\$export and .source_identity.code_only==\$marker[0] and .source_identity.code_only.original_head==\$original and .source_identity.code_only.export_head==\$export and (.source_identity.code_only.source_digest|length)==64 and (.source_identity.code_only.path_manifest_sha256|length)==64' '$NETWORK_META' >/dev/null"
  NETWORK_STATE="$(find "$AI_REVIEW_LIFECYCLE_DIR/runs" -name '*.json' -exec jq -r --arg export "$NETWORK_SNAPSHOT" 'select(.code_only_export==$export and .status=="completed") | input_filename' {} \; | head -1)"
  if [ -n "$NETWORK_STATE" ]; then
    NETWORK_REPORT="$(jq -r .report_path "$NETWORK_STATE")"
    NETWORK_SESSION="$(jq -r .session_id "$NETWORK_STATE")"
    check "original lifecycle keeps selected scope and independent native identity" "jq -e --arg h '$PRIVATE_HEAD' --arg export '$NETWORK_SYNTHETIC_HEAD' '.head==\$h and .code_only.original_head==\$h and .code_only.export_head==\$export and .code_only.paths==[\"src/loader.py\"] and .provider==\"deepseek\" and .implementer_engine==\"codex\" and .stale==false and .verdict==\"APPROVE\"' '$NETWORK_STATE' >/dev/null"
    PROOF_STATE="$TMP/proof-state.json"
    jq '.status="running"' "$NETWORK_STATE" > "$PROOF_STATE"
    chmod 600 "$PROOF_STATE"
    check "native proof verifies report bytes from the actual final message" "python3 '$REPO_ROOT/bin/ai-review-code-only.py' lifecycle-proof '$PROOF_STATE' '$NETWORK_SESSION' '$NETWORK_REPORT' >/dev/null"
    printf 'foreign report' > "$TMP/foreign-report"
    check "foreign report cannot inherit genuine native authority" "! python3 '$REPO_ROOT/bin/ai-review-code-only.py' lifecycle-proof '$PROOF_STATE' '$NETWORK_SESSION' '$TMP/foreign-report' >/dev/null 2>&1"
    check "completed invocation cannot be replayed or backfilled" "! python3 '$REPO_ROOT/bin/ai-review-code-only.py' lifecycle-proof '$NETWORK_STATE' '$NETWORK_SESSION' '$NETWORK_REPORT' >/dev/null 2>&1"
    check "old export with native sessions cannot start retrospective lifecycle" "! '$SCRIPT' begin --provider deepseek --repo '$PRIVATE' --run-id retrospective --caller codex --code-only-export '$NETWORK_SNAPSHOT' >/dev/null 2>&1"
    cp "$NETWORK_META" "$TMP/native-meta-before"
    for field in provider caller head governed_head; do
      jq --arg field "$field" '.[$field]="foreign"' "$TMP/native-meta-before" > "$NETWORK_META"
      check "native foreign $field refuses authority" "! python3 '$REPO_ROOT/bin/ai-review-code-only.py' lifecycle-proof '$PROOF_STATE' '$NETWORK_SESSION' '$NETWORK_REPORT' >/dev/null 2>&1"
    done
    cp "$TMP/native-meta-before" "$NETWORK_META"
    NETWORK_OBSERVED="$NETWORK_SNAPSHOT/.ai/deepseek-sessions/$NETWORK_SESSION.pending/observed.json"
    cp "$NETWORK_OBSERVED" "$TMP/native-observed-before"
    jq '.response_sha256="foreign"' "$TMP/native-observed-before" > "$NETWORK_OBSERVED"
    check "altered native response seal cannot authorize a real verdict" "! python3 '$REPO_ROOT/bin/ai-review-code-only.py' lifecycle-proof '$PROOF_STATE' '$NETWORK_SESSION' '$NETWORK_REPORT' >/dev/null 2>&1"
    cp "$TMP/native-observed-before" "$NETWORK_OBSERVED"
    chmod 644 "$NETWORK_META"
    check "publicly readable native metadata refuses authority" "! python3 '$REPO_ROOT/bin/ai-review-code-only.py' lifecycle-proof '$PROOF_STATE' '$NETWORK_SESSION' '$NETWORK_REPORT' >/dev/null 2>&1"
    chmod 600 "$NETWORK_META"
    mv "$NETWORK_REPORT" "$TMP/exact-report-before"
    ln -s "$TMP/exact-report-before" "$NETWORK_REPORT"
    check "symlinked genuine report cannot authorize the invocation" "! python3 '$REPO_ROOT/bin/ai-review-code-only.py' lifecycle-proof '$PROOF_STATE' '$NETWORK_SESSION' '$NETWORK_REPORT' >/dev/null 2>&1"
    rm "$NETWORK_REPORT"; mv "$TMP/exact-report-before" "$NETWORK_REPORT"
    check "hidden session identifier refuses native proof" "! python3 '$REPO_ROOT/bin/ai-review-code-only.py' lifecycle-proof '$PROOF_STATE' '.hidden' '$NETWORK_REPORT' >/dev/null 2>&1"
    check "reserved Windows session identifier refuses native proof" "! python3 '$REPO_ROOT/bin/ai-review-code-only.py' lifecycle-proof '$PROOF_STATE' 'CON' '$NETWORK_REPORT' >/dev/null 2>&1"
    printf 'drift after response\n' >> "$PRIVATE/evidence/raw.csv"
    check "unselected original drift invalidates native completion" "! python3 '$REPO_ROOT/bin/ai-review-code-only.py' lifecycle-proof '$PROOF_STATE' '$NETWORK_SESSION' '$NETWORK_REPORT' >/dev/null 2>&1"
  fi
fi

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

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
