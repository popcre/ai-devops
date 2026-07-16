# HANDOFF — machine-config consolidation onto ai-devops (updated 2026-07-16)

> Read this whole file before continuing. It is written for a developer with
> ZERO prior context — every path, alias, and identifier is defined. If anything
> here would make you ask a question, the answer is somewhere below.

## 1. What this application is

`ai-devops` (GitHub `u2giants/ai-devops`, **private**) is **not** an app — it's
Albert's personal **toolkit for backing up and distributing his AI coding setup**
across his machines:

- **Machines:** 3 Windows 11 dev boxes — `916` ("916-alien"), `t16` (`albt16`,
  the usual checkout for this repo), `4837` — and Ubuntu server(s) (`hetz`,
  `seafile`, `comp`, …) where Albert also codes via the Claude/Codex CLI over SSH.
- **What it is:** Bash CLI scripts + Markdown + skill/prompt scaffolding. Installed
  per machine by `install.sh` (Ubuntu) / `bin/install-ai-devops-windows.ps1`
  (Windows) / `bin/ai-install-skills`.
- **What it already distributes:** Claude+Codex **skills**
  (`skills/claude/*`, `skills/codex/*` → `~/.claude/skills`, `~/.codex/skills`),
  **global instructions** (`templates/system/CLAUDE-global.md` → `~/.claude/CLAUDE.md`;
  `AGENTS-global-codex.md` → `~/.codex/AGENTS.md`), and **workflow config**
  (`config/*.env.example` → `/etc/ai-devops/`, never clobbered).
- **Size:** ~1.5 GB, almost all in `claude_chats/` (~662 MB) + `codex_chats/`
  (~398 MB) transcript archives — excluded from AI context, may contain secrets.

Read `AGENTS.md` first for the full repo picture; it's the canonical guide.

## 2. What we set out to do this session, and why

Albert felt his machine config was "scattered across a lot of places." **Goal:**
make `ai-devops` the **single hub** that configures every machine on both OSes,
and add a "sync my dotfiles" capability — WITHOUT a new tool. **Trigger:** a dflow
UI task (making a Save control a button) led to setting gcloud defaults, which led
to "can I sync this across machines?", which surfaced the scatter.

The full current-state map is [`docs/config-inventory.md`](docs/config-inventory.md);
the phased plan is [`docs/config-consolidation-proposal.md`](docs/config-consolidation-proposal.md).
This handoff is the **live state + next steps**; those docs are the reference.

## 3. Current state — what is true right now

> **2026-07-15 update (read first).** Since this section was first written, **Phase 2
> was built and pushed** on 2026-07-14 afternoon (commits `5868f19`→`26c176f`) and
> then **adopted + verified on machine `t16` on 2026-07-15**. The Phase-1-era text
> below is kept for history; the authoritative Phase-2 state is in **§3a** just under it.

### 3a. Phase 2 state (authoritative, 2026-07-15)

**Built and committed (2a/2b/2c):**
- **[`bin/setup-machine.ps1`](bin/setup-machine.ps1)** — one-script Windows onboarding:
  base tools, skills/globals, service-account **token file**
  (`~/.config/ai-devops/op-service-account`, user-only), **`mcp.env`** (`op://`
  refs), MCP **launchers**, **916-alien key** restored from 1Password, **SSH
  aliases** (`~/.ssh/ai-devops.conf`, `Include`d), Claude Desktop MCP wiring
  (`-SkipDesktopMcp` skips it), memory-sync scheduled task.
- **[`bin/setup-secrets.sh`](bin/setup-secrets.sh)** — Ubuntu secret-plumbing half.
- **[`config/mcp.env.example`](config/mcp.env.example)** + **[`config/ssh-config.template`](config/ssh-config.template)** — committed, secret-free (`op://` refs / public host data only).
- **1Password:** the `916-alien SSH key` item now exists in `vibe_coding` (added 2026-07-14).

