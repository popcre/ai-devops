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

if ! grep -q 'GLM_AGENT_OK' "$SOURCE" &&
   grep -q -- '--json --prompt' "$SOURCE" &&
   grep -q 'session.type == "review"' "$SOURCE" &&
   grep -q 'session.model == "zai-coding-plan/glm-5.3"' "$SOURCE" &&
   grep -q 'APPROVE|REJECT' "$SOURCE" &&
   grep -q '\[ -s "$glm_report" \]' "$SOURCE"; then
  ok "GLM capability probe verifies the protected review envelope and report"
else
  bad "GLM capability probe verifies the protected review envelope and report"
fi

GLM_FILTER=""
if [ -n "$PYTHON" ]; then
  GLM_FILTER="$("$PYTHON" - "$SOURCE" <<'PY'
import pathlib
import sys

text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
anchor = text.index('glm_report="$(printf')
start = text.index("jq -er '\n", anchor) + len("jq -er '\n")
end = text.index("\n       ' 2>/dev/null)", start)
print(text[start:end])
PY
)"
fi

probe_fixture() {
  local text="$1" model="${2:-zai-coding-plan/glm-5.3}"
  jq -n --arg text "$text" --arg model "$model" \
    '{schema_version:1,ok:true,session:{type:"review",model:$model},response:{text:$text},artifacts:{report:"/tmp/report.md"}}' |
    jq -e "$GLM_FILTER" >/dev/null 2>&1
}

if [ -n "$GLM_FILTER" ] && command -v jq >/dev/null 2>&1 &&
   probe_fixture $'Reviewed.\n\n## Verdict\n\n**APPROVE**\n' &&
   probe_fixture $'Finding.\n\n## Verdict\nREJECT - repair required\n' &&
   ! probe_fixture '' &&
   ! probe_fixture $'Reviewed without a terminal verdict.' &&
   ! probe_fixture $'## Verdict\nBLOCKED\n' &&
   ! probe_fixture $'## Verdict\nAPPROVE\n\ntrailing nonterminal text\n' &&
   ! probe_fixture $'## Verdict\nAPPROVE\n' 'zai-coding-plan/wrong-model'; then
  ok "GLM capability probe accepts only a terminal protected verdict from the exact model"
else
  bad "GLM capability probe accepts only a terminal protected verdict from the exact model"
fi

[ "$failures" -eq 0 ]
