#!/usr/bin/env bash
# tests/test-ai-stepfun-windows-shell.sh — offline gate contract checks.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE="$ROOT/bin/ai-stepfun-windows-shell"
FIX="$ROOT/tests/fixtures/stepfun-windows-shell/pkg"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
check(){ # check "name" cmd...
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    printf 'ok   %s\n' "$name"; pass=$((pass+1))
  else
    printf 'FAIL %s\n' "$name"; fail=$((fail+1))
  fi
}

mkdir -p "$TMP/folder" "$TMP/host"
echo canary > "$TMP/host/secret.txt"
echo ok > "$TMP/folder/readme.md"
export AI_STEPFUN_REVIEW_DIR="$TMP/folder"
export GATE_PATH="/usr/bin:/bin"
export AI_STEPFUN_TEST_MODE=1
export AI_STEPFUN_RUNNERS_JSON="$TMP/no-such-runners.json"

refuses(){ "$GATE" "$@"; [ "$?" -eq 126 ]; }
allows(){ "$GATE" "$@"; }

check 'refuses cat outside folder' bash -c "\"$GATE\" cat \"$TMP/host/secret.txt\"; test \$? -eq 126"
check 'refuses python -c' bash -c "\"$GATE\" python -c print; test \$? -eq 126"
check 'refuses bash -c metachar' bash -c "\"$GATE\" bash -c 'cat /etc/passwd'; test \$? -eq 126"
check 'refuses npx' bash -c "\"$GATE\" npx --yes evil; test \$? -eq 126"
check 'refuses git' bash -c "\"$GATE\" git push; test \$? -eq 126"
check 'refuses parent path' bash -c "\"$GATE\" cat ../host/secret.txt; test \$? -eq 126"
check 'refuses absolute interpreter' bash -c "\"$GATE\" /c/Windows/System32/cmd.exe /c type x; test \$? -eq 126"
check 'refuses env prefix' bash -c "\"$GATE\" FOO=bar cat readme.md; test \$? -eq 126"
check 'refuses npm publish' bash -c "\"$GATE\" npm publish; test \$? -eq 126"
check 'refuses empty' bash -c "\"$GATE\"; test \$? -eq 126"
check 'refuses wsl name' bash -c "\"$GATE\" wsl.exe ls; test \$? -eq 126"

# Allow cat in folder — will fail at runner resolve without allowlist, so we
# only assert it does not exit 126 at the grammar layer. Use a stub runner.
mkdir -p "$TMP/bin"
printf '#!/bin/sh\nexit 0\n' > "$TMP/bin/cat"
printf '#!/bin/sh\nexit 0\n' > "$TMP/bin/npm"
chmod +x "$TMP/bin/cat" "$TMP/bin/npm"
export GATE_PATH="$TMP/bin:/usr/bin:/bin"
check 'allows cat in folder (stub)' bash -c "\"$GATE\" cat readme.md; test \$? -eq 0"
check 'allows npm test (stub)' bash -c "\"$GATE\" npm test; test \$? -eq 0"
check 'allows npm run test:unit (stub)' bash -c "\"$GATE\" npm run test:unit; test \$? -eq 0"
check 'refuses unknown npm flag' bash -c "\"$GATE\" npm --prefix /tmp test; test \$? -eq 126"

# Production allowlist/hash path (no test-mode fallback).
export AI_STEPFUN_TEST_MODE=0
mkdir -p "$TMP/stubs2"
printf '#!/bin/sh\nexit 0\n' > "$TMP/stubs2/cat"
chmod +x "$TMP/stubs2/cat"
echo 'missing allowlist refuses' >/dev/null
if AI_STEPFUN_RUNNERS_JSON="$TMP/missing.json" AI_STEPFUN_REVIEW_DIR="$TMP/folder" GATE_PATH="$TMP/stubs2" bash "$GATE" cat r.md >/dev/null 2>&1; then
  echo 'FAIL missing allowlist'; fail=$((fail+1))
else
  echo 'ok   missing allowlist refuses'; pass=$((pass+1))
fi
good_hash="$(sha256sum "$TMP/stubs2/cat" | awk '{print $1}')"
printf '{"cat":{"path":"%s","sha256":"%s"}}\n' "$TMP/stubs2/cat" "$good_hash" > "$TMP/runners.json"
if AI_STEPFUN_RUNNERS_JSON="$TMP/runners.json" AI_STEPFUN_REVIEW_DIR="$TMP/folder" GATE_PATH="$TMP/stubs2" bash "$GATE" cat r.md >/dev/null 2>&1; then
  echo 'ok   valid hash allowlist allows'; pass=$((pass+1))
else
  echo 'FAIL valid hash allowlist'; fail=$((fail+1))
