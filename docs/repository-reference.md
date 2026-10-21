# Repository reference

Moved from [`AGENTS.md`](../AGENTS.md) (#1881 phase 4). Load only the section the task needs.

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
| Change install/update/uninstall behavior | `install.sh` / `update.sh` / `uninstall.sh`, [`docs/deployment.md`](deployment.md), tests | Live `/etc/ai-devops/*.env` on machines |
| Add or change a skill | `skills/shared/` first; client trees only for true client-specific behavior | Duplicating the same skill in multiple client trees |
| Change model command flags | `config/models.env.example`, [`docs/configuration.md`](configuration.md), [`docs/model-setup.md`](model-setup.md) | Hard-coding secrets into examples |
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
| Machine classes | `edge-alien`, `edge-runn-envy`, `edge-runn-xps` | [`docs/deployment.md`](deployment.md) | Networking-only — never install the toolkit |
| Protected main branch | `main` + merge queue | GitHub | Never push directly; PR + queue |
| Work claims / plan identity | GitHub issues + `plan_*.md` STATUS | This repo | One issue per application need |

Do not casually rename, regenerate, or replace documented identifiers. Concrete
machine addresses, SSH host identities, and provider project IDs live in the
private config repository, not here.

## Container and service inventory

None. This repository is a scripts-and-docs toolkit. It does not ship
containers, compose stacks, or long-running services. GitHub Actions workflows
are CI/watchdogs only (see [`.github/workflows/`](../.github/workflows/)).

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

See [`docs/configuration.md`](configuration.md),
[`docs/onboarding-secrets.md`](onboarding-secrets.md), and
[`docs/config-inventory.md`](config-inventory.md).

## Deployment

This repository's deployment is **installation**, not a product rollout.

| Topic | Reality |
|---|---|
| Mechanism | `install.sh` (Ubuntu), `bin/bootstrap-windows-dev.ps1` (Windows), `update.sh` for upgrades |
| Update path | Candidate worktree at the reviewed merged commit + `update.sh` with the assigned AI reviewer's exact-head APPROVE |
| Rollback | Previous checkout / recorded tool pins in `config/tool-versions.json`; see [`docs/deployment.md`](deployment.md) |
| Runtime env | `/etc/ai-devops/` on each machine |
| CI workflows | `.github/workflows/` (`verify.yml`, docs reachability, watchdogs, runner qualification) |
| SSH | Used for machine setup and ops; not a routine "deploy" channel for this repo |
| Protected branch | `main` + merge queue; never push directly |

Full procedure and machine classes: [`docs/deployment.md`](deployment.md).
Restore from zero: [`docs/restore-from-zero.md`](restore-from-zero.md).
