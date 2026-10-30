#!/usr/bin/env bash
# Failure recording/maintenance remains used by preflight after Stage F.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib-reviewer-events-isolation.sh"
export PYTHONDONTWRITEBYTECODE=1
py="$(command -v python3 || command -v python)"
"$py" "$ROOT/tests/reviewer_maintenance_cases.py"
