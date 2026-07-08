# AGENTS.md — AI DevOps Toolkit operating guide

Canonical operating guide and documentation router for this repository. Read this
first. It is written so a new senior engineer or AI session can understand the
repo in under 5 minutes without prior chat context.

## Project summary

This repo is a **backup-and-restore toolkit for a multi-model AI coding
workflow**. It is a small set of Bash CLI scripts, prompt templates, docs, and
skill/MCP scaffolding — **not** an application, service, or web app.

- **What it does:** installs CLI helpers (`ai-devops`, `ai-workspace-status`,
  `ai-codex-review`, `ai-model-call`, `ai-run-task`) that drive a staged coding
  workflow: plan → plan-review → implement → diff-review → test → security-review
  → final-review.
- **Who uses it:** the repo owner (Albert, GitHub `u2giants`) and AI coding
  sessions (Claude/Opus for planning + review, Codex/GPT-5.5 for implementation +
  testing).
- **Key moving parts:** `bin/` scripts (the tools), `config/*.env.example`
  (seed for machine-local config at `/etc/ai-devops/`), `templates/prompts/`
  (the seven stage prompts), and `docs/` (restore/setup/onboarding).
- **Outcome that matters:** the whole workflow can be **restored from zero** on a
  fresh Ubuntu server if the current one dies. See
  [`docs/restore-from-zero.md`](docs/restore-from-zero.md).

This toolkit does **not** modify application repos automatically. Onboarding an
app repo is a separate, manual, opt-in process.

## Multi-model AI note

There is no universal ignore-file standard across AI coding tools.

`.claudeignore` works for Claude Code.

When using any other AI tool, paste this file as your first message and follow the instructions in the "What to ignore" section.

## Documentation map: what to read for each task

Always start with:

- `AGENTS.md`

Then load additional docs only when relevant:

| Task / question | Read these docs | Usually do not need |
|---|---|---|
| Quick repo orientation | `README.md`, `AGENTS.md` | Deep docs under `docs/` unless task requires them |
| Modify a `bin/` script or workflow behavior | `AGENTS.md`, `docs/architecture.md`, `docs/development.md` | `docs/deployment.md` unless install/symlink behavior changes |
| Add or change configuration, env vars, or model commands | `AGENTS.md`, `docs/configuration.md`, `docs/model-setup.md` (model commands) | Unrelated architecture docs |
| Change install/update/uninstall or restore flow | `AGENTS.md`, `docs/deployment.md`, `docs/restore-from-zero.md`, `install.sh`/`update.sh`/`uninstall.sh` | Local-only dev docs unless the dev workflow also changes |
| Edit the staged prompt templates | `AGENTS.md`, `templates/prompts/*`, `docs/architecture.md` | Deployment/config docs |
| Onboard an application repo to the workflow | `AGENTS.md`, `docs/repo-onboarding.md`, `templates/repo-docs/*` | Deployment docs |
| Back up / sync Claude Code transcripts | `AGENTS.md`, `claude_chats/README.md`, `claude_chats/sync.sh`, `skills/claude/claude-transcript-backup/SKILL.md` | Do not open the transcript `.jsonl` files themselves |
| Install or update Claude skills / global instructions on a machine | `AGENTS.md`, `docs/skills-usage-guide.md`, `bin/ai-install-skills`, `templates/system/*` | Transcript data |
| Change a standing AI behavior rule (branch policy, plain-English, verify-before-done, etc.) | `templates/system/CLAUDE-global.md`, `templates/system/machine-atlas.md`, affected `skills/claude/*/SKILL.md` | Unrelated docs |
| Work on future MCP wrapper | `AGENTS.md`, `docs/future-mcp-wrapper.md`, `mcp/README.md` | Unrelated docs |
| Work on future visual testing | `AGENTS.md`, `docs/future-visual-testing.md`, `templates/repo-docs/docs-ai-visual-testing.md` | Unrelated docs |
| Investigate a bug in a tool | `AGENTS.md`, `docs/development.md`, the specific `bin/` script, `HANDOFF.md` if present, Critical incidents section below | Unrelated docs |
| Continue unfinished work | `AGENTS.md`, `HANDOFF.md`, docs named inside `HANDOFF.md` | Docs unrelated to the handoff scope |
| Claude Code session | `CLAUDE.md`, then `AGENTS.md` | Other docs unless the task requires them |
| Documentation-only cleanup | `AGENTS.md`, `README.md`, affected docs under `docs/` | Source files except as needed to verify accuracy |

