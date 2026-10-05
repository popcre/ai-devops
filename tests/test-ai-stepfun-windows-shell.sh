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

printf 'passed=%s failed=%s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
