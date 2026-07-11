# HANDOFF — machine-config consolidation onto ai-devops (2026-07-10)

## 1. What this application is

`ai-devops` (GitHub `u2giants/ai-devops`, private) is **not** an app — it's
Albert's personal **toolkit for backing up and distributing his AI coding setup**
across his machines: 3 Windows dev boxes (`916`/916-alien, `t16`/albt16, `4837`)
and 2 Ubuntu servers. It's Bash CLI scripts + Markdown, installed per machine by
`install.sh` (Ubuntu) / `bin/install-ai-devops-windows.ps1` (Windows) /
`bin/ai-install-skills`. It already distributes Claude+Codex **skills**
(`skills/claude/*`, `skills/codex/*` → `~/.claude/skills`, `~/.codex/skills`),
**global instructions** (`templates/system/CLAUDE-global.md` → `~/.claude/CLAUDE.md`),
and **workflow config** (`config/*.env.example` → `/etc/ai-devops/`, never clobbered).
Read `AGENTS.md` first for the full picture.

## 2. What we set out to do this session, and why

Albert felt his machine config was "scattered across a lot of places." Goal:
make `ai-devops` the **single hub** that configures every machine, and add a
"sync my dotfiles" capability — WITHOUT introducing a new tool (we explicitly
rejected `chezmoi` because it would duplicate the mechanism ai-devops already
has, and as a subfolder of this 1.5 GB repo it would force huge clones).
Triggered by a tangent from a dflow UI task: setting gcloud defaults led to
"can I sync this across machines?" → discovering the scatter.

## 3. Current state — what is true right now

**Phase 1 is DONE, committed, and pushed** (commit `28c44bc` on `main`, pushed to
`origin/main`). Delivered:
- `skills/claude/sync-dotfiles/SKILL.md` + `skills/codex/codex-sync-dotfiles/SKILL.md`
  — trigger "sync my dotfiles". Installed to THIS machine already.
- `bin/ai-gcloud-dflow` — sets dflow gcloud defaults (project `lithe-breaker-323913`,
  region `us-east4`). Dry-run verified.
- `bin/ai-sync-memory` — two-way sync of Claude auto-memory
  (`~/.claude/projects/<slug>/memory/` ↔ `ai-devops/memory/<project>/`).
  Canonicalizes per-machine slugs (`C--repos-dflow` and `D--repos-dflow` → `dflow`)
  via a heuristic + `memory/project-map.tsv` overrides. Push+pull dry-run verified.
- `memory/` tree with `README.md` + `project-map.tsv`. **Currently empty of actual
  memory** — no real push has run yet (see §6 step 1).
- Docs: `docs/config-inventory.md` (the full scatter map), `docs/config-consolidation-proposal.md`
  (the 3-phase plan), AGENTS.md rows.

**Not started:** Phase 2 and Phase 3 (see `docs/config-consolidation-proposal.md`).

**Note on scripts' git mode:** `bin/ai-gcloud-dflow` and `bin/ai-sync-memory` are
tracked `100644` (not `+x`) — this MATCHES the existing `bin/ai-install-skills`
(Windows-authored; `install.sh` handles execution on Ubuntu). Not a bug.

## 4. Everything we tried that did NOT work

- **Verifying the dflow deploy via global gcloud** — `gcloud builds triggers list`
  returned `[]` and `gcloud builds list` showed only stale 2024 builds, which
  looked like "sandbox-albert isn't deployed via Cloud Build." **WRONG.** The
  triggers/builds are **2nd-gen REGIONAL**; you must pass
  `--region=us-east4 --project=lithe-breaker-323913`. Documented in the
  designflow-frontend AGENTS.md and `docs/config-inventory.md`.
- **gcloud default project was `dflow-plm`** — a stale/empty project that doesn't
  exist for real. Caused "Cloud Build API not enabled" errors. Wiped everywhere;
  correct project is `lithe-breaker-323913`.
- **chezmoi** — investigated as the dotfiles tool, then rejected: it duplicates
  ai-devops's existing installer machinery and would need a 1.5 GB clone as a
  subfolder. Do not revisit it.
- **`yarn` not on PATH** on Windows — use `corepack yarn` instead.

## 5. Root causes and key findings