`HANDOFF.md` is required reading **whenever it exists** — it means work is in
progress. It is currently **absent** (no work in progress).

## Repository structure

The toolkit code is **project-owned and hand-written** (no generated code, no
vendor/third-party code, no framework, no build artifacts). The one large
non-code area is `claude_chats/` — archived session transcripts (data, not code).

| Path | What it is | Category |
|---|---|---|
| `bin/` | The five CLI tools (Bash) | project-owned code |
| `install.sh`, `update.sh`, `uninstall.sh` | Lifecycle scripts (Bash) | project-owned scripts |
| `config/*.env.example` | Seed templates copied to `/etc/ai-devops/` on install | project-owned config templates |
| `templates/prompts/` | The seven staged prompt templates (01–07) | project-owned templates |
| `templates/repo-docs/` | Doc add-ons to drop into onboarded app repos | project-owned templates |
| `templates/system/` | Global standing instructions (`CLAUDE-global.md`) + per-machine environment atlas, installed to each machine's `~/.claude/CLAUDE.md` | project-owned templates |
| `docs/` | Restore, setup, onboarding, and future-feature docs | docs |
| `skills/` | Claude + Codex skill scaffolding (`SKILL.md`) | project-owned scaffolding |
| `mcp/` | Future MCP wrapper placeholder | project-owned scaffolding |
| `claude_chats/` | **~219 MB** of archived Claude Code session transcripts (`.jsonl`) across machines, plus `sync.sh` and its own `README.md` | archived data (sensitive — see below) |
| `codex_chats/` | Archived Codex session transcripts (`.jsonl`) across machines, plus its own `README.md` | archived data (scrubbed, still sensitive — see below) |
| `README.md`, `AGENTS.md`, `CLAUDE.md` | Top-level docs | docs |

`claude_chats/` is a cross-machine backup of `~/.claude/projects/` (machines:
`hetz`, `compshop`, `t16`, `seafile`). It is **tracked in git on purpose**, but
should **never be loaded into AI context** — it is large and, per
[`claude_chats/README.md`](claude_chats/README.md), may contain live secrets. It
is excluded via `.claudeignore` / `.cursorignore`. See **What to ignore** and
**Credentials and environment**.

There are **no** migrations, `Dockerfile`, `docker-compose`, CI/CD workflows
(`.github/workflows`), `package.json`, or database files in this repo. If you go
looking for them, they genuinely do not exist — do not assume they are hidden.

## Prime Directive: custom-code boundary

Our custom code lives here:

- `bin/` — the CLI tools
- `install.sh`, `update.sh`, `uninstall.sh`
- `config/` — `*.env.example` templates
- `templates/` — prompt templates and repo-doc add-ons
- `docs/` — documentation
- `skills/`, `mcp/` — skill/MCP scaffolding
- `claude_chats/` — transcript archive + `sync.sh` (owned, but data — edit only
  the script/README, never hand-edit transcript `.jsonl` files)

Everything else requires justification before touching.

Because this repo is 100% owned code, the boundary is really about **runtime
side-effects on the host**: `install.sh` writes to `/etc/ai-devops/`,
`/var/log/ai-devops/`, and `/usr/local/bin/` (symlinks). Those are outside the
repo. Changing what the scripts write to those locations requires care and a
`docs/deployment.md` update.

## Core modification inventory

No files outside the project-owned areas exist in this repo (there is no vendor,
generated, or framework code to modify). This section is intentionally empty.

| File | Change made | Why it was necessary | Risk during upgrades |
|---|---|---|---|
| _(none)_ | — | — | — |

Host side-effects (not repo files) that `install.sh` creates, for awareness:
`/etc/ai-devops/models.env`, `/etc/ai-devops/server.env`,
`/var/log/ai-devops/`, and symlinks under `/usr/local/bin/ai-*`.

## Task-to-file navigation: what to edit for common changes

