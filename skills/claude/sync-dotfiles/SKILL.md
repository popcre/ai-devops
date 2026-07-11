---
name: sync-dotfiles
description: Sync this machine's AI config with the ai-devops hub. Use when the user says "sync my dotfiles", "sync my config", "pull the latest skills/instructions", or "push my dotfiles". Pulls latest skills + global instructions + memory from ai-devops and installs them, sets the dflow gcloud defaults, and pushes local memory changes back. No chezmoi — ai-devops is the single hub.
---

# sync-dotfiles

One phrase keeps every machine's AI config in step with the `ai-devops` hub.
This is **Phase 1** of the config-consolidation plan
(`ai-devops/docs/config-consolidation-proposal.md`): skills, global
instructions, memory, and gcloud defaults. SSH + MCP setup are still the Dropbox
scripts until Phase 2 — do **not** claim they're synced here.

## Trigger phrases

- "sync my dotfiles" / "sync my config"
- "pull the latest skills" / "push my dotfiles"

## What is (and isn't) synced

| Thing | Direction | Mechanism |
|---|---|---|
| Claude/Codex skills | repo → machine (repo is source of truth) | `bin/ai-install-skills` |
| Global instructions (`CLAUDE.md`, Codex `AGENTS.md`) | repo → machine (never clobbers local edits) | `bin/ai-install-skills` |
| Auto-memory | machine ↔ repo (two-way, git-merged) | `bin/ai-sync-memory` |
| gcloud dflow defaults | apply on machine | `bin/ai-gcloud-dflow` |
| SSH config / MCP tokens | **NOT here yet — Phase 2** | Dropbox scripts for now |

## Procedure

Find the repo (`$HOME/repos/ai-devops`, `/worksp/ai-devops`, or `C:\repos\ai-devops`).
Run bash tools via git-bash on Windows.

1. **Pull the hub.** In the repo: `git pull --ff-only`. If it fails (local
   changes/diverged), stop and report — don't force.
2. **Lay down memory** from the hub: `bin/ai-sync-memory pull`. Only projects
   that already exist locally are updated (expected).
3. **Install skills + instructions:** `bin/ai-install-skills`. This refreshes
   `~/.claude/skills` (+ Codex) and seeds global instructions without clobbering
   local edits.
4. **Set gcloud defaults** (when this machine uses gcloud): `bin/ai-gcloud-dflow`.
5. **Capture local memory** back to the hub: `bin/ai-sync-memory push`.
6. **Commit + push the hub** if step 2/5 changed anything: stage `memory/`
   (and any skill/template edits the user made intentionally), commit with the
   `Co-Authored-By: Claude Opus 4.8` trailer, `git push`. Author uses the
   noreply email (repo convention).
7. **Report** in plain English: what was pulled, what memory changed, whether a
   commit/push happened, and that SSH/MCP remain on the Dropbox scripts.

## Safety

- Never commit a secret. Memory is secret-free by policy; if a memory file
  contains a credential, stop and flag it (it must move to 1Password, not git).
- `--dry-run` is available on `ai-sync-memory` and `ai-gcloud-dflow` — use it if
  the user wants a preview first.
- Skills flow repo→machine only. A skill edited locally in `~/.claude/skills`
  is NOT captured back; real skill changes belong in `ai-devops/skills/`.
