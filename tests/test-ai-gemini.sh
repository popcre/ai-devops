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

SCRIPT="$ROOT/bin/ai-gemini"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
cat > "$TMP/bin/agy" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  --version) echo 1.1.14 ;;
  --help) echo '  --sandbox' ;;
  models) echo -e 'gemini-3.7-flash-high\tGemini 3.7 Flash (High)' ;;
  *) exit 2 ;;
esac
EOF
chmod +x "$TMP/bin/agy"
check 'wrapper exposes its help' "$SCRIPT --help | grep -q 'ai-gemini new'"
check 'wrapper reports its version' "$SCRIPT --version | grep -q 'ai-gemini 0.1.0'"
check 'model verification uses the same containment and mode as the review' "grep -q -- '--conversation \"\$c\" --sandbox --mode plan' '$SCRIPT'"
check 'Git Bash does not rewrite the /model command as a Windows path' "grep -q 'MSYS_NO_PATHCONV=1' '$SCRIPT'"
check 'doctor verifies sandbox and configured model without a live turn' "AI_GEMINI_BIN='$TMP/bin/agy' $SCRIPT doctor | grep -q 'disposable-copy=yes'"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
