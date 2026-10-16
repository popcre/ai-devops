#!/usr/bin/env bash
# #1531: offline prospective native profile, scope and recovery admission proofs.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PYTHONDONTWRITEBYTECODE=1
python3 "$ROOT/tests/test-ai-review-action-profile.py"
# Same existing CI suite also qualifies the disjoint public-only gate.
python3 -m unittest discover -s "$ROOT/tests" -p test_generated_definition_action.py
