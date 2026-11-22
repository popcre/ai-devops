#!/usr/bin/env bash
# Offline tests for bin/ai-agy and bin/ai-install-completion-check-hook --client antigravity.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AI_AGY="$REPO_ROOT/bin/ai-agy"
HOOK_INSTALLER="$REPO_ROOT/bin/ai-install-completion-check-hook"

PASS=0
FAIL=0
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

ok()   { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1" >&2; }

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if printf '%s' "$haystack" | grep -Fq -- "$needle"; then
    ok "$label"
  else
    fail "$label (expected '$needle' in '$haystack')"
  fi
}

# 1. Version works even without CLI
out="$(AI_AGY_CLI="$TMP_ROOT/no-such-agy" "$AI_AGY" version 2>&1)"
assert_contains "$out" "ai-agy 1.0.0" "version prints wrapper version"

# 2. Refuses --dangerously-skip-permissions / --yolo / --never-ask
for flag in --yolo --dangerously-skip-permissions --never-ask; do
  set +e
  out="$(AI_AGY_CLI="$TMP_ROOT/no-such-agy" "$AI_AGY" ask "$flag" "hi" 2>&1)"
  rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    assert_contains "$out" "is refused" "ask refuses $flag"
  else
    fail "ask should exit non-zero for $flag"
  fi
done

# 3. Missing CLI fails closed with local_dependency_unavailable
set +e
out="$(AI_AGY_CLI="$TMP_ROOT/no-such-agy" "$AI_AGY" ask "hello" 2>&1)"
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
  assert_contains "$out" "local_dependency_unavailable" "missing CLI fails closed"
else
  fail "missing CLI should exit non-zero"
fi

# 4. Stub CLI: default --mode plan, --print, --output-format text
STUB_CLI="$TMP_ROOT/fake-agy"
cat > "$STUB_CLI" <<'EOF'
#!/usr/bin/env bash
printf 'ARGS:%s\n' "$*"
EOF
chmod +x "$STUB_CLI"

out="$(AI_AGY_CLI="$STUB_CLI" "$AI_AGY" ask "hello world")"
assert_contains "$out" "--print --mode plan" "ask defaults to --print --mode plan"
assert_contains "$out" "--output-format text" "ask defaults to --output-format text"
assert_contains "$out" "hello world" "ask passes prompt"

# 5. Stub CLI: --json-output wraps plain text into JSON object
out="$(AI_AGY_CLI="$STUB_CLI" "$AI_AGY" ask --json-output "hello json")"
if printf '%s' "$out" | jq -e '.response | contains("--output-format json")' >/dev/null 2>&1; then
  ok "ask --json-output passes --output-format json and returns valid JSON"
else
  fail "ask --json-output did not return expected JSON: $out"
fi

# 6. Empty stdout fails closed (completion honesty)
EMPTY_CLI="$TMP_ROOT/empty-agy"
printf '#!/usr/bin/env bash\nexit 0\n' > "$EMPTY_CLI"
chmod +x "$EMPTY_CLI"
set +e
out="$(AI_AGY_CLI="$EMPTY_CLI" "$AI_AGY" ask "hello" 2>&1)"
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
  assert_contains "$out" "empty answer" "empty stdout fails closed"
else
  fail "empty stdout should fail closed"
fi

# 7. Doctor green with valid fixture home
AGY_HOME="$TMP_ROOT/agy-home"
mkdir -p "$AGY_HOME/skills/demo"
touch "$AGY_HOME/skills/demo/.ai-devops-managed"
printf '# globals\n' > "$AGY_HOME/AGENTS.md"
printf '{"mcpServers":{"1password":{"command":"mcp-launch.cmd","args":["1p"]}}}\n' > "$AGY_HOME/mcp_config.json"

out="$(AI_AGY_HOME="$AGY_HOME" AI_AGY_CLI="$STUB_CLI" "$AI_AGY" doctor 2>&1)"
assert_contains "$out" "all checks green" "doctor passes with valid fixture home"

# 8. Hook installer --client antigravity installs, preserves foreign hooks, and passes --check
printf '{"user-hook":{"Stop":[{"type":"command","command":"echo hi"}]}}\n' > "$AGY_HOME/hooks.json"
HOME="$TMP_ROOT/fake-home" "$HOOK_INSTALLER" --client antigravity --antigravity-home "$AGY_HOME" --repo-root "$REPO_ROOT" >/dev/null
if jq -e '.["user-hook"] and .["ai-devops-completion-check"].enabled == true' "$AGY_HOME/hooks.json" >/dev/null 2>&1; then
  ok "hook installer adds ai-devops-completion-check and preserves foreign hooks"
else
  fail "hook installer did not produce expected hooks.json"
fi
if HOME="$TMP_ROOT/fake-home" "$HOOK_INSTALLER" --check --client antigravity --antigravity-home "$AGY_HOME" --repo-root "$REPO_ROOT" >/dev/null 2>&1; then
  ok "hook installer --check passes after install"
else
  fail "hook installer --check failed after install"
fi

printf '\nSummary: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
