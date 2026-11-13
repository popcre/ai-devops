#!/usr/bin/env bash
# Offline suite for bin/ai-gh-signature — the GitHub posting signature
# (app display name + short id, docs/standing-rules-details.md). Fixtures
# only; no live session store is read.
set -u
PASS=0; FAIL=0
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/lib-test-harness.sh"
tool="$here/../bin/ai-gh-signature"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT

py="$(command -v python3 2>/dev/null || command -v python 2>/dev/null || true)"
[ -n "$py" ] || { echo "test-ai-gh-signature: no python interpreter"; exit 1; }
run() { "$py" "$tool" "$@"; }

# One fixture store per app, plus a session env that must not leak in.
export AI_GH_SIG_MIMO_DB="$work/mimo.db"
export AI_GH_SIG_ZCODE_DB="$work/zcode.db"
export AI_GH_SIG_CLAUDE_PROJECTS="$work/claude-projects"
export AI_GH_SIG_CODEX_INDEX="$work/codex-index.jsonl"
unset MIMO_SESSION_ID ZCODE_SESSION_ID CLAUDE_CODE_SESSION_ID \
      CODEX_THREAD_ID CODEX_SESSION_ID 2>/dev/null || true

MIMO_ID="ses_ffe5e2d8d4fcdffeS1R1pHQ7vt"
ZCODE_ID="sess_9ed78740-9d9d-4622-9fbd-09f4b00dd4d7"
CLAUDE_ID="66bd69f2-fdd8-4bf0-9082-9239896851bb"
CODEX_ID="01a011c9-7fb6-7213-a61e-06cee388789d"

"$py" - "$work" <<'PYEOF'
import json, os, sqlite3, sys
work = sys.argv[1]
con = sqlite3.connect(os.path.join(work, "mimo.db"))
con.execute("create table session (id text primary key, title text not null)")
con.execute("insert into session values (?, ?)",
            ("ses_ffe5e2d8d4fcdffeS1R1pHQ7vt", 'Tracing "AI" sessions'))
con.commit(); con.close()
con = sqlite3.connect(os.path.join(work, "zcode.db"))
con.execute("create table tasks (task_id text primary key, title text not null, cli_title text)")
con.execute("insert into tasks values (?, ?, ?)",
            ("sess_9ed78740-9d9d-4622-9fbd-09f4b00dd4d7",
             "shared-db throughput follow-ups", "cli title"))
con.execute("insert into tasks values (?, ?, ?)",
            ("sess_aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
             "shared-db throughput follow-ups " + "x" * 90, ""))
con.commit(); con.close()
root = os.path.join(work, "claude-projects", "proj-a", "66bd69f2-fdd8-4bf0-9082-9239896851bb")
os.makedirs(root)
with open(os.path.join(root, "custom-title.json"), "w", encoding="utf-8") as fh:
    json.dump({"customTitle": "Shared-db throughput #401"}, fh)
with open(os.path.join(work, "codex-index.jsonl"), "w", encoding="utf-8") as fh:
    fh.write(json.dumps({"id": "01a011c9-7fb6-7213-a61e-06cee388789d",
                         "thread_name": "Pull latest ai-devops repo"}) + "\n")
PYEOF

# expect_sig <description> <expected through "on "> <tool args...>
expect_sig() {
  local desc="$1" want="$2" got
  shift 2
  got="$(run "$@" 2>&1)" || { bad "$desc (exit $?)"; return; }
  case "$got" in
    "$want on "*) ok "$desc" ;;
    *) bad "$desc (got: $got)" ;;
  esac
}

expect_sig "mimo resolves the session title" \
  "Posted by MiMo chat \"Tracing 'AI' sessions\" (ses_ffe5e2d8)" \
  --app mimo --id "$MIMO_ID"
expect_sig "mimo short id keeps the ses_ prefix" \
  "Posted by MiMo chat \"Tracing 'AI' sessions\" (ses_ffe5e2d8)" \
  --app mimo --id "$MIMO_ID"
