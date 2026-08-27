#!/usr/bin/env bash
# Offline tests for bin/ai-reviewer-issue.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/bin/ai-reviewer-issue"
PASS=0; FAIL=0
ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }
bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export AI_REVIEWER_ISSUE_DIR="$TMP/issues"
export AI_REVIEWER_STATE_BASE="$TMP/state"
export AI_REVIEW_SCOREBOARD_FILE="$TMP/state/review-scoreboard/reviews.jsonl"
mkdir -p "$TMP/repo/.ai/reviews" "$TMP/state/grok/sessions/x"
git -C "$TMP/repo" init -q
git -C "$TMP/repo" config user.name Test
git -C "$TMP/repo" config user.email test@example.com
printf 'base\n' > "$TMP/repo/file.txt"
git -C "$TMP/repo" add file.txt && git -C "$TMP/repo" commit -qm base
HEAD="$(git -C "$TMP/repo" rev-parse HEAD)"
TOOLKIT_HEAD="$(git -C "$ROOT" rev-parse HEAD)"
REPO_CANON="$(git -C "$TMP/repo" rev-parse --show-toplevel)"
STATE_PROVIDER_CANON="$(cd "$TMP/state/grok" && { pwd -W 2>/dev/null || pwd -P; })"
printf 'complete review output\ntoken=report-secret\n' > "$TMP/repo/.ai/reviews/grok-x-example.md"
printf '{"repo":"%s","head":"%s","session_id":"x","caller":"codex","prompt":"private code","total_tokens":42,"credential":"do-not-copy","report_path":"%s","log_path":"%s"}\n' "$REPO_CANON" "$HEAD" "$REPO_CANON/.ai/reviews/grok-x-example.md" "$STATE_PROVIDER_CANON/sessions/x/stream.jsonl" > "$TMP/state/grok/sessions/x/session.json"
mkdir -p "$TMP/state/grok/sessions/newer"
printf '{"repo":"/wrong/repo","head":"wrong","session_id":"newer","caller":"codex","total_tokens":999}\n' > "$TMP/state/grok/sessions/newer/session.json"
printf 'provider stream line\nsecret=stream-secret\n' > "$TMP/state/grok/sessions/x/stream.jsonl"
printf 'unrelated similar report\n' > "$TMP/repo/.ai/reviews/grok-xx-example.md"
mkdir -p "$TMP/state/grok/sessions/xx"; printf 'unrelated similar log\n' > "$TMP/state/grok/sessions/xx/stream.jsonl"
mkdir -p "$(dirname "$AI_REVIEW_SCOREBOARD_FILE")"
printf '{"provider":"grok","repo":"%s","head":"%s","session_id":"x","caller":"codex","elapsed_seconds":901,"failure_class":"no-verdict"}\n' "$REPO_CANON" "$HEAD" > "$AI_REVIEW_SCOREBOARD_FILE"
printf 'authorization=Bearer-abc\nordinary failure line 1\nordinary failure line 2\ntoken=live-value\n' > "$TMP/error.log"
printf 'Observed behavior:\nThe reviewer returned empty output twice.\nExpected behavior:\nA clear decision.\n' > "$TMP/details.txt"

