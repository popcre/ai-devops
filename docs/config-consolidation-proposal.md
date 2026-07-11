# Proposal — converge all machine config onto ai-devops (phased)

**Status:** PROPOSAL (not yet implemented). Written 2026-07-10.
**Companion:** [`config-inventory.md`](config-inventory.md) (the current scattered state).

## Goal
Make `ai-devops` the **single hub** that configures every machine (3 Windows dev
boxes + 2 Ubuntu servers), on both OSes, with **one install/update command** —
and retire the scattered Dropbox scripts. No new tools (no chezmoi): reuse the
`install.sh` / `install-ai-devops-windows.ps1` / `bin/ai-install-skills`
machinery that already exists.

## Principles
1. **One hub.** If it configures a machine, it lives in or is installed by
   `ai-devops`.
2. **Secrets from 1Password at install time — never committed.** Installers pull
   tokens/keys live and write them to machine-local files. The repo stays
   secret-free (consistent with `AGENTS.md` §Credentials).
3. **Never clobber machine-local values** (same rule as `config/*.env.example`
   → `/etc/ai-devops/`).
4. **Portable-only.** Sync prefs and shared config; leave per-install runtime
   paths (e.g. most of `config.toml`) alone.

## Phase 1 — quick wins (low risk)
| Item | Deliverable | Notes |
|---|---|---|
| `sync-dotfiles` skill | `skills/claude/sync-dotfiles/SKILL.md` (+ `skills/codex/` twin) | Triggered by "sync my dotfiles"; wraps `update.sh` (pull) + commit/push (send). No new tool to learn. |
| gcloud dflow defaults | `bin/ai-gcloud-dflow` | Sets project `lithe-breaker-323913` + region `us-east4` (Cloud Run/Build/Artifacts/Compute). Idempotent. |
| **Memory sync** | Extend `bin/ai-install-skills` (or a new `bin/ai-sync-memory`) to sync `~/.claude/projects/*/memory/` via the repo | Highest-value gap. Memory is secret-free by policy, so it can be git-tracked directly. |

**Exit criteria:** "sync my dotfiles" on any machine pulls latest skills +
instructions + memory and pushes local changes; gcloud is correct everywhere.

## Phase 2 — fold in the Dropbox scripts (medium risk)
| Item | Deliverable | Notes |
|---|---|---|
| SSH setup | Move `master_setupsshwindows.ps1` logic into `bin/` (e.g. `bin/ai-setup-ssh-windows.ps1`) + an Ubuntu equivalent | Host aliases become repo-tracked; **the `916-alien` key is pulled from 1Password**, not embedded. |
| MCP setup | Move `setup-claude-mcps.ps1` / `setup-codex-mcps.ps1` into `bin/` | MCP server shapes tracked in repo; **all tokens pulled from 1Password** at install. |
| Secret plumbing | A small helper that reads named 1Password items (via the scoped `vibe_coding` service account) and writes machine-local config | One consistent secret path for SSH keys + MCP tokens. |

**Exit criteria:** a fresh machine is fully configured (SSH + MCP + skills +
instructions + gcloud + memory) from ai-devops alone, secrets sourced from
1Password, nothing secret committed.

**Prerequisite / hygiene:** rotate the tokens currently sitting in plaintext
(Trigger PAT, MCP bearer tokens) as part of moving them into 1Password-sourced
install (see `config-inventory.md` §Security landmines).

## Phase 3 — retire Dropbox + document (low risk)
| Item | Deliverable |
|---|---|
| Retire Dropbox scripts | Leave a stub/README in the old Dropbox folders pointing at ai-devops; stop editing them |
| One-command onboarding | `docs/restore-from-zero.md` + a Windows quick-start updated so a new machine is "clone ai-devops → run installer → done" |
| Portable Codex prefs | Track the ~5 portable `config.toml` lines as a template; leave runtime paths alone |

**Exit criteria:** Dropbox is no longer a config source; the machine-atlas +
restore docs describe the single path.

## Open decisions (need owner input)
1. **Memory sync mechanism:** commit memory straight into `ai-devops` (simple,
   memory is secret-free) vs a dedicated small repo. Recommendation: straight
   into ai-devops under a `memory/` tree, per-machine-merged.
2. **Secret source in installers:** scoped 1Password service account (matches the
   existing `vibe_coding` MCP) — confirm that's the intended path for SSH keys too.
3. **Windows vs Ubuntu SSH parity:** the current script is Windows-only; decide
   whether the 2 servers need the same alias set installed.
4. **Order:** do Phase 1 now and schedule Phase 2 later, or batch 1+2.

## Non-goals
- No chezmoi or second sync system.
- No syncing of per-install runtime paths or the large chat archives beyond
  what already happens.
- No committing of any secret, ever.
