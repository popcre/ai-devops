# AGENTS.md — AI DevOps Toolkit router

Read this first, then open only the document named for the current task.

## Project summary

`popcre/ai-devops` is Albert's public recovery toolkit for a multi-model AI
coding workflow (plan → review → implement → test → review). It is **not** an
app, service, database, container stack, or product deployment pipeline.

- **Who uses it:** Albert and AI coding sessions (Claude, Codex, Grok, GLM,
  Kimi, Qwen, ZCode, MiMo/MiMoCode) on Windows development machines and Ubuntu
  servers.
- **Key moving parts:** `bin/` CLI tools, lifecycle scripts (`install.sh`,
  `update.sh`, `uninstall.sh`), `config/` examples and registries, `skills/`,
  `templates/`, `docs/`, and tests.
- **Outcome that matters:** the entire multi-model workflow can be restored
  from zero on a fresh machine and kept working without private chat context.
  Recovery procedure: [`docs/restore-from-zero.md`](docs/restore-from-zero.md).

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
| Quick repo orientation | `README.md`, `AGENTS.md` | Deep docs under `docs/` unless the task requires them |
| Modify toolkit behavior or project-owned code | `AGENTS.md`, [`docs/architecture.md`](docs/architecture.md), relevant folder-level `README.md` | `docs/deployment.md` unless install/update behavior changes |
| Add or change configuration, env vars, feature flags, secrets, or runtime settings | `AGENTS.md`, [`docs/configuration.md`](docs/configuration.md), [`docs/onboarding-secrets.md`](docs/onboarding-secrets.md) | Unrelated architecture docs |
| Change local setup, dev scripts, test/lint/debug workflow, or tooling | `AGENTS.md`, [`docs/development.md`](docs/development.md), relevant package/config files | `docs/deployment.md` unless CI/CD changes |
| Change install, update, uninstall, restore, deployment, CI/CD, runners, or runtime environment | `AGENTS.md`, [`docs/deployment.md`](docs/deployment.md), [`docs/configuration.md`](docs/configuration.md) | Local-only development docs unless needed |
| Investigate bugs or incidents | `AGENTS.md`, matching row below or in [`docs/task-router.md`](docs/task-router.md), [`docs/critical-incidents.md`](docs/critical-incidents.md), relevant OPEN files in `HANDOFF.d/` | Unrelated folder-level READMEs |
| Continue unfinished work | `AGENTS.md`, [`HANDOFF.md`](HANDOFF.md) (pointer) → OPEN files in [`HANDOFF.d/`](HANDOFF.d/) newest first, then docs named inside them | Docs unrelated to the handoff scope |
| Work in a subfolder with its own README | `AGENTS.md`, that folder-level `README.md`, and only broader docs referenced there | Other folder-level READMEs |
| Claude Code session | [`CLAUDE.md`](CLAUDE.md), then `AGENTS.md` | Other docs unless the task requires them |
| Documentation-only cleanup | `AGENTS.md`, `README.md`, affected docs under `docs/` | Source files except as needed to verify accuracy |
| Standing behavior, triggers, false completion, or transcript work | Matching row in [`docs/task-router.md`](docs/task-router.md) | Bulk plan files |
| Tool, workflow, prompt, install, model, secret, or machine setup | Matching row in [`docs/task-router.md`](docs/task-router.md) | Unrelated plans |
| Reviewer, provider, CI, runner, throughput, active plan, or known incident | Matching row in [`docs/task-router.md`](docs/task-router.md) | Full plan bodies until STATUS says so |
| Continue unfinished work from a handoff | OPEN `HANDOFF.d/` files, newest relevant first | Unrelated handoffs |

Specialized and low-frequency tasks (BlockerWatch, WarpBuild, Jev, individual
provider repairs, plan STATUS reading) live in
[`docs/task-router.md`](docs/task-router.md) and the **Specialized task router**
section below. Load only the matching row.

## Repository structure

