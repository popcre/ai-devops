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
printf '#!/usr/bin/env bash\nexit 0\n' > "$TMP/bin/cat"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TMP/bin/npm"
chmod +x "$TMP/bin/cat" "$TMP/bin/npm"
export GATE_PATH="$TMP/bin:/usr/bin:/bin"
check 'allows cat in folder (stub)' bash -c "\"$GATE\" cat readme.md; test \$? -eq 0"
check 'allows npm test (stub)' bash -c "\"$GATE\" npm test; test \$? -eq 0"
check 'allows npm run test:unit (stub)' bash -c "\"$GATE\" npm run test:unit; test \$? -eq 0"
check 'refuses unknown npm flag' bash -c "\"$GATE\" npm --prefix /tmp test; test \$? -eq 126"

printf 'passed=%s failed=%s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
