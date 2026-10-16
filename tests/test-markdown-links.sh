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
python "$ROOT/tools/check-markdown-links.py" "$ROOT"
