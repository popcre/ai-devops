# AGENTS.md — AI DevOps Toolkit operating guide

Canonical operating guide and documentation router for this repository. Read this
first. It is written so a new senior engineer or AI session can understand the
repo in under 5 minutes without prior chat context.

## Project summary

This repo is a **backup-and-restore toolkit for a multi-model AI coding
workflow**. It is a small set of Bash CLI scripts, prompt templates, docs, and
skill/MCP scaffolding — **not** an application, service, or web app.

- **What it does:** installs CLI helpers (`ai-devops`, `ai-workspace-status`,
  `ai-codex-review`, `ai-model-call`, `ai-run-task`, `ai-glm-agent`) that drive a staged coding
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
| Understand where machine config lives (skills, SSH, MCP, gcloud, memory, secrets) | `AGENTS.md`, `docs/config-inventory.md` | Unrelated architecture docs |
| **Codex "works" but `codex exec` changes nothing / sandbox helper not found / wiring the `codex-cli` MCP** | `AGENTS.md` (→ Critical incidents 2026-07-16 + Intentional quirks), `docs/config-inventory.md` (→ "Codex: PATH + MCP"), `templates/system/machine-atlas.md` (→ junction trap), `bin/setup-machine.ps1` (Windows), `bin/setup-secrets.sh` (Ubuntu) | Model/prompt docs |
| Anything about the Headroom token-compression proxy (find it, fix it, route a machine through it, see savings, turn it off) | `AGENTS.md`, `docs/headroom.md` | Unrelated architecture docs |
| Plan/track converging all machine config onto ai-devops | `AGENTS.md`, `docs/config-consolidation-proposal.md`, `docs/config-inventory.md` | Unrelated docs |
| Change install/update/uninstall or restore flow | `AGENTS.md`, `docs/deployment.md`, `docs/restore-from-zero.md`, `install.sh`/`update.sh`/`uninstall.sh` | Local-only dev docs unless the dev workflow also changes |
| Install/update AI DevOps on a Windows coding computer | `AGENTS.md`, `.config/configuration.winget` (packages/settings), `bin/bootstrap-windows-dev.ps1` (single entry point), `bin/configure-windows-bootstrap-access.ps1` (Tailscale/OpenSSH), `bin/configure-wsl-ansible-controller.ps1`, `bin/setup-machine.ps1` (AI/secret wiring), `bin/verify-windows-dev.ps1`, `docs/windows-winget-configuration.md` | `bin/run_me_setup_dev_comp.bat` and `bin/setup_dev_computer_internal.ps1` are transitional only; Linux restore docs unless also touching server install |
| Set up a new machine's secrets / 1Password / MCP tokens / `claude` launcher | `AGENTS.md`, `docs/onboarding-secrets.md`, `config/mcp.env.example`, `bin/setup-secrets.sh` (Ubuntu), `bin/setup-machine.ps1` (Windows) | Model/prompt docs unless also changing the workflow |
| Enable secure Windows remote setup over Tailscale / SSH | `AGENTS.md`, `docs/windows-openssh-tailscale.md` | Do not enable LAN/public SSH, password logins, broad default firewall rules, or WinRM |
| Edit the staged prompt templates | `AGENTS.md`, `templates/prompts/*`, `docs/architecture.md` | Deployment/config docs |
| Onboard an application repo to the workflow | `AGENTS.md`, `docs/repo-onboarding.md`, `templates/repo-docs/*` | Deployment docs |
| Back up / sync Claude Code transcripts | `AGENTS.md`, `claude_chats/README.md`, `claude_chats/sync.sh`, `skills/claude/claude-transcript-backup/SKILL.md` | Do not open the transcript `.jsonl` files themselves |
| Analyze Codex transcripts or repeated Codex prompts | `AGENTS.md`, `docs/codex-chat-analysis.md`, `docs/codex-skills-usage-guide.md`, `skills/codex/codex-transcript-miner/SKILL.md` | Raw transcript `.jsonl` unless the analysis task requires them |
| Install or update Claude/Codex skills / global instructions on a machine | `AGENTS.md`, `docs/skills-usage-guide.md`, `docs/codex-skills-usage-guide.md`, `bin/ai-install-skills`, `templates/system/*` | Transcript data |
| Add or update Codex workflow skills | `AGENTS.md`, `docs/codex-skills-usage-guide.md`, affected `skills/codex/*/SKILL.md`, `docs/skills-map.md` | Raw chat/docx prompt sources unless needed |
| Write a skill `description:`, or check whether a skill actually fires on real prompts | `AGENTS.md`, `docs/skill-trigger-eval.md`, `tools/skill-trigger-eval/` | skill-creator's bundled `scripts/run_loop.py` — it is Unix-only AND tests a mechanism that no longer triggers; see the doc |
| Create a NEW skill, or decide where an existing one belongs | `AGENTS.md`, `docs/skills-map.md`, `docs/skills-usage-guide.md`, then ONE of `skills/shared/<name>/` (serves Claude **and** Codex — the default when both should follow the rule) or `skills/claude/<name>/` / `skills/codex/<name>/` (genuinely client-specific only) | **Do not write two near-identical copies under `skills/claude/` and `skills/codex/`** — that is the drift trap; put it in `skills/shared/` instead. A name may exist in `shared/` **or** a client tree, never both: `ai-install-skills` fails closed on the collision |
| Change a standing AI behavior rule (branch policy, plain-English, verify-before-done, etc.) | `templates/system/CLAUDE-global.md`, `templates/system/AGENTS-global-codex.md`, `templates/system/machine-atlas.md`, affected `skills/shared/*/SKILL.md` (cross-client rules) or `skills/claude/*/SKILL.md` / `skills/codex/*/SKILL.md` | Unrelated docs |
| Work on future MCP wrapper | `AGENTS.md`, `docs/future-mcp-wrapper.md`, `mcp/README.md` | Unrelated docs |
| Work on future visual testing | `AGENTS.md`, `docs/future-visual-testing.md`, `templates/repo-docs/docs-ai-visual-testing.md` | Unrelated docs |
| Investigate a bug in a tool | `AGENTS.md`, `docs/development.md`, the specific `bin/` script, `HANDOFF.md` if present, Critical incidents section below | Unrelated docs |
| Continue unfinished work | `AGENTS.md`, `HANDOFF.md`, docs named inside `HANDOFF.md` | Docs unrelated to the handoff scope |
| Claude Code session | `CLAUDE.md`, then `AGENTS.md` | Other docs unless the task requires them |
| Documentation-only cleanup | `AGENTS.md`, `README.md`, affected docs under `docs/` | Source files except as needed to verify accuracy |

