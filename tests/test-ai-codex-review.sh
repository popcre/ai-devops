#!/usr/bin/env bash
# Offline trust and hostile-write tests for ai-codex-review.
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/bin/ai-codex-review"
PASS=0; FAIL=0
ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }
bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
R="$TMP/repo"; mkdir -p "$R"; git -C "$R" init -q
git -C "$R" config user.name Test; git -C "$R" config user.email t@example.com
printf '.ai/\n' > "$R/.gitignore"; printf 'base\n' > "$R/a.txt"
git -C "$R" add .gitignore a.txt; git -C "$R" commit -qm init
printf 'changed\n' >> "$R/a.txt"; printf 'brand-new\n' > "$R/new file.txt"
printf '\000\001\377' > "$R/new.bin"

STUB="$TMP/codex-stub"
cat > "$STUB" <<'EOF'
#!/usr/bin/env bash
dir=""; previous=""
printf '%s\0' "$@" > "$AI_CODEX_TEST_ARGS/args-$$"
for arg in "$@"; do [ "$previous" = --cd ] && dir="$arg"; previous="$arg"; done
prompt="$(cat)"; printf '%s' "$prompt" > "$AI_CODEX_TEST_ARGS/prompt-$$"
[ -n "$dir" ] && [ -f "$dir/new file.txt" ] && [ -f "$dir/new.bin" ] || exit 8
case "${AI_CODEX_STUB_MODE:-success}" in
  fail) printf 'provider TOKEN=must-not-leak failed\n' >&2; exit 7;; empty) exit 0;; missing) printf 'findings only\n';;
  mutate) printf 'provider-write\n' >> "$dir/a.txt"; printf '## Verdict\nAPPROVE\n';;
  mutate-source) printf 'source-write\n' >> "$AI_CODEX_STUB_SOURCE/a.txt"; printf '## Verdict\nAPPROVE\n';;
  trailing) printf '## Verdict\nAPPROVE\ntrailing text\n';;
  multiple) printf '## Verdict\nAPPROVE\n## Verdict\nAPPROVE\n';;
  hang) sleep 3; printf '## Verdict\nAPPROVE\n';;
  signal) [ -z "${AI_CODEX_SIGNAL_READY:-}" ] || printf '%s\n' "$$" > "$AI_CODEX_SIGNAL_READY"; trap '[ -z "${AI_CODEX_SIGNAL_STOPPED:-}" ] || printf stopped > "$AI_CODEX_SIGNAL_STOPPED"; exit 143' HUP INT TERM; sleep 30;;
  slow) sleep 1; printf 'review complete\n\n## Verdict\nAPPROVE\n';;
  *) printf 'review saw complete snapshot\n\n## Verdict\nAPPROVE\n\n'; printf 'codex diagnostic after response\n' >&2;;
esac
EOF
chmod +x "$STUB"; mkdir -p "$TMP/args"
MODELS="$TMP/models.env"; printf "CODEX_CMD='%s exec -m gpt-5.6-sol --skip-git-repo-check --sandbox read-only -c model_reasoning_effort=medium'\ntouch '%s'\n" "$STUB" "$TMP/models-executed" > "$MODELS"

export AI_DEVOPS_MODELS_ENV="$MODELS"
export AI_CODEX_REVIEW_TEST_DIR="$TMP"
export AI_CODEX_TEST_ARGS="$TMP/args"
export AI_CODEX_STUB_SOURCE="$R"
export AI_REVIEW_LIFECYCLE_DIR="$TMP/lifecycle"
export AI_REVIEW_SCOREBOARD_DIR="$TMP/scoreboard"
export AI_REVIEW_QUARANTINE_DIR="$TMP/quarantine"
export AI_REVIEW_SANDBOX_DIR="$TMP/sandboxes"

echo '== ai-codex-review'
check "doctor_proves_readonly_and_reasoning" "cd '$R' && '$SCRIPT' doctor | grep -q 'sandbox=read-only reasoning=explicit'"
if command -v cygpath >/dev/null 2>&1; then
  TEST_ROOT_WINDOWS="$(cygpath -w "$TMP")"
  check "doctor_normalizes_equivalent_Windows_test_paths" "cd '$R' && AI_CODEX_REVIEW_TEST_DIR='$TEST_ROOT_WINDOWS' '$SCRIPT' doctor | grep -q 'sandbox=read-only reasoning=explicit'"
  mkdir -p "$TMP/path-tools"
  cat > "$TMP/path-tools/readlink" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = -f ] && [ "${2:-}" = "${AI_CODEX_PATH_FIXTURE:-}" ]; then
  cygpath -am "$2"
else
  /usr/bin/readlink "$@"
fi
EOF
  chmod +x "$TMP/path-tools/readlink"
  check "doctor_normalizes_mixed_tmp_and_native_executable_paths" "cd '$R' && AI_CODEX_PATH_FIXTURE='$STUB' PATH='$TMP/path-tools:$PATH' '$SCRIPT' doctor | grep -q 'sandbox=read-only reasoning=explicit'"
