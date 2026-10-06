#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 "$ROOT/tests/test_review_credit_watch.py"

# Exercise the real dependency's public CLI with only isolated test state.
# A missing pause API must fail this suite rather than silently qualify a watch
# which cannot preserve admission holds on the installed platform.
state="$(mktemp -d)"
trap 'rm -rf -- "$state"' EXIT
export AI_REVIEW_QUARANTINE_DIR="$state"
"$ROOT/bin/ai-review-preflight" quarantine gemini credential-error --seconds 86400 >/dev/null
before="$(python3 "$ROOT/tools/reviewer_admission.py" global gemini --directory "$state")"
"$ROOT/bin/ai-review-preflight" pause gemini out-of-credit --seconds 3600 >/dev/null
after="$(python3 "$ROOT/tools/reviewer_admission.py" global gemini --directory "$state")"
[[ "$before" == "$after" ]]
if "$ROOT/bin/ai-review-preflight" pause gemini out-of-credit --seconds malformed >/dev/null 2>&1; then
  printf 'FAIL: malformed real pause duration was accepted\n' >&2
  exit 1
fi
[[ "$after" == "$(python3 "$ROOT/tools/reviewer_admission.py" global gemini --directory "$state")" ]]
printf 'PASS: real pause CLI preserves stronger hold and refuses malformed input\n'