**Adopted + VERIFIED on t16 (2026-07-15):** token installed straight from vault →
locked-down file (never materialized in the session); `mcp.env` matches repo;
secrets resolve from the token file; `~/.ssh/config` includes `ai-devops.conf`;
**`ssh vps whoami` → `root`**. Ran with `-SkipDesktopMcp`, so **t16's Claude
Desktop MCP config was deliberately NOT changed** (pending Albert's go-ahead).

**Still open in Phase 2:**
- **t16 Claude Desktop MCP migration** — held for explicit approval (it rewrites
  the live daily-driver MCP config; the script backs up to `*.aidevops.bak` first).
- **2d token rotation** — the two MCP bearers look already rotated (`designflow-mcp`
  item tagged `mcp-rotation`, updated 2026-07-14 17:20); the **Trigger PAT** looks
  NOT yet rotated (last updated 2026-07-09). Needs Albert's approval to rotate.
- **Rollout to 916, 4837, and the Ubuntu servers** — not yet done.

The rest of this file (Phase-1 history) is unchanged below.

---

**Phase 1 implementation and the first real memory push are DONE, committed,
and pushed.** Relevant commits on `main`:
- `28c44bc` — Phase 1 build (skill, gcloud helper, memory sync, docs)
- `e64c7cf` — this HANDOFF + AGENTS.md "HANDOFF present" notes
- `28d23d1` — comprehensive config-consolidation docs and handoff pass
- `c6c6ee3` — first real memory push from `916-alien` into `memory/`
- `1c7df3b` — mandatory fresh-session completeness loop added to both the Claude
  and Codex Markdown-update skills

**Files this session created/changed in ai-devops:**
| File | What |
|---|---|
| `skills/claude/sync-dotfiles/SKILL.md` | "sync my dotfiles" (Claude) — installed on t16 |
| `skills/codex/codex-sync-dotfiles/SKILL.md` | Codex twin — installed on t16 |
| `bin/ai-gcloud-dflow` | sets dflow gcloud defaults (project `lithe-breaker-323913`, region `us-east4`) |
| `bin/ai-sync-memory` | two-way memory sync w/ per-machine slug canonicalization |
| `memory/README.md`, `memory/project-map.tsv` | memory tree docs + slug overrides |
| `docs/config-inventory.md` | the full scatter map (paths, SSH aliases, MCP list, 1Password item titles) |
| `docs/config-consolidation-proposal.md` | the 3-phase plan w/ implementation detail |
| `AGENTS.md` | structure/commands/pending-work rows + HANDOFF-present notes |
| `skills/claude/session-docs-update/SKILL.md` | Claude docs updater now must reread and revise handoffs until the fresh-session completeness question passes |
| `skills/codex/codex-docs-update/SKILL.md` | Codex twin of the same mandatory revision loop |

**Verified:** `ai-gcloud-dflow --dry-run` prints the 5 correct commands;
`ai-sync-memory push --dry-run` maps this machine's 4 projects (dflow, oracle,
ansible, 1password-mcp) → `memory/<project>/`; `ai-install-skills` installed the
new skills to `~/.claude/skills` + `~/.codex/skills` without clobbering globals.

**Verified on 2026-07-14:** `memory/` now contains real project memory from
`916-alien` (commit `c6c6ee3`); the Windows installer refreshed all 16 Claude
skills and 12 Codex toolkit skills on machine `AL8960OFC`; both installed docs
skills exactly match their repository sources; both skill packages pass
`quick_validate.py`.

**NOT done (as of the Phase-1 writing; see §3a for the current Phase-2 truth):**
propagation and memory collection on every remaining machine; Phase 3. *(Phase 2
was subsequently built + verified on t16 — §3a.)*

**Script git mode note:** `bin/ai-gcloud-dflow` and `bin/ai-sync-memory` are
tracked `100644` (not `+x`). This MATCHES the existing `bin/ai-install-skills`
(Windows-authored; execution handled by `install.sh`/git-bash). Not a bug — do
not "fix" it in isolation.

### 3b. Codex PATH + `codex-cli` MCP state (authoritative, 2026-07-16)

Separate workstream, same consolidation goal: Codex is now set up **by these
scripts**, not by hand or by the Dropbox scripts.

