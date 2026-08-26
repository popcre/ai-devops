# MCP server scope: global vs project

**The rule: an MCP server that only one project ever uses is project-scoped,
never global.**

Claude Code starts every *globally* configured MCP server in every session, in
every repository. Global cost is therefore multiplied by the number of open
sessions, not by the number of times a server is used.

## The measurement that forced this rule

Measured on `edge-dev` (i7-12700, 32 GB) on 2026-08-26, with 11 global servers
and 22 open Claude Desktop sessions:

| Server | Processes | RAM |
| --- | ---: | ---: |
| 1password | 58 | 3.6 GB |
| chrome-devtools | 63 | 2.8 GB |
| trigger | 42 | 1.7 GB |
| supabase | 42 | 1.7 GB |
| playwright | 42 | 1.7 GB |
| ag-grid | 42 | 1.5 GB |
| railway | 29 | 1.4 GB |
| **total node processes** | **416** | **18.1 GB** |

Machine RAM sat at 85.8% (4.5 GB free of 31.7 GB) while CPU sat near 26%. Nothing
was leaking. The configuration was asking for all of it, every session.

Two of those servers were used by **no** cloned repository at all (`railway`), or
by exactly one (`recall-ai`, `ag-grid`).

## Where each server is wired

Defined once in `bin/setup-machine.ps1` step 5d. Step 5d-2 assigns scope.

**Global** — needed from any repository:
`1password`, `supabase` (read-only), `chrome-devtools`, `playwright`, `codex-cli`

**Project-scoped** — written into that repo's own `.mcp.json` by step 7b:

| Server | Project |
| --- | --- |
| `trigger` | `oracle` |
| `recall-ai` | `oracle` |
| `railway` | `popdam3` |
| `ag-grid` | `dflow_plm/designflow-frontend` |
| `devops-mcp` | `synology-monitor` |
| `synology-monitor` | `synology-monitor` |

Ownership decided by Albert, 2026-08-26.

**Codex-only:** `vercel`, via Codex's native HTTP transport. Deliberately absent
from Claude — behind `mcp-remote` it returns a 1-hour token with no refresh
token and re-opens a browser login every hour.

## How to add a server

1. Define it once in step 5d of `bin/setup-machine.ps1`.
2. If one project uses it, add it to `$McpProjectScope` in step 5d-2. Only add it
   to the global set if a session in *any* repository would genuinely need it.
3. Re-run `bin/setup-machine.ps1`.

Step 7b preserves entries it does not own in a project's `.mcp.json`, and reports
(never silently skips) a project that is not cloned on this machine.

## Adding a server to one session

Not possible. The finest scope Claude Code supports is per project, and the
configuration is read when a session starts — a running session will not pick up
a new server. Add it, then open a new session in that repository.

`claude mcp add --scope <local|project|user>`:

- `user` — every session everywhere. This is the global set above.
- `project` — the repo's `.mcp.json`, shared with anyone who works on it. This is
  what step 7b writes.
- `local` — only you, only that project. Stored in `~/.claude.json`.

## Sessions are the other half of the cost

An unused Claude Desktop session keeps its whole MCP stack resident. Stopping
talking to a session does not close it; **archiving** it does, and that is what
releases the processes. Turn on *Settings → Auto-archive on PR close* so finished
sessions do not accumulate.
