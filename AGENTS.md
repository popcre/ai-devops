# AGENTS.md — AI DevOps Toolkit router

Read this first, then open only the document named for the current task.

- Reviewer system: advisory, one rotating CI reviewer (owner ruling 2026-10-29). Plan + STATUS: [plan_skinny-review.md](plan_skinny-review.md); checklist: [docs/reviewer-enforcement-inventory-2026-10-29.md](docs/reviewer-enforcement-inventory-2026-10-29.md).
- Merge-blocking checks: only data-safety gates block a merge; everything else is advisory (owner ruling 2026-10-30). Plan + STATUS: [plan_lean-required-checks.md](plan_lean-required-checks.md).

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

`.claudeignore` covers Claude Code; other tools follow "What to ignore" below.

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
| Investigate bugs or incidents | `AGENTS.md`, matching row in [`docs/task-router.md`](docs/task-router.md), [`docs/critical-incidents.md`](docs/critical-incidents.md), relevant OPEN files in `HANDOFF.d/` | Unrelated folder-level READMEs |
| Continue unfinished work | `AGENTS.md`, [`HANDOFF.md`](HANDOFF.md) (pointer) → OPEN files in [`HANDOFF.d/`](HANDOFF.d/) newest first, then docs named inside them | Docs unrelated to the handoff scope |
| Work in a subfolder with its own README | `AGENTS.md`, that folder-level `README.md`, and only broader docs referenced there | Other folder-level READMEs |
| Claude Code session | [`CLAUDE.md`](CLAUDE.md), then `AGENTS.md` | Other docs unless the task requires them |
| Documentation-only cleanup | `AGENTS.md`, `README.md`, affected docs under `docs/` | Source files except as needed to verify accuracy |
| Standing behavior, triggers, false completion, or transcript work | Matching row in [`docs/task-router.md`](docs/task-router.md) | Bulk plan files |
| Running an in-house tool (ai-review, ai-task-gates, ai-muse, ai-pr-wait, ai-doc-safety, ai-blocker-watch, shared-db scripts) | [`docs/ai-tools-cheat-sheet.md`](docs/ai-tools-cheat-sheet.md) instead of `--help` | The tool's source |
| Tool, workflow, prompt, install, model, secret, or machine setup | Matching row in [`docs/task-router.md`](docs/task-router.md) | Unrelated plans |
| Reviewer, provider, CI, runner, throughput, active plan, or known incident | Matching row in [`docs/task-router.md`](docs/task-router.md) | Full plan bodies until STATUS says so |
| Repository layout, identifiers, credentials, deployment facts | [`docs/repository-reference.md`](docs/repository-reference.md) | Other sections of it |
| Intentional quirks | [`docs/design-decisions.md`](docs/design-decisions.md) | Unrelated decisions |
| Active plans and pending work | [`docs/pending-work.md`](docs/pending-work.md), then that plan's STATUS | Completed plans |

Specialized and low-frequency tasks (BlockerWatch, WarpBuild, Jev, individual
provider repairs, plan STATUS reading) live in
[`docs/task-router.md`](docs/task-router.md). Load only the matching row.

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

## Critical incidents

Read [`docs/critical-incidents.md`](docs/critical-incidents.md) before diagnosing "odd" tool behavior — it may be an intentional guardrail ([`docs/design-decisions.md`](docs/design-decisions.md)).

## Repository contract

`popcre/ai-devops` is Albert's public recovery toolkit for a multi-model AI
workflow, not an app, service, database, container stack, or deployment
pipeline. The recovery procedure lives in
[`docs/restore-from-zero.md`](docs/restore-from-zero.md).

- Work on a branch and pull request; never push to `main`. The protected branch
  uses a merge queue. GitHub is the source of truth, and finished work must be
  tested, merged, and verified on `origin/main`.
