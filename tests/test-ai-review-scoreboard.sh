#!/usr/bin/env bash
# Offline tests for bin/ai-review-scoreboard.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/bin/ai-review-scoreboard"
PASS=0; FAIL=0
ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }
bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export AI_REVIEW_SCOREBOARD_DIR="$TMP/state"
export AI_REVIEW_SCOREBOARD_FILE="$TMP/state/reviews.jsonl"

cat > "$TMP/grok.json" <<EOF
{"repo":"$TMP/repo","base":"$(printf 'a%.0s' {1..40})","head":"$(printf 'b%.0s' {1..40})","packet_sha256":"p1","turns":7,"total_tokens":300000,"total_cost_usd":0.05}
EOF
cat > "$TMP/kimi.json" <<EOF
{"repo":"$TMP/repo","base":"$(printf 'a%.0s' {1..40})","head":"$(printf 'b%.0s' {1..40})","packet_sha256":"p2","turns":1}
EOF
cat > "$TMP/glm.json" <<EOF
{"repository_root":"$TMP/repo","base":"$(printf 'a%.0s' {1..40})","head":"$(printf 'b%.0s' {1..40})","packet_sha256":"p3"}
EOF

echo '== ai-review-scoreboard'
$SCRIPT append grok "$TMP/grok.json" --elapsed 181 --verdict APPROVE --stale false >/dev/null
$SCRIPT append kimi "$TMP/kimi.json" --elapsed 3 --failure allowance-exhausted --stale false >/dev/null
$SCRIPT append glm "$TMP/glm.json" --elapsed 901 --failure empty-assistant-turns --stale true >/dev/null
check "three rows are appended" "test \"\$(wc -l < '$AI_REVIEW_SCOREBOARD_FILE')\" -eq 3"
check "every row is valid JSON" "jq -e . '$AI_REVIEW_SCOREBOARD_FILE' >/dev/null"
check "Grok metrics are preserved" "sed -n 1p '$AI_REVIEW_SCOREBOARD_FILE' | jq -e '.turns==7 and .tokens==300000 and .cost_usd==0.05'"
check "missing Kimi token and cost stay null" "sed -n 2p '$AI_REVIEW_SCOREBOARD_FILE' | jq -e '.tokens==null and .cost_usd==null'"
check "failure class is recorded" "sed -n 2p '$AI_REVIEW_SCOREBOARD_FILE' | jq -e '.failure_class==\"allowance-exhausted\"'"
check "stale evidence is recorded" "sed -n 3p '$AI_REVIEW_SCOREBOARD_FILE' | jq -e '.stale==true'"
check "report counts outcomes" "$SCRIPT report | jq -e '.reviews==3 and .usable_verdicts==1 and .failures==2 and .over_15_minutes==1'"
check "all active providers are accepted" "for p in muse gemini qwen codex deepseek; do $SCRIPT append \"\$p\" '$TMP/grok.json' --elapsed 1 --stale false >/dev/null || exit 1; done"
printf '{"packet_sha256":"p"}\n' > "$TMP/unknown.json"
row="$($SCRIPT append qwen "$TMP/unknown.json" --elapsed 1)"
check "missing repository and head are unknown" "printf '%s' '$row' | jq -e '.evidence_state==\"unknown\" and .stale==false'"
check "unknown evidence is never usable" "$SCRIPT report | jq -e '.usable_verdicts==1 and .unknown>=1'"
check "unknown provider is refused" "! $SCRIPT append nope '$TMP/grok.json' --elapsed 1"
check "invalid elapsed is refused" "! $SCRIPT append grok '$TMP/grok.json' --elapsed nope"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
