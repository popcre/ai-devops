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

- **Work on a branch and open a pull request. Do not push to `main`.**
  `main` is protected by a ruleset with a merge queue, so a direct push is
  rejected. This replaced the old "work directly on `main`" rule when the
  repository moved to the `popcre` organization on 2026-08-26 (issue #84).
  `config/repository-policy.json` reports `feature-branch-pr` for this
  repository under **both** owner names, so an old `u2giants` clone and a new
  `popcre` clone behave identically.
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
- **Wait on CI through bounded, event-aware tools, never long polling loops.**
  Use `bin/ai-pr-wait <pr>` for a pull request, surface a failing check or queue
  ejection immediately, and do independent useful work while long checks run.
- **Reuse before growing the repository.** New top-level plans, workflows, test
  harnesses, or copied provider logic need a stated owner, a reason the existing
  shared home cannot serve the need, and a retirement or consolidation path.
  Harness consolidation belongs to #167, provider-wrapper sharing to #169, and
  plan-backlog consolidation to #168 under parent #159.

## Documentation router

| Current task | Read first | Important boundary |
|---|---|---|
| Implement the 2026-08-21 full repository audit | [`plan_full-strategy-remediation.md`](plan_full-strategy-remediation.md) STATUS, [`bugs.md`](bugs.md) current audit | Incident-first; preserve capabilities; all 30 findings must reach production evidence |
| Quick orientation | `README.md`, this file | Do not load deep docs without a task reason |
| Context size, ownership, routing, or trigger quality | [`docs/context-spec.md`](docs/context-spec.md), [`plan_context-engineering-consolidation.md`](plan_context-engineering-consolidation.md) STATUS | Globals contain only universal rules; measurements come from audit JSON |
| False completion, closeout honesty, or "the instructions are not working" | [`plan_completion-honesty-enforcement.md`](plan_completion-honesty-enforcement.md) STATUS, the Response Style block in both `templates/system/*global*.md` | Read its STATUS table first. The rule is enforced in three places that must move together: the globals, `context-audit.py` (safety marker + parity rule), and the Claude `Stop` hook `bin/ai-completion-check-hook`. Never weaken one to quiet another, and never claim a wording change worked without a `tools/completion-eval/` run |
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
| Reviewer-assisted diagnosis when a session is stuck | [`plan_reviewer-assisted-problem-solving.md`](plan_reviewer-assisted-problem-solving.md) STATUS, issue #198 | Implementation has not started; the plan defines the evidence threshold, one-reviewer bound, privacy rules, and separation from formal approval |
| Add Grok integration-review shell or controlled internet access | [`plan_grok_integration-review-access.md`](plan_grok_integration-review-access.md) STATUS, issue #249, existing Grok wrapper/profile/tests | Keep the approval reviewer unchanged; the integration workload stays disposable, externally contained, and offline except for structured broker operations |
| Upgrade Grok Build to 1.0.13 or integrate post-1.0.5 wrapper behavior | [`plan_grok-build-1.0.13-wrapper-integration.md`](plan_grok-build-1.0.13-wrapper-integration.md) STATUS, issue #251, current Grok wrapper/installers/tests | Preserve every reviewer boundary; classify every release item and qualify exact 1.0.13 before adapting behavior |
| Reviewer evidence packet or sandbox | Header of `bin/ai-review-packet` or `bin/ai-review-sandbox`, matching tests | A reviewer keeps full repository read access; linked worktrees need self-contained snapshots |
| Reviewer caching, snapshot reuse, or token/cost reporting | [`plan_reviewer-cache-efficiency.md`](plan_reviewer-cache-efficiency.md) STATUS | Read its STATUS table first; never trade evidence integrity for speed, and never report a token number the provider did not return |
| `ai-muse` stale-turn rejection diagnostics | [`fix_muse_wrapper_reject.md`](fix_muse_wrapper_reject.md) STATUS | The guard is correct; never narrow what `tree_state` covers to stop it firing |
| Add shell and internet investigation mode to GLM, Kimi, Qwen, or Muse | [`plan_reviewer-investigation-mode-option-b.md`](plan_reviewer-investigation-mode-option-b.md) STATUS, parent issue #253 and the provider child issue | Reuse provider-local capable machinery; investigation is advisory and formal review remains read-only |
| Shared database structure or business rules | Load the matching `shared-db` or `pop-business-rules` skill and follow its router | Reading is open; structural changes go through `u2giants/shared-db`; licensed private data stays private |
| Repository or worktree cleanup | Load `cleanup-worktree`; read relevant open handoffs and [`docs/critical-incidents.md`](docs/critical-incidents.md) | Preserve every unique change before removing anything |
| Implement concurrent-session work claims | [`plan_ai-devops-work-claims.md`](plan_ai-devops-work-claims.md) STATUS, issue #131 | Do not start claim code until `plan_repo-throughput-restructure.md` completes reviewer determinism and CI-cost gates. V1 is task-only and advisory; no orchestrator, claims file, hooks, takeover command, or required check |
| Implement managed ast-grep across Windows and Ubuntu | [`plan_ast-grep-multi-machine-management.md`](plan_ast-grep-multi-machine-management.md) STATUS, issue #187 | `ai-devops` owns Windows/version/guidance; `u2giants/ansible` owns the Ubuntu host package; production apply needs exact current-chat authorization |
| Repository throughput, slow CI, flaky required checks, merge-queue ejections, or sessions shipping nothing | [`plan_repo-throughput-restructure.md`](plan_repo-throughput-restructure.md) STATUS, parent issue #159 | Read STATUS first; execute sub-issues #160–#169; preserve every safety assertion; required-check cutover #166 is last |
| A reviewer-suite wait that reports a "stall", or choosing between `poll_until` and `poll_until_progress` | [`plan_progress-wait-misuse-guard.md`](plan_progress-wait-misuse-guard.md) STATUS | Read its STATUS table first; start at Step 0. A stall window is only valid if the progress expression is **verified to change while the system is healthily waiting** - including during quiet phases, so a fingerprint must sense modification time, not just size and count. A signal that goes blind makes the wait give up early and report a stall that looks like a hang in the code under test. That misuse ejected PR #142 from the merge queue (run `33144576111`). A `cancelled` CI job is never a test result: check the duration against `timeout-minutes` first |
| Waiting on a pull request to merge, or monitoring CI for one | Run `bin/ai-pr-wait <pr>` — never hand-roll a wait loop | **A merge-queue ejection leaves the pull request `OPEN`**, so a loop watching `gh pr view --json state` waits forever on a PR that has already stopped. That cost about five hours on PR #142 on 2026-08-28. `ai-pr-wait` exits on every terminal outcome — merged, closed, failing check, ejection, or its own deadline — and `tests/test-ai-pr-wait.sh` fails CI if any file reintroduces the blind loop |
| Windows CI jobs, the self-hosted runner, or a local reviewer test series | [`docs/self-hosted-windows-runner.md`](docs/self-hosted-windows-runner.md), [`docs/independent-windows-runner-setup.md`](docs/independent-windows-runner-setup.md), [`docs/critical-incidents.md`](docs/critical-incidents.md) 2026-09-02 | Windows CI runs in two lanes: `windows-offline` on GitHub-hosted `windows-2025`, and `windows-reviewer-safety` on the `ai-devops-windows-qualified` self-hosted pool. The pool is extra capacity, never a replacement for GitHub's runners - routing both jobs to it serialised the repository on 2026-09-02. The pool resolves to `EDGE-RUNN-ENVY` today; `edge-dev` is being onboarded into it, not retired. Qualification jobs still use the candidate label `ai-devops-windows`. The `edge-dev` machine keeps its two runners for other work, and there **that machine hosts either the CI checks or a local test series, never both** - they share process names, so a local series can cancel a live CI job and a check can inflate a series. Confirm the runner is idle before starting one. This is a public repository: fork-PR approval must stay `all_external_contributors` |
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
- Keep command output quiet by default; verbose output is a permanent token cost
  in every later turn. Prefer `git status -s`, `git log --oneline`, and
  `git diff --stat` before a full diff, avoid `ls -R` unless recursion is needed,
  and pass a test runner's own quiet flag (`pytest -q --tb=short`,
  `npm test -- --silent`). Never quiet a command whose full output is the
  evidence you are about to report, and never silence errors: quiet flags reduce
  noise, not failures.
- The `edge-dev` machine runs one configured self-hosted Windows runner
  (`edge-dev-win`; the second install is not configured). It is a candidate for
  the qualified pool, not a retired host: the pool needs more than one machine.
  When working there, do not start a local full test sweep while a GitHub run is
  active; the local run cancels the running CI job.
- Installation is the deployment mechanism. The GitHub `verify` workflow checks
  toolkit source, but there is no container, package registry, hosted service,
  application deployment workflow, or application database.

- **Never verify the same commit twice (SOP).** The merge queue tests the exact
  commit that will land on `main` before it lands, so a second full run triggered
  by the resulting push proves nothing and costs another occupancy of the
  self-hosted Windows runner - about 71 minutes per merge as measured on
  2026-08-28. CI triggers exist for pull requests and for `merge_group`. Do not
  add or restore a `push:` trigger on a branch that only receives queue merges,
  and do not re-run a job whose identical commit already has a green result;
  re-run only what actually failed.

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
