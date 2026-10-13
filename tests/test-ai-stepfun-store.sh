#!/usr/bin/env bash
# Synthetic protected transfers only; no account, provider, or 1Password calls.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export AI_STEPFUN_KEY_STORE="$TMP/private/key" AI_REVIEW_EVENT_DIR="$TMP/events"
export AI_STEPFUN_STATE_DIR="$TMP/state" AI_REVIEW_QUARANTINE_DIR="$TMP/quarantine"
SCRIPT="$ROOT/bin/ai-stepfun"
pass=0
ok(){ printf 'PASS %s\n' "$1"; pass=$((pass+1)); }
printf 'synthetic-stepfun-credential\n' | bash "$SCRIPT" store-key --if-missing --key-fd 9 9<&0 >/dev/null
cmp "$AI_STEPFUN_KEY_STORE" <(printf 'synthetic-stepfun-credential\n'); ok 'actual FD9 round trip'
printf 'replacement-must-not-land\n' | bash "$SCRIPT" store-key --if-missing --key-fd 9 9<&0 >/dev/null
cmp "$AI_STEPFUN_KEY_STORE" <(printf 'synthetic-stepfun-credential\n'); ok 'existing valid store unchanged'
if printf 'bad credential\n' | bash "$SCRIPT" store-key --key-fd 9 9<&0 >/dev/null 2>&1; then exit 1; fi
cmp "$AI_STEPFUN_KEY_STORE" <(printf 'synthetic-stepfun-credential\n'); ok 'malformed transfer preserves existing bytes'
if bash "$SCRIPT" store-key --key-fd 2 >/dev/null 2>&1; then exit 1; fi
ok 'unsafe descriptor refused'
if bash "$SCRIPT" store-key --key-fd '' >/dev/null 2>&1; then exit 1; fi
ok 'empty explicit descriptor refused without vault fallback'
printf 'synthetic-stepfun-credential\r\n' | bash "$SCRIPT" store-key --key-fd 9 9<&0 >/dev/null
cmp "$AI_STEPFUN_KEY_STORE" <(printf 'synthetic-stepfun-credential\n'); ok 'Windows line ending normalizes without changing credential'
original="$AI_STEPFUN_KEY_STORE"; export AI_STEPFUN_KEY_STORE="$TMP/link/key"
if [ -n "${SYSTEMROOT:-}" ]; then
  AI_STEPFUN_TEST_LINK="$(cygpath -w "$TMP/link")" AI_STEPFUN_TEST_TARGET="$(cygpath -w "$TMP/private")" powershell.exe -NoProfile -Command 'New-Item -ItemType Junction -Path $env:AI_STEPFUN_TEST_LINK -Target $env:AI_STEPFUN_TEST_TARGET | Out-Null'
else
  ln -s "$TMP/private" "$TMP/link"
fi
if printf 'synthetic\n' | bash "$SCRIPT" store-key --key-fd 9 9<&0 >/dev/null 2>&1; then exit 1; fi
ok 'linked ancestor refused'
export AI_STEPFUN_KEY_STORE="$original"
if [ -n "${SYSTEMROOT:-}" ]; then
  # Force ACL protection to fail before opening the descriptor; no bytes land.
  export AI_STEPFUN_KEY_STORE="$TMP/new-private/key" AI_DEVOPS_TEST_ICACLS_FAIL=1
  if printf 'must-never-land\n' | bash "$SCRIPT" store-key --key-fd 9 9<&0 >/dev/null 2>&1; then exit 1; fi
  [ ! -e "$AI_STEPFUN_KEY_STORE" ]; ok 'native ACL failure precedes credential bytes'
  export AI_STEPFUN_KEY_STORE="$original"
  if printf 'must-never-land\n' | bash "$SCRIPT" store-key --key-fd 9 9<&0 >/dev/null 2>&1; then exit 1; fi
  cmp "$original" <(printf 'synthetic-stepfun-credential\n'); ok 'native staging file ACL failure preserves existing bytes'
  unset AI_DEVOPS_TEST_ICACLS_FAIL
  export AI_STEPFUN_KEY_STORE="$original"
  helper="$(cygpath -w "$ROOT/bin/windows-private-file.ps1")"
  target="$(cygpath -w "$original")"; parent="$(cygpath -w "$(dirname "$original")")"
  AI_DEVOPS_PRIVATE_HELPER="$helper" AI_DEVOPS_PRIVATE_TARGET="$target" AI_DEVOPS_PRIVATE_PARENT="$parent" env -u PSModulePath powershell.exe -NoProfile -ExecutionPolicy Bypass -Command '. $env:AI_DEVOPS_PRIVATE_HELPER; Assert-AiDevOpsPrivateAcl $env:AI_DEVOPS_PRIVATE_TARGET; Assert-AiDevOpsPrivateAcl $env:AI_DEVOPS_PRIVATE_PARENT' >/dev/null
  ok 'native owner and SYSTEM only file and parent ACL'
  python_dir="$(dirname "$(command -v python)")"
  fallback_path="/usr/bin:/bin:/mingw64/bin:/c/Windows/System32:/c/Windows/System32/WindowsPowerShell/v1.0:$python_dir"
  core_modules="$(cygpath -w '/c/Program Files/PowerShell/7/Modules')"
  parent_modules="${PSModulePath:-}"
  PSModulePath="$core_modules" PATH="$fallback_path" bash "$SCRIPT" store-key --if-missing >/dev/null
  [ "${PSModulePath:-}" = "$parent_modules" ]; ok 'real Windows PowerShell fallback isolates inherited Core modules without changing parent'
  AI_DEVOPS_PRIVATE_TARGET="$target" powershell.exe -NoProfile -Command '& icacls.exe $env:AI_DEVOPS_PRIVATE_TARGET /grant "*S-1-5-32-545:(R)" | Out-Null; exit $LASTEXITCODE'
  if printf 'replacement-must-not-land\n' | bash "$SCRIPT" store-key --if-missing --key-fd 9 9<&0 >/dev/null 2>&1; then exit 1; fi
  cmp "$original" <(printf 'synthetic-stepfun-credential\n'); ok 'native insecure existing file refused without replacement'
  if PSModulePath="$core_modules" PATH="$fallback_path" bash "$SCRIPT" store-key --if-missing >/dev/null 2>&1; then exit 1; fi
  ok 'Windows PowerShell fallback still refuses broad native ACL'
  if printf 'replacement-must-not-land\n' | env -u SYSTEMROOT -u SystemRoot bash "$SCRIPT" store-key --if-missing --key-fd 9 9<&0 >/dev/null 2>&1; then exit 1; fi
  cmp "$original" <(printf 'synthetic-stepfun-credential\n'); ok 'native ACL refusal survives absent optional Windows environment'
else
  [ "$(stat -c %a "$original")" = 600 ]; [ "$(stat -c %a "$(dirname "$original")")" = 700 ]; ok 'POSIX owner-only file and parent'
  chmod 755 "$(dirname "$original")"
  if printf 'synthetic\n' | bash "$SCRIPT" store-key --if-missing --key-fd 9 9<&0 >/dev/null 2>&1; then exit 1; fi
  ok 'insecure existing parent refused'
fi
printf 'StepFun protected store: %s passed\n' "$pass"
