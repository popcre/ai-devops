# HANDOFF — Railway MCP limited to popdam on every machine (2026-10-02T1737Z, al8960ofc/claude)

Session `fcded5df-960d-4e53-b1fb-466f6045193a`, written 1:37 PM EDT on 2026-10-02.

## 0. ⚠️ BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

None. Albert's request (his chat, verbatim): "Remove the Railway connection from
every project except popdam." then "do the other machines too".

## 1. What this application is

`popcre/ai-devops` manages AI tool configuration on Albert's machines. Railway's
MCP server ("Railway connection") is scoped by repository policy to `popdam3`
only: `bin/setup-machine.ps1` maps `"popdam3" = @("railway", "chrome-devtools")`
and project entries are written by `bin/write-project-mcp.ps1` (#705). The
repository needed no change; stale machine-local configs did.

## 2. What we set out to do this session, and why

Make Railway load only in popdam on every machine (Claude Code and Codex), because
some machines still carried Railway as a global (every-project) server.

## 3. Current state — what is true right now

| Machine | State | How verified |
| --- | --- | --- |
| al8960ofc (4837, this one) | Global Railway removed from `~/.claude.json` and `~/.codex/config.toml`; added as Claude project entry for `C:/repos/popdam3` and in untracked `C:\repos\popdam3\.codex\config.toml` (excluded via `.git/info/exclude`). Backups: `*.bak-railway-20261002`. | `claude mcp list` shows Railway connected in popdam3, absent in ai-devops |
| edge-dev (user `ahazan`) | Already correct: Railway only in popdam3 (Claude + Codex). No change. | `claude mcp list` in popdam3 vs ai-devops |
| edge-dev3 (Linux, `ahazan`) | Global Railway removed from `~/.claude.json`; removed from 5 non-popdam project entries; kept on `/home/ahazan/repos/popdam3`. Codex already correct. Backup `~/.claude.json.bak-railway-20261002`. | Direct JSON read (claude CLI not on SSH PATH) |
| hetz (users `ai`, `root`) | Already correct. Railway appears only in popdam `.mcp.json` files: `/worksp/popdam`, its `.claude/worktrees/*`, `/worksp/popdam-issue92-gemini-batch`, and review sandboxes under `/home/ai/.local/state/ai-devops/review-sandboxes/` that are popdam copies (AGENTS.md title "PopDAM"). No change. | Recursive grep of config files |
| 916-alien | NOT DONE — unreachable | `ssh 916-alien`: hostname does not resolve |
| t16 | NOT DONE — unreachable | `ssh t16`: port 22 timeout |
| edge-alien | NOT DONE — unreachable (CI runner; likely has no AI config) | `ssh edge-alien`: timeout |

## 4. Everything we tried that did NOT work

- First hetz check looked only at home-directory configs and missed `/worksp`;
  Albert corrected this. The full grep found only popdam hits.
- Python `os.path.realpath` crashed on edge-dev (WinError 448, untrusted mount
  point under `C:\repos\oracle-worktrees`); crash happened before any write.
  Using `abspath` fixed it.
- `ssh edge-dev` without `-i ~/.ssh/916-alien -o IdentitiesOnly=yes -l ahazan` fails.

## 5. Root causes and key findings

Machines that had not re-run `bin/setup-machine.ps1` (or the Linux equivalent)
since the #705 scoping still carried Railway globally. Re-running setup is the
canonical fix; a narrow manual move was used here to avoid unrelated changes.

## 6. Exact next steps

For each of 916-alien, t16, edge-alien once reachable:
1. Check `~/.claude.json` top-level `mcpServers.railway`, every
   `projects.*.mcpServers.railway`, and `[mcp_servers."railway"]` in
   `~/.codex/config.toml`.
2. Remove any entry not for a popdam checkout; ensure the popdam checkout keeps
   one (Claude project entry + untracked `.codex/config.toml`). Or run
   `bin/setup-machine.ps1` from a current ai-devops checkout.
3. Verify: `claude mcp list` inside popdam shows railway; inside ai-devops it does not.

## 7. Constraints and gotchas in force

- popdam3's `.mcp.json` is tracked; never edit it locally — use the Claude
  project entry instead.
- Back up each config before editing; write atomically.

## 8. Access and environment

Reached from al8960ofc: `vps` (hetz, root; `sudo -u ai`), `edge-dev`/`edge-dev3`
with `-i ~/.ssh/916-alien -o IdentitiesOnly=yes -l ahazan`. Machine atlas:
`ai-private-config path machine_atlas`.

## 9. Open questions and risks

- 916-alien has no working SSH name from this machine; its route is unknown.
- t16 has no SSH alias from edge-dev per the atlas and timed out here.
