
## MiMo-specific traps

- **Skills write root is `~/.config/mimocode/skills/` (and project
  `.mimocode/skills/`).** Never install toolkit-managed skills into
  `~/.agents/skills`, `~/.claude/skills`, or `~/.codex/skills` -- those are
  read-only compatibility scans for MiMo.
- **MCP config is `~/.config/mimocode/mimocode.jsonc` -> `mcp`.** Local servers
  use `command` as an **array** of argv strings and `timeout` (ms), not
  ZCode's string command / `timeoutMs`. Tokens never appear in the file --
  1Password routes through `mcp-launch.cmd`.
- **No config-file hooks.** There is no completion-check hook installer for
  MiMo. The Response Style rules above are the completion-honesty control.
- **Headless driving:** `ai-mimo ask "<prompt>"` -- the governed wrapper. Never
  launch `Xiaomi MiMo AI.exe` (Desktop GUI) as a headless fallback. Never pass
  `--yolo` / `--dangerously-skip-permissions` from caller input.
- **Transcripts:** SQLite `~/.local/share/mimocode/mimocode.db` -- back up and
  mine by SQL with `mimo-transcript-backup` (private repo only).
