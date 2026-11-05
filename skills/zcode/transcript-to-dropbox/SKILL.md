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
- ZCode: filtered session exports → `ai/chat_transcripts/hetz/zcode/sessions/`;
  rollout captures with either `model-io-session_` or `model-io-sess_` prefix
  → `ai/chat_transcripts/hetz/zcode/rollout/`.

Copy only; never sync with deletion. The exporter opens SQLite read-only,
including committed WAL data; reasoning and tool output stay out of exports.
Never resume dated raw database uploads.

## Tooling on hetz

The repo-owned Ubuntu transport is `bin/ai-transcripts-to-dropbox-hetz`.
Install it from merged main with `bash bin/ai-transcripts-to-dropbox-hetz --install`.
This saves the old job recoverably and replaces its existing launcher without
changing the nightly 3:17 AM America/New_York cron. Reinstall after source updates;
this transport deliberately has no independent updater. It uses the existing
rclone remote and does not expose its credentials.

Run `/home/ai/bin/transcripts-to-dropbox.sh` for an on-demand refresh.
The counts-only log ends with `errors=0`; verify remote session count and
activity times against the source, then trigger the single store writer on
edge-dev3. Historical raw copies may be removed only after store coverage and
Dropbox recovery retention are proven; keep the newest snapshot.

## Never

- Never push transcripts from this machine to GitHub (owner ruling above).
- Never paste or log the Dropbox token.
