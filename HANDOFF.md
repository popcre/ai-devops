# HANDOFF — machine-config consolidation onto ai-devops (2026-07-10)

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

**Phase 1 is DONE, committed, pushed.** Commits on `main` (pushed to origin):
- `28c44bc` — Phase 1 build (skill, gcloud helper, memory sync, docs)
- `e64c7cf` — this HANDOFF + AGENTS.md "HANDOFF present" notes
- (plus a docs-comprehensiveness pass — see git log for the latest SHA)

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

**Verified:** `ai-gcloud-dflow --dry-run` prints the 5 correct commands;
`ai-sync-memory push --dry-run` maps this machine's 4 projects (dflow, oracle,
ansible, 1password-mcp) → `memory/<project>/`; `ai-install-skills` installed the
new skills to `~/.claude/skills` + `~/.codex/skills` without clobbering globals.

**NOT done:** the first real `ai-sync-memory push` (so `memory/` has README +
project-map but **no actual memory files yet**); propagation to the other 4
machines; Phases 2 and 3.

**Script git mode note:** `bin/ai-gcloud-dflow` and `bin/ai-sync-memory` are
tracked `100644` (not `+x`). This MATCHES the existing `bin/ai-install-skills`
(Windows-authored; execution handled by `install.sh`/git-bash). Not a bug — do
not "fix" it in isolation.

## 4. Everything we tried that did NOT work (don't repeat these)

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

1. **First real memory push** (on this machine): `cd` to the repo, then
   `bin/ai-sync-memory push`; review, `git add memory/`, commit (noreply email +
   `Co-Authored-By: Claude Opus 4.8` trailer), `git push origin main`.
   ✅ *Worked when:* `memory/{dflow,oracle,ansible,1password-mcp}/` contain
   `MEMORY.md` + fact files on `origin/main`. (Or just say "sync my dotfiles".)
2. **Propagate Phase 1 to the other 4 machines** (916, 4837, 2 servers): on each,
   pull ai-devops and run the installer — `./update.sh` (Ubuntu) or
   `bin/install-ai-devops-windows.ps1` (Windows), or at minimum `bin/ai-install-skills`.
   ✅ *Worked when:* `~/.claude/skills/sync-dotfiles/SKILL.md` exists there and
   `bin/ai-gcloud-dflow --dry-run` prints the 5 gcloud commands.
3. **Phase 2** (when Albert asks — see proposal §Phase 2): build the 1Password
   secret-plumbing helper first (2a), then fold the Dropbox SSH (2b) and MCP (2c)
   scripts into `bin/`, then rotate exposed tokens (2d). **Add the `916-alien` key
   to the `vibe_coding` vault first — it isn't there yet.**
   ✅ *Worked when:* a fresh machine is fully configured from ai-devops alone,
   secrets pulled from 1Password, `git grep` finds no token in the repo.
4. **Phase 3** — retire the Dropbox scripts (stub → point at ai-devops), one-command
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
  `main`, checkout `C:\repos\ai-devops` on t16.
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
_Self-audit (per `templates/system/handoff-standard.md`) passed: a fresh developer
can execute §6 without questions; failed approaches are in §4; every path,
identifier, alias, and 1Password item is defined or pointed to; each next step has
a verification gate. Delete this file only when all three phases are complete._