(What **source/config** files to edit — distinct from the documentation map above.)

| Task | Files to touch | Files not to touch |
|---|---|---|
| Change a tool's behavior | `bin/<tool>` | `/etc/ai-devops/*.env` (machine-local, not in repo) |
| Add a new CLI tool | `bin/<new-tool>`, `install.sh` (symlink loop picks it up automatically), `AGENTS.md`, `README.md` | Existing tools unless related |
| Change what `doctor` checks | `bin/ai-devops` (`cmd_doctor`) | — |
| Add/rename a model command variable | `config/models.env.example`, `bin/ai-model-call` (stage→var map), `docs/configuration.md`, `docs/model-setup.md` | Real `/etc/ai-devops/models.env` (edit per-machine, never commit) |
| Add a server/config setting | `config/server.env.example`, the consuming script, `docs/configuration.md` | Real `/etc/ai-devops/server.env` |
| Edit a workflow stage prompt | `templates/prompts/0X-*.md` | Other stages unless intentionally aligning them |
| Change install/symlink logic | `install.sh` (and mirror in `uninstall.sh`), `docs/deployment.md` | — |
| Change the restore procedure | `docs/restore-from-zero.md`, `docs/deployment.md` | — |
| Back up session transcripts | run `claude_chats/sync.sh [machine]` | Transcript `.jsonl` files (never hand-edit) |

## Data model and external identifiers

There is **no database** and **no external cloud system** (no Coolify, Supabase,
container registry, or webhooks) wired to this repo. The "identifiers" that
matter are stable paths, the GitHub repo, and the workflow's stage/variable
names.

| Entity/System | Identifier | Where defined | Notes |
|---|---|---|---|
| GitHub repo | `u2giants/ai-devops` (private) | GitHub | Origin remote; push uses noreply email for privacy |
| Toolkit home | `/worksp/ai-devops` | fixed convention | **Never** `/opt/ai-devops`. Referenced by all scripts/docs |
| Machine config dir | `/etc/ai-devops/` | `install.sh`, `server.env` | Holds real `models.env` + `server.env` (not in repo) |
| Log dir | `/var/log/ai-devops/` | `install.sh`, `server.env` | Created on install; currently unused by scripts |
| Installed commands | `/usr/local/bin/ai-*` | `install.sh` symlinks | `ai-devops`, `ai-workspace-status`, `ai-codex-review`, `ai-model-call`, `ai-run-task` |
| Workflow stages | `plan`, `plan-review`, `implement`, `diff-review`, `test`, `security`, `final` | `bin/ai-model-call`, `templates/prompts/` | Stage → prompt → model-command mapping |
| Model command vars | `OPUS48_HIGH_REASONING_CMD`, `OPUS_REVIEW_CMD`, `GPT55_CMD`, `CODEX_CMD`, `TESTER_CMD` | `config/models.env.example` → `/etc/ai-devops/models.env` | Non-secret command strings |
| Run/review artifacts | `.ai/runs/`, `.ai/reviews/` (inside onboarded app repos) | `ai-run-task`, `ai-codex-review` | Git-ignored; created in the target repo, not here |
| Transcript archive machines | `hetz`, `compshop`, `t16`, `seafile` | `claude_chats/<machine>/` | Backup of each machine's `~/.claude/projects/`; synced by `claude_chats/sync.sh` |

Do not casually rename or regenerate these identifiers — scripts and docs assume
them verbatim.

## Container and service inventory

**There are no containers or long-running services.** This toolkit is a set of
CLI scripts symlinked into `/usr/local/bin`. Nothing runs as a daemon, container,
or hosted service.

| Container/service | Purpose | Managed by | App/project ID | Image/source |
|---|---|---|---|---|
| _(none)_ | — | — | — | — |

The closest thing to a "service" is the set of installed CLI commands listed in
**Data model and external identifiers** above.

## What to ignore

Apart from `claude_chats/`, this repo is small and text-only. Keep these aligned
with `.claudeignore` / `.cursorignore`.

- **`claude_chats/`** — **the big one.** ~219 MB of archived session transcripts
  that will blow out any AI context window and may contain live secrets. Never
  load it. (Tracked in git as a backup; excluded from AI context only.)
