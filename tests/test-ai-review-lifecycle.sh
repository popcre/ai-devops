#!/usr/bin/env bash
# Offline hostile tests for provider-neutral review ownership and accounting.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/bin/ai-review-lifecycle"
PASS=0; FAIL=0
ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }
bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
R="$TMP/repo"; mkdir -p "$R"; git -C "$R" init -q
git -C "$R" config user.name Test; git -C "$R" config user.email t@example.com
printf 'base\n' > "$R/a.txt"; git -C "$R" add a.txt; git -C "$R" commit -qm init
git -C "$R" remote add origin 'https://user:secret@GitHub.COM/Owner/Repo.git'

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


printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
