#!/usr/bin/env bash
# Offline incremental inspection and cross-platform owned-supervisor proof.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON="$(command -v python3 || command -v python)"
"$PYTHON" "$ROOT/tests/test_reviewer_credit_stream.py"
TASK_TMP="$(mktemp -d)"; trap 'rm -rf "$TASK_TMP"' EXIT
source "$ROOT/tools/reviewer_event_guard.sh"
# The helper must provide native executable/log paths even when a caller has
# disabled Git Bash's automatic argument conversion for a protected boundary.
printf 'stream-input' | MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' \
  reviewer_credit_run muse "$TASK_TMP/out" "$TASK_TMP/err" -- "$PYTHON" \
    -c 'import sys;print(sys.stdin.read())' > "$TASK_TMP/out" 2> "$TASK_TMP/err"
[ "$(cat "$TASK_TMP/out")" = stream-input ]
printf 'native-path helper with argument conversion disabled: PASS\n'
