---
name: sync-dotfiles
description: Sync this machine's public ai-devops configuration and its separate private portable-memory hub. Use when the user says "sync my dotfiles", "sync my config", "pull the latest skills/instructions", or "push my dotfiles". Installs current skills and globals, verifies machine wiring, and transactionally unions private memory without publishing facts.
---

# sync-dotfiles

One phrase keeps every machine's public AI configuration in step with
`popcre/ai-devops` and portable Markdown memory in the separate private
`u2giants/ai-devops-memory` hub: skills, global instructions, memory, gcloud
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
| Claude/Codex skills | repo → machine (repo is source of truth) | `bin/ai-adopt-globals` → `bin/ai-install-skills` |
| Global instructions (`CLAUDE.md`, Codex `AGENTS.md`) | repo → machine; shared body replaced, machine section preserved and verified | `bin/ai-adopt-globals` |
| Claude tool permissions (`~/.claude/settings.json` allow list) | repo → machine, **checked every run (step 5b)**; merged in when missing, never removed | `bin/ai-claude-permissions` (list: `config/claude-permissions.allow`) |
| Auto-memory | machine ↔ private memory hub (lossless transaction) | `bin/ai-memory-sync` |
| gcloud dflow defaults | apply on machine | `bin/ai-gcloud-dflow` |
| Local AI commands (Grok, Kimi, DeepSeek, GLM launcher) | repo → machine, checked every run | `bin/ai-machine-tools-doctor` + narrow platform installer |
| Codex's own memory feature (separate store from Claude's; OFF by default) | enabled on machine, **checked every run (step 6c)** | `bin/ai-codex-memories` |
| Memory-index hook (blocks a memory from going unindexed) | installed on machine, **checked every run (step 6c2)** | `bin/ai-install-memory-hook` |
| Weekly read-only memory-health report | per-machine task, **checked every run (step 6d)** | `bin/install-memory-health-task.ps1` → `bin/ai-memory-health` |
| Secret plumbing (1Password token file, `mcp.env`), MCP launchers + token-free MCP wiring, SSH aliases, 916-alien key, Codex PATH | repo → machine, **checked every run (step 2)**; installed by the per-OS script when missing | `bin/setup-machine.ps1` (Windows) / `bin/setup-secrets.sh` (Ubuntu) |
| GLM server (pinned OpenCode, agents, service, `ai-glm` on PATH) | repo → machine, **checked every run (step 2b)** via `ai-glm doctor`; installed/repaired when it fails | `bin/setup-opencode-glm.ps1` (Windows) / `bin/setup-opencode-glm.sh` (Ubuntu) |
| Dropbox scripts | **retired — not a config source.** Never send anyone there | — |

## The installed copy is a build output — never edit it

`~/.claude/skills/<name>/` and `~/.codex/prompts/` are **generated**.
`bin/ai-install-skills` rewrites them from the ai-devops working tree on every
sync and stamps each skill with a `.ai-devops-managed` fingerprint file. Any file
whose fingerprint no longer matches is classified as a local edit: it is copied to
`<client>/skills-backup/<name>/` and then overwritten.

So **a change made only under `~/.claude/skills` is temporary.** It survives until
the next time anyone on this machine syncs, then it is gone — and because each run
replaces the previous backup, a second sync erases the evidence of the first.

To change a skill: edit `<repo>/skills/...`, commit, push. Then sync.

Two traps worth knowing:

- **Line endings alone trigger the overwrite.** Git stores these files with Unix
  line endings and checks them out on Windows with Windows line endings, so a file
  installed straight from `git show` never matches the fingerprint of the same file
  installed from the working tree. Identical text, flagged as edited.
- **The install serves whatever the working tree holds at that moment.** If a
  concurrent session has the ai-devops clone on another branch, mid-rebase, or
  dirty, the sync installs that instead. The run log records the revision, branch
  and dirty state of every run for exactly this reason.

Who changed my skills, and when:

```bash
ai-install-skills --log
```

