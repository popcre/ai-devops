#!/usr/bin/env bash
# Regression test for project-scoped MCP servers in bin/setup-secrets.sh.
#
# Why this exists: the first draft pruned EVERY project-scoped name from the
# global config, including names whose project is not cloned on this machine.
# That silently removed a working capability with nowhere to put it. Case A
# below is that bug.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Git Bash on Windows often has `python` but no working `python3`; the Ubuntu
# runner has the reverse. Use whichever actually imports json, so this test runs
# on BOTH CI legs instead of silently skipping everywhere. A test that always
# skips proves nothing.
PY_BIN=""
for c in python3 python py; do
  if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import json' >/dev/null 2>&1; then
    PY_BIN="$c"; break
  fi
done
if [ -z "$PY_BIN" ]; then
  printf 'FAIL: no usable python interpreter (tried python3, python, py)\n' >&2
  exit 1
fi

"$PY_BIN" - "$ROOT/bin/setup-secrets.sh" <<'PY'
import re, io, json, os, sys, tempfile

src = io.open(sys.argv[1], encoding="utf-8").read()
m = re.search(r"python3 - .*?<<'PY'\n(.*?)\nPY\n", src, re.S)
if not m:
    print("FAIL: could not find the MCP-wiring python block in setup-secrets.sh")
    sys.exit(1)
block = m.group(1)

fails = []
def check(cond, msg):
    print(("  ok   " if cond else "  FAIL ") + msg)
    if not cond:
        fails.append(msg)

def run(clone_synology):
    tmp = tempfile.mkdtemp()
    cfgp = os.path.join(tmp, "claude.json")
    json.dump({"mcpServers": {"railway": {"command": "STALE"},
                              "trigger": {"command": "STALE"}},
               "otherKey": "must-survive"}, open(cfgp, "w"))
    repos = os.path.join(tmp, "repos")
    os.makedirs(os.path.join(repos, "oracle"))
    if clone_synology:
        os.makedirs(os.path.join(repos, "synology-monitor"))
    b = block.replace('os.path.expanduser("~/repos")', repr(repos))
    sys.argv = ["x", cfgp, "/launch.sh", "/remote.sh", "REF", "/usr/bin/codex"]
    os.environ["AI_DEVOPS_OWNED_OUT"] = os.path.join(tmp, "owned")
    import contextlib, io as _io
    with contextlib.redirect_stdout(_io.StringIO()):
        exec(compile(b, "embedded", "exec"), {"__name__": "__main__"})
    return json.load(open(cfgp)), repos

print("case A: a project that is NOT cloned keeps its servers global")
out, repos = run(False)
g = out["mcpServers"]
check("devops-mcp" in g and "synology-monitor" in g,
      "uncloned synology-monitor -> its servers stay global (no capability loss)")
check("railway" in g, "uncloned popdam3 -> railway stays global")
check("trigger" not in g and "recall-ai" not in g,
      "cloned oracle -> its servers pruned from global")
check(json.load(open(os.path.join(repos, "oracle", ".mcp.json")))["mcpServers"].keys() >= {"trigger", "recall-ai"},
      "oracle/.mcp.json seeded with trigger + recall-ai")
check(out.get("otherKey") == "must-survive", "unrelated config keys preserved")

print("case B: a project that IS cloned takes ownership")
out, repos = run(True)
g = out["mcpServers"]
check("devops-mcp" not in g and "synology-monitor" not in g,
      "cloned synology-monitor -> its servers pruned from global")
sm = json.load(open(os.path.join(repos, "synology-monitor", ".mcp.json")))["mcpServers"]
check(set(sm) == {"devops-mcp", "synology-monitor"},
      "synology-monitor/.mcp.json seeded with exactly its two servers")

print("case C: an entry the repo already owns is never overwritten")
tmp = tempfile.mkdtemp()
cfgp = os.path.join(tmp, "claude.json"); json.dump({"mcpServers": {}}, open(cfgp, "w"))
repos = os.path.join(tmp, "repos"); os.makedirs(os.path.join(repos, "oracle"))
# a hand-made portable (Linux) definition already committed by the project
json.dump({"mcpServers": {"trigger": {"command": "HAND-MADE-PORTABLE"}}},
          open(os.path.join(repos, "oracle", ".mcp.json"), "w"))
b = block.replace('os.path.expanduser("~/repos")', repr(repos))
sys.argv = ["x", cfgp, "/launch.sh", "/remote.sh", "REF", "/usr/bin/codex"]
os.environ["AI_DEVOPS_OWNED_OUT"] = os.path.join(tmp, "owned")
import contextlib, io as _io
with contextlib.redirect_stdout(_io.StringIO()):
    exec(compile(b, "embedded", "exec"), {"__name__": "__main__"})
kept = json.load(open(os.path.join(repos, "oracle", ".mcp.json")))["mcpServers"]["trigger"]
check(kept.get("command") == "HAND-MADE-PORTABLE",
      "a committed entry is left untouched (would clobber a Linux-portable file)")
check("trigger" not in json.load(open(cfgp))["mcpServers"],
      "an already-committed project server is still pruned from global")

if fails:
    print("\n%d failed" % len(fails))
    sys.exit(1)
print("\nall passed")
PY
