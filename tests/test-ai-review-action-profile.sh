#!/usr/bin/env bash
# #1531: offline prospective native profile, scope and recovery admission proofs.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PYTHONDONTWRITEBYTECODE=1
exec python3 "$ROOT/tests/test-ai-review-action-profile.py"
