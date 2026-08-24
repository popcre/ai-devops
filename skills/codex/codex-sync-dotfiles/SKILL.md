---
name: codex-sync-dotfiles
description: Sync this machine's public ai-devops configuration and its separate private portable-memory hub (Codex edition). Use for "sync my dotfiles", "sync my config", skills, globals, or memory. Installs current configuration and transactionally unions private memory without publishing facts.
---

# codex-sync-dotfiles

Codex twin of the Claude `sync-dotfiles` skill. Keeps this machine's AI config in
step with the public `u2giants/ai-devops` configuration hub and the separate
private `u2giants/ai-devops-memory` portable-memory hub: skills, global
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
| Claude/Codex skills | repo → machine (repo is source of truth) | `bin/ai-adopt-globals` → `bin/ai-install-skills` |
| Global instructions (`~/.codex/AGENTS.md`, `~/.claude/CLAUDE.md`) | repo → machine; shared body replaced, machine section preserved and verified | `bin/ai-adopt-globals` |
| Auto-memory | machine ↔ private memory hub (lossless transaction) | `bin/ai-memory-sync` |
| gcloud dflow defaults | apply on machine | `bin/ai-gcloud-dflow` |
| Local AI commands (Grok, Kimi, DeepSeek, GLM launcher) | repo → machine, checked every run | `bin/ai-machine-tools-doctor` + narrow platform installer |
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
1b. **Reconcile local AI commands before installing skills.** Run
   `bin/ai-machine-tools-doctor`. If it fails for Grok, Kimi, or DeepSeek, run
   Windows `pwsh -NoProfile -ExecutionPolicy Bypass -File <repo>\bin\install-machine-tools.ps1 -RepoPath <repo>`
   or Ubuntu `<repo>/bin/install-machine-tools.sh`, then re-run the doctor. If
   only `ai-glm` is missing, use the existing GLM installer in step 2b because
   it owns that command and service. Stop if the final doctor is nonzero. Say
   "Local AI commands already current" or name the launchers installed. On
   Windows, add `%USERPROFILE%\.local\bin` to this process PATH and use `hash -r`
   in Git Bash after repair. Never use the broad machine setup for this repair.
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

3. `bin/ai-memory-sync pull` — lay private hub memory onto this machine (only existing
   local projects update; a skip for a project this machine doesn't have is
   normal). **But if EVERY project skips, or `push` reports 0 folders, the
   script now exits non-zero — that is a real failure, not "expected". It means
   the resolved Claude home is not the one Claude Code uses. Do not report the
   sync as successful; report the failure.**
4. **Install skills and adopt both global instruction bodies:** run
   `bin/ai-adopt-globals`. It saves each original, refreshes both skill trees,
   replaces the shared Claude/Codex instruction bodies, restores the detected
   machine section, and proves both the body and restored section by comparison.
   A nonzero result means the sync is incomplete; do not fall back to
   `ai-install-skills`, append rules by hand, or report success. The installer
   contains a one-time bridge so a machine still running the previous version of
   this skill performs the adoption during its first post-pull sync.

   **Then PROVE it landed** — exit 0 means the files are correct on disk, not that
   anything read them. Check a distinctive phrase from a rule you expect in both
   live files, e.g.:

   ```bash
   grep -c "Move values only through pipes" ~/.codex/AGENTS.md ~/.claude/CLAUDE.md
   ```

   Both must return 1. If either returns 0, adoption did not take — say so and
   STOP; do not report the sync successful.