- **Config is scattered across THREE overlapping systems + gaps** (full map:
  `docs/config-inventory.md`): (a) ai-devops (skills/instructions/workflow config),
  (b) Dropbox `\vibe coding\ssh keys\master_setupsshwindows.ps1` (SSH config +
  the `916-alien` private key), (c) Dropbox `\vibe coding\…MCP servers\`
  (`setup-claude-mcps.ps1` / `setup-codex-mcps.ps1` → MCP config with tokens).
  Synced by nothing: **auto-memory**, gcloud defaults, portable Codex prefs.
- **Per-machine memory slugs differ** — the same project is `C--repos-dflow` on
  one box, `D--repos-dflow` on another. `ai-sync-memory` canonicalizes them.
- **Two plaintext-secret landmines** (why naive git-sync is unsafe):
  `master_setupsshwindows.ps1` embeds the `916-alien` private key in plaintext;
  `~/.claude/settings.json` holds live tokens in plaintext (a 1Password
  service-account token, a Trigger PAT `tr_pat_…`, and two MCP bearer tokens).
  These must NOT be committed; Phase 2 pulls them from 1Password instead.

## 6. Exact next steps

1. **Do the first real memory push** on this machine (t16/`C--repos-*`):
   `cd ai-devops && bin/ai-sync-memory push` then review, `git add memory/`,
   commit, push. *You'll know it worked when* `ai-devops/memory/{dflow,oracle,ansible,1password-mcp}/`
   contain the `MEMORY.md` + fact files and are on `origin/main`.
   (Or just say "sync my dotfiles" and let the skill do it.)
2. **Propagate Phase 1 to the other 4 machines** (916, 4837, 2 servers): on each,
   pull ai-devops and run the installer — `./update.sh` (Ubuntu) or
   `bin/install-ai-devops-windows.ps1` (Windows), or `bin/ai-install-skills`.
   *You'll know it worked when* `~/.claude/skills/sync-dotfiles/SKILL.md` exists
   there and `bin/ai-gcloud-dflow --dry-run` prints the 5 gcloud commands.
3. **Phase 2** (when Albert asks) — fold the two Dropbox scripts into `bin/`,
   pulling ALL secrets (incl. the `916-alien` key + MCP tokens) from the scoped
   `vibe_coding` 1Password service account; rotate the plaintext tokens as they
   move. Details: `docs/config-consolidation-proposal.md` §Phase 2.
4. **Phase 3** — retire the Dropbox scripts; one-command onboarding. Same doc.

## 7. Constraints and gotchas in force

- **Commit only when asked** (repo rule). Commits use the noreply email
  (`u2giants@users.noreply.github.com`) and end with the
  `Co-Authored-By: Claude Opus 4.8` trailer. This repo commits directly to `main`.
- **Never commit a secret.** `memory/` is secret-free by policy; if a memory file
  ever contains a credential, stop — it belongs in 1Password.
- **No chezmoi.** ai-devops is the one hub.
- Skills flow repo→machine only; edit real skills in `ai-devops/skills/`, not in
  `~/.claude/skills`.
- Bash tools run via git-bash on Windows.

## 8. Access and environment

- GitHub `gh` CLI is authenticated as `u2giants`. Repo `u2giants/ai-devops`,
  branch `main`, checkout `C:\repos\ai-devops` (this machine).
- gcloud authed as `u2giants@gmail.com`, now defaulted to project
  `lithe-breaker-323913` / region `us-east4` on this machine (via `ai-gcloud-dflow`).
- Secrets live in 1Password vault **`vibe_coding`** (scoped MCP service account) —
  NEVER the values. That vault is the intended source for Phase 2 secret plumbing.
- Related repo touched this session: `designflow-frontend` (branch `sandbox-albert`,
  `C:\repos\dflow\designflow-frontend`) — the Save-button change `ed80a38c` is in
  PR #144 → develop, not merged (Uma `devopswithkube` merges).

## 9. Open questions and risks

- **Decided (2026-07-10):** memory → straight into `ai-devops/memory/` (not a
  separate repo); Phase 2 secrets come from the `vibe_coding` 1Password SA
  (including SSH keys); do Phase 1 only for now.
- **Risk:** the plaintext tokens in `settings.json` were visible in this session's
  transcript, and transcripts are archived to `claude_chats/`. Rotating the
  Trigger PAT + the two MCP bearer tokens is recommended (folds into Phase 2).
- **Open:** do the 2 Ubuntu servers need the full SSH alias set installed (Phase 2)?
- **Watch:** `C:\repos\dflow` is edited by parallel Claude/Codex sessions — trees
  move under you. Not a blocker here, but coordinate (git worktrees would prevent
  collisions).

---
_Self-audit (per `templates/system/handoff-standard.md`) passed: a fresh developer
can execute §6 without questions; failed approaches are in §4; every path/identifier
is defined; each next step has a verification gate._