echo '== ai-reviewer-issue'
output="$($SCRIPT record --provider grok --summary 'Reviewer returned no verdict.' --details-file "$TMP/details.txt" --command 'ai-grok-review ask test' --repo "$TMP/repo" --error-file "$TMP/error.log" --session-id x --caller codex)"
id="$(printf '%s\n' "$output" | sed -n 's/^ai-reviewer-issue: recorded //p')"
report="$AI_REVIEWER_ISSUE_DIR/$id"
check "record creates a valid issue" "jq -e '.provider==\"grok\" and .summary==\"Reviewer returned no verdict.\"' '$report/issue.json'"
check "repository evidence is captured" "jq -e '.repository.head|length==40' '$report/issue.json'"
check "recent review artifacts are inventoried" "grep -q 'grok-x-example.md' '$report/recent-review-artifacts.txt'"
check "complete matching review output is captured" "grep -q 'complete review output' '$report/review-reports/001-grok-x-example.md'"
check "captured review output is redacted" "! grep -q 'report-secret' '$report/review-reports/001-grok-x-example.md'"
check "recent provider logs are captured" "grep -q 'provider stream line' '$report/provider-logs/001-stream.jsonl'"
check "captured provider logs are redacted" "! grep -q 'stream-secret' '$report/provider-logs/001-stream.jsonl'"
check "similar report name is not captured" "! grep -Rqs 'unrelated similar report' '$report/review-reports'"
check "similar log path is not captured" "! grep -Rqs 'unrelated similar log' '$report/provider-logs'"
check "latest scoreboard outcome is captured" "jq -e '.elapsed_seconds==901 and .failure_class==\"no-verdict\"' '$report/latest-scoreboard-entry.json'"
check "safe reviewer metrics are preserved" "jq -e '.total_tokens==42' '$report/reviewer-metadata.redacted.json'"
check "unrelated newer metadata is ignored" "jq -e '.total_tokens==42 and .session_id==\"x\"' '$report/reviewer-metadata.redacted.json'"
check "prompt and credential fields are removed" "! jq -e 'has(\"prompt\") or has(\"credential\")' '$report/reviewer-metadata.redacted.json'"
check "complete error log is captured and redacted" "grep -q 'ordinary failure line 1' '$report/error.redacted.txt' && grep -q 'ordinary failure line 2' '$report/error.redacted.txt' && ! grep -q 'live-value' '$report/error.redacted.txt'"
check "unrestricted details are captured" "grep -q 'returned empty output twice' '$report/details.redacted.txt'"
check "exact command is recorded" "jq -e '.reported_command==\"ai-grok-review ask test\"' '$report/issue.json'"
check "list finds the recorded issue" "$SCRIPT list | grep -q '$id'"
check "show returns the recorded issue" "$SCRIPT show '$id' | jq -e '.id==\"$id\"'"
check "new issues are listed as open" "$SCRIPT list | awk -F '\\t' '\$1==\"$id\" && \$4==\"open\" {found=1} END {exit !found}'"
check "resolve requires a repair commit" "! $SCRIPT resolve '$id' --status resolved --summary repaired --evidence tests/test-ai-reviewer-issue.sh"
check "resolve requires evidence" "! $SCRIPT resolve '$id' --status resolved --summary repaired --repair-commit '$TOOLKIT_HEAD'"
check "resolve rejects unsupported status" "! $SCRIPT resolve '$id' --status closed --summary repaired --repair-commit '$TOOLKIT_HEAD' --evidence tests/test-ai-reviewer-issue.sh"
check "resolve rejects missing evidence paths" "! $SCRIPT resolve '$id' --status resolved --summary repaired --repair-commit '$TOOLKIT_HEAD' --evidence tests/not-present.md"
check "resolve rejects parent traversal as an issue id" "! $SCRIPT resolve .. --status resolved --summary repaired --repair-commit '$TOOLKIT_HEAD' --evidence tests/test-ai-reviewer-issue.sh"
resolve_output="$($SCRIPT resolve "$id" --status partially-resolved --summary 'One symptom remains token=summary-secret.' --repair-commit "$TOOLKIT_HEAD" --evidence tests/test-ai-reviewer-issue.sh --details 'token=repair-secret Remaining symptom is named.')"
resolution="$(find "$report/resolutions" -type f -name '*.json' -print -quit)"
check "resolve appends a separate resolution record" "test -f '$resolution' && jq -e '.status==\"partially-resolved\" and .repair_commits[0]==\"$TOOLKIT_HEAD\"' '$resolution'"
check "resolve redacts its details" "grep -q 'Remaining symptom is named' '$resolution' && ! grep -q 'repair-secret' '$resolution'"
check "resolve redacts its summary" "jq -e '.summary|contains(\"[REDACTED]\")' '$resolution' && ! grep -q 'summary-secret' '$resolution'"
check "resolve leaves original incident immutable" "jq -e 'has(\"resolution\")|not' '$report/issue.json'"
check "list surfaces the latest resolution status" "$SCRIPT list | awk -F '\\t' '\$1==\"$id\" && \$4==\"partially-resolved\" {found=1} END {exit !found}'"
check "show joins the latest resolution without rewriting the issue" "$SCRIPT show '$id' | jq -e '.resolution.status==\"partially-resolved\"'"
mkdir -p "$TMP/installed"
ln -s "$SCRIPT" "$TMP/installed/ai-reviewer-issue"
symlink_issue="$($SCRIPT record --provider grok --summary 'Installed path regression.' --repo "$TMP/repo")"
symlink_id="$(printf '%s\n' "$symlink_issue" | sed -n 's/^ai-reviewer-issue: recorded //p')"
if [ -L "$TMP/installed/ai-reviewer-issue" ]; then
  check "installed symlink resolves toolkit commit and evidence paths" "$TMP/installed/ai-reviewer-issue resolve '$symlink_id' --status resolved --summary repaired --repair-commit '$TOOLKIT_HEAD' --evidence tests/test-ai-reviewer-issue.sh"
else
  ok "installed symlink regression is exercised where symlinks are supported"
fi
mkdir -p "$TMP/outside-issue"
cp "$report/issue.json" "$TMP/outside-issue/issue.json"
ln -s "$TMP/outside-issue" "$AI_REVIEWER_ISSUE_DIR/linked-incident"
if [ -L "$AI_REVIEWER_ISSUE_DIR/linked-incident" ]; then
  check "resolve refuses a linked incident directory" "! $SCRIPT resolve linked-incident --status resolved --summary repaired --repair-commit '$TOOLKIT_HEAD' --evidence tests/test-ai-reviewer-issue.sh"
  check "linked incident refusal writes nothing outside storage" "test ! -e '$TMP/outside-issue/resolutions'"
