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

**`synology-monitor` is worked on ~90% of the time from the hetz Ubuntu VPS, and
is not cloned on `edge-dev`.** Its two servers therefore remain in the Windows
global set for now. They must be scoped by committing a `.mcp.json` **in that
repo, authored on Linux** — the current Windows definitions point at
`.config/ai-devops/mcp-remote-launch.cmd`, which does not exist there. Do not
seed that project from a Windows machine.

**Codex-only:** `vercel`, via Codex's native HTTP transport. Deliberately absent
from Claude — behind `mcp-remote` it returns a 1-hour token with no refresh
token and re-opens a browser login every hour.

## The committed `.mcp.json` is the authority — not the setup script

A project is tied to its servers by the **`.mcp.json` committed in that project's
repository**, not by any path on any one machine. This matters because:

- **Extra clones.** Claude routinely creates a second or third checkout of the
  same repo (`shared-db-worktrees/`, `ai-devops-docs-1599/`,
  `licensor-source-data-sega-load/`). A committed file is present in all of them
  automatically. A machine-local list could never enumerate them.
- **Linked worktrees.** `.mcp.json` is a tracked file, so every
  `.claude/worktrees/<name>/` checkout has it too.
- **Other machines, including Linux.** The file travels with git to the hetz
  Ubuntu VPS and to every other workstation.

`bin/setup-machine.ps1` step 7b is therefore only a **bootstrap convenience** —
it seeds the file once so it can be committed. It probes several candidate roots
(`%USERPROFILE%\repos`, `C:\repos`, `D:\repos`, `/worksp`) rather than assuming
one, it never overwrites an entry the repo already owns, and a project it cannot
find is reported, not silently dropped.

### Portability rules for a committed `.mcp.json`

- **Never write a literal profile path.** Use `${USERPROFILE}` — Claude Code
  expands it in `.mcp.json`. (Claude *Desktop* does **not** expand variables in
  its own config, which is why the global config still carries literal paths.)
- **A Windows `.cmd` launcher path does not work on Linux.** A project worked on
  from both Windows and the hetz Ubuntu VPS needs entries that resolve on both,
  or a per-OS launcher. Check this before assuming a committed file is portable.
- First use in a project shows **"Pending approval"**. That is the safety
  mechanism that stops a repository from adding servers behind your back —
  approve it once per project.

## Codex is different

Codex reads MCP servers from `~/.codex/config.toml` (global) with optional
`--profile` layering. **It has no project-scoped equivalent of `.mcp.json`**, so
this rule cannot be applied to it.

In practice Codex does not have the same problem: it does not keep a parked
session per task the way Claude Desktop does. Measured alongside the 416-process
Claude figure above, Codex accounted for 20 processes and 1.2 GB. If long-lived
Codex sessions ever accumulate, `--profile` is the only lever available.

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
