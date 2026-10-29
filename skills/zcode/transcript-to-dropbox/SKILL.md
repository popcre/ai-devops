---
name: transcript-to-dropbox
description: Mirror ALL transcript sources on hetz (Claude projects, Codex sessions, ZCode sqlite+rollout) DIRECTLY into Dropbox ai/chat_transcripts/hetz/ per the 2026-10-29 owner ruling — never into the GitHub transcript repo from this machine. Use when refreshing or verifying the Dropbox transcript mirror, or before any session considers pushing hetz transcripts to GitHub.
---

# Skill: transcript-to-dropbox

> **Owner ruling 2026-10-29 (Albert, chat):** transcripts from hetz go DIRECTLY
> to Dropbox — **NOT** to the GitHub transcript repo. This supersedes the
> GitHub destination in `zcode-transcript-backup` for this machine.
> Never copy the other direction either: no Dropbox content into any repo.

## Destination — match the existing layout exactly

`dropbox:ai/chat_transcripts/<machine>/` — per-machine folders already exist
(4837, 916, al8960ofc, compshop, edge-dev, edge-dev3, hetz, seafile, t16).
For this server use `hetz`:

- Claude: `~/.claude/projects/` → `ai/chat_transcripts/hetz/claude/`
  (project dirs map 1:1, e.g. `-home-ai`, `-worksp-popdam`).
- Codex: `~/.codex/sessions/` →
  `ai/chat_transcripts/hetz/codex/home/ai/.codex/sessions/`
  plus `~/.codex/session_index.jsonl` →
  `.../codex/home/ai/.codex/session_index.jsonl`
  (single file: `rclone copyto`, not `copy`).
- ZCode: db trio (`db.sqlite`, `db.sqlite-wal`, `db.sqlite-shm`) **raw, no
  gzip** (Dropbox has no 100 MB file limit) →
  `ai/chat_transcripts/hetz/zcode/<YYYY-MM-DD>/` dated snapshot, like
  edge-dev; rollout captures `model-io-session_*.jsonl` →
  `ai/chat_transcripts/hetz/zcode/rollout/`.

Copy — never sync with `--delete`; the archive only ever grows. Never open the
live ZCode database; copy the trio first.

## Tooling on hetz (installed 2026-10-29)

- `rclone` at `/home/ai/bin/rclone`; remote `dropbox` in
  `~/.config/rclone/rclone.conf` (chmod 600). The token never goes in chat,
  logs, or command arguments.
- Script: `/home/ai/bin/transcripts-to-dropbox.sh` — mirrors all three sources.
- Nightly cron: 3:17 AM America/New_York.

## Running an on-demand refresh

```bash
/home/ai/bin/transcripts-to-dropbox.sh
grep "rc=" /home/ai/logs/transcripts-to-dropbox.log   # all four stages rc=0
```

Verify with `rclone size dropbox:ai/chat_transcripts/hetz` against the source
trees. Dropbox `too_many_write_operations` errors self-heal via rclone retries;
only a nonzero final rc is a failure.

## Never

- Never push transcripts from this machine to GitHub (owner ruling above).
- Never paste or log the Dropbox token.
