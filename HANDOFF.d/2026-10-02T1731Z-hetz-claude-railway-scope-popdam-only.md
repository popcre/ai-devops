# Railway: CLI on hetz done; desktop-app Railway MCP must be popdam-only

Written 1:31 PM EDT, 2026-10-02, by Claude on hetz (session via Claude desktop app on 4837).

## 1. Goal
Albert's words (from his chat): "The Railway connection should be connected only to the popdam repo in this AI app (in all places it's installed)."

## 2. Done and verified
- Railway CLI 5.63.1 installed on hetz via `npm i -g @railway/cli` (lands in `/home/ai/.npm-global/bin/railway`). `railway --version` works.
- 1Password `vibe_coding` item "Railway API" (id `ousrmts4sg6p3k62th2qmbpfvu`): fields `account token`, `ai account token` (new, added 2026-10-02 by Albert), `project token`. Both account tokens are VALID: a direct GraphQL call to `https://backboard.railway.com/graphql/v2` with `Authorization: Bearer` returns project `popdam`. NOTE: `railway whoami` / `railway list` print "Unauthorized" for these tokens (workspace-scoped tokens) — that is a CLI false negative, not a dead token. `RAILWAY_TOKEN=<project token> railway status` works.
- On hetz, Railway MCP is configured only in `/worksp/popdam/.mcp.json` (tracked in popdam) and the popdam worktree `/worksp/popdam-issue92-gemini-batch/.mcp.json`. Nothing global in `~/.claude.json`, `~/.claude/*.json`.
- A Claude OAuth token was accidentally printed into this session's transcript; it was redacted from the only hetz copy under `~/.claude` / `~/.cache` (grep count 0 afterward).

## 3. Not done (open)
a. Stray `railway` (and `chrome-devtools`) MCP servers appear in NON-popdam sessions started from the desktop app (seen in an ai-devops session on hetz, with `command: cmd` — Windows syntax). Source is NOT hetz: the desktop app on 4837 (al8960ofc, Windows) forwards its own MCP config into SSH sessions. Must be fixed ON 4837.
b. popdam's tracked `.mcp.json` uses `"command": "cmd"`, so Railway MCP cannot start in popdam sessions on Linux (hetz). Fix in u2giants/popdam3 to be cross-platform or deliver per-OS via `bin/mcp_policy.py deliver`.
c. Exposed Claude OAuth token: Albert must sign out/in of the desktop app once his concurrent sessions end (he cannot close it now). The Windows-side transcript copy also still holds it.

## 4. Intended design (already in repo)
`bin/setup-machine.ps1` `$McpProjectScope` already maps `popdam3 = @("railway","chrome-devtools")`; scoped servers must never be global. So (a) is drift on 4837, not a policy change.

## 5. What was tried and failed
- SSH from hetz to 4837 (its tailnet address) as u2giants/albert/Albert: publickey denied. Tailscale alias `4837` resolves wrong (0.0.18.229). No route from hetz.

## 6. Exact next steps
1. In a desktop-app session whose location is 4837 itself, in `C:\repos\ai-devops`: find where `railway`/`chrome-devtools` are defined globally (`%USERPROFILE%\.claude.json` top-level `mcpServers`, `%APPDATA%\Claude\claude_desktop_config.json`, `%USERPROFILE%\.claude\settings.json`), remove them from global scope, rerun `bin/setup-machine.ps1` so they are delivered only to popdam3 roots.
2. Fix popdam `.mcp.json` per 3b via PR in u2giants/popdam3.

## 7. Verification
Start a new non-popdam session from the desktop app: no `railway` server listed. Start a popdam session on hetz and on 4837: `railway` server connects.

## 8. Owner
Next Claude session on 4837. Albert only starts it.

## 9. Retention
Delete this file once 7 passes on both machines.