| Path | Role | Kind |
|---|---|---|
| `bin/` | Executable CLI tools (symlinked into `/usr/local/bin` by `install.sh`) | Project-owned code |
| `install.sh`, `update.sh`, `uninstall.sh` | Install / update / remove the toolkit on a machine | Project-owned deployment |
| `config/` | `*.env.example` templates and JSON registries copied or consulted at runtime | Project-owned config |
| `templates/` | Prompt templates, system globals, handoff/plan standards | Project-owned templates |
| `docs/` | Architecture, development, configuration, deployment, incidents, specialty guides | Documentation |
| `skills/` | Shared and per-client skill scaffolding (`skills/shared`, `skills/claude`, `skills/codex`, …) | Project-owned skills |
| `tools/` | Supporting libraries and specialized helpers | Project-owned code |
| `tests/` | Focused shell/Python tests for tools and docs gates | Project-owned tests |
| `mcp/`, `memory/` | MCP wrapper scaffolding and memory helpers | Project-owned code |
| `hooks/` | Client hook scripts | Project-owned code |
| `scripts/` | Supporting scripts | Project-owned code |
| `HANDOFF.d/` | One write-once handoff file per unfinished session | Session workstreams |
| `plan_*.md`, `fix_*.md`, `bugs.md` | Active plans, fix records, and current defect state | Living working docs |
| `transcripts/` | Private submodule (`u2giants/ai-devops-transcripts`) | Private — never load casually |
| `.github/workflows/` | CI: verify, docs reachability, watchdogs, runner qualification | CI |
| `/etc/ai-devops/` (outside repo) | Real machine runtime config (`*.env`) | Runtime — never committed |

There is no generated application code and no vendor tree in this repository.
Build artifacts and caches (if any appear) belong under ignored paths only.

## Prime Directive: custom-code boundary

Our custom code lives here:

- `bin/`
- `install.sh`, `update.sh`, `uninstall.sh`
- `config/`
- `templates/`
- `docs/`
- `skills/`
- `tools/`
- `mcp/`
- `memory/`
- `hooks/`
- `scripts/`
- `tests/`
- `.github/workflows/`

Everything else requires justification before touching. Never scatter toolkit
logic into ignore-irrelevant roots, private submodules, or another repository.

## Core modification inventory

| File | Change made | Why it was necessary | Risk during upgrades |
|---|---|---|---|
| _(none)_ | No files outside project-owned areas are modified by this toolkit in normal operation | The repository is the project | Installed machines keep runtime config under `/etc/ai-devops/`; review install/update scripts before assuming they overwrite it |

## Task-to-file navigation: what to edit for common changes

| Task | Files to touch | Files not to touch |
|---|---|---|
| Add or change a CLI tool | `bin/ai-*`, matching tests in `tests/`, docs row if behavior is new | Reviewer wrappers unless the task is reviewer-safety class |
| Change install/update/uninstall behavior | `install.sh` / `update.sh` / `uninstall.sh`, [`docs/deployment.md`](docs/deployment.md), tests | Live `/etc/ai-devops/*.env` on machines |
| Add or change a skill | `skills/shared/` first; client trees only for true client-specific behavior | Duplicating the same skill in multiple client trees |
| Change model command flags | `config/models.env.example`, [`docs/configuration.md`](docs/configuration.md), [`docs/model-setup.md`](docs/model-setup.md) | Hard-coding secrets into examples |
| Change machine or secret onboarding | `docs/onboarding-secrets.md`, setup scripts, `config/*.env.example` | Committing real `.env` or tokens |
| Change CI or runners | `.github/workflows/`, runner docs, related `config/*.json` | Weakening required checks |
| Change task gates or review safety | `bin/ai-task-gates`, `config/task-gates.json`, matching tests | Bypassing a protected class |
| Write or retire a plan | Root `plan_*.md` + STATUS, matching issue | Editing another session's `HANDOFF.d/` file |
| Documentation-only cleanup | `README.md`, `AGENTS.md`, `docs/`, folder READMEs | Source except to verify accuracy |

## Data model and external identifiers

| Entity / system | Identifier | Where defined | Notes |
|---|---|---|---|
| Public toolkit repo | `popcre/ai-devops` | GitHub | Source of truth for code and public docs |
| Shared database repo | `popcre/shared-db` | GitHub | Durable backend/structure truth |
| Private machine topology | `u2giants/ai-devops-private-config` | Private repo | Restored by `ai-private-config`; never in this repo |
| Private transcripts | `u2giants/ai-devops-transcripts` (`transcripts/` submodule) | Private repo | Never commit raw `.jsonl` here |
| Secrets vault | `vibe_coding` | 1Password | Only via `op` / `secrets-to-1password` |
| Runtime config root | `/etc/ai-devops/` | Machine | `models.env`, `server.env`, related runtime files |
| Machine classes | `edge-alien`, `edge-runn-envy`, `edge-runn-xps` | [`docs/deployment.md`](docs/deployment.md) | Networking-only — never install the toolkit |
| Protected main branch | `main` + merge queue | GitHub | Never push directly; PR + queue |
| Work claims / plan identity | GitHub issues + `plan_*.md` STATUS | This repo | One issue per application need |

