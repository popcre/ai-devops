# Session transcripts live in a PRIVATE repo

Claude Code / Codex session transcripts are **not** in this public repo. On
2026-07-17 they were removed from all history here (they contained live
credentials) and moved to the private repo:

**`u2giants/ai-devops-transcripts`** — mounted here as the `transcripts/` submodule.

## Get the transcripts locally (optional, ~1 GB)
```
git submodule update --init transcripts
```
Skip it and the rest of ai-devops works normally — the submodule is opt-in.

## Backing up new transcripts
Back them up **into the submodule / private repo**, never into ai-devops.
`.gitignore` blocks `/claude_chats/` and `/codex_chats/` here on purpose. The
`claude-transcript-backup` and `codex-transcript-miner` skills carry a STOP
header about this; they need rewiring to target the private repo (open item).

## Why
Every credential that appeared in any transcript while this repo was public
(2026-07-05 → 2026-07-17) must be treated as compromised. See the security
purge commit and the rotation tracking.
