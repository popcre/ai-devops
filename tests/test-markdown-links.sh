#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
git init -q -b main "$TMP/repo"; git -C "$TMP/repo" config user.name test; git -C "$TMP/repo" config user.email test@example.invalid
mkdir -p "$TMP/repo/docs"; printf '# Target\n' > "$TMP/repo/docs/target.md"; printf '[ok](docs/target.md)\n' > "$TMP/repo/README.md"
git -C "$TMP/repo" add .; git -C "$TMP/repo" commit -qm safe
python "$ROOT/tools/check-markdown-links.py" "$TMP/repo" >/dev/null || { echo 'FAIL: valid link rejected'; exit 1; }
printf '[bad](docs/missing.md)\n' >> "$TMP/repo/README.md"; git -C "$TMP/repo" add README.md
if python "$ROOT/tools/check-markdown-links.py" "$TMP/repo" >/dev/null 2>&1; then echo 'FAIL: broken link passed'; exit 1; fi
for invalid in "$TMP/repo/README.md" "$TMP/missing" "$TMP"; do
  if python "$ROOT/tools/check-markdown-links.py" "$invalid" >"$TMP/out" 2>"$TMP/err"; then
    echo 'FAIL: invalid repository input passed'; exit 1
  fi
  grep -q '^check-markdown-links:' "$TMP/err"
  if grep -q Traceback "$TMP/err"; then echo 'FAIL: invalid input crashed'; exit 1; fi
done
# A tracked file can disappear or contain invalid UTF-8; both remain failures.
printf '\377' > "$TMP/repo/docs/target.md"
for invalid_file in invalid-utf8 missing; do
  if [ "$invalid_file" = missing ]; then rm "$TMP/repo/docs/target.md"; fi
  if python "$ROOT/tools/check-markdown-links.py" "$TMP/repo" >"$TMP/out" 2>"$TMP/err"; then
    echo 'FAIL: unreadable tracked file passed'; exit 1
  fi
  grep -q 'cannot read tracked Markdown as UTF-8' "$TMP/err"
  if grep -q Traceback "$TMP/err"; then echo 'FAIL: unreadable file crashed'; exit 1; fi
done
# Historical records and evidence captures are not link-checked: root
# plan_*.md / fix_*.md and docs/verification/** carry capture-time paths.
HIST="$TMP/hist"; mkdir -p "$HIST"
git init -q -b main "$HIST"; git -C "$HIST" config user.name test; git -C "$HIST" config user.email test@example.invalid
mkdir -p "$HIST/docs/verification" "$HIST/docs/nested"
printf '# Live\n' > "$HIST/README.md"
printf '# Capture\n\n[stale](throughput-dispositions/scripts~gone.mjs.json)\n' > "$HIST/docs/verification/capture.md"
printf '# Plan\n\nStatus: APPLIED\n\nEdit [scripts/gone.mjs](scripts/gone.mjs) (3,917 lines)\n' > "$HIST/plan_old.md"
printf '# Fix\n\n[stale](bin/gone)\n[escape](../../outside.md)\n' > "$HIST/fix_old.md"
git -C "$HIST" add .; git -C "$HIST" commit -qm records
python "$ROOT/tools/check-markdown-links.py" "$HIST" >/dev/null || { echo 'FAIL: historical/evidence records rejected'; exit 1; }
# Root-level only: a nested plan_*.md is an ordinary doc and stays checked.
printf '[bad](missing.md)\n' > "$HIST/docs/nested/plan_inner.md"
git -C "$HIST" add .; git -C "$HIST" commit -qm nested-plan
if python "$ROOT/tools/check-markdown-links.py" "$HIST" >/dev/null 2>&1; then echo 'FAIL: nested plan_ file skipped'; exit 1; fi
git -C "$HIST" rm -q docs/nested/plan_inner.md; git -C "$HIST" commit -qm drop-nested
# Links inside fenced code blocks or inline code spans are ignored.
printf '# Fences\n\n```json\n{"link": "[stale](docs/gone.md)"}\n```\n\n~~~\n[stale](docs/gone.md)\n~~~\n\nInline `code [stale](docs/gone.md) span` here.\n' > "$HIST/fences.md"
git -C "$HIST" add .; git -C "$HIST" commit -qm fences
python "$ROOT/tools/check-markdown-links.py" "$HIST" >/dev/null || { echo 'FAIL: code-embedded links checked'; exit 1; }
# A genuinely broken link in ordinary live prose still fails.
printf '[bad](docs/gone.md)\n' > "$HIST/live.md"
git -C "$HIST" add .; git -C "$HIST" commit -qm broken
if python "$ROOT/tools/check-markdown-links.py" "$HIST" >"$TMP/out" 2>"$TMP/err"; then echo 'FAIL: broken live link passed'; exit 1; fi
grep -q 'missing local target: docs/gone.md' "$TMP/err"
# So does a live link that escapes the repository.
printf '[esc](../../outside.md)\n' > "$HIST/live.md"
git -C "$HIST" add .; git -C "$HIST" commit -qm escape
if python "$ROOT/tools/check-markdown-links.py" "$HIST" >"$TMP/out" 2>"$TMP/err"; then echo 'FAIL: escaping live link passed'; exit 1; fi
grep -q 'link escapes repository' "$TMP/err"
# A live link whose text is a code span is still checked.
printf '[`docs/gone.md`](docs/gone.md)\n' > "$HIST/live.md"
git -C "$HIST" add .; git -C "$HIST" commit -qm codespan-text
if python "$ROOT/tools/check-markdown-links.py" "$HIST" >"$TMP/out" 2>"$TMP/err"; then echo 'FAIL: code-span-text link unchecked'; exit 1; fi
grep -q 'missing local target: docs/gone.md' "$TMP/err"
python "$ROOT/tools/check-markdown-links.py" "$ROOT"