fi
printf '{"cat":{"path":"%s","sha256":"%s"}}\n' "$TMP/stubs2/cat" "deadbeef" > "$TMP/runners-bad.json"
if AI_STEPFUN_RUNNERS_JSON="$TMP/runners-bad.json" AI_STEPFUN_REVIEW_DIR="$TMP/folder" GATE_PATH="$TMP/stubs2" bash "$GATE" cat r.md >/dev/null 2>&1; then
  echo 'FAIL hash mismatch allowed'; fail=$((fail+1))
else
  echo 'ok   hash mismatch refuses'; pass=$((pass+1))
fi
printf '{"cat":{"path":"%s"}}\n' "$TMP/stubs2/cat" > "$TMP/runners-nohash.json"
if AI_STEPFUN_RUNNERS_JSON="$TMP/runners-nohash.json" AI_STEPFUN_REVIEW_DIR="$TMP/folder" GATE_PATH="$TMP/stubs2" bash "$GATE" cat r.md >/dev/null 2>&1; then
  echo 'FAIL missing hash allowed'; fail=$((fail+1))
else
  echo 'ok   missing hash pin refuses'; pass=$((pass+1))
fi

# Regression (#1266 residual): jq.exe on Windows ends every -r line with CRLF,
# so the gate compared the pinned path/hash against "<value>\r" and refused
# every runner. A jq shim that reproduces the CRLF artifact must not change
# either outcome.
crlf_bin="$TMP/crlfjq"; mkdir -p "$crlf_bin"
real_jq="$(command -v jq)"
cat > "$crlf_bin/jq" <<SHIM
#!/bin/sh
# jq.exe on Windows: CRLF on every stdout line, exit codes intact (jq -e
# truthiness), so the shim keeps both.
_t="\$(mktemp 2>/dev/null)" || _t="./.jq-crlf.\$\$"
"$real_jq" "\$@" > "\$_t"
_rc=\$?
sed 's/\$/\r/' "\$_t"
rm -f "\$_t"
exit "\$_rc"
SHIM
chmod +x "$crlf_bin/jq"
printf '{"a":"b"}\n' | "$crlf_bin/jq" -r .a | od -c | grep -q '\\r' \
  || { echo 'FAIL crlf jq shim does not emit CR'; fail=$((fail+1)); }
if AI_STEPFUN_RUNNERS_JSON="$TMP/runners.json" AI_STEPFUN_REVIEW_DIR="$TMP/folder" GATE_PATH="$TMP/stubs2" PATH="$crlf_bin:$PATH" bash "$GATE" cat r.md >/dev/null 2>&1; then
  echo 'ok   crlf-emitting jq still allows a valid hash'; pass=$((pass+1))
else
  echo 'FAIL crlf-emitting jq refused a valid hash'; fail=$((fail+1))
fi
if AI_STEPFUN_RUNNERS_JSON="$TMP/runners-bad.json" AI_STEPFUN_REVIEW_DIR="$TMP/folder" GATE_PATH="$TMP/stubs2" PATH="$crlf_bin:$PATH" bash "$GATE" cat r.md >/dev/null 2>&1; then
  echo 'FAIL crlf-emitting jq allowed a hash mismatch'; fail=$((fail+1))
else
  echo 'ok   crlf-emitting jq still refuses a mismatched hash'; pass=$((pass+1))
fi

# BASH_ENV gate routing (config/opencode-stepfun/windows-gate-env.sh): the
# DEBUG trap must exec the gate copy before the model command runs, the
# gate-set marker must stop the trap from re-arming inside a verified
# runner, and the allowlisted bash <script> runner must not be re-gated.
# #1229 shipped a PATH shim that no Windows process could spawn, so every
# in-sandbox bash tool call died with NotFound: ChildProcess.spawn before a
# single gated command ran (shared-db#3943); these checks pin the contract.
GATE_ENV="$ROOT/config/opencode-stepfun/windows-gate-env.sh"
[ -f "$GATE_ENV" ] || { echo 'FAIL windows-gate-env.sh missing'; fail=$((fail+1)); }
mkdir -p "$TMP/stubs3"
printf '#!/bin/sh\nprintf "be=%%s marker=%%s\\n" "${BASH_ENV:-none}" "${AI_STEPFUN_SHELL_GATE:-0}"\n' > "$TMP/stubs3/cat"
chmod +x "$TMP/stubs3/cat"
cat_hash="$(sha256sum "$TMP/stubs3/cat" | awk '{print $1}')"
printf '{"cat":{"path":"%s","sha256":"%s"}}\n' "$TMP/stubs3/cat" "$cat_hash" > "$TMP/runners3.json"

