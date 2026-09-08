# AGENTS.md — AI DevOps Toolkit router

Read this first, then open only the document named for the current task.

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
- Custom code belongs in `bin/`, lifecycle scripts, `config/`, `templates/`,
  `docs/`, `skills/`, `tools/`, `mcp/`, `memory/`, or `tests/`. Runtime config
  belongs under `/etc/ai-devops/`; never commit `.env` files or secrets.
- This repository is public. Never open or commit raw transcript `.jsonl`,
  licensed data, secrets, or private artifacts. The private `transcripts/`
  submodule and ignored chat archives stay outside normal AI context.
- Production and shared cloud infrastructure are read-only by default. Do not
  run `terraform apply`, `terraform destroy`, or mutating production `gcloud`
  commands without Albert naming the exact action and resource in this chat.
- Shared-database STRUCTURE changes are authored in `u2giants/shared-db` through
  its branch-and-PR workflow. Load the matching shared-db skill before acting;
  application rows remain owned by the application.
- Installation changes can write outside the repository. Read
  [`docs/deployment.md`](docs/deployment.md) before changing install, update,
  uninstall, symlink, or machine-setup behavior.
- **Independent review is required for the reviewer safety path:** changes to
  reviewer wrappers, evidence tools, safety tests, or installed routing rules
  need one read-only exact-head final review before merge. Ordinary plans,
  analysis notes, and documentation-router wording do not.
- Wait on CI through **bounded, event-aware** tools.
  Use `bin/ai-pr-wait <pr>` for a pull request, surface a failing check or queue
  ejection immediately, and do independent useful work while long checks run.
- Reuse before adding another plan, workflow, harness, or provider copy. Every
  new shared artifact needs an owner, a reason the
  shared home cannot serve the need, and a retirement or consolidation path.
  Harness consolidation belongs to #167; provider-wrapper sharing to #169;
  plan-backlog consolidation to #168 under parent #159.

## Task router

| Task | Read first | Boundary |
|---|---|---|
| Quick orientation | [`README.md`](README.md) | Do not bulk-load docs |
| Context size or routing ownership | [`docs/context-spec.md`](docs/context-spec.md), relevant STATUS in [`plan_context-engineering-consolidation.md`](plan_context-engineering-consolidation.md) | One owner per rule; measure before and after |
| Standing behavior, trigger quality, false completion, “instructions not working,” or transcript work | Matching row in [`docs/task-router.md`](docs/task-router.md) | Preserve client parity, safety gates, and private-data boundaries |
| Tool, workflow, prompt, install, model, secret, or machine setup | The matching row in [`docs/task-router.md`](docs/task-router.md) | Read the affected verification header before edits |
| Reviewer, provider, CI, runner, throughput, active plan, or known incident | [`docs/task-router.md`](docs/task-router.md) | Resolve current status; preserve safety behavior |
| Shared database or POP business rules | Matching shared-db or `pop-business-rules` skill | Reading is open; governed structure and private-data boundaries remain |
| Repository or worktree cleanup | `cleanup-worktree`, relevant open handoff, [`docs/critical-incidents.md`](docs/critical-incidents.md) | Preserve every unique change before removal |
| Continue unfinished work | Matching OPEN file in [`HANDOFF.d/`](HANDOFF.d/), newest relevant first | Do not read unrelated handoffs |
| Write a handoff | `handoff-writer`, [`templates/system/handoff-standard.md`](templates/system/handoff-standard.md) | Root `HANDOFF.md` is a static pointer |
| Write an implementation plan | `implementation-plan-writer`, [`templates/system/implementation-plan-standard.md`](templates/system/implementation-plan-standard.md) | Write for a session with no chat context |
| Documentation-only cleanup | [`README.md`](README.md) and affected docs | Do not touch source code except to verify accuracy |

## Editing and delivery

- Search before reading large files. Follow [`docs/development.md`](docs/development.md),
  use `apply_patch` for hand edits, preserve unrelated work, and run focused
  tests before the required suites. Keep routine output compact without hiding
  errors. PowerShell must stay compatible; run Bash tests through Git Bash on
  Windows. This repository has no UI.
- Never run a local full test series on a Windows host while its GitHub runner
  is active. For any runner or CI task, follow the live-state checks in
  [`docs/task-router.md`](docs/task-router.md).
- Do not verify the same commit twice. The merge queue tests the exact landing
  commit; rerun only a failed or changed result.
- A reviewer repair is complete only when tests pass and every affected local
  reviewer-issue record is resolved or partially resolved with exact evidence.
  Follow `log-reviewer-issue` and preserve the incident package.

Before reporting completion: run required tests; verify Git identity; commit and
push only task-owned files; reconcile current `main`; merge through the queue;
confirm the intended commit on `origin/main`; report the commit and checks.
Installation is this repository's deployment mechanism. Active state lives in
`bugs.md`, root `plan_*.md` files, and matching OPEN handoffs; completed plans
remain as decision records.
