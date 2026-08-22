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
  fail) exit 7;; empty) exit 0;; missing) printf 'findings only\n';;
  mutate) printf 'provider-write\n' >> "$dir/a.txt"; printf '## Verdict\nAPPROVE\n';;
  mutate-source) printf 'source-write\n' >> "$AI_CODEX_STUB_SOURCE/a.txt"; printf '## Verdict\nAPPROVE\n';;
  slow) sleep 1; printf 'review complete\n\n## Verdict\nAPPROVE\n';;
  *) printf 'review saw complete snapshot\n\n## Verdict\nAPPROVE\n';;
esac
EOF
chmod +x "$STUB"; mkdir -p "$TMP/args"
MODELS="$TMP/models.env"; printf "CODEX_CMD='%s exec -m gpt-5.6-sol --skip-git-repo-check --sandbox read-only -c model_reasoning_effort=medium'\n" "$STUB" > "$MODELS"

export AI_DEVOPS_MODELS_ENV="$MODELS"
export AI_CODEX_TEST_ARGS="$TMP/args"
export AI_CODEX_STUB_SOURCE="$R"
export AI_REVIEW_LIFECYCLE_DIR="$TMP/lifecycle"
export AI_REVIEW_SCOREBOARD_DIR="$TMP/scoreboard"
export AI_REVIEW_QUARANTINE_DIR="$TMP/quarantine"
export AI_REVIEW_SANDBOX_DIR="$TMP/sandboxes"

echo '== ai-codex-review'
check "doctor_proves_readonly_and_reasoning" "cd '$R' && '$SCRIPT' doctor | grep -q 'sandbox=read-only reasoning=explicit'"
BEFORE="$($REPO_ROOT/bin/ai-review-sandbox digest "$R")"
OUT="$(cd "$R" && "$SCRIPT" diff-review)"
check "successful_review_publishes_one_report" "[ -s '$OUT' ]"
check "report_has_exact_verdict" "grep -A1 '^## Verdict' '$OUT' | tail -1 | grep -qx APPROVE"
check "report_binds_source_digest" "grep -q \"$BEFORE\" '$OUT'"
check "provider_received_complete_untracked_snapshot" "grep -q 'review saw complete snapshot' '$OUT'"
check "provider_command_keeps_readonly_sandbox" "grep -Rzq -- '--sandbox' '$TMP/args' && grep -Rzq -- 'read-only' '$TMP/args'"
check "provider_command_receives_private_directory" "grep -Rzq -- '--cd' '$TMP/args'"
check "source_is_unchanged_by_successful_review" "[ \"$BEFORE\" = \"\$('$REPO_ROOT/bin/ai-review-sandbox' digest '$R')\" ]"
check "lifecycle_records_completed_verdict" \
  "find '$TMP/lifecycle/runs' -name '*.json' -exec jq -e 'select(.status==\"completed\" and .verdict==\"APPROVE\")' {} \; | grep -q APPROVE"
check "scoreboard_records_current_result" "jq -e 'select(.provider==\"codex\" and .evidence_state==\"current\")' '$TMP/scoreboard/reviews.jsonl'"

REPORT_COUNT="$(find "$R/.ai/reviews" -type f -name 'codex-*.md' | wc -l | tr -d ' ')"
check "provider_failure_is_nonzero" "cd '$R' && ! AI_CODEX_STUB_MODE=fail '$SCRIPT' diff-review >/dev/null 2>&1"
check "provider_failure_publishes_no_success_report" \
  "[ '$REPORT_COUNT' = \"\$(find '$R/.ai/reviews' -type f -name 'codex-*.md' | wc -l | tr -d ' ')\" ]"
check "missing_verdict_is_nonzero" "cd '$R' && ! AI_CODEX_STUB_MODE=missing '$SCRIPT' security-review >/dev/null 2>&1"
check "empty_response_is_nonzero" "cd '$R' && ! AI_CODEX_STUB_MODE=empty '$SCRIPT' final-check >/dev/null 2>&1"

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
check "unknown_mode_is_rejected" "cd '$R' && ! '$SCRIPT' nonsense >/dev/null 2>&1"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