`HANDOFF.md` is required reading **whenever it exists** — it means work is in
progress. It is currently **present**. The immediate unfinished work is proving
the Windows minimum-touch bootstrap on a disposable Windows 11 machine and then
proving a second run makes no unintended changes. Older config-consolidation
rollout work is also recorded there. Do not apply the unproven bootstrap to an
established workstation merely as a test.

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
| `templates/system/` | Global standing instructions (`CLAUDE-global.md`, `AGENTS-global-codex.md`) + per-machine environment atlas, installed to each machine's AI config | project-owned templates |
| `docs/` | Restore, setup, onboarding, and future-feature docs | docs |
| `skills/` | Claude + Codex skill scaffolding (`SKILL.md`) | project-owned scaffolding |
| `tests/` | Dependency-free Bash and PowerShell installer behavior tests | project-owned tests |
| `memory/` | Cross-machine Claude auto-memory (per-project `MEMORY.md` + fact files), synced by `bin/ai-sync-memory`. **Secret-free** — see `memory/README.md` | project-owned data (git-tracked) |
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
- `tests/` — dependency-free installer behavior tests
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
| Installed commands | `/usr/local/bin/ai-*` | `install.sh` symlinks | `ai-devops`, `ai-workspace-status`, `ai-codex-review`, `ai-model-call`, `ai-run-task`, `ai-glm-agent`, `ai-install-skills`, `ai-gcloud-dflow`, `ai-sync-memory` |
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

### `codex-cli` MCP uses Codex's own `mcp-server`, not a third-party wrapper

