#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
is_python3() { "$1" -c 'import sys; raise SystemExit(0 if sys.version_info.major == 3 else 1)' >/dev/null 2>&1; }
if command -v cygpath >/dev/null 2>&1; then
  for candidate in python python3; do
    candidate_path="$(command -v "$candidate" 2>/dev/null || true)"
    if [ -n "$candidate_path" ] && is_python3 "$candidate_path"; then
      exec "$candidate_path" "$ROOT/tests/test-ai-shared-db-closeout-check.py"
    fi
  done
else
  candidate_path="$(command -v python3 2>/dev/null || true)"
  if [ -n "$candidate_path" ] && is_python3 "$candidate_path"; then
    exec "$candidate_path" "$ROOT/tests/test-ai-shared-db-closeout-check.py"
  fi
fi
printf '%s\n' 'Python 3 is required to run the shared-db closeout checker tests.' >&2
exit 2
