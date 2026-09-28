---
name: claude-transcript-backup
description: Find all local Claude Code and Codex session transcripts on this machine and back them up to Albert's private Dropbox folder `Dropbox\ai\chat_transcripts\<machine>`. Use when the user says "upload/back up the transcripts", "find all the Local Claude Code session transcripts everywhere on this entire machine", or "put all of these into claude_chats".
---

# claude-transcript-backup

> **Owner rule (Albert, 2026-09-27): "use Dropbox going forward. put everything
> in the \ai\chat_transcripts folder right now and make that a rule going
> forward."**
>
> The destination is `<Dropbox root>\ai\chat_transcripts\<machine>\`, stored
> **uncompressed**. The private Git repository `u2giants/ai-devops-transcripts`
> is a frozen historical archive (last upload 2026-09-27); never add new
> transcripts to it, and never to the PUBLIC `ai-devops` repository.

## Where transcripts live

- **Linux:** `~/.claude/projects/` (check BOTH `/root` and `/home/ai`),
  `~/.codex/sessions/`, `~/.codex/archived_sessions/`.
- **Windows:** `C:\Users\<user>\.claude\projects\`, `.codex\sessions\`,
  `.codex\archived_sessions\`, `.codex\session_index.jsonl` (these may be
  symlinks — follow them), plus `%APPDATA%\Claude\local-agent-mode-sessions\`
  when it holds transcripts.
- Scan the system drive only — never network/SMB drives.

## Procedure

1. Find the Dropbox root: `%LOCALAPPDATA%\Dropbox\info.json` (`personal.path`)
   on Windows, `~/.dropbox/info.json` on Linux. No Dropbox client on the
   machine → stop and tell Albert; do not substitute another destination.
2. Report the source transcript count and total size.
3. Mirror each source into `chat_transcripts/<machine>/` (machine = short
   hostname, e.g. `edge-dev`, `916`), with this layout:
   `claude/projects/`, `codex/sessions/`, `codex/archived_sessions/`,
   `codex/session_index.jsonl`. Copy additively (Windows: `robocopy /E`;
   Linux: `rsync -a`) — never mirror-delete, so sessions pruned locally stay
   in Dropbox.
4. Verify the `.jsonl` count in Dropbox is at least the source count.
5. Never share the `chat_transcripts` folder or create a Dropbox link to it —
   transcripts may contain live secrets.
