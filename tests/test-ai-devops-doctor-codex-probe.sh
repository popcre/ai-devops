#!/usr/bin/env bash
# Proves the doctor's codex sandbox probe: closes stdin, and tells apart
# "not logged in", "sandbox broken", "hung", and "worked".
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# 1. The real probe must close stdin, or it hangs waiting for a prompt.
grep -q '</dev/null 2>&1)' "$repo/bin/ai-devops"

AI_DEVOPS_LIB_ONLY=1 . "$repo/bin/ai-devops"

check() { [ "$(codex_probe_verdict "$1" "$2" "$3")" = "$4" ] || { echo "FAIL: expected $4 for [$2]"; exit 1; }; }

check 0 'anything at all' 1 ok
check 1 'ERROR: Your access token could not be refreshed because your refresh token was revoked.' 0 auth
check 1 'failed to connect to websocket: HTTP error: 401 Unauthorized' 0 auth
check 1 'orchestrator_helper_launch_failed: helper=codex-windows-sandbox-setup.exe, error=program not found' 0 sandbox
check 124 'Reading additional input from stdin...' 0 timeout
check 1 'some unexpected explosion' 0 unknown

# 2. A revoked login must be a WARNING, not a REQUIRED failure: doctor's own
#    policy is that "not logged in" never fails the run.
fake="$tmp/bin"; mkdir -p "$fake"
cat >"$fake/codex" <<'FAKE'
#!/usr/bin/env bash
cat >/dev/null   # if stdin were open this would block forever
echo 'ERROR: Your access token could not be refreshed because your refresh token was revoked.' >&2
exit 1
FAKE
chmod +x "$fake/codex"
PATH="$fake:$PATH"; FAILED=0
set +e; check_codex_sandbox >"$tmp/out" 2>&1; set -e
grep -q 'NOT authenticated' "$tmp/out"
grep -q 'codex login' "$tmp/out"
[ "$FAILED" = "0" ]

# 3. A genuinely broken sandbox must still FAIL.
cat >"$fake/codex" <<'FAKE'
#!/usr/bin/env bash
echo 'orchestrator_helper_launch_failed: helper=codex-windows-sandbox-setup.exe, error=program not found' >&2
exit 1
FAKE
chmod +x "$fake/codex"
FAILED=0
set +e; check_codex_sandbox >"$tmp/out" 2>&1; set -e
grep -q 'CANNOT write' "$tmp/out"
[ "$FAILED" = "1" ]

# 4. A working codex passes.
cat >"$fake/codex" <<'FAKE'
#!/usr/bin/env bash
printf 'OK' > probe.txt
FAKE
chmod +x "$fake/codex"
FAILED=0
set +e; check_codex_sandbox >"$tmp/out" 2>&1; set -e
grep -q 'can write' "$tmp/out"
[ "$FAILED" = "0" ]

echo 'PASS: codex sandbox probe closes stdin and classifies auth/sandbox/timeout/ok'