Do not casually rename, regenerate, or replace documented identifiers. Concrete
machine addresses, SSH host identities, and provider project IDs live in the
private config repository, not here.

## Container and service inventory

None. This repository is a scripts-and-docs toolkit. It does not ship
containers, compose stacks, or long-running services. GitHub Actions workflows
are CI/watchdogs only (see [`.github/workflows/`](.github/workflows/)).

## What to ignore

Keep these out of AI context. `.claudeignore` and `.cursorignore` must stay
aligned with this list:

- `.git/`
- `transcripts/` and any raw `.jsonl` chat archives (`claude_chats/`,
  `codex_chats/`, and similar)
- `.ai/runs/`, `.ai/tmp/`, `.ai/reviews/`
- `.playwright-mcp/`, `.playwright-cli/`, `test-results/`, `playwright-report/`
- `*.env` (keep `*.env.example`)
- `node_modules/`, `dist/`, `.cache/`, `coverage/`
- Machine-local config under `/etc/ai-devops/` (never in the repo anyway)

## Intentional quirks and non-obvious decisions

### Networking-only machine classes

Looks like:
Any hostname can take the full toolkit install.

Actually:
`edge-alien`, `edge-runn-envy`, and `edge-runn-xps` receive networking only
(SSH key, SSH config, hostnames, Tailscale).

Why:
They are not development machines; installing the toolkit on them has caused
repeated real damage.

Do not change because:
A new session that "helpfully" installs there recreates the incident. Check the
hostname first. Full rule: [`docs/deployment.md`](docs/deployment.md) § Machine classes.

### Canonical checkout is landing-only

Looks like:
`C:\repos\ai-devops` or `/worksp/ai-devops` is a normal editable clone.

Actually:
Write-capable work uses a fresh worktree at current upstream. The canonical
checkout is for landing, installation, and recovery only.

Why:
Concurrent AI sessions destroy each other's uncommitted work when they share
one dirty tree (see [`docs/critical-incidents.md`](docs/critical-incidents.md)).

Do not change because:
Shared-editing in the landing checkout is how sessions lose work with no merge
to recover it.

### Installation is the deployment

Looks like:
This repo needs a product deploy pipeline.

Actually:
`install.sh` / `update.sh` / candidate-worktree `update.sh` with reviewer
APPROVE **is** the deployment path. There is no app runtime to roll out.

Why:
The deliverable is a working multi-model toolkit on a machine.

Do not change because:
Inventing a product deployment path would describe a system that does not exist.

### `HANDOFF.md` is a static pointer

Looks like:
One shared handoff document that each session rewrites at closeout.

Actually:
Root `HANDOFF.md` never changes. Each session writes exactly one write-once
file under `HANDOFF.d/` and deletes it when that workstream is proven done.

Why:
Concurrent sessions rewriting one file silently drop work.

Do not change because:
A shared mutable handoff or `merge=union` reintroduces silent corruption. See
[`templates/system/handoff-standard.md`](templates/system/handoff-standard.md).

### Config lives outside the repo

Looks like:
Runtime settings belong in committed config.

Actually:
`config/*.env.example` is committed; real `models.env` / `server.env` live under
`/etc/ai-devops/` on each machine and are never committed.

Why:
This repo is public; real env files and secrets must stay out of it.

Do not change because:
Committing a real `.env` is a credential leak.

More quirks (read-only reviews, MCP secret launcher caching, install-skills
never pruning, dual Muse engines, and others):
[`docs/design-decisions.md`](docs/design-decisions.md).

## Credentials and environment

Names only — never secret values in this repository.

