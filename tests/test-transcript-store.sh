#!/usr/bin/env bash
# Transcript store, plan steps 2-4 (popcre/ai-devops#2050, #2060).
# Synthetic fixtures only; never point these at real transcripts.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PYTHONDONTWRITEBYTECODE=1
for t in test_transcript_normalize.py test_transcript_segment.py test_transcript_build.py; do
  python3 "$ROOT/tests/$t"
done
empty="$(mktemp -d)"
trap 'rm -rf -- "$empty"' EXIT
out="$(AI_DROPBOX_ROOT="$empty" bash "$ROOT/bin/ai-transcript-envcheck" --role reader || true)"
printf '%s\n' "$out" | grep -q '^PASS python>=3.10' || { printf 'FAIL: envcheck did not report python\n%s\n' "$out" >&2; exit 1; }
printf '%s\n' "$out" | grep -q '^RESULT PASS' || { printf 'FAIL: reader envcheck should pass with an empty Dropbox folder\n%s\n' "$out" >&2; exit 1; }
printf 'PASS: transcript store\n'
