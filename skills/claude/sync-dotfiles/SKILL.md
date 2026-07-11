---
name: sync-dotfiles
description: Sync this machine's AI config with the ai-devops hub. Use when the user says "sync my dotfiles", "sync my config", "pull the latest skills/instructions", or "push my dotfiles". Pulls latest skills + global instructions + memory from ai-devops and installs them, sets the dflow gcloud defaults, and pushes local memory changes back. No chezmoi — ai-devops is the single hub.
---

# sync-dotfiles

One phrase keeps every machine's AI config in step with the `ai-devops` hub
(GitHub `u2giants/ai-devops`). This is **Phase 1** of the config-consolidation
plan (`ai-devops/docs/config-consolidation-proposal.md`): skills, global
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

## Locate the repo
Check, in order: `$HOME/repos/ai-devops`, `/worksp/ai-devops`,
`C:\repos\ai-devops`, `D:\repos\ai-devops`. On Windows run the bash `bin/` tools
via git-bash (the Bash tool is git-bash). If no checkout exists, this machine
hasn't been onboarded — run `bin/install-ai-devops-windows.ps1` (Windows) or
clone + `./install.sh` (Ubuntu) first.

## Procedure

1. **Pull the hub.** In the repo: `git pull --ff-only`. If it fails (local
   changes / diverged history), STOP and report — do not force, do not `git
   reset`. Tell the user to resolve or ask to inspect.
2. **Lay down memory** from the hub: `bin/ai-sync-memory pull`. Only projects
   that already exist locally are updated (skips are expected and printed).
3. **Install skills + instructions:** `bin/ai-install-skills`. Refreshes
   `~/.claude/skills` (+ `~/.codex/skills`) and seeds global instructions
   **only if absent** — if `CLAUDE.md`/`AGENTS.md` differ it prints a diff hint
   and does NOT overwrite. Relay that hint if shown.
4. **Set gcloud defaults** (when this machine uses gcloud): `bin/ai-gcloud-dflow`.
   Skips cleanly if gcloud isn't installed.
5. **Capture local memory** back to the hub: `bin/ai-sync-memory push`.
6. **Commit + push the hub** if step 2/5 changed anything: `git status` to see
   what changed, then stage `memory/` (and any skill/template edits the user made
   intentionally), commit with the `Co-Authored-By: Claude Opus 4.8` trailer and
   the noreply author email (`u2giants@users.noreply.github.com`), then
   `git push`. If nothing changed, say so.
7. **Report** in plain English: what was pulled, which memory projects changed,
   whether a commit/push happened (with SHA), and the standing note that SSH/MCP
   remain on the Dropbox scripts until Phase 2.

## Preview mode
If the user wants a dry run first: `bin/ai-sync-memory {push,pull} --dry-run` and
`bin/ai-gcloud-dflow --dry-run` print what they'd do without changing anything.

## Safety
- **Never commit a secret.** Memory is secret-free by policy; if a memory file
  contains a credential, STOP and flag it — it must move to 1Password
  (`vibe_coding` vault), not git.
- Skills flow repo→machine only. A skill edited locally in `~/.claude/skills` is
  NOT captured back; real skill changes belong in `ai-devops/skills/` (edit there,
  then this skill installs them).
- Don't force-pull or reset the hub to resolve a conflict — surface it instead.

## Related
`ai-devops/docs/config-inventory.md` (the full config map),
`ai-devops/docs/config-consolidation-proposal.md` (Phases 2–3),
`ai-devops/HANDOFF.md`, `ai-devops/memory/README.md`.
