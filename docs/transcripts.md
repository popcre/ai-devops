# Session transcripts live in a PRIVATE repo

Claude Code / Codex session transcripts are **not** in the current public tree.
They were moved to the private repository on 2026-07-17. Historical public Git
objects still exist pending the coordinated rewrite in
`plan_full-strategy-remediation.md`; do not claim the purge is complete until a
fresh unauthenticated clone proves it.

**`u2giants/ai-devops-transcripts`** — mounted here as the `transcripts/` submodule.

## Get the transcripts locally (optional, ~1 GB)
```
git submodule update --init transcripts
```
Skip it and the rest of ai-devops works normally — the submodule is opt-in.

## Backing up new transcripts
Back them up **into the submodule / private repo**, never into ai-devops.
`.gitignore` blocks `/claude_chats/` and `/codex_chats/` here on purpose. The
transcript skills run `ai-transcript-destination-check` before copying; it
accepts only the canonical private remote and rejects public or lookalike paths.

## Why
Every credential that appeared in any transcript while this repo was public
(2026-07-05 → 2026-07-17) must be treated as compromised. See the security
purge commit and the rotation tracking.