fi
check "models_configuration_is_parsed_as_data" "test ! -e '$TMP/models-executed'"
check "doctor_rejects_unknown_options" "cd '$R' && ! '$SCRIPT' doctor --unknown"
export AI_CODEX_TEST_MARKER="$TMP/tests-ran"
check "review_runs_the_supplied_test_evidence_command" "cd '$R' && '$SCRIPT' diff-review --tests 'printf passed > \"\$AI_CODEX_TEST_MARKER\"' >/dev/null && grep -qx passed '$TMP/tests-ran'"
check "review_rejects_a_missing_tests_command" "cd '$R' && ! '$SCRIPT' diff-review --tests >/dev/null 2>&1"
check "review_rejects_duplicate_test_commands" "cd '$R' && ! '$SCRIPT' diff-review --tests true --tests true >/dev/null 2>&1"
check "review_rejects_unknown_options" "cd '$R' && ! '$SCRIPT' diff-review --unknown >/dev/null 2>&1"
BEFORE="$($REPO_ROOT/bin/ai-review-sandbox digest "$R")"
OUT="$(cd "$R" && "$SCRIPT" diff-review)"
check "successful_review_publishes_one_report" "[ -s '$OUT' ]"
check "provider_diagnostics_do_not_corrupt_the_model_verdict" "! grep -q 'codex diagnostic after response' '$OUT'"
check "report_has_exact_verdict" "grep -A1 '^## Verdict' '$OUT' | tail -1 | grep -qx APPROVE"
check "report_binds_source_digest" "grep -q \"$BEFORE\" '$OUT'"
check "provider_received_complete_untracked_snapshot" "grep -q 'review saw complete snapshot' '$OUT'"
check "provider_command_keeps_readonly_sandbox" "grep -Rzq -- '--sandbox' '$TMP/args' && grep -Rzq -- 'read-only' '$TMP/args'"
check "provider_command_receives_private_directory" "grep -Rzq -- '--cd' '$TMP/args'"
check "source_is_unchanged_by_successful_review" "[ \"$BEFORE\" = \"\$('$REPO_ROOT/bin/ai-review-sandbox' digest '$R')\" ]"
if [ -n "${SYSTEMROOT:-}" ]; then
  export AI_PRIVATE_HELPER_WIN="$(cygpath -w "$REPO_ROOT/bin/windows-private-file.ps1")"
  export AI_PRIVATE_DIR_WIN="$(cygpath -w "$R/.ai/reviews")"
  export AI_PRIVATE_FILE_WIN="$(cygpath -w "$OUT")"
  check "review_storage_has_a_private_Windows_ACL" "pwsh.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command '\$ErrorActionPreference = \"Stop\"; . \$env:AI_PRIVATE_HELPER_WIN; Assert-AiDevOpsPrivateAcl -Path \$env:AI_PRIVATE_DIR_WIN; Assert-AiDevOpsPrivateAcl -Path \$env:AI_PRIVATE_FILE_WIN'"
else
  check "review_storage_is_private" "test \"\$(stat -c %a '$R/.ai/reviews')\" = 700 && test \"\$(stat -c %a '$OUT')\" = 600"
fi
check "lifecycle_records_completed_verdict" \
  "find '$TMP/lifecycle/runs' -name '*.json' -exec jq -e 'select(.status==\"completed\" and .verdict==\"APPROVE\")' {} \; | grep -q APPROVE"
check "scoreboard_records_current_result" "jq -e 'select(.provider==\"codex\" and .evidence_state==\"current\")' '$TMP/scoreboard/reviews.jsonl'"

REPORT_COUNT="$(find "$R/.ai/reviews" -type f -name 'codex-*.md' | wc -l | tr -d ' ')"
check "provider_failure_is_nonzero" "cd '$R' && ! AI_CODEX_STUB_MODE=fail '$SCRIPT' diff-review >/dev/null 2>&1"
check "provider_failure_publishes_no_success_report" \
  "[ '$REPORT_COUNT' = \"\$(find '$R/.ai/reviews' -type f -name 'codex-*.md' | wc -l | tr -d ' ')\" ]"
check "provider_failure_preserves_private_sanitized_diagnostics" "f=\$(find '$R/.ai/reviews' -type f -name 'codex-*-failed-*.log' -print -quit); test -f \"\$f\" && grep -q 'provider TOKEN=\[REDACTED\] failed' \"\$f\" && ! grep -q 'must-not-leak' \"\$f\""
check "missing_verdict_is_nonzero" "cd '$R' && ! AI_CODEX_STUB_MODE=missing '$SCRIPT' security-review >/dev/null 2>&1"
check "empty_response_is_nonzero" "cd '$R' && ! AI_CODEX_STUB_MODE=empty '$SCRIPT' final-check >/dev/null 2>&1"
check "text_after_verdict_is_rejected" "cd '$R' && ! AI_CODEX_STUB_MODE=trailing '$SCRIPT' diff-review >/dev/null 2>&1"
check "multiple_verdict_sections_are_rejected" "cd '$R' && ! AI_CODEX_STUB_MODE=multiple '$SCRIPT' diff-review >/dev/null 2>&1"
check "provider_run_is_bounded" "cd '$R' && ! AI_CODEX_REVIEW_TIMEOUT=1 AI_CODEX_STUB_MODE=hang '$SCRIPT' diff-review >/dev/null 2>&1"

