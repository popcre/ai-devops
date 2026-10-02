#!/usr/bin/env bash
# Live canary proof — never touches real host credential files.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"
OUT="tests/verification/stepfun-windows-folder-shell/README.md"
TMP="$(mktemp -d)"
mkdir -p "$TMP/folder" "$TMP/host" "$TMP/stubs"
echo CANARY_SECRET_DO_NOT_LEAK > "$TMP/host/id_rsa"
echo readme > "$TMP/folder/r.md"
printf '#!/bin/sh\nexit 0\n' > "$TMP/stubs/cat"
printf '#!/bin/sh\nexit 0\n' > "$TMP/stubs/npm"
chmod +x "$TMP/stubs/cat" "$TMP/stubs/npm"
GATE=bin/ai-stepfun-windows-shell

{
  echo "# Windows StepFun canary proof"
  echo
  echo "- Host: $(hostname)"
  echo "- When: $(date '+%Y-%m-%d %H:%M %Z')"
  echo "- Gate: \`$GATE\`"
  echo "- Mode: offline canary (no live StepFun turn yet; no real host secrets read)"
  echo
  echo "## Refusals (must refuse)"
  echo
  try_refuse(){
    local label="$1"; shift
    if AI_STEPFUN_REVIEW_DIR="$TMP/folder" GATE_PATH="$TMP/stubs:/usr/bin:/bin" bash "$GATE" "$@" >/dev/null 2>&1; then
      echo "- FAIL \`$label\` was ALLOWED"
    else
      echo "- ok \`$label\` refused (exit $?)"
    fi
  }
  try_allow(){
    local label="$1"; shift
    if AI_STEPFUN_REVIEW_DIR="$TMP/folder" GATE_PATH="$TMP/stubs:/usr/bin:/bin" bash "$GATE" "$@" >/dev/null 2>&1; then
      echo "- ok \`$label\` allowed"
    else
      echo "- FAIL \`$label\` refused unexpectedly (exit $?)"
    fi
  }
  try_refuse 'cat host canary' cat "$TMP/host/id_rsa"
  try_refuse 'cat parent escape' cat ../host/id_rsa
  try_refuse 'python -c' python -c print
  try_refuse 'npx' npx --yes evil
  try_refuse 'git push' git push
  try_refuse 'bash -c' bash -c 'cat /etc/passwd'
  try_refuse 'npm publish' npm publish
  try_refuse 'absolute interpreter' /c/Windows/System32/cmd.exe /c type x
  echo
  echo "## Allows (folder + tests)"
  echo
  try_allow 'cat in folder' cat r.md
  try_allow 'npm test' npm test
  try_allow 'npm run test:unit' npm run test:unit
  echo
  echo "## Residual (owner-accepted 2026-09-30)"
  echo
  echo "In-folder script bodies executed by allowlisted runners are arbitrary"
  echo "user-level code. Network/registry is shared. Not mount-isolated."
  echo
  echo "No real host credential file was opened by this proof."
} > "$OUT"

rm -rf "$TMP"
cat "$OUT"
