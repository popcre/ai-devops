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
python "$ROOT/tools/check-markdown-links.py" "$ROOT"