| Thing | State |
|---|---|
| Codex PATH (Windows) | **Fixed on t16 only.** `bin/setup-machine.ps1` step "Codex PATH" prepends `%USERPROFILE%\.codex\packages\standalone\current\bin` (real package bin) ahead of the broken `…\Programs\OpenAI\Codex\bin` junction, then verifies with a real sandboxed write. **916 and 4837 still need the script run.** |
| `codex-cli` MCP (Windows) | Wired by `setup-machine.ps1` to the **absolute** `codex.exe` + `mcp-server`. Replaces the third-party `@cexll/codex-mcp-server` npx wrapper that was previously in-flight here. |
| `codex-cli` MCP (Ubuntu) | Wired by `bin/setup-secrets.sh` into `~/.claude/settings.json` via `python3`, preserving all other servers/keys. **Written + logic-tested in Ubuntu 26.04 (WSL), but NOT yet run on the real `hetz` server.** |
| `ai-devops doctor` | Now proves the Codex sandbox with a real `--sandbox workspace-write` write (`check_codex_sandbox`). Tested both ways: passes on a good install, fails with cause+fix on the broken junction path. |
| Upstream | Not our bug to fix. [openai/codex#32655](https://github.com/openai/codex/issues/32655) — we commented confirming 0.144.5 reproduces. |

**Verified on t16:** bare `codex` resolves to the real package bin and
`codex exec --sandbox workspace-write` writes files; the native MCP `codex` tool
was called end-to-end and wrote a file. **Not verified:** the MCP entries as seen
by a restarted Claude Desktop / Claude Code (requires an app restart), and
anything on 916 / 4837 / `hetz`.

**Trade-off recorded:** dropping the third-party wrapper loses `changeMode`
(structured OLD/NEW patch output), `fetch-chunk`, `batch-codex` (parallel task
delegation) and `brainstorm`. All are reproducible by prompting the native `codex`
tool. If a future session needs structured patch output, this is the decision to
revisit — see AGENTS.md → Intentional quirks.

## 4. Everything we tried that did NOT work (don't repeat these)

- **Trusting `codex --version` / `codex login status` as proof Codex works.** Both
  pass, and exit 0, on a machine where **every** sandboxed write silently fails.
  This is the single most expensive mistake of 2026-07-16. Presence is not
  capability — only a real `workspace-write` write proves it (now what
  `ai-devops doctor` does).
- **Concluding "the helpers are missing" from a directory listing.** `find -type f`
  showed `…\Programs\OpenAI\Codex\bin` as empty, so the helpers looked absent. They
  were not — `find` does not traverse the **junction**. The package was complete all
  along. Use `Get-Item <dir> | Select LinkType,Target` (PowerShell) to see what a
  Windows dir really is.
- **Concluding the 1Password MCP `op_run` "env injection is broken".** It is not.
  `argv:["bash",…]` on Windows spawns **WSL** bash, and WSL does not inherit the
  injected Windows env, so vars arrive empty. Native children (cmd `%VAR%`,
  PowerShell `$env:VAR`, `node`) get them fine, and `op://` refs resolve and are
  redacted correctly. One `pwd` (→ `/mnt/c/...`) would have shown this in seconds.
- **`codex update` from Git Bash.** Fails on an msys `tar` vs `C:` path clash. Use
  the official PowerShell installer in **native** PowerShell
  (`irm https://chatgpt.com/codex/install.ps1 | iex`).
- **Backgrounding codex with `nohup … &` inside an already-backgrounded task.** The
  wrapper exits instantly, the harness reports "completed, exit 0", and codex is
  orphaned having done nothing. An exit code is not evidence work happened — check
  the working tree.
- **Trusting PowerShell 5.1's legacy `PSParser` as a syntax check.** It reported 25
  errors in `setup-machine.ps1`; the real parser reports **0**. The script is
  pwsh-7-only by design (HEAD already failed 5.1 the same way). Use
  `[System.Management.Automation.Language.Parser]::ParseFile`.
- **Guarding on `command -v python3`.** On Windows that matches the Store *stub*,
  which satisfies presence and then fails on use. `setup-secrets.sh` now probes
  `python3 -c 'import json'` instead. (Same lesson as the `--version` trap, found in
  our own code.)
- **Filing a fresh upstream issue without searching first.** The bug already had 8+
  open reports on `openai/codex`. A 9th adds noise; a comment confirming a newer
  version adds signal.

- **Verifying the dflow deploy via GLOBAL gcloud.** `gcloud builds triggers list`
  returned `[]` and `gcloud builds list` showed only stale 2024 builds → looked
  like "sandbox-albert isn't deployed via Cloud Build." **WRONG.** The
  triggers/builds are **2nd-gen REGIONAL**; you must pass
  `--project=lithe-breaker-323913 --region=us-east4`. Then triggers + live builds
  appear. This wasted real time — it's why `ai-gcloud-dflow` and the inventory doc
  exist.
- **gcloud default project was `dflow-plm`** — a stale/empty project that doesn't
  really exist. Caused "Cloud Build API not enabled." Wiped everywhere; the ONLY
  real project is `lithe-breaker-323913`.
- **Guessing the Cloud Run region from the URL** — the `-uk` in the `.run.app`
  host suggested `europe-west2`; actual region is `us-east4`. Get region from
  `gcloud run services list`, don't infer.
- **chezmoi** — investigated as the dotfiles tool, then rejected: duplicates
  ai-devops's installer machinery and would need a 1.5 GB clone as a subfolder.
  **Do not revisit it.**
- **`yarn` not on PATH** (Windows, both bash and PowerShell) — use `corepack yarn`.
- **Git initially auto-selected `albert@popcre.com` for the 2026-07-14 skill
  commit.** That violates this repo's noreply-author rule. The commit was amended
  before push, repo-local `user.name`/`user.email` were corrected, and the pushed
  commit `1c7df3b` has author `Albert Hazan
  <u2giants@users.noreply.github.com>`. Do not reintroduce the old identity.

## 5. Root causes and key findings

- **Config lives in THREE overlapping systems + gaps** (full map in
  `docs/config-inventory.md`):
  (a) **ai-devops** — skills, global instructions, workflow config, transcripts;
  (b) **Dropbox `\vibe coding\ssh keys\master_setupsshwindows.ps1`** — writes
  `~/.ssh/config` (host aliases: `coolify`/`vps`/`vps2`, `seafile`, `edge1`/`edge2`,
  `backupwiz`, `comp`, `auth`, `vpn`, …) + the `916-alien` private key;
  (c) **Dropbox `\vibe coding\…MCP servers\`** — `setup-claude-mcps.ps1` /
  `setup-codex-mcps.ps1` → MCP config (servers: ag-grid, devops-mcp, synology,
  playwright, vercel, trigger, 1password) with tokens.
  Synced by **nothing** before this session: auto-memory, gcloud defaults,
  portable Codex prefs.
- **Per-machine memory slugs differ** — same project is `C--repos-dflow` on one
  box, `D--repos-dflow` on another. `ai-sync-memory` canonicalizes (drop through
  last `repos-`; overrides in `memory/project-map.tsv`).
- **Two plaintext-secret landmines** (why naive git-sync is unsafe):
  `master_setupsshwindows.ps1` embeds the `916-alien` private key in plaintext;
  `~/.claude/settings.json` holds live tokens in plaintext (the 1Password
  service-account token, a Trigger PAT `tr_pat_…`, two MCP bearer tokens). Phase 2
  sources all secrets from 1Password instead. Those tokens were also visible in an
  archived transcript → rotate them (Phase 2d).

## 6. Exact next steps (in order, each with a verification gate)

0. **Roll the Codex fix out to the 3 remaining machines** (t16 is done; `916`,
   `4837`, and `hetz` are NOT). This is first because until it runs, `codex exec`
   on those boxes may silently do nothing.
   - **Windows (`916`, `4837`):** pull ai-devops, then run
     `bin/setup-machine.ps1 -RepoPath C:\repos\ai-devops` (pwsh 7 — the script does
     **not** parse under Windows PowerShell 5.1 and has no `#requires` to tell you
     so). It prepends the real Codex package bin to the user PATH, wires the
     `codex-cli` MCP to the absolute `codex.exe` + `mcp-server`, and self-verifies.
   - **Ubuntu (`hetz`):** pull ai-devops, run `bin/setup-secrets.sh`. Its new
     `codex-cli` step is **untested on the real server** — it was only logic-tested
     in Ubuntu 26.04 under WSL. If `codex` is not installed there, the step warns
     and skips by design.
   ✅ *Worked when:* on each machine, in a **new** terminal, `ai-devops doctor`
   prints `ok codex sandbox can write (workspace-write verified end-to-end)` — not
   merely `codex responds to --version`, which proves nothing (see §4). Then
   restart Claude Desktop / Claude Code and confirm `codex-cli` shows connected.
   ⚠️ *If doctor prints `codex sandbox CANNOT write`:* it will name the resolved
   binary and the fix; do not "fix" it by copying helpers into the shim `bin` —
   that must be redone on every Codex upgrade. Put the real package bin first on
   PATH instead.