else
  ok "linked incident regression is exercised where symlinks are supported"
  ok "linked incident outside-write check is exercised where symlinks are supported"
fi
linked_resolution_id="$(printf '%s\n' "$($SCRIPT record --provider grok --summary 'Linked resolution regression.' --repo "$TMP/repo")" | sed -n 's/^ai-reviewer-issue: recorded //p')"
mkdir -p "$TMP/outside-resolutions"
ln -s "$TMP/outside-resolutions" "$AI_REVIEWER_ISSUE_DIR/$linked_resolution_id/resolutions"
if [ -L "$AI_REVIEWER_ISSUE_DIR/$linked_resolution_id/resolutions" ]; then
  check "resolve refuses linked resolution storage" "! $SCRIPT resolve '$linked_resolution_id' --status resolved --summary repaired --repair-commit '$TOOLKIT_HEAD' --evidence tests/test-ai-reviewer-issue.sh"
  check "linked resolution refusal writes nothing outside storage" "test -z \"\$(find '$TMP/outside-resolutions' -type f -print -quit)\""
else
  ok "linked resolution regression is exercised where symlinks are supported"
  ok "linked resolution outside-write check is exercised where symlinks are supported"
fi
concurrent_id="$(printf '%s\n' "$($SCRIPT record --provider grok --summary 'Concurrent resolution regression.' --repo "$TMP/repo")" | sed -n 's/^ai-reviewer-issue: recorded //p')"
$SCRIPT resolve "$concurrent_id" --status partially-resolved --summary first --repair-commit "$TOOLKIT_HEAD" --evidence tests/test-ai-reviewer-issue.sh >/dev/null & first_pid=$!
$SCRIPT resolve "$concurrent_id" --status resolved --summary second --repair-commit "$TOOLKIT_HEAD" --evidence tests/test-ai-reviewer-issue.sh >/dev/null & second_pid=$!
wait "$first_pid"; first_rc=$?; wait "$second_pid"; second_rc=$?
check "concurrent resolution writers both append successfully" "test '$first_rc' -eq 0 && test '$second_rc' -eq 0"
check "concurrent resolution writers preserve both records" "test \"\$(find '$AI_REVIEWER_ISSUE_DIR/$concurrent_id/resolutions' -type f -name '*.json' | wc -l | tr -d ' ')\" -eq 2"
check "path returns the configured directory" "test \"$($SCRIPT path)\" = '$AI_REVIEWER_ISSUE_DIR'"
uncorrelated="$($SCRIPT record --provider grok --summary 'Identifiers unavailable.' --repo "$TMP/repo")"
uncorrelated_id="$(printf '%s\n' "$uncorrelated" | sed -n 's/^ai-reviewer-issue: recorded //p')"
uncorrelated_report="$AI_REVIEWER_ISSUE_DIR/$uncorrelated_id"
check "missing join identifiers capture no nearby metadata" "test ! -e '$uncorrelated_report/reviewer-metadata.redacted.json'"
check "missing join identifiers capture no nearby scoreboard row" "test ! -e '$uncorrelated_report/latest-scoreboard-entry.json'"
check "missing join identifiers capture no reports or provider logs" "test -z \"\$(find '$uncorrelated_report/review-reports' '$uncorrelated_report/provider-logs' -type f -print -quit 2>/dev/null)\""
check "missing join identifiers are labelled" "grep -q 'No exact reviewer metadata' '$uncorrelated_report/missing-evidence.txt'"
mkdir -p "$TMP/state/grok/sessions/duplicate"
cp "$TMP/state/grok/sessions/x/session.json" "$TMP/state/grok/sessions/duplicate/session.json"
ambiguous="$($SCRIPT record --provider grok --summary 'Duplicate identity.' --repo "$TMP/repo" --session-id x --caller codex)"
ambiguous_id="$(printf '%s\n' "$ambiguous" | sed -n 's/^ai-reviewer-issue: recorded //p')"
ambiguous_report="$AI_REVIEWER_ISSUE_DIR/$ambiguous_id"
check "duplicate exact metadata captures no arbitrary record" "test ! -e '$ambiguous_report/reviewer-metadata.redacted.json'"
check "duplicate exact metadata captures no owned files" "test -z \"\$(find '$ambiguous_report/review-reports' '$ambiguous_report/provider-logs' -type f -print -quit 2>/dev/null)\""
check "duplicate exact metadata is labelled ambiguous" "grep -q 'Multiple reviewer metadata records matched' '$ambiguous_report/missing-evidence.txt'"
check "missing summary is refused" "! $SCRIPT record --provider grok --repo '$TMP/repo'"
check "unsafe provider name is refused" "! $SCRIPT record --provider '../bad' --summary bad --repo '$TMP/repo'"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
