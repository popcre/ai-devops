#!/usr/bin/env bash
# Runs the candidate reviewer route suite (#2549/#2550,
# plan_deepseek-harness-openrouter.md section 10): registry, secret scope,
# plan fallback and stop rules, attribution, second-opinion resume and the
# atomic Muse failover.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PYTHONDONTWRITEBYTECODE=1
py="$(command -v python3 2>/dev/null || command -v python 2>/dev/null || true)"
[ -n "$py" ] && "$py" -c 'import sys; raise SystemExit(sys.version_info.major != 3)' || {
  printf '%s\n' 'Python 3 is required to run the reviewer route tests.' >&2; exit 2; }
"$py" -W error::ResourceWarning "$ROOT/tests/test_reviewer_routes.py"
