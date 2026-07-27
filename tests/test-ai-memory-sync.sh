#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/bin/ai-memory-sync"

fail() { echo "FAIL: $*" >&2; exit 1; }

grep -Fq 'git clone -q -c core.longpaths=true' "$SCRIPT" ||
  fail "new clones do not enable long paths before checkout"

grep -Fq 'git -C "$HUB" config core.longpaths true' "$SCRIPT" ||
  fail "existing clones do not enable long paths before reset"

grep -Fq 'reset -q --hard origin/main || { log "reset failed;' "$SCRIPT" ||
  fail "initial reset failure is not fatal"

grep -Fq 'reset -q --hard origin/main || { log "final reset failed;' "$SCRIPT" ||
  fail "final reset failure is not fatal"

bash -n "$SCRIPT" || fail "ai-memory-sync has invalid Bash syntax"

echo "PASS: ai-memory-sync long-path and reset-failure guards"
