#!/usr/bin/env bash
# Guard: every workflow concurrency group carries the shared LANE_EPOCH suffix
# (popcre/ai-devops#2367; escape runbook docs/ghost-run-escape.md). Offline.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
node --test "$ROOT/tests/test-concurrency-epoch.mjs"