expect_sig "unknown mimo id omits the name" \
  "Posted by MiMo chat (ses_nosuchse)" \
  --app mimo --id "ses_nosuchsession00000000000"
expect_sig "zcode resolves the task title" \
  "Posted by ZCode chat \"shared-db throughput follow-ups\" (sess_9ed78740)" \
  --app zcode --id "$ZCODE_ID"
out="$(run --app zcode --id "sess_aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee")"
check "long titles are capped at 80 characters" 'printf %s "$out" | grep -qE "\"[^\"]{77}\\.\\.\\.\" \\(sess_aaaaaaaa\\)"'
expect_sig "claude resolves the custom title" \
  "Posted by Claude chat \"Shared-db throughput #401\" (66bd69f2)" \
  --app claude --id "$CLAUDE_ID"
expect_sig "claude without a custom title omits the name" \
  "Posted by Claude chat (11111111)" \
  --app claude --id "11111111-2222-3333-4444-555555555555"
expect_sig "codex resolves the thread name" \
  "Posted by Codex chat \"Pull latest ai-devops repo\" (01a011c9)" \
  --app codex --id "$CODEX_ID"
expect_sig "chatgpt alias signs as Codex" \
  "Posted by Codex chat \"Pull latest ai-devops repo\" (01a011c9)" \
  --app "ChatGPT for Windows" --id "$CODEX_ID"

export MIMO_SESSION_ID="$MIMO_ID"
expect_sig "session env supplies the id without --id" \
  "Posted by MiMo chat \"Tracing 'AI' sessions\" (ses_ffe5e2d8)"
unset MIMO_SESSION_ID

out="$(run)"
check "no app and no id falls back to a stub" 'printf %s "$out" | grep -q "^Posted by chat (unknown) on [A-Za-z0-9._-][A-Za-z0-9._-]*$"'
out="$(run --app claude)"
check "an app without an id falls back to unknown" 'printf %s "$out" | grep -q "^Posted by Claude chat (unknown) on "'

"$py" - "$tool" "$work" <<'PYEOF'
import os, re, runpy, shutil, sqlite3, sys
from unittest.mock import patch

tool, work = sys.argv[1:]
module = runpy.run_path(tool)
for sid in ("ab\ncd", "ab cd", "ab)cd", "ab\x00cd", "ab\x7fcd", "ab\u2028cd", ""):
    signature = module["build"]("codex", sid)
    assert re.fullmatch(r"Posted by Codex chat \(unknown\) on [A-Za-z0-9._-]+", signature), repr(signature)

connect = sqlite3.connect
def readonly_connect(*args, **kwargs):
    con = connect(*args, **kwargs)
    try:
        con.execute("create table forbidden_write (id text)")
    except sqlite3.OperationalError as exc:
        assert "readonly" in str(exc), str(exc)
    else:
        con.close()
        raise AssertionError("signature lookup opened a writable database")
    return con

for app, sid, title in (
        ("mimo", "ses_ffe5e2d8d4fcdffeS1R1pHQ7vt", 'Tracing "AI" sessions'),
        ("zcode", "sess_9ed78740-9d9d-4622-9fbd-09f4b00dd4d7", "shared-db throughput follow-ups")):
    for suffix in ("?mode=rw", "#fragment", "%20 space"):
        path = os.path.join(work, app + suffix + ".db")
        shutil.copyfile(os.path.join(work, app + ".db"), path)
        with patch.dict(os.environ, {"AI_GH_SIG_" + app.upper() + "_DB": path}), \
                patch.object(sqlite3, "connect", readonly_connect):
            assert module["lookup_" + app](sid) == title, path
PYEOF
if [ "$?" -eq 0 ]; then ok "unsafe ids and URI paths preserve the signature and read-only contract"; else bad "unsafe ids or URI paths"; fi

if [ "$(uname -s)" = Linux ]; then
  if "$tool" --app codex --id "$CODEX_ID" >/dev/null; then
    ok "signature tool executes directly"
  else
    bad "signature tool executes directly"
  fi
fi

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