trap_env(){ # trap_env CMD -> runs `bash -c CMD` with the trap wiring
  BASH_ENV="$GATE_ENV" \
  AI_STEPFUN_GATE_BIN="$GATE" \
  AI_STEPFUN_REVIEW_DIR="$TMP/folder" \
  AI_STEPFUN_RUNNERS_JSON="$TMP/runners3.json" \
  AI_STEPFUN_SHELL_GATE=0 \
  GATE_PATH="$TMP/stubs3" \
  bash -c "$1"
}
out="$(trap_env 'cat readme.md' 2>/dev/null)" || true
if [ "$out" = "be=none marker=1" ]; then
  echo 'ok   BASH_ENV trap routes cat through the gate (marker set, BASH_ENV cleared)'; pass=$((pass+1))
else
  echo "FAIL BASH_ENV trap routing, got: $out"; fail=$((fail+1))
fi
out="$(BASH_ENV="$GATE_ENV" \
  AI_STEPFUN_GATE_BIN="$GATE" \
  AI_STEPFUN_REVIEW_DIR="$TMP/folder" \
  AI_STEPFUN_RUNNERS_JSON="$TMP/runners3.json" \
  AI_STEPFUN_SHELL_GATE=0 \
  AI_STEPFUN_GATE_LOG="$TMP/gate-audit.log" \
  GATE_PATH="$TMP/stubs3" \
  bash -c 'cat readme.md' 2>/dev/null)" || true
if [ "$out" = "be=none marker=1" ] && grep -q 'cat readme.md' "$TMP/gate-audit.log" 2>/dev/null; then
  echo 'ok   gated command is recorded in the per-run audit log'; pass=$((pass+1))
else
  echo "FAIL audit log, got: $out / $(cat "$TMP/gate-audit.log" 2>/dev/null)"; fail=$((fail+1))
fi
if trap_env 'whoami' >/dev/null 2>&1; then
  echo 'FAIL BASH_ENV trap let a non-allowlisted command run'; fail=$((fail+1))
else
  rc=$?
  if [ "$rc" -eq 126 ]; then
    echo 'ok   BASH_ENV trap refuses non-allowlisted command (126)'; pass=$((pass+1))
  else
    echo "FAIL BASH_ENV trap refusal rc=$rc (want 126)"; fail=$((fail+1))
  fi
fi
out="$(BASH_ENV="$GATE_ENV" AI_STEPFUN_SHELL_GATE=1 bash -c 'printf "freed\n"' 2>/dev/null)"
if [ "$out" = "freed" ]; then
  echo 'ok   gate marker skips the trap for verified runners'; pass=$((pass+1))
else
  echo "FAIL gate marker skip, got: $out"; fail=$((fail+1))
fi
# The allowlisted bash <script> runner runs inside one gate pass: the trap
# execs the gate once, the gate verifies the stub bash hash and execs it
# with the marker set and BASH_ENV cleared, so the script is not re-gated.
printf '#!/bin/sh\nexec /usr/bin/bash "$@"\n' > "$TMP/stubs3/bash"
chmod +x "$TMP/stubs3/bash"
bash_hash="$(sha256sum "$TMP/stubs3/bash" | awk '{print $1}')"
printf '{"cat":{"path":"%s","sha256":"%s"},"bash":{"path":"%s","sha256":"%s"}}\n' \
  "$TMP/stubs3/cat" "$cat_hash" "$TMP/stubs3/bash" "$bash_hash" > "$TMP/runners3.json"
echo 'echo "script-ran marker=${AI_STEPFUN_SHELL_GATE:-0} be=${BASH_ENV:-none}"' > "$TMP/folder/t.sh"
out="$(trap_env 'bash t.sh' 2>/dev/null)" || true
if [ "$out" = "script-ran marker=1 be=none" ]; then
  echo 'ok   allowlisted bash script runner not re-gated'; pass=$((pass+1))
else
  echo "FAIL bash script runner re-gating, got: $out"; fail=$((fail+1))
fi

# Hardening from the #1344 review: the direct -c form refuses extra argv, and
# the trap template fails closed when AI_STEPFUN_GATE_BIN is unset.
check 'refuses extra args after -c payload' bash -c "\"$GATE\" -c 'cat r.md' extra; test \$? -eq 126"
if out="$(cd "$TMP/folder" && env -u AI_STEPFUN_GATE_BIN \
    BASH_ENV="$GATE_ENV" \
    AI_STEPFUN_REVIEW_DIR="$TMP/folder" \
    AI_STEPFUN_SHELL_GATE=0 \
    GATE_PATH="$TMP/stubs3" \
    bash -c 'cat readme.md' 2>/dev/null)"; then
  echo 'FAIL unset gate bin still ran'; fail=$((fail+1))
else
  if [ -z "$out" ]; then
    echo 'ok   unset AI_STEPFUN_GATE_BIN fails closed (no command output)'; pass=$((pass+1))
  else
    echo "FAIL unset gate bin leaked output: $out"; fail=$((fail+1))
  fi
fi

printf 'passed=%s failed=%s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