- Documentation-only changes (every changed file is prose) merge **around** the
  merge queue: run `bin/ai-doc-safety` on the exact head worktree first; when it
  passes, `gh pr merge --squash --admin`. Any code, test, script, workflow, or
  config change uses the merge queue. Never admin-merge a non-prose change.
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
- Production and shared cloud infrastructure are read-only by default; never
  ask Albert to approve (owner rulings 2026-09-28 and 2026-10-29). AI review
  is advice only and gates nothing. Shared-db migrations reach production only
  through its automatic promotion workflow (preview rehearsal, tests, no
  blocking `review-finding` issue); no manual production command.
  `ai-task-gates` requires no reviewer verdict for any class (#2071); a
  refusal there is reported `Blocked —`, never worked around.
- Shared-database STRUCTURE changes are authored in `popcre/shared-db` through
  its branch-and-PR workflow. Load the matching shared-db skill before acting;
  application rows remain owned by the application.
- **Never run `git pull` or merge in the installed checkout** (`/worksp/ai-devops`). It
  advances only through the protected install: a candidate worktree at the reviewed merged commit,
  its `update.sh`, per `docs/deployment.md`. A plain pull is recorded by
  the post-merge detector and warned about by `ai-task-gates`.
- Installation changes can write outside the repository. Read
  [`docs/deployment.md`](docs/deployment.md) before changing install, update,
  uninstall, symlink, or machine-setup behavior.
- **The reviewer safety path** (reviewer wrappers, evidence tools, safety
  tests, installed routing rules) no longer needs a review before merge: owner
  ruling 2026-10-15 limits required review to `popcre/shared-db`.
- **Two operating systems, one toolkit** (#1783): reviewer tooling runs on Ubuntu (hetz, edge-dev3) and Windows (4837/al8960ofc, 916, edge-dev). Before changing it, write down the OS the problem happened on and every OS the change will run on; design for both, prove both, install on both by each OS's route. Brief: [`config/reviewer-platform-brief.txt`](config/reviewer-platform-brief.txt) (printed by `ai-task-gates start` and `ai-reviewer-issue show`).
- **One code path for every reviewer** (#1834): in shared review code, a step that decides whether evidence, a receipt, a record, cleanup or qualification happens never branches on a provider name — declare the exception as a capability in `config/review-runner-doors.json` (inventory: [`docs/reviewer-harness-consolidation.md`](docs/reviewer-harness-consolidation.md)).
- **AI review is advice only** (owner ruling 2026-10-29, #2041; see
  `docs/owner-rulings.md`). CI's `ai-review` check runs one rotating reviewer
  (Muse, GLM, DeepSeek, StepFun) once per code or plan PR, never fails, and
  skips docs-only PRs; REJECT/REVISE findings open a `review-finding` issue
  for the automatic fixer. No work waits for a review. Wrappers stay callable
  by name for second opinions. Plan: [`plan_skinny-review.md`](plan_skinny-review.md).
- Declare what the task is before starting it: `ai-task-gates start --class
  <class>`. `bin/ai-pr-wait` and the second-opinion wrappers recheck the
  real change set first and refuse an action the work does not call for. A
  protected class cannot be acknowledged away, and no review verdict lifts it;
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
  `ai-gh-wait`; `ai-pr-wait` defaults to a 60-minute deadline and runs in the
  background (owner ruling 2026-10-21, #1962, supersedes the #1183 explicit-flag
  rule), `ai-gh-wait` still needs an explicit `--timeout-minutes`; there is
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

Shared-db migration gate trimming (plan, not active): read
[`plan_shared-db-gate-trim.md`](plan_shared-db-gate-trim.md) STATUS first;
[popcre/shared-db#5150](https://github.com/popcre/shared-db/issues/5150) tracks it.
No gate or workflow changes until the owner approves.

Entire alongside GitHub (memory, Trails, sessions/search and optional CI): read
[`plan_entire-reversible-trial.md`](plan_entire-reversible-trial.md) STATUS first;
[#2022](https://github.com/popcre/ai-devops/issues/2022) owns the reversible trial.

During the authorized public-companion trial, follow
[`docs/entire-trial.md` § Session workflow](docs/entire-trial.md#session-workflow)
for public ai-devops work: keep the owning GitHub issue and normal PR route,
inspect the corresponding mirrored Trail, compare exact source/check links,
and retain sanitized continuation context on GitHub. Entire is advisory and
must not delay GitHub delivery. Never upload private context or enable capture,
Agents, billing, integrations or required-check changes. This instruction
expires November 12, 2026, 5:58 AM EST; check the current New York time before
trial activity. After expiry, record the trial disposition on #2022 and continue
GitHub-only work without altering shared integrations.

Low-frequency and specialized tasks live in [`docs/task-router.md`](docs/task-router.md); load only the matching row.

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
- Never compare file-system paths as raw strings in code or tests: source
  `tools/lib/path-identity.sh` and use `ai_same_path`, or match a fixed fixture suffix.
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
- A second-opinion tool repair is complete only when tests pass and one live
  call of the repaired tool succeeds.

Before reporting completion: run required tests; verify Git identity; commit and
push only task-owned files; reconcile current `main`; merge through the queue;
confirm the intended commit on `origin/main`; report the commit and checks.
Installation is this repository's deployment mechanism. Active state lives in
`bugs.md`, root `plan_*.md` files, and matching OPEN handoffs; completed plans
remain as decision records.
