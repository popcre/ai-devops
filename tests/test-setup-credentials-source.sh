#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT/bin/setup-secrets.sh"

failures=0
ok() { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1"; failures=$((failures + 1)); }

PYTHON=""
for candidate in python3 python; do
  if "$candidate" -c 'import pathlib' >/dev/null 2>&1; then
    PYTHON="$candidate"
    break
  fi
done

if bash -n "$SOURCE"; then
  ok "setup-secrets shell syntax is valid"
else
  bad "setup-secrets shell syntax is valid"
fi

# Bash does not parse Python heredoc bodies. Compile every embedded Python
# block independently so a split string or similar defect cannot pass bash -n.
if [ -n "$PYTHON" ] && "$PYTHON" - "$SOURCE" <<'PY'
import pathlib
import re
import sys

lines = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()
blocks = []
i = 0
while i < len(lines):
    match = re.search(r"<<'(?P<marker>PY\d*)'", lines[i])
    if not match:
        i += 1
        continue
    marker = match.group("marker")
    start = i + 1
    i = start
    while i < len(lines) and lines[i] != marker:
        i += 1
    if i == len(lines):
        raise SystemExit(f"unterminated Python heredoc starting at line {start}")
    source = "\n".join(lines[start:i]) + "\n"
    compile(source, f"setup-secrets.sh:{start}", "exec")
    blocks.append(start)
    i += 1

if len(blocks) < 3:
    raise SystemExit(f"expected at least 3 Python heredocs, found {len(blocks)}")
print(f"compiled {len(blocks)} embedded Python blocks")
PY
then
  ok "all embedded Python blocks compile"
else
  bad "all embedded Python blocks compile"
fi

[ "$failures" -eq 0 ]
