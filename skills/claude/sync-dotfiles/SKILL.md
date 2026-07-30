---
name: sync-dotfiles
description: Sync this machine's AI config with the ai-devops hub. Use when the user says "sync my dotfiles", "sync my config", "pull the latest skills/instructions", or "push my dotfiles". Pulls latest skills + global instructions + memory from ai-devops and installs them, sets the dflow gcloud defaults, and pushes local memory changes back. No chezmoi — ai-devops is the single hub.
---

# sync-dotfiles

One phrase keeps every machine's AI config in step with the `ai-devops` hub
(GitHub `u2giants/ai-devops`): skills, global instructions, memory, gcloud
defaults, **and the secret/MCP/SSH plumbing** (Phase 2 of
`ai-devops/docs/config-consolidation-proposal.md`, shipped 2026-07-14).

> **This skill must bring the machine to FULL current state, or say loudly what is
> missing.** Until 2026-07-26 it did neither: it covered only skills + memory +
> gcloud while claiming SSH/MCP "are still the Dropbox scripts", so a machine that
> had only ever been synced kept **plaintext 1Password tokens inside its MCP config
> files** and the pre-fix "storming" launcher that rate-limit-locked the shared
> service account — and was told it was synced. Step 2 below exists to make that
> impossible. Never report success while Phase 2 wiring is absent.

## Trigger phrases
- "sync my dotfiles" / "sync my config"
- "pull the latest skills" / "push my dotfiles"

## What is (and isn't) synced

| Thing | Direction | Mechanism |
|---|---|---|
| Claude/Codex skills | repo → machine (repo is source of truth) | `bin/ai-install-skills` |
| Global instructions (`CLAUDE.md`, Codex `AGENTS.md`) | repo → machine (seeded only if absent; never clobbers local edits) | `bin/ai-install-skills` |
| New standing rules added to those templates | repo → machine, **by hand, step 4** — no script does this | you, appending the missing section |
| Auto-memory | machine ↔ repo (two-way, git-merged) | `bin/ai-sync-memory` |
| gcloud dflow defaults | apply on machine | `bin/ai-gcloud-dflow` |
| Secret plumbing (1Password token file, `mcp.env`), MCP launchers + token-free MCP wiring, SSH aliases, 916-alien key, Codex PATH | repo → machine, **checked every run (step 2)**; installed by the per-OS script when missing | `bin/setup-machine.ps1` (Windows) / `bin/setup-secrets.sh` (Ubuntu) |
| Dropbox scripts | **retired — not a config source.** Never send anyone there | — |

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
2. **Check the Phase 2 wiring (secrets, MCP, SSH) — never skip this.** Report each
   item as present or missing:
   - `~/.config/ai-devops/op-service-account` (the vault-locked 1Password
     service-account token file) exists.
   - Both launchers exist: `mcp-launch.cmd` + `mcp-remote-launch.cmd` (Windows) or
     `mcp-launch.sh` + `mcp-remote-launch.sh` (Ubuntu), in `~/.config/ai-devops/`.
   - `~/.config/ai-devops/mcp.env` exists **and matches** `config/mcp.env.example`
     in the repo (plain `diff`). A mismatch means this machine is on an older
     reference set — the `TRIGGER_ACCESS_TOKEN` pointer changed 2026-07-26, so this
     is live, not theoretical.
   - **No real plaintext token** in `~/.claude/settings.json`, `~/.codex/config.toml`,
     or the Claude Desktop config
     (`…\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude_desktop_config.json`
     on the Store/MSIX install). ⚠️ Use a **shape-based** check —
     `grep -oE '\bops_[A-Za-z0-9_-]{20,}' <file>` — NOT a bare `grep ops_`: the
     legitimate reference `op://vibe_coding/designflow-mcp/devops_token` contains the
     substring `ops_` and produced a false "plaintext token found" on 2026-07-26.
     A real service-account token is ~866 characters.
   - Windows: `~/.ssh/ai-devops.conf` exists and `~/.ssh/config` `Include`s it.
     Ubuntu: `~/.config/ai-devops/shellrc` exists and `.bashrc` sources it.
   **If anything is missing or a real token is found**, run the per-OS installer —
   `pwsh -NoProfile -ExecutionPolicy Bypass -File <repo>\bin\setup-machine.ps1 -RepoPath <repo>`
   or `<repo>/bin/setup-secrets.sh`. Two hard preconditions:
   (a) **pwsh 7** — the Windows script has no `#requires` and dies with cryptic parse
   errors under PowerShell 5.1; (b) **the token file must already exist**, because
   the script otherwise blocks forever on a token prompt and an AI session will hang.
   If the token file is absent, do NOT invoke the script — tell Albert the token is
   in 1Password `vibe_coding` → item `vibe_coding-service-account` → field
   `op_service_account_token` (NOT the empty `credential` field), and that it can be
   passed as `-Token <value>` or `OP_SERVICE_ACCOUNT_TOKEN=<value>`.
   A plaintext token or a missing launcher is a security/regression condition — fix
   it. If the only gap is cosmetic (e.g. the memory-sync task), report and let him
   choose. The installer rewrites the live Claude Desktop MCP config (backing up to
   `*.aidevops.bak` first), so say so before running it.
   **If everything is present, say "Phase 2 wiring already current" explicitly** —
   the report must distinguish *checked and fine* from *not checked*.
   After any MCP config rewrite: Claude Desktop must be **fully quit and reopened**
   (MCP servers only re-read config on a full restart), and deleting
   `~/.config/ai-devops/mcp-secrets.dpapi.json` forces a fresh secret resolve
   (it is a 15-minute cache).