It prints this machine's append-only install log
(`~/.cache/ai-devops/install-log.tsv`): one `run-start` line per run with the
source revision, one `overwrote-local-edits` line naming every locally edited file
that was replaced and where the backup went, and a `run-end` line. Dry runs write
nothing. Added 2026-08-18, after an edit to `session-docs-update` was silently
replaced twice in one afternoon and there was no record to explain it.

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
1b. **Reconcile local AI commands before installing skills.** Run
   `bin/ai-machine-tools-doctor`. If it fails for Grok, Kimi, or DeepSeek, run
   Windows `pwsh -NoProfile -ExecutionPolicy Bypass -File <repo>\bin\install-machine-tools.ps1 -RepoPath <repo>`
   or Ubuntu `<repo>/bin/install-machine-tools.sh`, then re-run the doctor. If
   only `ai-glm` is missing, use the existing GLM installer in step 2b because
   it owns that command and service. Stop if the final doctor is nonzero. Say
   "Local AI commands already current" or name what was installed. On Windows,
   update this process PATH and run `hash -r` in Git Bash after repair. Never
   use the broad machine setup for this repair.
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
2b. **Check the GLM server** (`ai-glm`), because it is machine-local state that a
   `git pull` alone cannot install. Run `ai-glm doctor`. Three outcomes:
   - **Exit 0** — say "GLM server already current" explicitly, and move on.
   - **Exit non-zero, or `ai-glm` not found** — install/repair it. It is idempotent
     and installs its own prerequisites, so just run it:
     Windows: `pwsh -NoProfile -ExecutionPolicy Bypass -File <repo>\bin\setup-opencode-glm.ps1 -RepoPath <repo>`
     Ubuntu:  `<repo>/bin/setup-opencode-glm.sh`
     Then re-run `ai-glm doctor` and report the result. Do NOT report the sync as
     successful while doctor still fails.
   - **No 1Password service-account token file yet** — do not run it (same rule as
     step 2: it needs the token). Report that GLM is unavailable until the token is
     in place, and say so plainly rather than skipping silently.
   The pinned OpenCode version lives in `config/opencode/version`; when a pull changes
   it, the setup script installs the new build and doctor verifies the running server
   matches. That is why this step runs on every sync and not only on a fresh machine.

3. **Memory is one transaction, and it runs at most once a day.** Step 7 does the
   whole round trip; there is no separate pull step. Memory is the slow half of a
   sync — it fetches the private hub, unions every project both ways, audits
   health, then commits and pushes — and on 2026-08-27 it measured 2m18s of a
   3m10s sync. `sync-if-stale` skips it when the last success is under 24 hours
   old, so an ordinary sync costs about 50 seconds and memory still converges
   daily. Force one at any time with `bin/ai-memory-sync sync`.
   When it does run, only projects that already exist locally are updated, so a skip for a project
   that already exist locally are updated, so a skip for a project this machine
   doesn't have is normal. **A skip for EVERY project is not** — nor is `push`
   reporting `0 project memory folder(s)`. Both now exit non-zero, because they
   mean the resolved Claude home is not the one Claude Code actually writes to
   (classically: Git Bash `$HOME` on a `Z:`/roaming drive). Previously this
   printed reassuring "expected" skips and returned success while memory never
   moved in either direction. If either fails, STOP and report the failure —
   never call the sync successful.
4. **Install skills and adopt both global instruction bodies:** run
   `bin/ai-adopt-globals`. It saves each original, refreshes both skill trees,
   replaces the shared Claude/Codex instruction bodies, restores the detected
   machine section, and proves both the body and restored section by comparison.
   A nonzero result means the sync is incomplete; do not fall back to
   `ai-install-skills`, append rules by hand, or report success. The installer
   contains a one-time bridge so a machine still running the previous version of
   this skill performs the adoption during its first post-pull sync.

   **Then PROVE it landed**, because exit 0 means the files are right on disk, not
   that anything read them. Pick a distinctive phrase from a rule you expect and
   check both live files. Confirm the phrase is CURRENTLY in the template first
   (globals get condensed over time, and a stale probe string fails for the wrong
   reason). Example:

   ```bash
   grep -c "Move values only through pipes" ~/.claude/CLAUDE.md ~/.codex/AGENTS.md
   ```

   Both must return 1. If either returns 0, the adoption did not take — say so
   and STOP; do not report the sync successful.

4c. **Install the protected topology:** `bin/ai-private-config sync`.
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

5. **Ensure the required Claude tool permissions:** `bin/ai-claude-permissions`.
   Merges every entry in `config/claude-permissions.allow` into the USER-level
   `~/.claude/settings.json`, so it covers every project on the machine. It is
   idempotent, strictly additive (never removes an entry, never touches `deny`
   or anything else), and backs the file up to `settings.json.aidevops.bak`
   before its first change. Prints `OK all N required permission(s) already
   present` when there is nothing to do — say that verdict out loud, the same
   way step 2 distinguishes *checked and fine* from *not checked*.
   This is not cosmetic: Claude Code STOPS and asks before using a tool that is
   not allowed, and in a delegated/unattended session (a subagent doing visual
   verification, a background task) nobody is there to answer — the work stalls
   and the transcript reads like the tool is broken rather than un-permitted.
   That is exactly how browser screenshotting worked on one machine and silently
   did not on the others (2026-08-13). If it exits 3 (`ERROR unparseable JSON`),
   the local settings file is already broken — do NOT rewrite it; report it and
   let Albert decide. To add a permission for every machine, add the line to
   `config/claude-permissions.allow` in the repo and commit; never hand-edit one
   machine's settings file.
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
6c. **Switch on Codex's own memory:** `bin/ai-codex-memories`. Idempotent; prints
   `OK Codex memories already enabled` and exits when there is nothing to do, and
   exits 2 with an informational line on a machine that has no Codex. This is NOT
   the same store as Claude's: Codex keeps its memories in
   `~/.codex/memories_<n>.sqlite`, Claude keeps markdown under
   `~/.claude/projects/*/memory`, and **neither client reads the other's**. Codex
   ships the feature OFF, so a machine that never had this run learns nothing
   across Codex sessions — the facts a Codex session establishes die with it.
   It is per-MACHINE state a `git pull` cannot deliver, which is why it runs every
   sync and not only on a fresh machine. The script calls Codex's own
   `codex features enable memories` and backs up `config.toml` first; never
   hand-edit that file (standing rule 16 — Claude setup scripts must not touch
   Codex config).
   **Known limitation, say it out loud rather than implying coverage:** Codex's
   SQLite memory is machine-local and is NOT synced by `ai-sync-memory`, which
   handles Claude's markdown memory only. Facts Codex learns on one computer do
   not reach the others. Durable cross-machine facts still belong in Claude's
   memory files or in the repo's own docs.