rm -f "$TMP/signal-ready" "$TMP/signal-stopped"
(cd "$R" && exec env AI_CODEX_STUB_MODE=signal AI_CODEX_SIGNAL_READY="$TMP/signal-ready" AI_CODEX_SIGNAL_STOPPED="$TMP/signal-stopped" "$SCRIPT" diff-review >/dev/null 2>&1) & SIGNAL_WRAPPER_PID=$!
for _ in $(seq 1 600); do [ -s "$TMP/signal-ready" ] && break; sleep .1; done
if [ ! -s "$TMP/signal-ready" ]; then
  kill -TERM "$SIGNAL_WRAPPER_PID" 2>/dev/null || true; wait "$SIGNAL_WRAPPER_PID" 2>/dev/null || true
  printf '  diagnostic: provider did not start within the bounded fixture deadline\n'
  bad "signal_stops_and_reaps_the_provider"
else
  SIGNAL_PROVIDER_PID="$(cat "$TMP/signal-ready")"
  kill -TERM "$SIGNAL_WRAPPER_PID" 2>/dev/null || true; wait "$SIGNAL_WRAPPER_PID" 2>/dev/null || true
if [ -f "$TMP/signal-stopped" ] && ! kill -0 "$SIGNAL_PROVIDER_PID" 2>/dev/null; then
  ok "signal_stops_and_reaps_the_provider"
else
  printf '  diagnostic: signal marker=%s provider-alive=%s\n' "$([ -f "$TMP/signal-stopped" ] && printf present || printf missing)" "$(kill -0 "$SIGNAL_PROVIDER_PID" 2>/dev/null && printf yes || printf no)"
  bad "signal_stops_and_reaps_the_provider"
fi
fi
check "signal_finalizes_the_lifecycle_as_failed" "find '$TMP/lifecycle/runs' -name '*.json' -exec jq -e 'select(.status==\"failed\" and .failure_class==\"interrupted\")' {} \; | grep -q BLOCKED"

check "provider_write_to_snapshot_is_rejected" "cd '$R' && ! AI_CODEX_STUB_MODE=mutate '$SCRIPT' diff-review >/dev/null 2>&1"
check "provider_write_does_not_touch_source" "[ \"$BEFORE\" = \"\$('$REPO_ROOT/bin/ai-review-sandbox' digest '$R')\" ]"
check "source_change_during_review_is_rejected" "cd '$R' && ! AI_CODEX_STUB_MODE=mutate-source '$SCRIPT' diff-review >/dev/null 2>&1"
git -C "$R" checkout -q -- a.txt; printf 'changed\n' >> "$R/a.txt"

(cd "$R" && AI_CODEX_STUB_MODE=slow "$SCRIPT" visual-review > "$TMP/one.out") & P1=$!
(cd "$R" && AI_CODEX_STUB_MODE=slow "$SCRIPT" visual-review > "$TMP/two.out") & P2=$!
wait "$P1"; C1=$?; wait "$P2"; C2=$?
check "concurrent_reviews_both_complete" "[ '$C1' -eq 0 ] && [ '$C2' -eq 0 ]"
check "concurrent_reviews_use_distinct_reports" "[ \"\$(cat '$TMP/one.out')\" != \"\$(cat '$TMP/two.out')\" ]"
check "concurrent_reports_are_both_complete" "grep -q '^APPROVE$' \"\$(cat '$TMP/one.out')\" && grep -q '^APPROVE$' \"\$(cat '$TMP/two.out')\""

BAD_MODELS="$TMP/bad-models.env"; printf "CODEX_CMD='%s exec --skip-git-repo-check'\n" "$STUB" > "$BAD_MODELS"
check "missing_readonly_and_reasoning_config_is_refused" "cd '$R' && ! AI_DEVOPS_MODELS_ENV='$BAD_MODELS' '$SCRIPT' doctor >/dev/null 2>&1"
APPENDED_MODELS="$TMP/appended-models.env"; printf "CODEX_CMD='%s exec -m gpt-5.6-sol --skip-git-repo-check --sandbox read-only -c model_reasoning_effort=medium --dangerously-bypass-approvals-and-sandbox'\n" "$STUB" > "$APPENDED_MODELS"
check "appended_command_options_are_refused" "cd '$R' && ! AI_DEVOPS_MODELS_ENV='$APPENDED_MODELS' '$SCRIPT' doctor >/dev/null 2>&1"
printf 'historic\n' > "$R/.ai/reviews/historic.md"; git -C "$R" add -f .ai/reviews/historic.md; git -C "$R" commit -qm historic
check "tracked_historic_reports_do_not_block_a_unique_destination" "cd '$R' && '$SCRIPT' diff-review >/dev/null"
check "unknown_mode_is_rejected" "cd '$R' && ! '$SCRIPT' nonsense >/dev/null 2>&1"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
