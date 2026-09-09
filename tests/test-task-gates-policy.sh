#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POLICY="$ROOT/config/task-gates.json"
SCHEMA="$ROOT/config/task-gates.schema.json"
CASES="$ROOT/tests/fixtures/task-gates/policy-cases.json"
ROUTER="$ROOT/tests/fixtures/task-gates/lean-router-contract.json"
failures=0

check() {
  local label="$1" command="$2"
  if eval "$command"; then printf '  ok   %s\n' "$label"; else printf '  FAIL %s\n' "$label" >&2; failures=$((failures + 1)); fi
}

check 'schema defines the versioned policy shape' "jq -e '(.required | index(\"schemaVersion\")) and (.required | index(\"classes\")) and .properties.classes.additionalProperties.required == [\"precedence\",\"requiredGates\",\"forbiddenActions\"]' '$SCHEMA' >/dev/null"
check 'policy has every required class' "jq -e '.classes | has(\"ordinary-prose\") and has(\"code-configuration\") and has(\"reviewer-safety\") and has(\"ui-live-workflow\") and has(\"shared-database\") and has(\"deployment\") and has(\"infrastructure\") and has(\"production\") and has(\"private-licensed-evidence\")' '$POLICY' >/dev/null"
check 'unknown policy and repository fail closed' "jq -e '.resolution.unknownRepository == \"deny\" and .resolution.missingPolicy == \"deny\" and .resolution.intentMismatch == \"stop-before-action\"' '$POLICY' >/dev/null"
check 'protected classes cannot be downgraded by an override' "jq -e '.resolution.explicitOverride.required and .resolution.explicitOverride.recordReason and .resolution.explicitOverride.cannotDowngradeProtected' '$POLICY' >/dev/null"
check 'every protected class exists and has a unique precedence' "jq -e '[.protectedClasses[] as \$name | .classes[\$name].precedence] | length == (. | unique | length)' '$POLICY' >/dev/null"
check 'each declaration refers only to known classes' "jq -e '. as \$policy | [.repositoryDeclarations[] | .minimumClasses[] | select(. as \$name | (\$policy.classes | has(\$name)) | not)] | length == 0' '$POLICY' >/dev/null"

while IFS=$'\t' read -r name expected classes; do
  classes="${classes%$'\r'}"
  actual="$(jq -r --argjson names "$classes" '[$names[] as $name | .classes[$name] | {name:$name, precedence}] | max_by(.precedence).name' "$POLICY")"
  check "mixed-change case: $name" "[ '$actual' = '$expected' ]"
done < <(jq -r '.cases[] | [.name, .expected, (.classes | tojson)] | @tsv' "$CASES")

while IFS=$'\t' read -r base override; do
  override="${override%$'\r'}"
  base_rank="$(jq -r --arg name "$base" '.classes[$name].precedence' "$POLICY")"
  override_rank="$(jq -r --arg name "$override" '.classes[$name].precedence' "$POLICY")"
  check "protected downgrade rejected: $base" "jq -e --arg name '$base' '.protectedClasses | index(\$name)' '$POLICY' >/dev/null && [ '$override_rank' -lt '$base_rank' ]"
done < <(jq -r '.invalidOverrides[] | [.base, .override] | @tsv' "$CASES")

check 'lean root router has only durable routing responsibilities' "jq -e '.rootRouterRequired | length == 4' '$ROUTER' >/dev/null && jq -e '.rootRouterForbidden | index(\"full-procedures\") and index(\"machine-facts\") and index(\"volatile-live-facts\") and index(\"history\")' '$ROUTER' >/dev/null"
check 'documentation trigger avoids unrelated protected procedures' "jq -e '.triggers[] | select(.task == \"documentation-only\") | (.doesNotLoad | index(\"database-procedure\") and index(\"production-procedure\") and index(\"reviewer-procedure\"))' '$ROUTER' >/dev/null"
check 'protected triggers still load their exact procedures' "jq -e '[.triggers[] | select(.task != \"documentation-only\") | .loads[] | select(endswith(\"procedure\"))] | length == 3' '$ROUTER' >/dev/null"
check 'no-loss ledger has only accountable dispositions' "jq -e '.noLossDisposition | sort == [\"consolidate\",\"keep\",\"move\",\"remove-with-proof\"]' '$ROUTER' >/dev/null"

[ "$failures" -eq 0 ] || exit 1
printf 'PASS: task-gate policy is versioned, fail-closed, strongest-match, and preserves lean-router reachability\n'
