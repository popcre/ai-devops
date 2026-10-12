#!/usr/bin/env bash
# find_passing_report must skip a candidate when cygpath is missing or hangs.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON="$(command -v python3 || command -v python)"
"$PYTHON" "$ROOT/tests/test_reviewer_events_cygpath.py"
