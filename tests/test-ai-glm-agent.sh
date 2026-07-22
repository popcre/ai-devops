#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
launcher="$repo/bin/ai-glm-agent"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat >"$tmp/claude" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$FAKE_CAPTURE"
printf 'ANTHROPIC_API_KEY=%s\n' "${ANTHROPIC_API_KEY:-}" >>"$FAKE_CAPTURE"
printf 'ANTHROPIC_BASE_URL=%s\n' "${ANTHROPIC_BASE_URL:-}" >>"$FAKE_CAPTURE"
printf '{"is_error":false,"result":"FAKE_OK","modelUsage":{"%s":{}}}\n' "$FAKE_MODEL"
FAKE
chmod +x "$tmp/claude" "$launcher"

export PATH="$tmp:$PATH"
export ZAI_API_KEY="test-only-not-a-secret"
export ZAI_CLAUDE_CONFIG_DIR="$tmp/glm-config"
export FAKE_CAPTURE="$tmp/args.txt"
export FAKE_MODEL="glm-5.2"
export ANTHROPIC_API_KEY="must-be-cleared"

[ "$($launcher --mode review 'Inspect the repository')" = "FAKE_OK" ]
grep -q -- '--permission-mode plan' "$FAKE_CAPTURE"
grep -Eq '^ANTHROPIC_API_KEY=$' "$FAKE_CAPTURE"
grep -q '^ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic$' "$FAKE_CAPTURE"

$launcher --mode implement 'Make the scoped change' >/dev/null
grep -q -- '--permission-mode auto' "$FAKE_CAPTURE"

export FAKE_MODEL="glm-5.1"
if "$launcher" 'Reject fallback' >"$tmp/out" 2>"$tmp/err"; then
  echo "FAIL: returned-model mismatch was accepted" >&2; exit 1
fi
grep -q 'No fallback accepted' "$tmp/err"

echo "PASS: Bash GLM launcher isolation, modes, prompt, and fallback rejection"
