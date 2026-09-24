# MiMo Windows baseline — edge-dev 2026-09-23

Probe machine: **edge-dev** (Windows 11). Re-run these commands after any MiMo
Desktop or MiMoCode CLI update; update this file and `bin/ai-mimo` STEP 0 when
facts change.

## Presence

| Fact | Value | Reproduce |
|---|---|---|
| Desktop app | `C:\Program Files\Xiaomi MiMo AI\Xiaomi MiMo AI.exe` | `Get-Item 'C:\Program Files\Xiaomi MiMo AI\Xiaomi MiMo AI.exe'` |
| Desktop ProductVersion | (fill from `.VersionInfo.ProductVersion` at next probe) | `(Get-Item ...).VersionInfo.ProductVersion` |
| Standalone CLI `mimo` | **ABSENT on PATH** | `Get-Command mimo` |
| User config | `~/.config/mimocode/mimocode.jsonc` | `Get-Content ~\.config\mimocode\mimocode.jsonc` |
| Data / sessions | `~/.local/share/mimocode/mimocode.db` (+ memory/) | `Get-Item ~\.local\share\mimocode\mimocode.db` |
| Skills write root | `~/.config/mimocode/skills/` | (managed dir after install) |
| Skills compat (read-only) | `~/.agents/skills` default | Desktop guide §7 |

## MCP schema (live `mimocode.jsonc`)

Local server entry shape observed 2026-09-23:

```json
{
  "type": "local",
  "command": ["cmd", "/c", "C:\\Users\\...\\mcp-launch.cmd", "cmd", "/c", "...\\1password-mcp.cmd"],
  "enabled": true,
  "timeout": 120000
}
```

- `command` is an **array** (full argv), not string + args.
- Timeout key is `timeout` (milliseconds).
- No tokens in the file.

## Hooks

**None.** MiMoCode permissions cannot be modified by custom tools/hooks
(`mimocode-docs` reference/permissions.md). No `ai-install-completion-check-hook
--client mimo` surface exists.

## Headless CLI

Documented entry: `mimo run` (`mimocode-docs` reference/commands.md). Exact
flag set **UNQUALIFIED** because the standalone CLI is not installed here
(plan D10). When the CLI appears, capture:

```bash
mimo --help
mimo run --help
mimo --version
```

and pin only what the parser accepts (ZCode taught that `--help` can advertise
flags the parser rejects).

## What was NOT probed live

- `mimo run` end-to-end (CLI absent).
- BlockerWatch resume (`mimo --session` / `--continue`) — plan D11.
- SQL schema of `mimocode.db` (copy-then-mine only; see `mimo-transcript-backup`).