| Variable / store | Purpose | Stored where | Required in dev | Required in prod |
|---|---|---|---|---|
| `AI_DEVOPS_HOME` | Toolkit checkout root | `/etc/ai-devops/models.env`, `server.env` | yes | yes |
| `AI_DEVOPS_ETC` | Runtime config directory | `server.env` | yes | yes |
| `AI_DEVOPS_LOG_DIR` | Log directory | `server.env` | yes | yes |
| `WORKSPACE_ROOT` | Application repos root (informational) | `server.env` | optional | optional |
| `DEFAULT_MAIN_BRANCH` | Safety warnings (`main` / `master`) | `server.env` | yes | yes |
| `OWNER_NAME` | Plain-English review summaries | `server.env` | yes | yes |
| `CLAUDE_REVIEW_CMD` | Legacy Claude adapter command | `models.env` | optional | optional |
| `CODEX_PLAN_CMD` | Codex planning stage | `models.env` | yes | yes |
| `CODEX_IMPLEMENT_CMD` | Codex implementation stage | `models.env` | yes | yes |
| `CODEX_TEST_CMD` | Codex testing stage | `models.env` | yes | yes |
| `CODEX_CMD` | Codex second-opinion review | `models.env` | optional | optional |
| 1Password vault `vibe_coding` | Secrets and service-account token | 1Password | setup once | setup once |
| CLI login state | Provider auth (`~/.claude`, `~/.codex`, etc.) | Machine, not this repo | yes | yes |

See [`docs/configuration.md`](docs/configuration.md),
[`docs/onboarding-secrets.md`](docs/onboarding-secrets.md), and
[`docs/config-inventory.md`](docs/config-inventory.md).

## Deployment

This repository's deployment is **installation**, not a product rollout.

| Topic | Reality |
|---|---|
| Mechanism | `install.sh` (Ubuntu), `bin/bootstrap-windows-dev.ps1` (Windows), `update.sh` for upgrades |
| Update path | Candidate worktree at the reviewed merged commit + `update.sh` with the assigned AI reviewer's exact-head APPROVE |
| Rollback | Previous checkout / recorded tool pins in `config/tool-versions.json`; see [`docs/deployment.md`](docs/deployment.md) |
| Runtime env | `/etc/ai-devops/` on each machine |
| CI workflows | `.github/workflows/` (`verify.yml`, docs reachability, watchdogs, runner qualification) |
| SSH | Used for machine setup and ops; not a routine "deploy" channel for this repo |
| Protected branch | `main` + merge queue; never push directly |

Full procedure and machine classes: [`docs/deployment.md`](docs/deployment.md).
Restore from zero: [`docs/restore-from-zero.md`](docs/restore-from-zero.md).

## Critical incidents

Maintained in [`docs/critical-incidents.md`](docs/critical-incidents.md). High
level:

- Silent non-functional Codex on Windows (2026-07-16)
- 1Password service-account lockout (2026-07-23)
- `git reset --hard` destroying another session's work (2026-08-18)
- Force-push dropping commits from `main` (2026-08-19)
- MCP config written where the client never reads it (2026-08-20)
- Local test series cancelling live CI on the same machine (2026-08-28)
- Disk exhaustion from review artifacts (2026-09-23 and later)
- Installer parity test wiping real skills (2026-09-25)
- OOM from leaked helpers / huge assert diffs (2026-09-28, 2026-10-11)

Read the incident file before diagnosing "odd" tool behavior — it may be an
intentional guardrail ([`docs/design-decisions.md`](docs/design-decisions.md)).

## Pending work

Current reviewer recurrence repairs: read the [edge-dev3 repair plan](plan_reviewer-recurrence-repair.md) STATUS first; reuse existing owners and completed programmes.

Edge-dev reviewer repair without AI-reviewer gates: read the [edge-dev no-review plan](plan_edge-dev-reviewer-repair-no-review.md) STATUS first (owner bootstrap: implementation must not need reviewers).

Live sources (always prefer these over this table when they disagree):

| Status | Item | Owner / next action |
|---|---|---|
| live | Active plans and STATUS | Root `plan_*.md` — read STATUS first |
| live | Open session workstreams | `HANDOFF.d/` OPEN files, newest first |
| live | Known defects | [`bugs.md`](bugs.md) |
| live | Specialized task queue | [`docs/task-router.md`](docs/task-router.md) matching rows |

Do not treat completed `plan_*.md` files as a backlog; they remain decision
records. When adding rows here, mark them `done` or remove them as soon as they
stale.

## Repository contract

