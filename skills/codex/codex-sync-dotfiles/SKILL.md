---
name: codex-sync-dotfiles
description: Sync this machine's AI config with the ai-devops hub (Codex edition). Use when the user says "sync my dotfiles", "sync my config", "pull the latest skills/instructions", or "push my dotfiles". Pulls latest skills + global instructions + memory from ai-devops and installs them, sets the dflow gcloud defaults, and pushes local memory back. ai-devops is the single hub — no chezmoi.
---

# codex-sync-dotfiles

Codex twin of the Claude `sync-dotfiles` skill. Keeps this machine's AI config in
step with the `ai-devops` hub (GitHub `u2giants/ai-devops`): skills, global
instructions, memory, gcloud, **and the secret/MCP/SSH plumbing** (Phase 2 of
`ai-devops/docs/config-consolidation-proposal.md`, shipped 2026-07-14).

> **This skill must bring the machine to FULL current state, or say loudly what is
> missing.** Until 2026-07-26 it did neither: it covered only skills + memory +
> gcloud while claiming SSH/MCP "remain the Dropbox scripts", so a machine that had
> only ever been synced kept **plaintext 1Password tokens inside its MCP config
> files** and the pre-fix "storming" launcher that rate-limit-locked the shared
> service account — and was told it was synced. Step 2 exists to make that
> impossible. Never report success while Phase 2 wiring is absent.

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
| Secret plumbing (1Password token file, `mcp.env`), MCP launchers + token-free MCP wiring, SSH aliases, 916-alien key, Codex PATH | repo → machine, **checked every run (step 2)**; installed by the per-OS script when missing | `bin/setup-machine.ps1` (Windows) / `bin/setup-secrets.sh` (Ubuntu) |
| GLM server (pinned OpenCode, agents, service, `ai-glm` on PATH) | repo → machine, **checked every run (step 2b)** via `ai-glm doctor` | `bin/setup-opencode-glm.ps1` (Windows) / `bin/setup-opencode-glm.sh` (Ubuntu) |
| Dropbox scripts | **retired — not a config source.** Never send anyone there | — |

## Locate the repo
Check `$HOME/repos/ai-devops`, `/worksp/ai-devops`, `C:\repos\ai-devops`,
`D:\repos\ai-devops`. Use git-bash for the bash `bin/` tools on Windows. If no
checkout exists, onboard first (`bin/install-ai-devops-windows.ps1` on Windows,
clone + `./install.sh` on Ubuntu).

## Procedure
1. `git pull --ff-only` in the repo. On failure (local changes/diverged), STOP
   and report — never force or reset.
2. **Check the Phase 2 wiring (secrets, MCP, SSH) — never skip.** Report each item
   present/missing:
   - `~/.config/ai-devops/op-service-account` (vault-locked 1Password SA token file).
   - Both launchers: `mcp-launch.cmd` + `mcp-remote-launch.cmd` (Windows) or
     `mcp-launch.sh` + `mcp-remote-launch.sh` (Ubuntu) in `~/.config/ai-devops/`.
   - `~/.config/ai-devops/mcp.env` exists and `diff`s clean against the repo's
     `config/mcp.env.example` (the `TRIGGER_ACCESS_TOKEN` pointer changed
     2026-07-26, so a mismatch is real drift).
   - **No real plaintext token** in `~/.codex/config.toml`, `~/.claude/settings.json`,
     or the Claude Desktop config. Use a shape-based check —
     `grep -oE '\bops_[A-Za-z0-9_-]{20,}' <file>` — NOT a bare `grep ops_`: the
     legitimate ref `op://vibe_coding/designflow-mcp/devops_token` contains `ops_`
     and produced a false positive on 2026-07-26. A real SA token is ~866 chars.
   - Windows: `~/.ssh/ai-devops.conf` exists and `~/.ssh/config` `Include`s it.
     Ubuntu: `~/.config/ai-devops/shellrc` exists and `.bashrc` sources it.
   **If anything is missing or a real token is found**, run the per-OS installer:
   `pwsh -NoProfile -ExecutionPolicy Bypass -File <repo>\bin\setup-machine.ps1 -RepoPath <repo>`
   or `<repo>/bin/setup-secrets.sh`. Preconditions: **pwsh 7** (the Windows script
   has no `#requires` and dies with cryptic parse errors under 5.1), and **the token
   file must already exist** or the script blocks on a prompt and a headless Codex
   run will hang. If it is absent, do NOT invoke — tell Albert the token is in
   1Password `vibe_coding` → `vibe_coding-service-account` → field
   `op_service_account_token` (NOT the empty `credential` field), passable as
   `-Token <value>` / `OP_SERVICE_ACCOUNT_TOKEN=<value>`. A plaintext token or a
   missing launcher is a security/regression condition — fix it; a cosmetic gap
   (e.g. the memory-sync task) is his call. The installer rewrites the live Claude
   Desktop MCP config (backup: `*.aidevops.bak`) — say so first.
   **If all present, state "Phase 2 wiring already current"** so the report
   distinguishes *checked and fine* from *not checked*. After any MCP config
   rewrite, Claude Desktop needs a full quit+reopen, and deleting
   `~/.config/ai-devops/mcp-secrets.dpapi.json` forces a fresh resolve (15-min cache).
2b. **Check the GLM server — never skip.** `ai-glm` is machine-local state that a
   `git pull` cannot install. Run `ai-glm doctor`.
   - Exit 0 → say "GLM server already current" explicitly.
   - Non-zero, or `ai-glm` not found → run the idempotent installer (it installs its
     own prerequisites):
     Windows `pwsh -NoProfile -ExecutionPolicy Bypass -File <repo>\bin\setup-opencode-glm.ps1 -RepoPath <repo>`,
     Ubuntu `<repo>/bin/setup-opencode-glm.sh`. Re-run doctor and report. Do NOT call
     the sync successful while doctor still fails.
   - No 1Password service-account token file → do not run it; report that GLM is
     unavailable until the token is in place. Never skip silently.
   `config/opencode/version` pins OpenCode, so a pull that bumps it is installed here.