Looks like:
A third-party npx package (`@cexll/codex-mcp-server`) would give more tools, so
using Codex's own server is a downgrade.

Actually:
`bin/setup-machine.ps1` (Windows) and `bin/setup-secrets.sh` (Ubuntu) wire
`codex-cli` to the **absolute** codex binary + `mcp-server`. That exposes exactly
two tools — `codex` (prompt, model, sandbox, approval-policy, cwd, config,
base/developer-instructions) and `codex-reply` (thread continuation, which the
wrapper does not appear to offer at all). Verified end-to-end 2026-07-16: a
`tools/call` with `sandbox=workspace-write` really writes files.

Why:
No third-party supply chain and no `npx` download in the hot path; version-locked
to the CLI it ships with; and — decisively — a wrapper *shells out to* `codex`
resolved from PATH, which re-introduces the junction bug below. Pinning the
absolute binary cannot resolve to the wrong codex.

Do not change because:
Swapping back to a wrapper reintroduces both the supply-chain surface and the
PATH-resolution failure. The trade-off was made knowingly: we gave up the
wrapper's `changeMode`/`fetch-chunk`, `batch-codex` and `brainstorm` tools, all of
which are reproducible by prompting the native `codex` tool.

### `ai-devops doctor` runs Codex for real instead of asking `--version`

Looks like:
`doctor` should just check that `codex` exists and answers `--version` — cheap and
fast, like every other liveness check.

Actually:
`check_codex_sandbox()` creates a temp dir, runs a real
`codex exec --sandbox workspace-write`, and asserts the file exists. It costs a
real (small) model call and a few seconds.

Why:
On 2026-07-16 a machine had codex passing `--version`, passing
`codex login status`, and exiting 0 — while **every** sandboxed write silently
failed and `codex exec` changed nothing. A `--version` probe is structurally
incapable of seeing that failure mode. Presence is not capability; only exercising
the capability proves it.

Do not change because:
Reverting to a `--version` check restores a green light over a broken tool, which
is worse than no check at all. If the cost matters, gate it behind a flag — do not
delete it.

### `ai-install-skills` installs but never prunes — orphans live forever

Looks like:
`bin/ai-install-skills` syncs `skills/claude/` to `~/.claude/skills`, so a machine's
skill set should mirror the repo.

Actually:
It only ever `rm -rf`s the specific skill names it is **about to copy**, then copies
them. A skill directory on the machine with **no counterpart in the repo is never
touched**. Verified 2026-07-16 on `hetz`: `/home/ai/.claude/skills` held 21 skills —
the repo's 18 plus 3 orphans (`codex-consult`, `codex-code-review`,
`codex-plan-review`, all dated 2026-07-04) that have **never existed in this repo**.
`codex-consult` is actively broken: it shells out to a `codex-consult` binary that
is not on PATH.

Why:
The one-way repo→machine copy is deliberate (a local edit must never be captured
back). Pruning was simply never implemented — nobody noticed, because an orphan
fails only when a session actually triggers it.

Future sessions should:
Treat "the skill is installed" as **no evidence** it came from the repo. When a
machine behaves oddly, diff `ls ~/.claude/skills` against `ls skills/claude/` in the
repo. Orphans are worse than clutter: `codex-consult` overlaps semantically with
`codex-second-opinion`, so a session on `hetz` could match the broken one. If a
prune step is ever added, it must be opt-in (`--prune`) — a blind prune would delete
legitimately machine-local skills. Repo-owned cross-client skills live under
`skills/shared/` and install into both Claude and Codex. The one sanctioned
migration is explicit and recoverable: `--migrate-obsolete` (Bash) or
`-MigrateObsolete` (PowerShell) moves only the retired
`synology-sharesync-stuck-triage` directory outside the active skills root after
the replacement exists. Default installs warn but never move or delete it.

### `codex exec resume` takes different flags from `codex exec`

Looks like:
`resume` is `exec` plus a session id, so the flags carry over.

Actually:
`codex exec resume` **rejects** `-s/--sandbox`, `-C/--cd`, and `--color`
(`error: unexpected argument '-s' found`). Verified against codex-cli 0.144.5 on
2026-07-16. It does accept `-c`, `-m`, `-o`, `--json`, `--last`. To resume
read-only, pass `-c sandbox_mode="read-only"` and `cd` to the repo first.

