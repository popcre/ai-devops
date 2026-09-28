#!/usr/bin/env bash
# move-bulk-to-d.ps1 -DryRun: exits 0, announces DRYRUN, executes no moves.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/ai-housekeeping/move-bulk-to-d.ps1"

PWSH="$(command -v pwsh || true)"
if [[ -z "$PWSH" ]]; then
  echo "SKIP: pwsh not available on this host"
  exit 0
fi

out="$("$PWSH" -NoProfile -ExecutionPolicy Bypass -File "$SCRIPT" -DryRun 2>&1)"
rc=$?
if [[ $rc -ne 0 ]]; then
  echo "$out"
  echo "FAIL: -DryRun exited $rc"
  exit 1
fi
if ! grep -q "DRYRUN complete" <<<"$out"; then
  echo "$out"
  echo "FAIL: missing DRYRUN completion banner"
  exit 1
fi
if grep -qE "^MOVE " <<<"$out"; then
  echo "$out"
  echo "FAIL: -DryRun executed a move"
  exit 1
fi
echo "OK move-bulk-to-d -DryRun previews without moving"
