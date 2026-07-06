---
name: claude-transcript-backup
description: Find all local Claude Code session transcripts on this machine and back them up to u2giants/ai-devops under claude_chats/<machine>. Use when the user says "find all the Local Claude Code session transcripts everywhere on this entire machine" or "put all of these into claude_chats".
---

# claude-transcript-backup

Albert ran this identically on 916, t16, 4837, hetz, seafile, compshop.
On Linux, `claude_chats/sync.sh` already does the core copy — use it. On
Windows, follow the manual procedure below.

## Where transcripts live

- **Linux:** `~/.claude/projects/` (check BOTH `/root` and `/home/ai` — compshop
  needed a merge of the two).
- **Windows:** `C:\Users\<user>\.claude\projects\` plus Claude Desktop
  local-agent-mode sessions at `%APPDATA%\Claude\local-agent-mode-sessions\`
  (each sandbox has a nested `.claude/projects/` and an `audit.jsonl`), and
  Desktop cowork sessions if present.
- Scan the system drive only — do NOT scan network/SMB drives (standing
  instruction: "don't scan network drives. only C:\").

## Procedure

1. Locate all `.jsonl` transcripts in the paths above; report the count, total
   size, and date range before copying.
2. Clone/pull `u2giants/ai-devops`; copy into `claude_chats/<machine>/`
   mirroring the source layout (machine name = short hostname, e.g. `916` for
   `916-alien`; Windows layout keeps the `D--repos-x` encoded folders and a
   `local-agent-mode-sessions/` subfolder).
3. Respect the repo's `.gitignore` — files matching `*secret*`/`*token*`
   patterns are intentionally excluded; do not force-add them.
4. Update `claude_chats/README.md` with a machine section in the existing
   format (transcript counts per project folder).
5. Commit and push to main. Warn (don't block) on files over GitHub's 50 MB
   soft limit; suggest Git LFS if they become common.
6. Remind: this repo must stay **private** — transcripts may contain live
   secrets.
