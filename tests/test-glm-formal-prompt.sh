#!/usr/bin/env bash
# Formal presentation guidance must preserve caller evidence and ordinary asks.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export AI_DEVOPS_CONFIG_DIR="$TMP/config" AI_REVIEWER_STATE_BASE="$TMP/state"
source "$ROOT/bin/ai-glm"
PROMPT_FILE=''
PROMPT_TEXT='Discuss the tradeoffs without deciding.'
out="$(read_prompt)"
[ "$(cat "$out")" = "$PROMPT_TEXT" ]; rm -f "$out"
for shape in 'VERDICT: APPROVE exact-head' $'Findings\n## Verdict\nAPPROVE'; do
  PROMPT_TEXT="$shape"
  out="$(read_prompt)"
  grep -q 'Emit exactly one' "$out"
  grep -q 'provisional decision' "$out"
  grep -q 'independent judgment' "$out"
  [ "$(head -c "${#shape}" "$out")" = "$shape" ]
  rm -f "$out"
done
PROMPT_TEXT=''
printf 'Evidence sentinel\nVERDICT: REJECT exact-head\n' > "$TMP/input"
PROMPT_FILE="$TMP/input"
out="$(read_prompt)"
cmp "$TMP/input" <(head -n 2 "$out")
grep -q 'requested exact-head' "$out"
rm -f "$out"
PROMPT_FILE=''
PROMPT_TEXT='Implement a parser for VERDICT: lines.'
out="$(read_prompt implement)"
[ "$(cat "$out")" = "$PROMPT_TEXT" ]; rm -f "$out"
printf '5 GLM formal-presentation checks passed\n'