6c2. **Install the memory-index hook:** `bin/ai-install-memory-hook`. Idempotent;
   prints `OK memory-index hook already registered` when there is nothing to do.
   It copies the hook to `~/.config/ai-devops/memory-index-hook` and registers a
   PostToolUse `Write|Edit` entry in the USER-level `~/.claude/settings.json`,
   strictly additively, backing the file up first and refusing outright if that file
   does not parse (a broken `settings.json` silently disables EVERY setting in it).
   **What it prevents:** a memory file that never gets a line in `MEMORY.md` is
   invisible forever, because only the index is loaded into a session. On 2026-08-21
   an audit found 20 of 34 shared-db memories and 17 of 28 dflow memories in exactly
   that state, including owner rulings Albert had made himself. The weekly report
   detects that after the fact; this hook catches it in the same turn the file is
   written. Report the verdict out loud.
6d. **Report the memory-health task, don't assume it:** the weekly read-only audit
   (`bin/ai-memory-health`) is registered by
   `bin/install-memory-health-task.ps1` and is per-machine. Check for it with
   `Get-ScheduledTask -TaskName ai-memory-health` on Windows; if it is absent, say
   so and offer to register it. Never register an unattended job that EDITS
   memory: `ai-sync-memory` tombstones make a deletion propagate everywhere and
   survive a later pull, so a wrong automated delete is unrecoverable. The audit
   reports; a human approves every change.
7. **Capture and publish local memory transactionally:**
   `bin/ai-memory-sync sync-if-stale`. This command alone owns the private clone,
   privacy proof, union, health gate, commit, push, retry state, and success
   message. It prints `memory sync skipped` when the last success is under 24
   hours old — say that verdict out loud rather than implying memory moved. Use
   plain `sync` instead when the user asks for memory specifically, when a memory
   was just written that another machine needs, or after any `forget`. Never stage memory in the
   public `ai-devops` checkout and never hand-compose a memory commit.
8. **Verify public separation:** `git status --short -- memory/` in `ai-devops`
   must show no operational fact change. Only `memory/README.md` and the
   secret-free mapping/schema belong in this public repository.
9. **Report** in plain English: what was pulled, **the Phase 2 wiring verdict from
   step 2** (either "already current" or exactly what was installed), which memory
   projects changed, whether a commit/push happened (with SHA), and any manual step
   left (Claude Desktop restart). Never imply SSH/MCP live anywhere but this repo.

## Preview mode
If the user wants a dry run first: `bin/ai-memory-sync --dry-run` and
`bin/ai-gcloud-dflow --dry-run` print what they'd do without changing anything.

## Safety
- **Deleting a memory needs `forget`, not `rm`.** Sync copies, it never mirrors,
  so a plain delete does not propagate: the next `pull` restores the file from
  the hub and any machine still holding it re-pushes it. A memory you removed
  *because it was wrong* comes back. Use
  `bin/ai-memory-sync forget <project> <file.md> "<reason>"` — it records a
  tombstone in `memory/<project>/.forgotten`, so every machine drops the file on
  its next pull and no stale machine can resurrect it. A reason is mandatory
  (without it the fact just gets re-learned later). The command removes the
  file's index line and commits/pushes the private hub in the same transaction;
  do not edit an index or public repository by hand.
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
- Do not manipulate the private clone to resolve a failure. `ai-memory-sync`
  preserves the exact rejected commit and retries it on the next run.

## Related
`ai-devops/docs/config-inventory.md` (the full config map),
`ai-devops/docs/config-consolidation-proposal.md` (the phased plan; Phase 1 and 2
complete), `ai-devops/plan_phase3-config-consolidation.md` (**the remaining Phase 3
work — read this when Albert asks "what's left on the config consolidation?"**),
`ai-devops/docs/mcp-1password-rate-limit-hardening.md` (why the launchers cache),
`ai-devops/HANDOFF.md` (pointer) plus the OPEN files in `ai-devops/HANDOFF.d/`,
`ai-devops/memory/README.md`, and
`ai-devops/plan_sync-machine-wrapper-reconciliation.md` (open plan; read STATUS
first before changing local AI-command reconciliation).