`popcre/ai-devops` is Albert's public recovery toolkit for a multi-model AI
workflow, not an app, service, database, container stack, or deployment
pipeline. The recovery procedure lives in
[`docs/restore-from-zero.md`](docs/restore-from-zero.md).

- Work on a branch and pull request; never push to `main`. The protected branch
  uses a merge queue. GitHub is the source of truth, and finished work must be
  tested, merged, and verified on `origin/main`.
- Before committing, run `git var GIT_COMMITTER_IDENT`; it must show
  `Albert Hazan <u2giants@users.noreply.github.com>`.
- The canonical local checkout is landing-only. Every write-capable Codex or Claude task uses its own current-upstream worktree. Stage only task-owned
  files; never use broad staging, destructive resets, or force-pushes.
- **Machine classes:** `edge-alien`, `edge-runn-envy`, and `edge-runn-xps` are
  **networking-only** (SSH key, SSH config, hostnames, Tailscale). Never install
  the ai-devops toolkit on them. See [`docs/deployment.md`](docs/deployment.md)
  § Machine classes. This mistake keeps happening — check the hostname first.
- Custom code belongs in `bin/`, lifecycle scripts, `config/`, `templates/`,
  `docs/`, `skills/`, `tools/`, `mcp/`, `memory/`, or `tests/`. Runtime config
  belongs under `/etc/ai-devops/`; never commit `.env` files or secrets.
- This repository is public. Never open or commit raw transcript `.jsonl`,
  licensed data, secrets, or private artifacts. The private `transcripts/`
  submodule and ignored chat archives stay outside normal AI context.
