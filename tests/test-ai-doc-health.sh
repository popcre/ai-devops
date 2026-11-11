#!/usr/bin/env bash
# Runs the ai-doc-health unit tests inside the standard suite runner.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PY="$(command -v python3 || command -v python)"
exec "$PY" "$REPO_ROOT/tests/test-ai-doc-health.py"