- **`codex_chats/`** — archived Codex session transcripts. Scrubbed before
  commit, but still large and sensitive. Never load it into AI context.
- `.git/` — version-control internals
- `.ai/runs/`, `.ai/tmp/`, `.ai/reviews/` — run/review artifacts (generated inside
  target repos; never source-of-truth here)
- `node_modules/`, `dist/`, `.cache/`, `coverage/` — do not exist here, but ignore
  if ever generated
- `*.env` (real config) — lives at `/etc/ai-devops/`, never committed; only
  `*.env.example` belongs in git

Note: real config and secrets are **not in the toolkit code** — they live under
`/etc/ai-devops/` and in the Claude/Codex CLI login state (`~/.claude`,
`~/.codex`). The exception is `claude_chats/`, whose raw transcripts may embed
secrets that were visible during those sessions — see below.

## Intentional quirks and non-obvious decisions

### Config lives in /etc, not in the repo

Looks like:
The scripts read `/etc/ai-devops/models.env` and `server.env`, but those files
are nowhere in the repo — only `*.env.example` are here.

Actually:
`install.sh` copies the examples into `/etc/ai-devops/` **only if the real file
does not already exist**, so machine-local edits are never clobbered by a repo
pull or re-install.

Why:
Keeps the repo safe to publish privately with zero secrets, and lets each server
tune model CLI flags without touching git.

Do not change because:
Committing real `.env` files would leak machine-specific config and risk secrets;
having scripts read from the repo would make `update.sh` overwrite local tuning.

### Model CLI flags are configurable, not hard-coded

Looks like:
`OPUS48_HIGH_REASONING_CMD='claude --model opus-4.8 --reasoning high'` — a very
specific command that may not match the installed `claude`/`codex` CLI.

Actually:
These are **defaults meant to be edited** per machine in
`/etc/ai-devops/models.env`. The exact model ids and flags differ across CLI
versions.

Why:
The `claude`/`codex` CLIs evolve; hard-coding flags would break on some machines.

Do not change because:
Removing the indirection (e.g. hard-coding `claude ...` inside the scripts) would
force a code edit on every machine whose CLI flags differ. See
[`docs/model-setup.md`](docs/model-setup.md).

### Fable is deliberately absent

Looks like:
A planning/final-review model slot with no "Fable" option, even though earlier
drafts of this workflow mentioned it.

Actually:
Fable is intentionally **not used**. Planning and final review use **Opus 4.8
with high reasoning** instead.

Why:
Fable is being removed from the subscription plan.

Do not change because:
Re-introducing Fable would reference a model that is going away. Use Opus 4.8
(high reasoning) for the planning and final-review stages.

### Reviews are read-only by design

Looks like:
`ai-codex-review` gathers a full diff and prompt but never applies changes.

Actually:
Review stages (plan/diff/security/visual/final) are strictly read-only — they
save a Markdown report under `.ai/reviews/` and print the path. They never
commit, push, merge, or delete.

Why:
Separation of duties: implementation stages write code; review stages only judge
it. This keeps an independent check in the loop.

Do not change because:
Letting a review stage edit code would collapse the safety gate the workflow
exists to provide.

## Credentials and environment

No secrets live in this repo. The variables below are **non-secret** command
strings and paths. Real values live in `/etc/ai-devops/*.env` (machine-local) and
are seeded from `config/*.env.example`. The only true credentials are the
Claude/Codex/gh **login sessions**, which are stored by those CLIs
(`~/.claude`, `~/.codex`, `~/.config/gh`) — never in this repo.