Why:
Upstream CLI surface; nothing we control.

Future sessions should:
Copy `exec` flags onto `resume` and it fails immediately and loudly — which is the
good case. The dangerous case is the sandbox: a mistyped `-c` key does **not**
error, it silently falls back to the config default. Always confirm the run header
prints `sandbox: read-only`. Prefer the explicit session id (the header of the
first run prints `session id: <uuid>`) over `--last`, which silently picks the
newest session for the cwd and can grab the wrong one.

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

### The MCP secret launcher caches; it must not re-resolve per launch

Looks like:
`~/.config/ai-devops/mcp-launch.cmd` just runs an MCP server with secrets.

Actually:
It calls `bin/mcp-secret-launch.ps1`, which resolves all `mcp.env` `op://`
references **once** behind a machine-wide mutex and reuses a 15-minute
DPAPI-encrypted cache (`mcp-secrets.dpapi.json`). It does **not** run
`op run --env-file` on every launch. `$CommandArgs` is declared
`[Parameter(Position = 0, ValueFromRemainingArguments = $true)]`, and the
generated `.cmd` files pass `%*` with **no `--` separator**.

Why:
5 machines share one 1Password service account with a per-hour request cap. A
per-launch `op run` resolving ~11 refs × every window/server/subagent overran the
cap and locked the account (see the 2026-07-23 incident). The cache makes it
≤1 refresh / 15 min / machine. `Position = 0` forces `-Url`/`-SecretRef` to bind
by name only so a Stdio child's leading `cmd /c` is not swallowed; `--` is omitted
because `pwsh -File` mis-parses it as an empty parameter name.

Do not change because:
Re-introducing a per-launch `op run`, removing `Position = 0`, or re-adding `--`
each independently reproduces a real outage. Full detail:
[docs/mcp-1password-rate-limit-hardening.md](docs/mcp-1password-rate-limit-hardening.md).

## Credentials and environment

No secrets live in this repo. The variables below are **non-secret** command
strings and paths. Real values live in `/etc/ai-devops/*.env` (machine-local) and
are seeded from `config/*.env.example`. Claude/Codex/gh login sessions are stored
by those CLIs (`~/.claude`, `~/.codex`, `~/.config/gh`). The GLM Coding Plan key
lives only in 1Password item `GLM z.ai API`; the repo distributes its `op://`
reference and injects it only into an isolated `ai-glm-agent` child process.