4bb. **Install the protected topology:** `bin/ai-private-config sync`.
   Some tools (e.g. `ai-headroom`) deliberately keep private addresses OUT of
   this public repo and read them from `u2giants/ai-devops-private-config`. A
   machine without it has tools that look installed and then fail confusingly —
   on 2026-08-23 `ai-headroom status` reported "Proxy health: NOT REACHABLE.
   Claude WILL FAIL to connect" against a perfectly healthy proxy, purely
   because this config was missing. Verify afterwards:

   ```bash
   ai-private-config value headroom_proxy_url
   ```

   It must print a URL. If it errors, say so and STOP — do not report the sync
   successful.

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
5c. `bin/ai-codex-memories` — switch on Codex's own memory feature. Idempotent;
   prints `OK Codex memories already enabled` when there is nothing to do and
   exits 2 informationally where Codex is absent. Codex stores memories in
   `~/.codex/memories_<n>.sqlite`; Claude stores markdown under
   `~/.claude/projects/*/memory`; **neither reads the other's**. The feature ships
   OFF, so an un-run machine learns nothing across Codex sessions. Per-MACHINE
   state that `git pull` cannot deliver, hence every sync. The script uses Codex's
   own `codex features enable memories` and backs up `config.toml` first — never
   hand-edit it. **Limitation to state plainly:** the SQLite store is machine-local
   and NOT synced by `ai-sync-memory` (which covers Claude's markdown only), so
   durable cross-machine facts belong in Claude's memory or repo docs.
5c2. `bin/ai-install-memory-hook` — install the memory-index hook (Claude only; it
   registers a PostToolUse Write|Edit entry in `~/.claude/settings.json`). Idempotent,
   strictly additive, backs the file up, and refuses if that file does not parse.
   It catches a memory written without a `MEMORY.md` index line in the same turn —
   the failure that left 20 of 34 shared-db memories unreachable until 2026-08-21.
   Run it from a Codex sync too: the machine, not the client, is what is missing it.
5d. Check the weekly read-only memory audit exists (`ai-memory-health` scheduled
   task on Windows, registered by `bin/install-memory-health-task.ps1`). If absent,
   say so and offer to register it. Never schedule anything that EDITS memory
   unattended: tombstoned deletions propagate to every machine and survive a later
   pull, so a wrong automated delete cannot be undone.
6. `bin/ai-memory-sync sync` — union local memory into the private hub and pull
   the verified union back. This command owns privacy verification, health,
   commit, push, and recovery; never stage memory in public `ai-devops`.
   **Deleting a memory needs `forget`, not `rm`.** Sync copies, never mirrors, so
   a plain delete does not propagate — the next `pull` restores it and any
   machine still holding it re-pushes it, making a WRONG memory immortal. Use
   `bin/ai-memory-sync forget <project> <file.md> "<reason>"` (reason mandatory);
   it tombstones the file in `memory/<project>/.forgotten`, removes its index
   line, and commits/pushes the private hub in the same transaction, so every
   machine drops it and no stale machine resurrects it. The `note ... in the hub but not on this
   machine` line is NOT proof of a deletion — it is equally memory from a machine
   you never pulled; never delete on that basis alone.
7. Verify `git status --short -- memory/` in public `ai-devops` shows no
   operational fact change. Commit only intentional public tooling or skill
   edits there; private memory commits are exclusively `ai-memory-sync`'s job.
8. Report plainly: what synced, **the step-2 Phase 2 wiring verdict** (either
   "already current" or exactly what was installed), which memory projects changed,
   whether a push happened (SHA), and any manual step left (Claude Desktop restart).
   Never imply SSH/MCP live anywhere but this repo.

## Preview mode
`bin/ai-memory-sync --dry-run` and `bin/ai-gcloud-dflow --dry-run`
show what would happen without changing anything.

## Safety
- Never commit a secret; memory is secret-free by policy. Flag and STOP if a
  memory file holds a credential (it belongs in the `vibe_coding` 1Password vault).
- Skills flow repo→machine only; edit real skills in `ai-devops/skills/`.
- Do not manipulate the private clone after a failure; the transaction preserves
  and retries the exact rejected commit.

## Related
`ai-devops/docs/config-inventory.md`, `docs/config-consolidation-proposal.md`
(Phases 1 and 2 complete), **`plan_phase3-config-consolidation.md` — the remaining
Phase 3 work; read it when Albert asks "what's left on the config consolidation?"**,
`docs/mcp-1password-rate-limit-hardening.md`, `HANDOFF.md` (pointer) plus the OPEN
files in `HANDOFF.d/`, `memory/README.md`, and
`plan_sync-machine-wrapper-reconciliation.md` (open plan; read STATUS first before
changing local AI-command reconciliation).
