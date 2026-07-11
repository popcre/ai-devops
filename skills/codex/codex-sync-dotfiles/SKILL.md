---
name: codex-sync-dotfiles
description: Sync this machine's AI config with the ai-devops hub (Codex edition). Use when the user says "sync my dotfiles", "sync my config", "pull the latest skills/instructions", or "push my dotfiles". Pulls latest skills + global instructions + memory from ai-devops and installs them, sets the dflow gcloud defaults, and pushes local memory back. ai-devops is the single hub — no chezmoi.
---

# codex-sync-dotfiles

Codex twin of the Claude `sync-dotfiles` skill. Keeps this machine's AI config in
step with the `ai-devops` hub (GitHub `u2giants/ai-devops`). **Phase 1** of the
consolidation plan (`ai-devops/docs/config-consolidation-proposal.md`): skills,
global instructions, memory, gcloud. SSH + MCP remain the Dropbox scripts until
Phase 2 — do not claim otherwise.

## Trigger phrases
- "sync my dotfiles" / "sync my config"
- "pull the latest skills" / "push my dotfiles"

## What is (and isn't) synced

| Thing | Direction | Mechanism |
|---|---|---|
| Claude/Codex skills | repo → machine (repo is source of truth) | `bin/ai-install-skills` |
| Global instructions (`~/.codex/AGENTS.md`, `~/.claude/CLAUDE.md`) | repo → machine (never clobbers local edits) | `bin/ai-install-skills` |
| Auto-memory | machine ↔ repo (two-way, git-merged) | `bin/ai-sync-memory` |
| gcloud dflow defaults | apply on machine | `bin/ai-gcloud-dflow` |
| SSH config / MCP tokens | **NOT here yet — Phase 2** | Dropbox scripts for now |

## Locate the repo
Check `$HOME/repos/ai-devops`, `/worksp/ai-devops`, `C:\repos\ai-devops`,
`D:\repos\ai-devops`. Use git-bash for the bash `bin/` tools on Windows. If no
checkout exists, onboard first (`bin/install-ai-devops-windows.ps1` on Windows,
clone + `./install.sh` on Ubuntu).

## Procedure
1. `git pull --ff-only` in the repo. On failure (local changes/diverged), STOP
   and report — never force or reset.
2. `bin/ai-sync-memory pull` — lay hub memory onto this machine (only existing
   local projects update; skips are expected).
3. `bin/ai-install-skills` — refresh Codex (`~/.codex/skills`) + Claude skills and
   global instructions; never clobbers local edits (prints a diff hint instead —
   relay it).
4. `bin/ai-gcloud-dflow` — set the dflow gcloud project/region (skips if gcloud
   absent).
5. `bin/ai-sync-memory push` — copy local memory back into the hub.
6. Commit + push `ai-devops` if memory (or intentional skill edits) changed. Use
   the noreply email (`u2giants@users.noreply.github.com`); keep the repo
   secret-free. If nothing changed, say so.
7. Report plainly: what synced, which memory projects changed, whether a push
   happened (SHA), and that SSH/MCP are still on the Dropbox scripts.

## Preview mode
`bin/ai-sync-memory {push,pull} --dry-run` and `bin/ai-gcloud-dflow --dry-run`
show what would happen without changing anything.

## Safety
- Never commit a secret; memory is secret-free by policy. Flag and STOP if a
  memory file holds a credential (it belongs in the `vibe_coding` 1Password vault).
- Skills flow repo→machine only; edit real skills in `ai-devops/skills/`.
- Don't force-pull/reset the hub to resolve a conflict — surface it.

## Related
`ai-devops/docs/config-inventory.md`, `docs/config-consolidation-proposal.md`,
`HANDOFF.md`, `memory/README.md`.