1. **Propagate Phase 1 to each remaining machine and collect its memory.** On
   each machine, pull ai-devops; run `./update.sh` on Ubuntu or
   `bin/install-ai-devops-windows.ps1` on Windows; run `bin/ai-sync-memory pull`,
   then `bin/ai-sync-memory push`; review and commit only new secret-free memory.
   Do not assume the old "other 4 machines" count is still exact: record each
   completed machine in this handoff as rollout proceeds.
   ✅ *Worked when:* the sync skill exists in both installed skill directories,
   `bin/ai-gcloud-dflow --dry-run` prints the five expected commands on Windows,
   machine-only memory is present on `origin/main`, and `git status` is clean.
2. **Phase 2** — 2a/2b/2c DONE (see §3a). Remaining:
   (a) **Migrate t16's Claude Desktop MCP config** — re-run
   `bin/setup-machine.ps1 -RepoPath C:\repos\ai-devops` *without* `-SkipDesktopMcp`
   (needs Albert's OK; it backs up the config first). Then fully quit + reopen
   Claude Desktop and confirm supabase, devops-mcp, synology-monitor connect.
   (b) **2d token rotation** — verify/rotate the Trigger PAT (the MCP bearers
   appear already rotated); Albert-approved, click-through.
   (c) **Roll out** to 916, 4837, Ubuntu servers.
   ✅ *Worked when:* a fresh machine is fully configured from ai-devops alone,
   secrets pulled from 1Password, `git grep` finds no token in the repo. *(Verified
   on t16 2026-07-15: `ssh vps whoami`→root, all `mcp.env` refs resolve from the
   token file, repo secret-free.)*
3. **Phase 3** — retire the Dropbox scripts (stub → point at ai-devops), one-command
   onboarding docs, track the ~5 portable `config.toml` prefs.
   ✅ *Worked when:* Dropbox is no longer a config source and this HANDOFF can be
   deleted (project complete).

## 7. Constraints and gotchas in force

- **Commit only when asked** (repo rule). Commits use noreply email
  (`u2giants@users.noreply.github.com`) + `Co-Authored-By: Claude Opus 4.8`
  trailer. This repo commits directly to `main` (no PR flow).
- **Never commit a secret.** `memory/` is secret-free by policy.
- **No chezmoi.** ai-devops is the one hub.
- Skills flow repo→machine only; edit real skills in `ai-devops/skills/`, then
  `ai-install-skills` distributes them. A local edit in `~/.claude/skills` is lost
  on next install.
- Bash `bin/` tools run via git-bash on Windows.
- **Never `git push --force` or `reset --hard`** to resolve a hub conflict —
  surface it.

## 8. Access and environment

- **GitHub:** `gh` CLI authed as `u2giants`. Repo `u2giants/ai-devops`, branch
  `main`, checkout `C:\repos\ai-devops` on Windows machine `AL8960OFC` during
  the 2026-07-14 closeout. Do not infer the marketing nickname from the hostname;
  the shared Windows atlas section covers `916`, `t16`, and `4837`.
- **gcloud:** authed as `u2giants@gmail.com`; defaulted on t16 to project
  `lithe-breaker-323913` / region `us-east4` (via `ai-gcloud-dflow`). Cloud Build
  is 2nd-gen regional — always pass `--region=us-east4`.
- **Secrets:** 1Password vault **`vibe_coding`** (scoped MCP service account) —
  NEVER the values. Item titles referenced in `docs/config-inventory.md`. This is
  the intended source for Phase 2 secret plumbing.
- **Related repo touched this session:** `designflow-frontend` (the DesignFlow PLM
  Angular app), branch `sandbox-albert`, checkout `C:\repos\dflow\designflow-frontend`.
  The Save-button UI change (`ed80a38c`) is in PR #144 → `develop`, **not merged**
  (Uma, GitHub `devopswithkube`, reviews/merges). That repo's tree is clean and
  pushed; its `AGENTS.md` now documents the gcloud deploy-verification trap.

## 9. Open questions and risks

- **Decided (2026-07-10):** memory → straight into `ai-devops/memory/` (not a
  separate repo); Phase 2 secrets from the `vibe_coding` 1Password SA (incl. SSH
  keys); Phase 1 only for now.
- **Open:** do the 2 Ubuntu servers need the full SSH alias set (Phase 2b)?
  `op` CLI vs service-account token for the 2a helper (Phase 2a)?
- **Risk — token exposure:** the plaintext tokens in `settings.json` were visible
  in this session's transcript, and transcripts archive to `claude_chats/`.
  Rotate the Trigger PAT + the two MCP bearer tokens (Phase 2d).
- **Watch — parallel sessions:** `C:\repos\dflow` was edited by parallel
  Claude/Codex sessions this session; working trees moved mid-task. Not a blocker
  here, but for multi-session work use git worktrees to avoid collisions.

---
_Mandatory completeness gate passed after rereading this handoff with the linked
docs and no reliance on chat context. Honest answer: **yes** to: "If I were to
erase this session and start a brand new one with no knowledge of what we
discussed and no context here it would be able to pick up where you left off
with ALL the relevant knowledge you have about this session and application from
handoff.md and related .md files? Nothing relevant is left out?" Failed
approaches are in §4, exact current state is in §3, and every next step in §6 has
a verification gate. Delete this file only when all three phases are complete._
