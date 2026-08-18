#!/usr/bin/env bash
# Offline contract tests for the planned ai-gemini wrapper. These fixtures never
# execute agy, contact Google, or read machine-local Antigravity state.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURES="$ROOT/tests/fixtures/ai-gemini"
PASS=0; FAIL=0
ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }
bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }

require_success_verdict(){
  local file="$1"
  jq -e '.status == "SUCCESS" and (.conversation_id | type == "string" and length > 0) and (.response | type == "string" and length > 0) and (.response | test("^## Verdict"; "m"))' "$file" >/dev/null
}
require_exact_model(){
  local file="$1" requested="$2"
  jq -e --arg requested "$requested" '.status == "SUCCESS" and .command.name == "model" and .command.data.id == $requested and .command.data.is_default == false' "$file" >/dev/null
}

echo '== ai-gemini contract fixtures'
check 'exact High model is present' "grep -q '^gemini-3.7-flash-high' '$FIXTURES/models.txt'"
check 'successful turn has a usable verdict and conversation ID' "require_success_verdict '$FIXTURES/turn-success.json'"
check 'empty success is rejected' "! require_success_verdict '$FIXTURES/empty-success.json'"
check 'exact model proof is accepted' "require_exact_model '$FIXTURES/model-success.json' gemini-3.7-flash-high"
check 'model mismatch is rejected' "! require_exact_model '$FIXTURES/model-mismatch.json' gemini-3.7-flash-high"
check 'usage has explicit Gemini weekly and five-hour buckets' "jq -e '[.command.data.groups[] | select(.name == \"Gemini Models\") | .buckets[] | .window] | sort == [\"5h\",\"weekly\"]' '$FIXTURES/usage-success.json'"
check 'quota failure is distinct from success' "jq -e '.status == \"ERROR\" and .error.code == \"RESOURCE_EXHAUSTED\"' '$FIXTURES/quota-error.json'"
check 'authentication failure is distinct from success' "jq -e '.status == \"ERROR\" and .error.code == \"UNAUTHENTICATED\"' '$FIXTURES/auth-error.json'"
check 'malformed JSON is rejected' "! jq -e . '$FIXTURES/malformed.json'"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