3. `bin/ai-sync-memory pull` — lay hub memory onto this machine (only existing
   local projects update; a skip for a project this machine doesn't have is
   normal). **But if EVERY project skips, or `push` reports 0 folders, the
   script now exits non-zero — that is a real failure, not "expected". It means
   the resolved Claude home is not the one Claude Code uses. Do not report the
   sync as successful; report the failure.**
4. `bin/ai-install-skills` — refresh Codex (`~/.codex/skills`) + Claude skills and
   global instructions; never clobbers local edits (prints a diff hint instead —
   relay it).
4b. **Carry across any standing rule the local instruction file is missing.**
   Step 4 deliberately never overwrites `~/.codex/AGENTS.md` (it holds this
   machine's own atlas section and hand edits), so a NEW STANDING RULE added to
   `templates/system/AGENTS-global-codex.md` reaches this machine only if you
   carry it. Without this step a rule Albert set once is silently absent here
   while he believes it is everywhere. Diff
   `~/.codex/AGENTS.md` against `templates/system/AGENTS-global-codex.md`; for
   each rule section present in the template but absent locally, append it
   verbatim (append-only — never rewrite or reorder the local file). Report what
   you appended. This mirrors step 4 of the Claude `sync-dotfiles` skill.
4b. `bin/ai-claude-permissions` — merge the permissions in
   `config/claude-permissions.allow` into the user-level `~/.claude/settings.json`,
   covering every project on the machine. Run it here too even though this is the
   Codex skill: the gap is per-MACHINE, not per-agent, and Albert expects one
   "sync my dotfiles" to leave the machine complete whichever client he said it
   in. Idempotent and strictly additive — it never removes an entry and never
   touches `deny`. Prints `OK all N required permission(s) already present` when
   there is nothing to do; say that verdict out loud. Exit 3 means the local
   settings file is already unparseable JSON — it is left untouched; report it,
   do not rewrite it. Why it matters: Claude Code STOPS and asks before using a
   tool that is not allowed, so in a delegated or unattended session the work
   stalls and reads like a broken tool. To add a permission everywhere, add the
   line to `config/claude-permissions.allow` in the repo — never hand-edit one
   machine's settings file.
5. `bin/ai-gcloud-dflow` — set the dflow gcloud project/region (skips if gcloud
   absent).
5b. `bin/ai-git-identity` — pin the Git commit identity. Idempotent; prints
   `already correct` when there is nothing to do. Not cosmetic: Git has no
   default identity, and with none configured it does not stop — it silently
   invents one from the OS/AD account and stamps it on every commit. That put
   **231 wrong-identity commits into merged `develop`/`main`** across the dflow
   repos before it was noticed, which is unfixable without force-pushing shared
   release history. Also sets `user.useConfigOnly=true` so Git FAILS LOUDLY
   rather than guessing if the config is lost. Machine-level on purpose: Codex,
   Claude, GLM, Grok and Kimi all use the same `git`, so one setting covers
   every agent. Relay any warning about a repo-local override or a Git Bash
   `$HOME` that differs from the Windows profile.
6. `bin/ai-sync-memory push` — copy local memory back into the hub.
   **Deleting a memory needs `forget`, not `rm`.** Sync copies, never mirrors, so
   a plain delete does not propagate — the next `pull` restores it and any
   machine still holding it re-pushes it, making a WRONG memory immortal. Use
   `bin/ai-sync-memory forget <project> <file.md> "<reason>"` (reason mandatory);
   it tombstones the file in `memory/<project>/.forgotten` so every machine drops
   it on its next pull and no stale machine resurrects it. Then remove its line
   from that project's `MEMORY.md`. The `note ... in the hub but not on this
   machine` line is NOT proof of a deletion — it is equally memory from a machine
   you never pulled; never delete on that basis alone.
7. Commit + push `ai-devops` if memory (or intentional skill edits) changed. Use
   the noreply email (`u2giants@users.noreply.github.com`); keep the repo
   secret-free. If nothing changed, say so.
8. Report plainly: what synced, **the step-2 Phase 2 wiring verdict** (either
   "already current" or exactly what was installed), which memory projects changed,
   whether a push happened (SHA), and any manual step left (Claude Desktop restart).
   Never imply SSH/MCP live anywhere but this repo.

## Preview mode
`bin/ai-sync-memory {push,pull} --dry-run` and `bin/ai-gcloud-dflow --dry-run`
show what would happen without changing anything.

## Safety
- Never commit a secret; memory is secret-free by policy. Flag and STOP if a
  memory file holds a credential (it belongs in the `vibe_coding` 1Password vault).
- Skills flow repo→machine only; edit real skills in `ai-devops/skills/`.
- Don't force-pull/reset the hub to resolve a conflict — surface it.

## Related
`ai-devops/docs/config-inventory.md`, `docs/config-consolidation-proposal.md`
(Phases 1 and 2 complete), **`plan_phase3-config-consolidation.md` — the remaining
Phase 3 work; read it when Albert asks "what's left on the config consolidation?"**,
`docs/mcp-1password-rate-limit-hardening.md`, `HANDOFF.md` (pointer) plus the OPEN
files in `HANDOFF.d/`, `memory/README.md`, and
`plan_sync-machine-wrapper-reconciliation.md` (open plan; read STATUS first before
changing local AI-command reconciliation).