- Production and shared cloud infrastructure are read-only by default. Run `terraform apply`,
  `terraform destroy`, or mutating production `gcloud` commands only with the
  assigned AI reviewer's explicit APPROVE of the exact action and
  resource; never ask Albert to approve (owner ruling 2026-09-28). Where
  `ai-task-gates` asks for approval, pass `--reviewer-approval <report>`: the
  assigned AI reviewer's exact-head APPROVE report (popcre/ai-devops#996); run
  that review with `ai-review --implementer <your engine>` unless you are Claude
  Code or Codex.
  The sole exception is the separately activated `shared-db` automatic migration
  workflow after exact structural admission, guarded merge, and merged-main
  preview proof; it authorizes no manual production command or other infrastructure
  mutation and fails closed to an engineer on any absent or ambiguous evidence.
  Owner ruling (2026-10-02, verbatim: "let AI launch it and remove that rule
  permanently"): an AI session may launch its merged-preview run for an
  approved, merged change after `ai-task-gates check --before shared-db-promotion`.
- Shared-database STRUCTURE changes are authored in `popcre/shared-db` through
  its branch-and-PR workflow. Load the matching shared-db skill before acting;
  application rows remain owned by the application.
- **Never run `git pull` or merge in the installed checkout** (`/worksp/ai-devops`). It
  advances only through the protected install: a candidate worktree at the reviewed merged commit,
  its `update.sh` with the exact-head APPROVE, per `docs/deployment.md`. A plain pull is recorded by
  the post-merge detector and warned about by `ai-task-gates`.
- Installation changes can write outside the repository. Read
  [`docs/deployment.md`](docs/deployment.md) before changing install, update,
  uninstall, symlink, or machine-setup behavior.
- **Independent review is required for the reviewer safety path:** changes to
  reviewer wrappers, evidence tools, safety tests, or installed routing rules
  need one read-only exact-head final review before merge. Ordinary plans,
  analysis notes, and documentation-router wording do not.
- **Discretionary AI review is shared-db-only** (owner 2026-10-13, #1714).
  Outside `popcre/shared-db`, dispatch a review only when the task class's gate
  already demands one (installation, reviewer-safety, deployment,
  infrastructure, production, shared-db promotion). Ordinary docs, tooling, and
  non-shared-db code land with no review; a review stays available on request
  by name. The rotation pool is Muse, DeepSeek, GLM, and StepFun. Other
  wrappers stay installed and callable by name but are frozen (best-effort,
  not maintained). Rules: [`docs/reviewer-rotation-rules.md`](docs/reviewer-rotation-rules.md)
  13–14; plan [`plan_review-scope-reduction.md`](plan_review-scope-reduction.md).
- Declare what the task is before starting it: `ai-task-gates start --class
  <class>`. The reviewer lifecycle, `bin/ai-pr-wait`, and `bin/ai-review`
  recheck the real change set first and refuse an action the work does not
  call for. A protected class cannot be acknowledged or reviewer-approved away;
  the honest way past one is to redeclare the task at the stronger class and
  then do what that class actually requires.
- Wait on CI through **bounded, event-aware** tools.
  Use `bin/ai-pr-wait <pr> --timeout-minutes N` for a pull request, surface a failing check or queue
  ejection immediately, and do independent useful work while long checks run.
  Make every GitHub call through `bin/ai-gh` (machine-wide lock, spacing, hourly
  budget, and rate-limit back-off) — this is a rule for callers, not something the
  shell enforces, and a few older scripts still call `gh` directly and are being
  migrated; other waits use `bin/ai-gh-wait`. At most one
  GitHub call every 5 minutes per waiter; never `gh run watch`, and never an
  open-ended `until`/`while` loop around `gh` — every wait needs a deadline or
  iteration cap (#401). Use bounded in-session `ai-pr-wait` /
  `ai-gh-wait` with an **explicit** `--timeout-minutes` deadline only; there is
  no required waiter registry, TTL service, or park-state store (voluntary
  inert registration is permitted, unrequired, unmeasured). If the wait will outlive
  the turn, leave the existing issue or pull request as the card and return
  later — GitHub notifications are the reminder (#1183 child 3, #511).
- Reuse before adding another plan, workflow, harness, or provider copy. Every
  new shared artifact needs an owner, a reason the
  shared home cannot serve the need, and a retirement or consolidation path.
  Harness consolidation belongs to #167; provider-wrapper sharing to #169;
  plan-backlog consolidation to #168 under parent #159.

## Specialized task router

High-frequency tasks are in the Documentation map. Use this table only after
that map routes you here.

| Task | Read first | Boundary |
|---|---|---|
| GitHub API limits, request volume, quota coverage or duplicate polling | [GitHub request reduction plan](plan_github-request-reduction.md) STATUS, [issue #658](https://github.com/popcre/ai-devops/issues/658); for remaining unneeded traffic (snapshot reuse, waiter sharing, direct `gh`) use [cut unneeded GitHub traffic plan](plan_cut-unneeded-github-traffic.md) STATUS | Measure and reduce sources; preserve workflow and separate quota buckets; continue authorized phases when actual gates allow |
| Tools or skills loading per session, per-repository scoping, MCP membership drift | [Tool and skill scoping plan](plan_tool-and-skill-scoping.md) STATUS, [issue #707](https://github.com/popcre/ai-devops/issues/707) | Measure before/after; never remove a constrained server; protected skills stay global; passthrough gateways only |
| Leftover AI temporary files, full `/tmp`, memory filled by temp | [Session temp cleanup plan](plan_session-temp-cleanup.md) STATUS | Creator deletes its own temp root; sweeper is backup only; never delete another session's files |
| GitHub Actions minutes, hosted-runner cost, stale or duplicate CI runs | [Actions minutes reduction plan](plan_actions-minutes-reduction.md) STATUS, [issue #1464](https://github.com/popcre/ai-devops/issues/1464) | Never weaken a required check; never cancel merge_group; edge-dev3 first with hosted fallback |
| Context size or routing ownership | [`docs/context-spec.md`](docs/context-spec.md), relevant STATUS in [`plan_context-engineering-consolidation.md`](plan_context-engineering-consolidation.md) | One owner per rule; measure before and after |
| Azure CLI mailbox access | [`docs/onboarding-secrets.md#azure-cli-mailbox-access`](docs/onboarding-secrets.md#azure-cli-mailbox-access) | Use the isolated profile and private machine allowlist; Exchange continues to enforce mailbox scope |
| BlockerWatch waking (registration is OUT), dependency links, scheduler health, or repair | [`plan_blockerwatch-reliability-repair.md`](plan_blockerwatch-reliability-repair.md) STATUS, then the BlockerWatch row in [`docs/task-router.md`](docs/task-router.md) | Do not trust exit 0 until the plan's reconciliation and live-health gates are complete |
| StepFun OpenCode compaction or Windows runner list | [StepFun OpenCode profile](config/opencode-stepfun/README.md) | Keep explicit compaction settings until measured evidence supports a change; preserve hashed runner gates |
| Repeated tests/reviews, interrupted runs, or workflow delivery efficiency | [`plan_workflow-efficiency.md`](plan_workflow-efficiency.md) STATUS, issue #650 | Continue authorized outcomes when actual gates allow; reuse existing repairs and retain source-bound safety |
| Evidence-only commit churn, unrelated-main review invalidation, or Jujutsu pilot | [`plan_agent_evidence_and_jujutsu_pilot.md`](plan_agent_evidence_and_jujutsu_pilot.md) STATUS, issue #903 | Reconcile existing owners first; GitHub stays authoritative; pilot remains reversible |
| Windows runner maintenance elevation over SSH | [Windows runner maintenance elevation plan](plan_windows-runner-maintenance-elevation.md) STATUS, [issue #262](https://github.com/popcre/ai-devops/issues/262) | Keep UAC and remote-token filtering; only the qualification refresh is allowlisted; installation/live proof remains a protected gate |
| WarpBuild Azure BYOC Windows CI (canary or cost cut-over) | [`docs/warpbuild-azure-byoc.md`](docs/warpbuild-azure-byoc.md), [issue #961](https://github.com/popcre/ai-devops/issues/961) | Required CI stays Blacksmith until a reviewed cut-over; public-repo runner groups must allow public jobs |
| Watchdog duty pool, local timed tasks, or adding a machine to alarms | [`docs/watchdog-duty-pool.md`](docs/watchdog-duty-pool.md), then [`plan_watchdog-local-timed-tasks.md`](plan_watchdog-local-timed-tasks.md) STATUS | Name is **watchdog duty pool** / `watch_hosts`; never Blacksmith for alarms; claim/lease single poster; live proof + failover drill |
| ZCode for Windows client support (skills, MCP, hooks, wrapper) | [ZCode Windows support plan](plan_zcode-windows-support.md) STATUS, [issue #558](https://github.com/popcre/ai-devops/issues/558) | Follow the Claude/Codex per-client pattern; never edit vendor bytes under `C:\Program Files\ZCode`; NO ZCode reviewer ever (owner ruling 2026-09-17: GLM never reviews GLM-orchestrated work) |
| MiMo / MiMoCode for Windows client support (skills, MCP, wrapper) | [MiMo Windows support plan](plan_mimo-windows-support.md) STATUS | Follow the Claude/Codex/ZCode per-client pattern; skills write root is `~/.config/mimocode/skills/` only; MCP `command` is an array and timeout key is `timeout`; NO MiMo reviewer; no completion-check hook (no hook surface) |
| Shared-db delivery delay or orchestrator throughput | [`plan_shared-db-complete-throughput-repair.md`](plan_shared-db-complete-throughput-repair.md) STATUS (closed #401 decision record) | Preserve the proven request-to-live safeguards; route new defects to new issues rather than reopening the programme |
| Multiple live proofs or proofs saved for a later chat | [`plan_live-proof-session-sizing.md`](plan_live-proof-session-sizing.md) STATUS | Complete authorized proofs across child boundaries; preserve actual dependencies, ownership and safety gates |
| Reviewer token waste, repeat reviews, paid-key fallbacks (not Grok) | [`plan_reviewer-spend-waste.md`](plan_reviewer-spend-waste.md) STATUS (all done 2026-10-07), parent [#1436](https://github.com/popcre/ai-devops/issues/1436) closed | Never cap turn budgets; no silent paid-key fallback; do not redo C1-C9 |
| Combined reviewer reliability and cache/session qualification | [`plan_reviewer-reliability-and-efficiency.md`](plan_reviewer-reliability-and-efficiency.md) STATUS | Reuse existing provider work; no completion without installed evidence |
| TypeSafe Jev evaluation or advisory integration | [`plan_typesafe-jev-decision-layer.md`](plan_typesafe-jev-decision-layer.md) STATUS, then [`plan_typesafe-jev-advisory-integrations.md`](plan_typesafe-jev-advisory-integrations.md) STATUS and [issue #643](https://github.com/popcre/ai-devops/issues/643); for measured token substitution read [`plan_typesafe-jev-spend-reduction.md`](plan_typesafe-jev-spend-reduction.md) STATUS | Public-data pilots first; Jev never opens a gate, mutates authoritative state, or replaces review; key via `op run` only |
| Review-value / review-waste mining from AI transcripts (Jev labeling) | [the Jev review-waste mining plan](plan_jev-review-waste-mining.md) STATUS first — do not re-derive or re-plan | Evidence only; safety-gate reviews get their own bucket; no raw transcript text in the public repo; five-level `Score` value scale is locked |
| Review-packet race (target moved forward), slow review evidence, or adversarial-case planning | [review-packet race and evidence speed plan](plan_review-packet-race-and-evidence-speed.md) STATUS | Only the target-ref tip check gains ancestry tolerance; HEAD/digest/merge-base stay strict; never delete a guarded packet test — re-scope it |
| Shared database or POP business rules | Matching shared-db or `pop-business-rules` skill | Reading is open; governed structure and private-data boundaries remain |
| Repository or worktree cleanup | `cleanup-worktree`, relevant open handoff, [`docs/critical-incidents.md`](docs/critical-incidents.md) | Preserve every unique change before removal |
| Find branches, worktrees, handoff files, or agent job records | [the housekeeping inventory guide](docs/housekeeping.md), `bin/ai-housekeeping`, [plan_repo-housekeeping-visibility.md](plan_repo-housekeeping-visibility.md) STATUS first, `skills/shared/cleanup-worktree/SKILL.md` | Report-only inventory; do not build a delete mode — see the plan's rejected approaches |
| Write a handoff | `handoff-writer`, [`templates/system/handoff-standard.md`](templates/system/handoff-standard.md) | Root `HANDOFF.md` is a static pointer |
| Write an implementation plan | `implementation-plan-writer`, [`templates/system/implementation-plan-standard.md`](templates/system/implementation-plan-standard.md) | Write for a session with no chat context |
| Documentation-only cleanup | [`README.md`](README.md) and affected docs | Do not touch source code except to verify accuracy |
| AI token waste, reply discipline, compression pilots | [`docs/compression-and-process-fixes.md`](docs/compression-and-process-fixes.md), `skills/shared/scaledown-compress/SKILL.md` | Measure billed tokens and cache hits; never send secrets or private transcripts through a compressor |
| Markdown reachability gate or rollout | [`docs/doc-reachability.md`](docs/doc-reachability.md), `bin/ai-doc-reachability`, `.doc-reachability.json`, and its tests | Gate only PR-added or moved Markdown; do not make legacy orphans block unrelated work |

**Every `HANDOFF.d/` file in this repo MUST open with the three-line contract block
(`issue:`, `status:`, `owner:`).** A file without it cannot be retired by
anyone but its author, and will be reported as `UNATTRIBUTED` by
`ai-housekeeping`. When there is no GitHub issue, do not invent a parallel
tracker: open one on this repo with `gh issue create`, or if the work genuinely
has no issue write `issue: none` plus a one-line reason. `issue: none` is legal
but will be reported as `UNPROVABLE`.

## Editing and delivery

- Search before reading large files. Follow [`docs/development.md`](docs/development.md),
  use `apply_patch` for hand edits, preserve unrelated work, and run focused
  tests before the required suites. Keep routine output compact without hiding
  errors. PowerShell must stay compatible; run Bash tests through Git Bash on
  Windows. This repository has no UI.
- Never overlap a local full test series with a GitHub job on the same physical
  Windows host or a shared installed runtime. Check that boundary with
  `bin/ai-test-local --check-collision`; a busy remote self-hosted runner does
  not create a machine-wide stop, and GitHub-hosted and Blacksmith lanes remain
  usable. For runner or CI work, follow [`docs/task-router.md`](docs/task-router.md).
- Do not verify the same commit twice. The merge queue tests the exact landing
  commit; rerun only a failed or changed result.
- **One status probe per state change.** After a wait completes or a merge
  lands, record the answer and move on. Prefer `bin/ai-pr-wait` /
  `bin/ai-gh-wait` over open polling; leave the issue or pull request as the
  card when a wait outlives the turn.
- A reviewer repair is complete only when tests pass and every affected local
  reviewer-issue record is resolved or partially resolved with exact evidence.
  Follow `log-reviewer-issue` and preserve the incident package.

Before reporting completion: run required tests; verify Git identity; commit and
push only task-owned files; reconcile current `main`; merge through the queue;
confirm the intended commit on `origin/main`; report the commit and checks.
Installation is this repository's deployment mechanism. Active state lives in
`bugs.md`, root `plan_*.md` files, and matching OPEN handoffs; completed plans
remain as decision records.
