#!/usr/bin/env bash
# Offline tests for bin/ai-review-posthoc (observation-week post-hoc drain).
# GitHub is a recorded stub; the scoreboard is a temp file. No network.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/bin/ai-review-posthoc"
PASS=0; FAIL=0
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# Recorded gh stub: logs every call, answers the three reads the drain makes.
cat > "$TMP/gh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_LOG"
case "$1 $2" in
  "repo view") printf 'popcre/demo\n' ;;
  "pr list") cat "$GH_QUEUE" ;;
  "issue list") cat "${GH_ISSUES:-/dev/null}" ;;
  "issue create") printf 'https://github.com/popcre/demo/issues/9\n' ;;
  *) exit 1 ;;
esac
STUB
chmod +x "$TMP/gh"
export GH_LOG="$TMP/gh.log" GH_QUEUE="$TMP/queue.txt"
export AI_POSTHOC_GH_BIN="$TMP/gh"
export AI_REVIEW_SCOREBOARD_FILE="$TMP/reviews.jsonl"
A="$(printf 'a%.0s' $(seq 40))"; B="$(printf 'b%.0s' $(seq 40))"; C="$(printf 'c%.0s' $(seq 40))"; D="$(printf 'd%.0s' $(seq 40))"
printf '11 %s %s approved one\n12 %s %s rejected one\n13 %s %s revised one\n14 %s %s fresh one\n' "$A" "$A" "$B" "$B" "$C" "$C" "$D" "$D" > "$GH_QUEUE"
printf '{"head":"%s","verdict":"APPROVE"}\n{"head":"%s","verdict":"REJECT"}\n{"head":"%s","verdict":"REVISE"}\n' "$A" "$B" "$C" > "$AI_REVIEW_SCOREBOARD_FILE"

run(){ : > "$GH_LOG"; "$SCRIPT" "$@" 2>"$TMP/err"; }

printf 'ai-review-posthoc: argument handling\n'
"$SCRIPT" --bogus >/dev/null 2>&1; check 'an unknown option exits 2' '[ $? -eq 2 ]'
"$SCRIPT" --limit x >/dev/null 2>&1; check 'a non-numeric --limit exits 2' '[ $? -eq 2 ]'
AI_POSTHOC_GH_BIN="$TMP/no-such-gh" "$SCRIPT" --dry-run >/dev/null 2>"$TMP/err2"; rc=$?
check 'a missing GitHub throttle fails closed without a GitHub call' "[ $rc -eq 2 ] && grep -q 'throttle' '$TMP/err2'"
check 'the default GitHub binary is the ai-gh throttle, never bare gh' \
  "grep -q 'AI_POSTHOC_GH_BIN:-\$ROOT/ai-gh' '$SCRIPT' && ! grep -qE 'GH_BIN:-gh\"' '$SCRIPT'"

printf 'ai-review-posthoc: dry run\n'
out="$(run --dry-run)"; rc=$?
check 'a dry run exits 0' "[ $rc -eq 0 ]"
check 'a dry run resolves the repository through the stub' "grep -q '^repo view' '$GH_LOG'"
check 'an approved head is neither queued nor reopened' "! grep -q '#11' <<<\"$out\""
check 'a rejected head is reported as refused after merge' "grep -q '^reject popcre/demo#12 .* (refused after merge)' <<<\"$out\""
check 'a REVISE head is reported as refused after merge, not stranded' "grep -q '^revise popcre/demo#13 .* (refused after merge)' <<<\"$out\""
check 'a head without a verdict is queued' "grep -q '^queued popcre/demo#14 ' <<<\"$out\""
check 'a dry run opens no issue' "! grep -q '^issue create' '$GH_LOG'"
check 'a dry run counts one pending pull request' "grep -q '1 merged unreviewed-week' '$TMP/err'"

printf 'ai-review-posthoc: fix-forward issues for recorded refusals\n'
# Keep the live phase from needing a reviewer: queue only the refused heads.
printf '12 %s %s rejected one\n13 %s %s revised one\n' "$B" "$B" "$C" "$C" > "$GH_QUEUE"
run >/dev/null; rc=$?
check 'a drain with only recorded refusals exits 0' "[ $rc -eq 0 ]"
check 'a recorded REJECT opens its fix-forward issue' "grep -q 'issue create .*Post-hoc REJECT on popcre/demo#12' '$GH_LOG'"
check 'a recorded REVISE opens its fix-forward issue' "grep -q 'issue create .*Post-hoc REVISE on popcre/demo#13' '$GH_LOG'"
check 'the issue body names the verdict' "grep -q 'returned REVISE for head' '$GH_LOG'"
check 'the issue body carries the ai-review-posthoc signature' "grep -q 'Posted by ai-review-posthoc on' '$GH_LOG'"
printf 'Post-hoc REJECT on popcre/demo#12\nPost-hoc REVISE on popcre/demo#13\n' > "$TMP/issues.txt"
GH_ISSUES="$TMP/issues.txt" run >/dev/null
check 'an existing fix-forward issue is never duplicated' "! grep -q '^issue create' '$GH_LOG'"

printf 'ai-review-posthoc: explicit --repo\n'
run --dry-run --repo other/name >/dev/null
check '--repo skips the repository lookup' "! grep -q '^repo view' '$GH_LOG' && grep -q 'pr list -R other/name' '$GH_LOG'"

printf 'ai-review-posthoc: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
