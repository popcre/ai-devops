#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT/bin/setup-secrets.sh"

failures=0
ok() { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1"; failures=$((failures + 1)); }
skip() { printf 'skip - %s\n' "$1"; }

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

# Test the snippet the installer actually renders, with only synthetic values.
# A login shell is noninteractive and must not fetch credentials for Codex.
if [ -n "$PYTHON" ]; then
  shellrc_tmp="$(mktemp -d)"
  mkdir -p "$shellrc_tmp/bin"
  TOKEN_FILE="$shellrc_tmp/token"
  MCP_ENV="$shellrc_tmp/mcp.env"
  printf 'synthetic-token\n' > "$TOKEN_FILE"
  printf 'SYNTHETIC_KEY=op://test/fake/key\n' > "$MCP_ENV"
  "$PYTHON" - "$SOURCE" <<'PY' > "$shellrc_tmp/render-source.sh"
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
start = source.index("read -r -d '' SHELLRC_BODY <<EOF\n")
end = source.index("\nEOF\n", start) + len("\nEOF")
print(source[start:end])
PY
  . "$shellrc_tmp/render-source.sh" || true
  printf '%s\n' "$SHELLRC_BODY" > "$shellrc_tmp/shellrc"
  cat > "$shellrc_tmp/bin/op" <<'SH'
#!/usr/bin/env bash
[ -z "${OP_MARKER:-}" ] || printf called > "$OP_MARKER"
while [ "$#" -gt 0 ]; do
  [ "$1" != -- ] || { shift; break; }
  shift
done
SYNTHETIC_KEY=synthetic-value "$@"
SH
  chmod 700 "$shellrc_tmp/bin/op"
  if /usr/bin/env -i PATH="$shellrc_tmp/bin:/usr/bin:/bin" HOME="$shellrc_tmp" \
      bash --noprofile --norc -c '. "$1"; [ -z "${OP_SERVICE_ACCOUNT_TOKEN+x}" ] && [ -z "${SYNTHETIC_KEY+x}" ]' _ "$shellrc_tmp/shellrc"; then
    ok "noninteractive shell does not resolve credentials"
  else
    bad "noninteractive shell does not resolve credentials"
  fi
  if /usr/bin/env -i PATH="$shellrc_tmp/bin:/usr/bin:/bin" HOME="$shellrc_tmp" \
      AI_DEVOPS_RESOLVE_SHELL_SECRETS=1 bash --noprofile --norc -c '. "$1"; [ "$OP_SERVICE_ACCOUNT_TOKEN" = synthetic-token ] && [ "$SYNTHETIC_KEY" = synthetic-value ] && [ -z "${AI_DEVOPS_RESOLVE_SHELL_SECRETS+x}" ]' _ "$shellrc_tmp/shellrc"; then
    ok "explicit noninteractive opt-in still resolves credentials"
  else
    bad "explicit noninteractive opt-in still resolves credentials"
  fi
  if /usr/bin/env -i PATH="$shellrc_tmp/bin:/usr/bin:/bin" HOME="$shellrc_tmp" \
      bash --noprofile --norc -ic '. "$1"; [ "$OP_SERVICE_ACCOUNT_TOKEN" = synthetic-token ] && [ "$SYNTHETIC_KEY" = synthetic-value ]' _ "$shellrc_tmp/shellrc" 2>/dev/null; then
    ok "interactive shell still resolves credentials"
  else
    bad "interactive shell still resolves credentials"
  fi
  if /usr/bin/env -i PATH="$shellrc_tmp/bin:/usr/bin:/bin" HOME="$shellrc_tmp" \
      OP_MARKER="$shellrc_tmp/direct-op" bash "$shellrc_tmp/shellrc" >/dev/null 2>&1 &&
      [ ! -e "$shellrc_tmp/direct-op" ]; then
    ok "direct noninteractive execution exits without resolving credentials"
  else
    bad "direct noninteractive execution exits without resolving credentials"
  fi
  rm -rf -- "$shellrc_tmp"
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

# Run the installer's actual probe-repository setup. An empty commit has no
# classifiable paths and the protected review sandbox must refuse it.
GLM_REPO_SETUP=""
if [ -n "$PYTHON" ]; then
  GLM_REPO_SETUP="$("$PYTHON" - "$SOURCE" <<'PY'
import pathlib
import sys

text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
start = text.index('    glm_probe="$(mktemp -d)"')
end = text.index('    glm_result=""', start)
print(text[start:end])
PY
)"
fi
if [ -n "$GLM_REPO_SETUP" ] &&
   GLM_REPO_SETUP="$GLM_REPO_SETUP" SANDBOX="$ROOT/bin/ai-review-sandbox" bash -c '
     set -e
     eval "$GLM_REPO_SETUP"
     trap '\''rm -rf "$glm_probe"'\'' EXIT
     test "$(git -C "$glm_probe" ls-files)" = README.md
     "$SANDBOX" assert-public "$glm_probe" >/dev/null
     before="$("$SANDBOX" digest "$glm_probe")"
     mkdir -p "$glm_probe/.ai/reviews" && printf report > "$glm_probe/.ai/reviews/glm-probe.md"
     test "$("$SANDBOX" digest "$glm_probe")" = "$before"
   '; then
  ok "GLM installer creates a classifiable public probe repository"
else
  bad "GLM installer creates a classifiable public probe repository"
fi

# A symlinked invocation (e.g. /usr/local/bin/setup-secrets.sh) must resolve
# REPO_ROOT to the real checkout, not the symlink's directory.
link_tmp="$(mktemp -d)"
mkdir -p "$link_tmp/repo/bin" "$link_tmp/usr/bin" "$link_tmp/rel"
{
  sed -n '/^_self="\${BASH_SOURCE\[0\]}"$/,/^unset _self _dir$/p' "$SOURCE"
  printf 'printf %%s "$REPO_ROOT"\n'
} > "$link_tmp/repo/bin/probe.sh"
ln -s "$link_tmp/repo/bin/probe.sh" "$link_tmp/usr/bin/probe.sh" 2>/dev/null
ln -s "../usr/bin/probe.sh" "$link_tmp/rel/chained.sh" 2>/dev/null
if [ -L "$link_tmp/usr/bin/probe.sh" ] && [ -L "$link_tmp/rel/chained.sh" ]; then
  want="$(cd "$link_tmp/repo" && pwd -P)"
  direct="$(bash "$link_tmp/usr/bin/probe.sh")"
  chained="$(bash "$link_tmp/rel/chained.sh")"
  if grep -q '^REPO_ROOT=' "$link_tmp/repo/bin/probe.sh" &&
     [ "$direct" = "$want" ] && [ "$chained" = "$want" ]; then
    ok "setup-secrets resolves REPO_ROOT through symlinks"
  else
    bad "setup-secrets resolves REPO_ROOT through symlinks (got '$direct' / '$chained', want '$want')"
  fi
else
  skip "setup-secrets resolves REPO_ROOT through symlinks (this filesystem cannot create real symlinks)"
fi
rm -rf "$link_tmp"

[ "$failures" -eq 0 ]
