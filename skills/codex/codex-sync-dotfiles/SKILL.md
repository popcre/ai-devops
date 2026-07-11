---
name: codex-sync-dotfiles
description: Sync this machine's AI config with the ai-devops hub (Codex edition). Use when the user says "sync my dotfiles", "sync my config", "pull the latest skills/instructions", or "push my dotfiles". Pulls latest skills + global instructions + memory from ai-devops and installs them, sets the dflow gcloud defaults, and pushes local memory back. ai-devops is the single hub — no chezmoi.
---

# codex-sync-dotfiles

Codex twin of the Claude `sync-dotfiles` skill. Keeps this machine's AI config
in step with the `ai-devops` hub. **Phase 1** of the consolidation plan
(`ai-devops/docs/config-consolidation-proposal.md`): skills, global
instructions, memory, gcloud. SSH + MCP remain the Dropbox scripts until
Phase 2 — do not claim otherwise.

## Trigger phrases

- "sync my dotfiles" / "sync my config"
- "pull the latest skills" / "push my dotfiles"

## Procedure

Locate the repo (`$HOME/repos/ai-devops`, `/worksp/ai-devops`, or
`C:\repos\ai-devops`). Use git-bash for the bash tools on Windows.

1. `git pull --ff-only` in the repo. On failure, stop and report — never force.
2. `bin/ai-sync-memory pull` — lay hub memory onto this machine (only existing
   local projects update).
3. `bin/ai-install-skills` — refresh Codex (`~/.codex/skills`) + Claude skills
   and global instructions; never clobbers local edits.
4. `bin/ai-gcloud-dflow` — set the dflow gcloud project/region (if gcloud is
   used here).
5. `bin/ai-sync-memory push` — copy local memory back into the hub.
6. Commit + push `ai-devops` if memory (or intentional skill edits) changed.
   Use the noreply email; keep the repo secret-free.
7. Report plainly: what synced, what changed, whether a push happened, and that
   SSH/MCP are still on the Dropbox scripts.

## Safety

- Never commit a secret; memory is secret-free by policy. Flag and stop if a
  memory file holds a credential (it belongs in 1Password).
- `ai-sync-memory` and `ai-gcloud-dflow` accept `--dry-run` for a preview.
- Skills flow repo→machine only; edit real skills in `ai-devops/skills/`.