| Variable | Purpose | Stored where | Required in dev | Required in prod |
|---|---|---|---|---|
| `AI_DEVOPS_HOME` | Toolkit checkout path (`/worksp/ai-devops`) | `models.env`, `server.env` | yes | yes |
| `AI_DEVOPS_ETC` | Machine config dir (`/etc/ai-devops`) | `server.env` | yes | yes |
| `AI_DEVOPS_LOG_DIR` | Log dir (`/var/log/ai-devops`) | `server.env` | no | no |
| `WORKSPACE_ROOT` | Where app repos live (`/worksp`) | `server.env` | no | no |
| `DEFAULT_MAIN_BRANCH` | Branch name for safety warnings | `server.env` | no | no |
| `OWNER_NAME` | Name used in plain-English final summaries (`Albert`) | `server.env` | no | no |
| `OPUS48_HIGH_REASONING_CMD` | Command for plan + final-review stages | `models.env` | yes | yes |
| `OPUS_REVIEW_CMD` | Command for plan/diff/security reviews | `models.env` | yes | yes |
| `GPT55_CMD` | Command for the implement stage | `models.env` | yes | yes |
| `CODEX_CMD` | Command for `ai-codex-review` | `models.env` | yes | yes |
| `TESTER_CMD` | Command for the test stage | `models.env` | yes | yes |

There are **no** API keys, tokens, or passwords in the **toolkit code or config
templates**. Model access comes from the Claude/Codex CLI login sessions, not
from env vars here.

> ⚠️ **`claude_chats/` may contain live secrets.** The archived transcripts are
> raw session logs including full tool outputs, so they can embed API tokens,
> credentials, or private data that were on screen during those sessions (this
> warning is stated in [`claude_chats/README.md`](claude_chats/README.md)).
> Consequences: **keep this repository private**, do not paste transcript
> contents elsewhere, and **rotate any secret** you find exposed there. This is
> why `claude_chats/` is excluded from AI context in `.claudeignore` /
> `.cursorignore`.

## Deployment

"Deployment" here means **installing the toolkit onto a machine**, not a cloud
release. There is **no CI/CD pipeline, no container image, no hosting platform,
and no GitHub Actions workflow** in this repo.

- **Install / update mechanism:** run `./install.sh` (verify deps, create
  `/etc/ai-devops` + `/var/log/ai-devops`, seed config without overwriting,
  symlink `bin/*` into `/usr/local/bin`, run `ai-devops doctor`). `./update.sh`
  does `git pull --ff-only` then re-runs `install.sh`. `./uninstall.sh` removes
  the symlinks (keeps config unless `--purge`, keeps the checkout unless
  `--remove-repo`).
- **GitHub Actions workflow name:** none (no `.github/workflows`).
- **Image/package names, tag pattern, registry:** not applicable — nothing is
  built or published.
- **Deployment platform / app/project ID:** not applicable — installs directly on
  an Ubuntu host.
- **Deploy trigger:** manual — run `install.sh`/`update.sh` on the target host.
- **Rollback:** `git checkout <previous-sha>` in `/worksp/ai-devops` then re-run
  `./install.sh`; or `./uninstall.sh` to remove symlinks. Config in
  `/etc/ai-devops/` is preserved.
- **Runtime environment variables:** in `/etc/ai-devops/models.env` and
  `server.env` on each host (not in the repo).
- **SSH:** SSH is how you reach the host to run the scripts; there is no
  SSH-based deploy automation. It is the normal (and only) access path, since
  installation is a local operation on the box.

Full first-time / disaster restore steps:
[`docs/restore-from-zero.md`](docs/restore-from-zero.md). Overview:
[`docs/deployment.md`](docs/deployment.md).

## Critical incidents

No critical incidents have occurred. This section is intentionally kept for future
use.

_(One noteworthy setup detail, not an incident: the very first push to GitHub was
rejected by GitHub's email-privacy protection because the commit used a private
`@gmail.com` address. Resolved by setting the repo-local git email to the
`@users.noreply.github.com` form. Future commits should keep using the noreply
email.)_

## Pending work

| Status | Item | Owner/next action |
|---|---|---|
| open | Orchestrate stages end-to-end | `ai-run-task` / `ai-model-call` are v0.1 scaffolds; full pipeline automation is future work |
| open | MCP wrapper | Design sketched in `docs/future-mcp-wrapper.md` + `mcp/README.md`; not implemented |
| open | Automated visual testing (Playwright) | Design sketched in `docs/future-visual-testing.md`; manual for now |
| open | App-repo onboarding helper | `docs/repo-onboarding.md` describes manual steps; `ai-onboard-repo` helper not built |
| done | Initial toolkit scaffold + install + doctor green | Completed in commit `f39315d` |

No work is currently in progress or blocked, so there is **no** `HANDOFF.md`.