3. **Lay down memory** from the hub: `bin/ai-sync-memory pull`. Only projects
   that already exist locally are updated, so a skip for a project this machine
   doesn't have is normal. **A skip for EVERY project is not** — nor is `push`
   reporting `0 project memory folder(s)`. Both now exit non-zero, because they
   mean the resolved Claude home is not the one Claude Code actually writes to
   (classically: Git Bash `$HOME` on a `Z:`/roaming drive). Previously this
   printed reassuring "expected" skips and returned success while memory never
   moved in either direction. If either fails, STOP and report the failure —
   never call the sync successful.
4. **Install skills + instructions:** `bin/ai-install-skills`. Refreshes
   `~/.claude/skills` (+ `~/.codex/skills`) and seeds global instructions
   **only if absent** — if `CLAUDE.md`/`AGENTS.md` differ it prints a diff hint
   and does NOT overwrite. Relay that hint if shown.
5. **Carry across any standing rule the local file is missing.** This step exists
   because step 4 never overwrites: skills propagate automatically, but a NEW
   STANDING RULE added to `templates/system/CLAUDE-global.md` reaches a machine
   only if someone carries it. Without this, a rule Albert set once is silently
   absent on every other machine — he believes it's everywhere; it isn't.
   Diff the template against the live file
   (`diff ~/.claude/CLAUDE.md templates/system/CLAUDE-global.md`, and the Codex
   pair). For each **rule section present in the template but absent locally**,
   append it verbatim (config edits are append-only — never rewrite or reorder
   the local file, which carries this machine's own atlas section and hand
   edits). Report what you appended. Leave machine-specific local content alone;
   you are only adding missing rules, never reconciling wording.
6. **Set gcloud defaults** (when this machine uses gcloud): `bin/ai-gcloud-dflow`.
   Skips cleanly if gcloud isn't installed.
6b. **Pin the Git commit identity:** `bin/ai-git-identity`. Idempotent; prints
   `already correct` and exits when there is nothing to do. This is NOT
   cosmetic. Git has no default identity: with none configured it does not stop,
   it silently invents one from the OS/AD account and stamps that on every
   commit. On al8960ofc that reached **231 commits already merged into `develop`
   AND `main`** across the dflow repos before anyone noticed — unfixable, since
   correcting them would mean force-pushing shared release history. The script
   also sets `user.useConfigOnly=true`, so if the config is ever lost Git FAILS
   LOUDLY instead of guessing. It is machine-level on purpose: Claude, Codex,
   GLM, Grok and Kimi all shell out to the same `git`, so one setting covers
   every agent — there is nothing per-agent to configure. Relay any warning it
   prints about a repo-local override or a Git Bash `$HOME` that differs from
   the Windows profile.
7. **Capture local memory** back to the hub: `bin/ai-sync-memory push`.
8. **Commit + push the hub** if step 3/7 changed anything: `git status` to see
   what changed, then stage `memory/` (and any skill/template edits the user made
   intentionally), commit with the `Co-Authored-By: Claude Opus 4.8` trailer and
   the noreply author email (`u2giants@users.noreply.github.com`), then
   `git push`. If nothing changed, say so.
9. **Report** in plain English: what was pulled, **the Phase 2 wiring verdict from
   step 2** (either "already current" or exactly what was installed), which memory
   projects changed, whether a commit/push happened (with SHA), and any manual step
   left (Claude Desktop restart). Never imply SSH/MCP live anywhere but this repo.

## Preview mode
If the user wants a dry run first: `bin/ai-sync-memory {push,pull} --dry-run` and
`bin/ai-gcloud-dflow --dry-run` print what they'd do without changing anything.

## Safety
- **Deleting a memory needs `forget`, not `rm`.** Sync copies, it never mirrors,
  so a plain delete does not propagate: the next `pull` restores the file from
  the hub and any machine still holding it re-pushes it. A memory you removed
  *because it was wrong* comes back. Use
  `bin/ai-sync-memory forget <project> <file.md> "<reason>"` — it records a
  tombstone in `memory/<project>/.forgotten`, so every machine drops the file on
  its next pull and no stale machine can resurrect it. A reason is mandatory
  (without it the fact just gets re-learned later). Then remove the file's line
  from that project's `MEMORY.md` and commit.
- `push` prints `note ...is in the hub but not on this machine`. That is NOT
  automatically a deletion — it is equally "memory from another machine you have
  never pulled". Never delete on that basis; use `forget` only when you know the
  memory is wrong.
- **Never commit a secret.** Memory is secret-free by policy; if a memory file
  contains a credential, STOP and flag it — it must move to 1Password
  (`vibe_coding` vault), not git.
- Skills flow repo→machine only. A skill edited locally in `~/.claude/skills` is
  NOT captured back; real skill changes belong in `ai-devops/skills/` (edit there,
  then this skill installs them).
- Don't force-pull or reset the hub to resolve a conflict — surface it instead.

## Related
`ai-devops/docs/config-inventory.md` (the full config map),
`ai-devops/docs/config-consolidation-proposal.md` (the phased plan; Phase 1 and 2
complete), `ai-devops/plan_phase3-config-consolidation.md` (**the remaining Phase 3
work — read this when Albert asks "what's left on the config consolidation?"**),
`ai-devops/docs/mcp-1password-rate-limit-hardening.md` (why the launchers cache),
`ai-devops/HANDOFF.md` (pointer) plus the OPEN files in `ai-devops/HANDOFF.d/`,
`ai-devops/memory/README.md`.
