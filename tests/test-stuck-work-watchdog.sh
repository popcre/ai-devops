#!/usr/bin/env bash
# Stuck-work watchdog unit tests (popcre/ai-devops#1011).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
node --test "$ROOT/tests/test-stuck-work-watchdog.mjs"
