#!/usr/bin/env bash
# Runs the Python suites for bin/ai-review-simple (#2041): review mode and merge rule.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PYTHONDONTWRITEBYTECODE=1
py="$(command -v python3 2>/dev/null || command -v python 2>/dev/null || true)"
[ -n "$py" ] && "$py" -c 'import sys; raise SystemExit(sys.version_info.major != 3)' || {
  printf '%s\n' 'Python 3 is required to run the ai-review-simple tests.' >&2; exit 2; }
"$py" -W error::ResourceWarning "$ROOT/tests/test_ai_review_simple.py"
"$py" -W error::ResourceWarning "$ROOT/tests/test_ai_review_rule.py"
"$py" -W error::ResourceWarning "$ROOT/tests/test_ai_second_opinion.py"
