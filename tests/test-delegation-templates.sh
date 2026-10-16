#!/usr/bin/env bash
# Shared delegation-contract checks that used to live only in the frozen Grok
# suite. The debate-turn template is used by pool member GLM (and by any
# by-name debate), so these assertions must stay green without running the
# Grok wrapper suite (popcre/ai-devops#1714 complete freeze).
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"

TEMPLATE="$REPO_ROOT/templates/delegation/debate-turn.md"
GLM_SKILL="$REPO_ROOT/skills/shared/ask-glm/SKILL.md"

check "debate template exists" "test -f '$TEMPLATE'"
for heading in "Goal" "Disputed claim" "Other model's reasoning" \
  "Current plan or diff paths" "New test or runtime evidence" "Constraints" \
  "What changed since the last turn" "Claim-by-claim check" "Material objections" \
  "Required correction" "Consensus question" "Consensus ledger" \
  "Agreed decisions" "Rejected alternatives" "Unresolved objections" \
  "Evidence still needed" "Last verified commit and path state"; do
  check "template has $heading" "grep -Fqx \"## $heading\" '$TEMPLATE' || grep -Fqx \"### $heading\" '$TEMPLATE'"
done
check "template requires current path re-read" "grep -qi 're-read.*current' '$TEMPLATE'"
check "GLM skill uses shared template" "grep -Fq 'templates/delegation/debate-turn.md' '$GLM_SKILL'"

printf 'test-delegation-templates: %s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
