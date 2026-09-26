#!/usr/bin/env bash
# bin/setup-desktop-apps.sh: Claude Desktop membership, Codex TOML merge, defer while running.
set -u
PY3="$(command -v python3 || command -v python)"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib-test-harness.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/cfg/state" "$T/Claude" "$T/codex"
export AI_DEVOPS_CONFIG="$T/cfg" CLAUDE_DESKTOP_CONFIG="$T/Claude/claude_desktop_config.json" CODEX_CONFIG="$T/codex/config.toml"
# Model the minimal Linux desktop PATH, but keep the same interpreter and git
# this suite resolved: the Windows lanes run under Git Bash, where /usr/bin
# carries neither python nor git, and the script under test must not see a
# different python than the assertions do.
export PATH="/usr/bin:/bin:$(dirname "$PY3"):$(dirname "$(command -v git)")"

echo '{"preferences":{"keep":true},"mcpServers":{"railway":{"command":"x"},"recall-ai":{"command":"x"},"mine":{"command":"y"}}}' > "$CLAUDE_DESKTOP_CONFIG"
cat > "$CODEX_CONFIG" <<'EOF'
[desktop]
followUpQueueMode = "steer"

[mcp_servers.node_repl]
command = "/usr/lib/chatgpt/node_repl"

[mcp_servers.playwright]
command = "old"

[mcp_servers.playwright.env]
X = "1"

[mcp_servers.playwright.tools.browser_click]
approval_mode = "approve"

[mcp_servers.recall-ai]
command = "old"

[mcp_servers.trigger]
command = "old"
EOF
cat > "$T/cfg/state/mcp-catalog.json" <<'EOF'
{"1password":{"command":"/l/mcp-launch.sh","args":["npx","-y","@u2giants/1password-mcp"]},
 "playwright":{"command":"npx","args":["-y","@playwright/mcp"]},
 "railway":{"command":"npx","args":["-y","mcp-remote","https://mcp.railway.com"]},
 "trigger":{"command":"/l/mcp-launch.sh","args":["npx","-y","trigger.dev","mcp"]},
 "codex-cli":{"command":"/usr/bin/codex","args":["mcp-server"],"env":{"MCP_TOOL_TIMEOUT":"1"}}}
EOF

CLAUDE_DESKTOP_STATE=running "$ROOT/bin/setup-desktop-apps.sh" --claude-only >/dev/null
sleep 0.2; pkill -f -- "--claude-only --wait-for-desktop-exit" 2>/dev/null
grep -q '"railway"' "$CLAUDE_DESKTOP_CONFIG" && ok "running Claude Desktop: config untouched" || bad "wrote while Claude Desktop ran"

CLAUDE_DESKTOP_STATE=stopped "$ROOT/bin/setup-desktop-apps.sh" >/dev/null || bad "script failed"
"$PY3" - "$CLAUDE_DESKTOP_CONFIG" <<'PY' && ok "Claude Desktop membership applied, prefs and unmanaged kept" || bad "Claude Desktop config wrong"
import json, sys
c = json.load(open(sys.argv[1]))
assert sorted(c["mcpServers"]) == ["1password", "mine", "playwright"], c["mcpServers"]  # scoped + retired gone
assert c["preferences"] == {"keep": True}
PY
"$PY3" - "$CODEX_CONFIG" <<'PY' && ok "Codex merge: replaced, env dropped, scoped/retired removed, app entries kept" || bad "Codex config wrong"
import tomllib, sys
d = tomllib.load(open(sys.argv[1], "rb"))
m = d["mcp_servers"]
assert d["desktop"]["followUpQueueMode"] == "steer"
assert m["node_repl"]["command"] == "/usr/lib/chatgpt/node_repl"
assert m["playwright"] == {"command": "npx", "args": ["-y", "@playwright/mcp"],
                           "tools": {"browser_click": {"approval_mode": "approve"}}}, m["playwright"]
assert m["codex-cli"]["enabled"] is False and "env" not in m["codex-cli"]
assert set(m) == {"node_repl", "playwright", "1password", "codex-cli"}, set(m)  # scoped + retired gone
PY
before="$(cat "$CODEX_CONFIG")"
"$ROOT/bin/setup-desktop-apps.sh" --codex-only >/dev/null
[ "$before" = "$(cat "$CODEX_CONFIG")" ] && ok "Codex rerun is idempotent" || bad "Codex rerun changed the file"

"$PY3" "$ROOT/bin/mcp_policy.py" policy | "$PY3" -c '
import json, sys
p = json.load(sys.stdin)
assert "recall-ai" in p["retired"] and "recall-ai" not in p["scoped"] + p["desktop"]
assert p["scope"]["oracle"] == ["trigger", "vercel"] and "railway" in p["scope"]["popdam3"]
assert {"ag-grid", "devops-mcp", "synology-monitor"} <= set(p["scoped"])
' && ok "policy parsed from setup-machine.ps1" || bad "policy parse wrong"

clones="$T/clones"; mkdir -p "$clones/theoracle"
git -C "$clones/theoracle" init -q && git -C "$clones/theoracle" remote add origin https://github.com/u2giants/theoracle.git
mv "$clones/theoracle" "$clones/oracle"
# The project key must be the path form the native python sees: Git Bash
# embeds MSYS paths verbatim in file content, while the policy resolves
# Windows paths, and the two never match.
oracle_key="$clones/oracle"
command -v cygpath >/dev/null 2>&1 && oracle_key="$(cygpath -m "$oracle_key")"
echo '{"mcpServers":{},"projects":{"'"$oracle_key"'":{"mcpServers":{"recall-ai":{"command":"x"},"mine":{"command":"y"}}}}}' > "$T/claude.json"
AI_REPO_CLONE_ROOTS="$clones" "$PY3" "$ROOT/bin/mcp_policy.py" deliver --catalog "$T/cfg/state/mcp-catalog.json" --claude-json "$T/claude.json" >/dev/null
"$PY3" - "$T/claude.json" "$oracle_key" <<'PY' && ok "oracle clone gets trigger; retired pruned; foreign kept" || bad "project delivery wrong"
import json, os, sys, tomllib
# Temp paths on the Windows runners can appear long, short, slashed or
# backslashed depending on who produced them; normalize both sides.
want = os.path.normcase(os.path.normpath(sys.argv[2]))
e = next(v["mcpServers"] for k, v in json.load(open(sys.argv[1]))["projects"].items()
         if os.path.normcase(os.path.normpath(k)) == want)
assert sorted(e) == ["mine", "trigger"], e
t = tomllib.load(open(sys.argv[2] + "/.codex/config.toml", "rb"))
assert list(t["mcp_servers"]) == ["trigger"], t
PY
grep -qx '/.codex/config.toml' "$clones/oracle/.git/info/exclude" && ok "project Codex config is git-excluded" || bad "project Codex config not excluded"

rm "$T/cfg/state/mcp-catalog.json"
"$ROOT/bin/setup-desktop-apps.sh" | grep -q "run bin/setup-secrets.sh first" && ok "missing catalog is a no-op" || bad "missing catalog not reported"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
