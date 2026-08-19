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
mkdir -p "$TMP/repo/.ai/reviews" "$TMP/state/grok/sessions/x"
git -C "$TMP/repo" init -q
git -C "$TMP/repo" config user.name Test
git -C "$TMP/repo" config user.email test@example.com
printf 'base\n' > "$TMP/repo/file.txt"
git -C "$TMP/repo" add file.txt && git -C "$TMP/repo" commit -qm base
printf 'review\n' > "$TMP/repo/.ai/reviews/grok-example.md"
printf '{"repo":"%s","head":"abc","prompt":"private code","total_tokens":42,"credential":"do-not-copy"}\n' "$TMP/repo" > "$TMP/state/grok/sessions/x/session.json"
printf 'authorization=Bearer-abc\nordinary failure line\ntoken=live-value\n' > "$TMP/error.log"

echo '== ai-reviewer-issue'
output="$($SCRIPT record --provider grok --summary 'Reviewer returned no verdict.' --repo "$TMP/repo" --error-file "$TMP/error.log")"
id="$(printf '%s\n' "$output" | sed -n 's/^ai-reviewer-issue: recorded //p')"
report="$AI_REVIEWER_ISSUE_DIR/$id"
check "record creates a valid issue" "jq -e '.provider==\"grok\" and .summary==\"Reviewer returned no verdict.\"' '$report/issue.json'"
check "repository evidence is captured" "jq -e '.repository.head|length==40' '$report/issue.json'"
check "recent review artifacts are inventoried" "grep -q 'grok-example.md' '$report/recent-review-artifacts.txt'"
check "safe reviewer metrics are preserved" "jq -e '.total_tokens==42' '$report/reviewer-metadata.redacted.json'"
check "prompt and credential fields are removed" "! jq -e 'has(\"prompt\") or has(\"credential\")' '$report/reviewer-metadata.redacted.json'"
check "error tail is bounded and redacted" "grep -q 'token=\[REDACTED\]' '$report/error-tail.redacted.txt' && ! grep -q 'live-value' '$report/error-tail.redacted.txt'"
check "list finds the recorded issue" "$SCRIPT list | grep -q '$id'"
check "show returns the recorded issue" "$SCRIPT show '$id' | jq -e '.id==\"$id\"'"
check "path returns the configured directory" "test \"$($SCRIPT path)\" = '$AI_REVIEWER_ISSUE_DIR'"
check "missing summary is refused" "! $SCRIPT record --provider grok --repo '$TMP/repo'"
check "unsafe provider name is refused" "! $SCRIPT record --provider '../bad' --summary bad --repo '$TMP/repo'"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
