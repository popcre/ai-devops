#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 "$ROOT/tools/context-audit/audit-repository-routing.py" --coverage "$ROOT/config/repository-coverage.json" --baseline "$ROOT/tests/verification/task-gates/routing-baseline.json"
echo "PASS: canonical repository coverage has one metadata-only row for each of the 17 rollout targets"