> ⚠️ **1Password account = `popcreations.1password.com` (since 2026-07-22).** The
> scoped service account was migrated off `my.1password.com`; the `vibe_coding`
> vault re-created every item under **new UUIDs**. All `op://` references are now
> **name-based** (`op://vibe_coding/<title>/<field>`). Two deliberate UUID
> exceptions remain — do **not** "fix" them to name-based: (1) the Trigger PAT
> (parentheses in the title, which `op` rejects in a reference); (2) the
> **recall-ai** ref in `bin/setup-machine.ps1` / `bin/setup-secrets.sh`, which is
> passed **inline** through the mcp-remote launcher (a space in the ref breaks the
> launcher's arg/`op read` parsing). Name-based is safe only for refs resolved via
> `op run --env-file` (the mcp.env path). The GLM key is in the `api key` field,
> not `credential` (empty →
> silent-empty). Rotating the bootstrap `OP_SERVICE_ACCOUNT_TOKEN` does **not**
> auto-propagate — update the machine-local token file/env var/embedded configs by
> hand and restart the apps. `op whoami` decodes the token locally, so it can
> report a **deleted** SA while real calls return `(403) Service Account Deleted` —
> prove a token with a real `op item create`/`delete`, never `whoami`. Full detail:
> `docs/onboarding-secrets.md`, `docs/config-inventory.md`.

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

All direct 1Password access is serialized. Agents and scripts must never fan
out `op read`, `op run`, or 1Password MCP calls in parallel. Shared MCP secrets
are resolved as one environment and reused; Windows launchers enforce this with
an OS mutex and DPAPI-encrypted short-lived cache, while Ubuntu resolves once in
the login shell and locks any fallback refresh.

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

### 2026-07-16 — Codex on Windows: healthy-looking, silently non-functional

**Impact:** every sandboxed `codex exec` on t16 wrote nothing while reporting
success. An AI session handed Codex an 8-item implementation task; Codex changed
zero files and the run still exited 0. Cost roughly a full session, most of it
spent misdiagnosing.

**Symptom:**
`windows sandbox: orchestrator_helper_launch_failed: setup refresh failed to
launch helper: helper=codex-windows-sandbox-setup.exe, error=program not found`
— while `codex --version` and `codex login status` both succeeded and exited 0.

**Root cause (upstream, not a bad install):** the standalone installer puts
`%LOCALAPPDATA%\Programs\OpenAI\Codex\bin` on PATH. That directory is a
**junction** to `%USERPROFILE%\.codex\packages\standalone\current\bin` — only
`bin` is linked, so the package's sibling `codex-resources\` (holding the sandbox
helper) is unreachable from it. Codex resolves the helper relative to the invoked
exe, so via that PATH entry it cannot launch it. The package itself is complete
and passes the installer's own `Test-PackageContentsAreComplete`. Proven A/B: same
binary, same version 0.144.5, same flags — fails via the junction, succeeds via
`…\.codex\packages\standalone\current\bin\codex.exe`. Filed upstream:
[openai/codex#32655](https://github.com/openai/codex/issues/32655) (we confirmed
0.144.5; see also #30829, #32359, #28457 — a regression tracked since 0.132/0.138).

**Fix:** `bin/setup-machine.ps1` step "Codex PATH" prepends the real package bin
to the user PATH (`current` is a junction the updater re-points, so it survives
upgrades) and then verifies with a real sandboxed write.

**Prevention:** `ai-devops doctor` now proves the sandbox with a real
`workspace-write` instead of asking `--version`. Run it on every machine after any
Codex install/upgrade.

**Lessons worth keeping (these are why it took so long):**
1. **Presence is not capability.** `--version`, `login status`, and exit 0 were all
   green while the tool was broken. Every one of our checks asked the wrong
   question. Health checks must exercise the capability.
2. **An empty result is not proof a tool is broken.** The same session first
   misdiagnosed the 1Password MCP `op_run` as "env injection is broken" — actually
   `argv:["bash",…]` on Windows resolves to **WSL** bash, whose isolated Linux env
   does not inherit the injected Windows env. One `pwd` (returning `/mnt/c/...`)
   would have ended it immediately. Establish platform, resolved executable, shell,
   cwd, and env boundary *before* blaming the tool.
3. **Know how your tools lie.** `find -type f` showed an "empty" dir because it does
   not traverse junctions; that was read as "helpers are missing" and sent the
   diagnosis down a wrong path. PowerShell
   `Get-Item <dir> | Select LinkType,Target` shows the truth.
4. **Verify the verifier.** Two "syntax errors" and one "broken probe" during the
   fix were false alarms from the wrong tool (PowerShell 5.1's legacy `PSParser`;
   a hand-rolled test harness). Confirm a failure is real before acting on it.
5. **Check for duplicates before filing.** The bug already had 8+ open upstream
   issues; a 9th would have been noise. Commenting with a new-version repro added
   signal instead.

_(One noteworthy setup detail, not an incident: the very first push to GitHub was
rejected by GitHub's email-privacy protection because the commit used a private
`@gmail.com` address. Resolved by setting the repo-local git email to the
`@users.noreply.github.com` form. Future commits should keep using the noreply
email.)_

_(One noteworthy setup detail, not an incident: the very first push to GitHub was
rejected by GitHub's email-privacy protection because the commit used a private
`@gmail.com` address. Resolved by setting the repo-local git email to the
`@users.noreply.github.com` form. Future commits should keep using the noreply
email.)_

### 2026-07-23 — 1Password service account locked out by a "parallel initialization storm"

**Impact:** the shared 1Password **service account** (one account across all 5
machines) hit its **per-hour request cap** and temporarily locked, cutting off
1Password secret access for every AI surface.

**Root cause:** the deployed MCP secret launcher (`~/.config/ai-devops/mcp-launch.cmd`,
2026-07-17 version) wrapped every server in `op run --env-file=mcp.env`, which
**re-resolved all ~11 `op://` references on every MCP-server start** — whether or
not that server needed them. Claude Code boots ~2 wrapped servers (~22 reads),
Claude Desktop ~3 (~33 reads), per window open/reload, ×5 machines sharing one
account, into a rolling 60-minute window. Parallel subagents from one session
compounded it. The limit is **total requests/hour, not concurrency** — so a mutex
alone is the wrong tool, and a shared HTTP broker was rejected (no new moving
parts across 5 machines).

**Fix (all in this repo):** `bin/mcp-secret-launch.ps1` resolves all secrets
**once** behind a machine-wide mutex (`Local\ai-devops-1password-refresh`) and
reuses a **15-minute DPAPI-encrypted cache** (`mcp-secrets.dpapi.json`), so
1Password is hit **≤1 refresh / 15 min / machine** no matter how many
windows/servers/subagents launch (~44 reads/hr/machine worst case). Also folded
**Codex** (`~/.codex/config.toml`) into the same launcher via
`bin/configure-codex-1password.ps1`, removing its inline plaintext token.
Deployed + verified on t16; **still to roll out on the other machines** and
**commit/push**. Full detail: [docs/mcp-1password-rate-limit-hardening.md](docs/mcp-1password-rate-limit-hardening.md).

**Trap fixed along the way:** the caching launcher had been committed but never
deployed, hiding a bug. `pwsh -File script -- %*` mis-parses `--` as an empty
parameter name, and even without `--` the child's leading `cmd /c` bound
positionally to `-Url`/`-SecretRef` and was silently dropped. Fixed by declaring
`$CommandArgs` as `[Parameter(Position = 0, ValueFromRemainingArguments = $true)]`
(makes it the only positional, forcing `-Url`/`-SecretRef` to name-only) and
removing `--` from both generated launchers. **Do not re-add `--` or remove
`Position = 0`.**

**Lessons worth keeping:**
1. **A committed fix that was never deployed is not a fix.** The caching launcher
   existed in the repo for days while every machine still ran the storming
   2026-07-17 launcher. Verify the artifact on disk, not just the repo.
2. **Rate limits are per-time-window totals.** Reach for "resolve once, reuse"
   (cache), not concurrency limits, when the cap is requests/hour.
3. **The config/launch layer, not the server, was the primary lever** — confirmed
   by an independent Codex review.

## Pending work

| Status | Item | Owner/next action |
|---|---|---|
| open | Orchestrate stages end-to-end | `ai-run-task` / `ai-model-call` are v0.1 scaffolds; full pipeline automation is future work |
| open | MCP wrapper | Design sketched in `docs/future-mcp-wrapper.md` + `mcp/README.md`; not implemented |
| open | Automated visual testing (Playwright) | Design sketched in `docs/future-visual-testing.md`; manual for now |
| open | App-repo onboarding helper | `docs/repo-onboarding.md` describes manual steps; `ai-onboard-repo` helper not built |
| done | Initial toolkit scaffold + install + doctor green | Completed in commit `f39315d` |
| done | Config-consolidation **Phase 1** | `sync-dotfiles` skill (Claude + Codex), `bin/ai-gcloud-dflow`, `bin/ai-sync-memory` + `memory/` tree. See `docs/config-consolidation-proposal.md`. |
| open | Config-consolidation **Phase 2** | Fold the Dropbox SSH + MCP scripts into `bin/`, pulling secrets from the scoped `vibe_coding` 1Password service account (incl. the `916-alien` SSH key). Rotate the currently-plaintext tokens as they move. |
| open | Config-consolidation **Phase 3** | Retire Dropbox scripts; one-command per-machine onboarding; track the ~5 portable `config.toml` prefs. |

Config-consolidation follow-through is in progress, so **`HANDOFF.md` is present** —
read it for the exact next steps (first memory push, propagate to other machines,
Phase 2/3).
