#!/usr/bin/env bash
# Focused unit proof for extract_report terminal VERDICT: conversion.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOOR="$ROOT/tools/lib/review-doors/stepfun.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Pull extract_report only (the door's main() must not run).
export SF_OC_PROVIDER=p SF_OC_MODEL_ID=m SF_STEP_MODEL=s
eval "$(sed -n '/^extract_report()/,/^}/p' "$DOOR")"
type extract_report >/dev/null

result="$TMP/result.txt"
printf 'Analysis of the change with plenty of detail in f:1.\n\nVERDICT: APPROVE abc123\n' > "$result"

extract_report "$result" "$TMP/r1.md" abc123 review stepcode
echo "--- r1 ---"
cat "$TMP/r1.md"
grep -qx APPROVE <(awk '/^## Verdict[[:space:]]*$/{p=1;next} p{print;exit}' "$TMP/r1.md") \
  && echo 'PASS terminal VERDICT becomes ## Verdict APPROVE' \
  || { echo 'FAIL r1'; exit 1; }
! grep -qx BLOCKED "$TMP/r1.md" && echo 'PASS not recorded as BLOCKED' || { echo 'FAIL blocked'; exit 1; }

# Contradictory report keeps last ## Verdict (already the contract)
printf 'Analysis of the change with plenty of detail in f:1.\nVERDICT: APPROVE abc123\n\n## Verdict\nREJECT\n' > "$result"
extract_report "$result" "$TMP/r2.md" abc123 review stepcode
grep -qx REJECT <(awk '/^## Verdict[[:space:]]*$/{p=1;next} p{print;exit}' "$TMP/r2.md") \
  && echo 'PASS last ## Verdict wins when both shapes appear' \
  || { echo 'FAIL r2'; exit 1; }

# No verdict at all still BLOCKED
printf 'Analysis only, no decision line anywhere.\n' > "$result"
extract_report "$result" "$TMP/r3.md" abc123 review stepcode
grep -qx BLOCKED <(awk '/^## Verdict[[:space:]]*$/{p=1;next} p{print;exit}' "$TMP/r3.md") \
  && echo 'PASS missing verdict still BLOCKED' \
  || { echo 'FAIL r3'; exit 1; }

# Qualified prose after the decision word must fail closed as BLOCKED
for line in 'APPROVE only after the lint fix lands' 'VERDICT: APPROVE once CI passes' 'REJECT unless reverted abc123'; do
  printf 'Analysis of the change with plenty of detail in f:1.

%s
' "$line" > "$result"
  extract_report "$result" "$TMP/r4.md" abc123 review stepcode
  grep -qx BLOCKED <(awk '/^## Verdict[[:space:]]*$/{p=1;next} p{print;exit}' "$TMP/r4.md")     && echo "PASS qualified line stays BLOCKED: $line"     || { echo "FAIL qualified: $line"; cat "$TMP/r4.md"; exit 1; }
done

echo ALL_PASS
