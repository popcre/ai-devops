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

STATE="$($SCRIPT begin --provider grok --repo "$R" --run-id run-one --session-id session-one --caller codex)"
check "begin_runs_mandatory_preflight" "grep -q '^check grok ' '$AI_TEST_PREFLIGHT_LOG'"
check "begin_records_running_state" "[ \"\$(jq -r .status '$STATE')\" = running ]"
check "begin_records_exact_join_fields" \
  "jq -e '.run_id==\"run-one\" and .session_id==\"session-one\" and .caller==\"codex\"' '$STATE'"
LOCK="$(jq -r .lock_path "$STATE")"
check "begin_holds_assignment_lock" "[ -d '$LOCK' ]"
check "duplicate_run_is_rejected" \
  "! '$SCRIPT' begin --provider grok --repo '$R' --run-id run-one --caller codex >/dev/null 2>&1"

REPORT="$TMP/report.md"; printf '# Review\n' > "$REPORT"
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

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
