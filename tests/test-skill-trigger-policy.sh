#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; POLICY="$ROOT/config/skill-trigger-policy.json"
PASS=0; FAIL=0; ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }; bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
min_pos="$(jq -r .minimum_positive_cases "$POLICY")"; min_neg="$(jq -r .minimum_negative_cases "$POLICY")"
if jq -e '.schema_version==1 and .repeated_run_minimum>=3 and (.platforms|index("windows")!=null and index("linux")!=null)' "$POLICY" >/dev/null; then ok 'policy requires repeated Windows and Linux evidence'; else bad 'policy requires repeated Windows and Linux evidence'; fi
while IFS= read -r skill; do
  skill="${skill%$'\r'}"; eval_file="$ROOT/tools/skill-trigger-eval/$skill.eval.json"
  matches="$(find "$ROOT/skills" -path "*/$skill/SKILL.md" -type f | wc -l | tr -d ' ')"
  if [ "$matches" -eq 1 ]; then ok "$skill has one skill source"; else bad "$skill has $matches skill sources"; fi
  if [ -f "$eval_file" ] && jq -e --argjson p "$min_pos" --argjson n "$min_neg" \
    'type=="array" and ([.[]|select(.should_trigger==true)]|length)>=$p and ([.[]|select(.should_trigger==false)]|length)>=$n and all(.[];.query|type=="string")' "$eval_file" >/dev/null; then
    ok "$skill has balanced committed trigger cases"
  else bad "$skill lacks its required trigger eval set"; fi
done < <(jq -r '.protected_skills[]' "$POLICY")
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]
