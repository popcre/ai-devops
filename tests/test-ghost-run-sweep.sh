#!/usr/bin/env bash
# Ghost-run sweeper unit tests (popcre/ai-devops#2367; ported from
# popcre/shared-db#6215/#6216). Offline only — no network.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
node --test "$ROOT/tests/test-ghost-run-sweep.mjs"
