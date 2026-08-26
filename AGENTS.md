# AGENTS.md — AI DevOps Toolkit router

Read this first, then open only the documents named for the current task. This
file is a router and repository contract, not the complete operating manual.

## What this repository is

`popcre/ai-devops` is Albert's backup-and-restore toolkit for a multi-model AI
coding workflow. It contains Bash and PowerShell command-line tools, prompt
templates, documentation, machine setup, Claude/Codex skills, and an offline
verification workflow. It is not a web application, hosted service, database,
container stack, or deployment pipeline.

The outcome that matters is that the workflow can be restored on a new machine.
The full recovery procedure is in
[`docs/restore-from-zero.md`](docs/restore-from-zero.md).

## Repository rules

- **Route every routine change through a branch and a pull request.**
  This replaced the old "work directly on `main`" rule when the repository moved
  to the `popcre` organization on 2026-08-26 (issue #84).
  `config/repository-policy.json` reports `feature-branch-pr` for this
  repository under **both** owner names, so an old `u2giants` clone and a new
  `popcre` clone behave identically.
- **A direct push is NOT rejected, and that is deliberate. Do not write or rely
  on the claim that it is.**
  Ruleset `21564317` (`main: pull request + merge queue`) grants
  `OrganizationAdmin` a `bypass_mode: always` exemption, and every session
  authenticates as `u2giants`, who holds `admin` on this repository (verified
  against the live ruleset on 2026-08-26). The bypass exists as an emergency
  escape hatch for a repository whose whole purpose is restoring a broken
  machine — the recovery path must not depend on CI being healthy.
  Three consequences follow, and all three are load-bearing:
  1. The `push: main` trigger in `.github/workflows/verify.yml` is **permanent**.
     For a bypassed merge it is the only full verification that commit ever
     gets. Do not remove it as "redundant with the merge queue".
  2. A bypassed merge that lands while a pull request is queued **resets that
     pull request's merge group and rebuilds it from scratch**. Measured on
     2026-08-26: pull request #104 sat healthy at position 1 and never merged,
     while `main` took four bypassed commits in 28 minutes, at one point running
     four ~65-minute Windows builds concurrently for the same pull request.
     Stated plainly: **a required check slower than the interval between
     bypassed merges can never finish** (issue #112).
  3. **Until #98 lands, dequeuing and merging directly is the documented
     interim practice, not a violation** — see
     [`fix_to_gh_org.md`](fix_to_gh_org.md) "MEASURED 2026-08-26 EVENING".
     Re-verify a clean merge against the current `main` first; that check is the
     protection the queue would have given you. Do **not** respond to this by
     removing the bypass actor: without it nothing can merge at all, because a
     ruleset ignores `--admin`. Both settings are individually justified and
     jointly unusable, and both are downstream of `windows-offline` taking ~64
     minutes. Shorten that job and both symptoms disappear.
- GitHub is the source of truth. Finished work is tested, committed, pushed, and
  verified on `origin/main`.
- Before committing, run `git var GIT_COMMITTER_IDENT`; it must show
  `Albert Hazan <u2giants@users.noreply.github.com>`.
- Several AI sessions may share this checkout. Check `git status --short` before
  pulling or staging. Stage only files owned by the current task; never use
  broad staging, destructive resets, or force-pushes.
- Custom code is limited to `bin/`, lifecycle scripts, `config/`, `templates/`,
  `docs/`, `skills/`, `tools/`, `mcp/`, `memory/`, and `tests/`. Changes outside
  that boundary need a task-specific reason.
- Runtime configuration lives outside the repository under `/etc/ai-devops/`.
  Never commit real `.env` files or secrets.
- This repository is public. Raw Claude/Codex transcripts can contain secrets;
  never open or commit transcript `.jsonl` files. The private `transcripts/`
  submodule and ignored chat archives remain outside normal AI context.
- Installation changes can write outside the repository. Read
  [`docs/deployment.md`](docs/deployment.md) before changing install, update,
  uninstall, symlink, or machine-setup behavior.
- **Independent review is required for the reviewer safety path:** changes to
  reviewer wrappers, evidence tools, safety tests, or installed routing rules
  need one read-only exact-head final review before merge. Ordinary plans,
  analysis notes, and documentation-router wording do not.
- A reviewer repair is not complete until every affected local reviewer-issue
  record is marked resolved or partially resolved with exact repair evidence.
  Preserve the original incident package; follow `log-reviewer-issue` for the
  closure audit before reporting success.

## Documentation router

| Current task | Read first | Important boundary |
|---|---|---|
| Implement the 2026-08-21 full repository audit | [`plan_full-strategy-remediation.md`](plan_full-strategy-remediation.md) STATUS, [`bugs.md`](bugs.md) current audit | Incident-first; preserve capabilities; all 30 findings must reach production evidence |
| Quick orientation | `README.md`, this file | Do not load deep docs without a task reason |
| Context size, ownership, routing, or trigger quality | [`docs/context-spec.md`](docs/context-spec.md), [`plan_context-engineering-consolidation.md`](plan_context-engineering-consolidation.md) STATUS | Globals contain only universal rules; measurements come from audit JSON |
| False completion, closeout honesty, or "the instructions are not working" | [`plan_completion-honesty-enforcement.md`](plan_completion-honesty-enforcement.md) STATUS | Read its STATUS table first; prose rewrites alone have already failed twice, so never ship the instruction change without the audit, hook, and eval steps |
| Change a standing Claude/Codex behavior rule | Both files under `templates/system/*global*.md`, [`templates/system/machine-atlas.md`](templates/system/machine-atlas.md), affected shared skill | Keep shared behavior aligned across clients; install with `bin/ai-adopt-globals` |
| Change a `bin/` tool or workflow | [`docs/architecture.md`](docs/architecture.md), [`docs/development.md`](docs/development.md), the tool's verification header and tests | Do not simplify a measured guardrail without reading its reason |
| Install, update, uninstall, or restore | [`docs/deployment.md`](docs/deployment.md), [`docs/restore-from-zero.md`](docs/restore-from-zero.md), affected lifecycle scripts | Preserve machine-local configuration |
| Windows machine setup | [`docs/windows-winget-configuration.md`](docs/windows-winget-configuration.md), `bin/bootstrap-windows-dev.ps1`, `bin/setup-machine.ps1`, `bin/verify-windows-dev.ps1` | Transitional setup scripts are not the primary path |
| Secrets, MCP tokens, or 1Password | [`docs/onboarding-secrets.md`](docs/onboarding-secrets.md), [`docs/config-inventory.md`](docs/config-inventory.md), affected setup script | Serialize 1Password access; never commit secret values |
| Model commands or settings | [`docs/configuration.md`](docs/configuration.md), [`docs/model-setup.md`](docs/model-setup.md) | Per-machine commands stay outside source code |
| Prompt templates | `templates/prompts/`, [`docs/architecture.md`](docs/architecture.md) | Change only the affected workflow stages |
| Skill creation, placement, or trigger quality | [`docs/skills-map.md`](docs/skills-map.md), [`docs/skills-usage-guide.md`](docs/skills-usage-guide.md), [`docs/skill-trigger-eval.md`](docs/skill-trigger-eval.md) | Shared is the default; never keep duplicate client copies |
| Install or refresh skills/globals | [`docs/skills-usage-guide.md`](docs/skills-usage-guide.md), [`docs/codex-skills-usage-guide.md`](docs/codex-skills-usage-guide.md), `bin/ai-install-skills`, `bin/ai-adopt-globals` | `ai-adopt-globals` preserves and verifies machine sections |
| Delegated reviewer work | [`bugs.md`](bugs.md) status, the linked provider plan, [`docs/reviewer-issues.md`](docs/reviewer-issues.md), affected wrapper header/skill/tests | Preserve read-only boundaries, completion proof, exact-head evidence, and provider-specific restrictions |
| Reviewer evidence packet or sandbox | Header of `bin/ai-review-packet` or `bin/ai-review-sandbox`, matching tests | A reviewer keeps full repository read access; linked worktrees need self-contained snapshots |
| Reviewer caching, snapshot reuse, or token/cost reporting | [`plan_reviewer-cache-efficiency.md`](plan_reviewer-cache-efficiency.md) STATUS | Read its STATUS table first; never trade evidence integrity for speed, and never report a token number the provider did not return |
| `ai-muse` stale-turn rejection diagnostics | [`fix_muse_wrapper_reject.md`](fix_muse_wrapper_reject.md) STATUS | The guard is correct; never narrow what `tree_state` covers to stop it firing |
| Shared database structure or business rules | Load the matching `shared-db` or `pop-business-rules` skill and follow its router | Reading is open; structural changes go through `u2giants/shared-db`; licensed private data stays private |
| Repository or worktree cleanup | Load `cleanup-worktree`; read relevant open handoffs and [`docs/critical-incidents.md`](docs/critical-incidents.md) | Preserve every unique change before removing anything |
| Continue unfinished work | The matching OPEN file in `HANDOFF.d/`, newest relevant first, and documents it names | Do not load unrelated handoffs |
| Write a handoff | `handoff-writer`, [`templates/system/handoff-standard.md`](templates/system/handoff-standard.md) | Root `HANDOFF.md` is a static pointer; never rewrite another session's file |
| Write an implementation plan | `implementation-plan-writer`, [`templates/system/implementation-plan-standard.md`](templates/system/implementation-plan-standard.md) | Write for a new session with no chat context |
| Diagnose a known tool failure | [`docs/critical-incidents.md`](docs/critical-incidents.md), [`docs/design-decisions.md`](docs/design-decisions.md), affected tool/tests | Odd behavior may be an intentional guardrail |
| Transcript backup or analysis | Matching transcript skill and its routed docs | Do not open raw archives unless the task explicitly requires their contents |
| Documentation-only cleanup | `README.md` and affected docs | Do not touch source code except to verify accuracy |

## Repository map

| Path | Purpose |
|---|---|
| `bin/` | Installed `ai-*` command-line tools |
| `config/` | Secret-free schemas, templates, policies, and version pins |
| `templates/` | Prompts, repo-doc additions, globals, and a protected-atlas pointer |
| `skills/shared/` | Skills installed for both clients; the default location |
| `skills/claude/`, `skills/codex/` | Genuinely client-specific skills |
| `tools/`, `tests/` | Audits, evaluations, and offline verification |
| `memory/` | Public memory guard only; portable facts live in the private hub. See [`memory/README.md`](memory/README.md) |
| `transcripts/` | Private submodule; never inspect raw transcript data casually |

Installed Linux commands normally point from `/usr/local/bin/ai-*` to the
checkout at `/worksp/ai-devops`. Machine-local settings live in
`/etc/ai-devops/`; logs live in `/var/log/ai-devops/`. Do not rename these paths
casually. Full inventories live in [`docs/config-inventory.md`](docs/config-inventory.md)
and [`docs/architecture.md`](docs/architecture.md).

## Editing and verification

- Search first and read affected verification headers before changing unusual
  guardrails. Use `apply_patch`, preserve unrelated work, and test changed behavior
  per [`docs/development.md`](docs/development.md).
- Keep PowerShell compatible and correctly formatted; run Bash tests through Git
  Bash on Windows.
- UI changes require visual verification. This repository itself has no UI.
- Installation is the deployment mechanism. The GitHub `verify` workflow checks
  toolkit source, but there is no container, package registry, hosted service,
  application deployment workflow, or application database.

## Handoffs and completion

`HANDOFF.md` is a static pointer. Read only OPEN files in `HANDOFF.d/` that
match the current request. When unfinished work needs a handoff, create one new
file through the `handoff-writer` procedure; never edit another session's file.
A completed task needs no new handoff.

Before reporting completion:

1. Run the required tests.
2. Verify Git identity.
3. Commit only task-owned files.
4. Reconcile concurrent `main` safely and push without force.
5. Confirm the intended commit is present on `origin/main`.
6. Report the commit and checks. There is no application deployment for this
   repository; GitHub Actions runs the same offline verification suites used locally.

Active work is recorded in `bugs.md`, root `plan_*.md` files, and matching OPEN
handoffs. Completed plans are retained as decision records; do not treat their
presence as unfinished work or delete them during general cleanup.
