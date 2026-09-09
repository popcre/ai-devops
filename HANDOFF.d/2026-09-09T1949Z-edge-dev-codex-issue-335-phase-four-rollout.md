---
issue: 335
status: OPEN
owner: codex/issue-335-phase3-closeout-01a086
---

# HANDOFF — Issue #335 Phase 3 complete, Phase 4 rollout next

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

None — nothing in this workstream currently needs Albert to decide. Start Phase
4 without asking him to repeat earlier decisions.

Already settled — do NOT re-ask:

- The rollout covers all 17 canonical repositories (2026-09-08).
- Central enforcement lives in `popcre/ai-devops`; consumer repositories receive
  thin local declarations that may strengthen but never weaken it (2026-09-08).
- Raw transcripts and licensed source rows must not be opened for this routing
  audit (2026-09-08).
- Phase 3 used three self-mergeable pilots first and DesignFlow last
  (2026-09-09).
- For Issue #335 DesignFlow rollout acceptance, Albert wants the capability live
  on each current `sandbox-albert` branch and explicitly said not to wait on
  `develop` or Uma (2026-09-09). Normal DesignFlow product delivery rules remain
  unchanged outside this rollout.
- Issue #335 stays OPEN through Phase 5. Do not use a closing keyword before the
  final Phase 5 acceptance passes (2026-09-09).

If later evidence creates a genuinely new owner decision, consolidate the whole
list here before asking. There is no current decision gate.

## 1. What this application is

`popcre/ai-devops` is POP Creations' public recovery and governance toolkit for
AI-assisted engineering. It supplies shared commands, policy, installer logic,
reviewer routing, and repository coverage evidence. Issue #335 makes task scope
machine-checkable across 17 repositories so a small documentation task cannot
silently become expensive review, deployment, database, infrastructure, or
production work.

The central engine is `bin/ai-task-gates`; the central contract is
`config/task-gates.json` plus its schema and validator. Each consumer may add a
thin `.ai-devops/task-gates.json` declaration for its own high-risk paths and
retained proof requirements.

## 2. What this session set out to do, and why

This session continued the Phase 3 handoff at Section 6 step 1. It had to clear
the stale duplicate PR, prove the installed command, run four materially
different repository pilots in order, land them, and only then advance the plan
to Phase 4.

The owner later changed the DesignFlow acceptance target: the frontend pilot had
to be fully running on `sandbox-albert`, without waiting for `develop` or Uma.
The session therefore preserved the live sandbox history, integrated the pilot
in an isolated worktree, pushed it directly, and verified the exact Cloud Run
revision and public site.

## 3. Current state — what is true now

Phase 3 is complete. The four pilots are landed and verified:

1. `popcre/ai-devops`: PR #352 merged as
   `4d83f9a5dc400f87408663eddac872b9074c18ed`. The installed system-path command
   reports version 1.0.0 and resolves repository policy from ordinary and linked
   worktrees. The exact-head independent review approved it.
2. `u2giants/shared-db`: PR #2637 merged as
   `fe5fa74db889652768029116e636f8cbe69b955e`. Its exact head was
   `d2231a7ffb21743542f3c424beddfd14363422b8`; governed review approved it, the focused fixture passed 10/10,
   and no database action occurred.
3. `u2giants/theoracle`: PR #9 merged as
   `28e8eb75f74387ded651e7fcad2dd73638e111e9`. Exact-head review approved
   `89a6b5dfc541b261b247e57709fe3d96d7a9845d`; 21/21 task fixtures, all seven
   workspace typechecks, the Vercel contract guard, post-merge task-gate run
   34380054774, and post-merge full check run 34380054909 passed. No database,
   deployment, or production mutation occurred.
4. `popcre/designflow-frontend`: the pilot is live on `sandbox-albert` at
   `ea8f602923f200b500dd76b322a818af014352ca`. GitHub Task Gates run
   34396174935 passed. Cloud Build
   `27721624-9702-4435-afea-fb41c6f6849b` succeeded and produced digest
   `sha256:aefe1f8ae1dc1447431d6b0c23ea9534f7c0b7ebf1db7c7a8f63d0b93dc61b79`.
   Cloud Run revision `popcre-albert-frontend-sandbox-00456-76t` is ready and
   serves 100% of traffic. `https://alsand.designflow.app` and the direct Cloud
   Run URL both returned HTTP 200 and referenced the same current Angular main
   and styles bundles. Local and clean-container evidence was 18/18 policy
   checks, 131/131 suites, 1,656/1,656 tests, and a successful Angular build.
   Exact-head independent review approved `ea8f6029`. PR #179 was closed
   unmerged after Albert redirected delivery to the sandbox branch.

Supporting Phase 3 housekeeping is also complete: stale PR #343 closed
unmerged; the wrong-timeout follow-up is Issue #349; the Claude closeout wording
landed separately through PR #350 as `daa0e9a1`; and Issue #335 records the
pilot evidence.

The old Phase 3 handoff was retired in this same change after its landed state
was verified and every continuing obligation was carried into this file or the
plan. Phase 4 and Phase 5 have not started. Issue #335 remains OPEN.

## 4. Everything tried that did not work

- DesignFlow PR #179 was initially opened against `develop` because that was the
  prior instruction. Albert later explicitly changed the target to the live
  `sandbox-albert` branch. The PR was closed unmerged; do not reopen it or wait
  for Uma for Issue #335.
- The first DesignFlow exact-head review rejected the workflow because it called
  a non-executable shell file directly, moved workflow rules into an unprotected
  document, left the mirrored `shared-db/` tree outside the governed class, and
  used a whitespace-sensitive identity grep. The fixed head invoked `bash`, used
  `jq`, protected `docs/development.md`, and classified all `shared-db/**`; the
  next exact-head review approved.
- DesignFlow's Jest exclusions used expanded `<rootDir>/...` regexes that did not
  match Windows path separators, causing the Angular suite to discover 123
  mirrored backend and Playwright files. Cross-platform separator patterns fixed
  the gate. Do not re-run the broken configuration or treat those foreign files
  as Angular failures.
- Plain `bash` on EDGE-DEV launches WSL, which has no installed distribution.
  Use `C:\Program Files\Git\bin\bash.exe` for repository Bash tests.
- The current DesignFlow sandbox had diverged from the pilot's `develop` base.
  Merging or rebasing `develop` would have violated the owner's target and risked
  concurrent work. The safe route was a new worktree from current
  `origin/sandbox-albert` followed by the two reviewed cherry-picks.
- `sandbox-albert.designflow.app` has no DNS record. The documented public Albert
  sandbox is `https://alsand.designflow.app`. Do not diagnose the obsolete name
  as an application outage.
- `gcloud beta run domain-mappings` tried to install a component into protected
  Program Files and was unavailable. It was unnecessary: the documented hostname,
  exact image digest, ready revision, 100% traffic, and matching live bundles
  supplied the acceptance evidence.
- After the pilot merged, the system-path `ai-task-gates` command still resolved
  its central policy from the clean canonical checkout at `daa0e9a1`, one commit
  behind current main. That stale copy cannot validate the new local
  `installation` class inside `ai-devops`. The exact current worktree command
  works. Do not fast-forward the shared checkout while its many MCP launchers are
  active; serialize that supported-machine update during Phase 5.
- Oracle's merge command printed that local `main` was already used by another
  worktree after GitHub had successfully merged the PR. Always verify GitHub
  state before treating that cleanup message as a failed merge.

## 5. Root causes and key findings

- Pilot acceptance must prove the installed capability, not merely a committed
  declaration. Each pilot used real `ai-task-gates explain`, mismatch refusal,
  valid-flow, rollback, repository tests, and an exact-head review.
- A verification-only workflow can still break delivery if its script mode or
  identity parsing is wrong. Linux execution and repository identity must be
  tested on the runner, not inferred from Windows.
- DesignFlow carries a large mirrored `shared-db/` tree. The entire prefix must
  resolve to the governed database class; matching only `supabase/**` and
  `migrations/**` leaves a material safety hole.
- `ai-task-gates explain` on a long-diverged sandbox can include all changes from
  the merge base, not only the current task. Use explicit `--paths-from`
  fixtures for path assertions and inspect the actual Git diff before deciding
  what the current session owns.
- Cloud Build success alone is not live acceptance. For DesignFlow, verify the
  exact commit-to-image digest, ready revision, traffic percentage, public URL,
  and served bundle identity.
- The DesignFlow Task Gates GitHub workflow is verification-only and advisory;
  Cloud Build still owns deployment. Record that limitation during Phase 5
  rather than claiming the GitHub job blocks a sandbox release.

## 6. Exact next steps

1. Read this handoff and the STATUS table in
   `plan_cross_repo_routing_and_gate_enforcement.md`. Do not repeat Phases 0-3.
   Re-resolve Issue #335 and `origin/main` before editing. You'll know this is
   correct when Phase 3 reads DONE and Phase 4 is the first OPEN row.
2. Refresh `config/repository-coverage.json` against current saved projects and
   Git remotes, and inventory open PRs/worktrees before selecting ownership.
   Create a current-upstream isolated worktree in each repository. You'll know
   it worked when all 13 remaining canonical identities have exactly one Phase 4
   owner and no active branch collision.
3. Execute Step 4.1 in this order: `designflow-backend`, `designflow-bff`,
   `designflow-data-syncing`, `designflow-item-master`, and
   `designflow-tracking`. Add thin service-specific declarations and fixtures;
   preserve database, deployment, test, authenticated UI, and shared-db routes.
   For Issue #335, land and verify each current `sandbox-albert` branch directly
   as Albert instructed; do not wait on `develop` or Uma. You'll know each is
   complete when its branch has the policy, gate tests pass, and any automatic
   sandbox deployment serves the exact branch commit.
4. Execute Step 4.2 for `popcrm-web`, `poppim-web`, `popdam3`, `backrest-wiz`,
   `licensor-source-data`, and `ai-devops-transcripts`. Do not open licensed rows
   or raw transcript archives. Add a root router only where Phase 0 proves a
   discoverability gap. You'll know each is complete when its thin policy is
   landed through that repository's current workflow and its highest-risk dry
   fixture refuses correctly.
5. Execute Step 4.3 for `popcre/infrastructure` and `u2giants/ansible`.
   Production mutation remains forbidden without a new exact resource/action
   authorization in the current chat. You'll know each is complete when dry
   infrastructure fixtures refuse apply/deploy actions and no live resource was
   changed.
6. Update the coverage evidence for every repository with policy version,
   landed commit or PR, routing before/after measurement, trigger evaluation,
   local verification, and remaining exception. Re-run the four-pilot suite if
   and only if the central schema version changes. You'll know Phase 4 is done
   when all 17 manifest rows have complete evidence and the mixed/missing
   coverage guard passes.
7. Mark Phase 4 DONE and write a new Phase 5 handoff. Do not start Phase 5 in the
   same context cut and do not close Issue #335. You'll know the handoff is ready
   when a new session can begin at Step 5.1 without reading this chat.

## 7. Constraints and gotchas in force

- Use an isolated current-upstream worktree per repository. Preserve dirty
  canonical checkouts and all concurrent work; never broad-stage, reset, clean,
  force-push, or use the shared stash.
- Declare the task class before edits. Recompute the real change set before
  review, wait, push, deployment, or any protected action.
- Consumer policies are thin and may strengthen central rules only. A common
  defect requires a new central version; do not patch 13 consumers differently.
- The owner-directed direct DesignFlow sandbox route applies to Issue #335
  rollout acceptance. It does not silently rewrite normal feature-delivery
  governance for unrelated work.
- Shared-database structure work belongs only in `u2giants/shared-db`. Phase 4
  policy work authorizes no schema, data, or production database mutation.
- Infrastructure and production remain read-only without exact current-chat
  authority. Never use broader credentials to bypass this rule.
- Keep licensed data, raw transcripts, secrets, and private evidence out of the
  public toolkit and ordinary AI context. Secrets live in 1Password vault
  `vibe_coding`; name locations only, never values.
- On Windows use Git Bash by absolute path. Do not run concurrent full ai-devops
  suites or run them while the protected Windows runner is active.
- Documentation-only ai-devops PRs merge immediately after changed-file scope is
  confirmed. Any code, test, script, workflow, or configuration change restores
  normal checks and exact-head requirements.
- Keep Issue #335 open through Phase 5 and do not start Phase 5 before every
  coverage row is complete.

## 8. Access and environment

- EDGE-DEV is Windows 11. `gh`, Git, `gcloud`, Node/Corepack Yarn, and the
  installed `ai-task-gates` 1.0.0 command are authenticated/available.
- Git commits must use `Albert Hazan <u2giants@users.noreply.github.com>`.
- DesignFlow sandbox cloud reads use project `lithe-breaker-323913`, region
  `us-east4`. The public Albert frontend is `https://alsand.designflow.app`;
  its service is `popcre-albert-frontend-sandbox`.
- Reviewer entry point is `ai-review claude final-check`; use an isolated clone
  whose head and base are explicit. Reviewer output is evidence, not permission
  for external mutation.
- No secret was read, created, printed, or committed in Phase 3. Future secret
  access uses 1Password vault `vibe_coding` and the repository's secret skill.

## 9. Open questions and risks

- No owner question is open. Section 0 contains every settled decision that
  materially changes Phase 4 execution.
- The 13 remaining repositories may have moved, gained active branches, or
  changed deployment triggers. Treat this handoff as historical evidence and
  re-resolve each live repository immediately before writes.
- Direct DesignFlow sandbox pushes can auto-deploy even though the GitHub task
  gate is advisory. A red GitHub job is therefore a real acceptance failure even
  if Cloud Build deploys; diagnose and repair it before calling that repository
  complete.
- EDGE-DEV's shared `C:\repos\ai-devops` checkout is clean but remains at
  `daa0e9a1`, one commit behind the Phase 3 pilot merge, because many live MCP
  launcher processes resolve files there. The worktree-local current command is
  green; Phase 5 must take a serialized installation window, fast-forward the
  canonical checkout, and repeat the system-path smoke before machine acceptance.
- Phase 4 could expose a common policy/schema gap. If it does, stop consumer
  rollout, version and qualify the central engine once, rerun the four pilots,
  then resume. Do not accumulate incompatible local workarounds.
- `bin/ai-pr-wait` previously produced a false timeout message; Issue #349 owns
  the repair. Do not rerun an unchanged wait failure or treat the message as
  elapsed-time proof.

## Self-audit

1. Yes. Sections 1-3 explain the system, purpose, exact landed commits, tests,
   deployment, and current open phase from zero context; Section 6 gives ordered
   continuation gates.
2. Yes. Sections 4-5 preserve the failed PR route, review defects, Windows Jest
   and Bash traps, divergent sandbox integration, hostname discovery, and live
   deployment proof that a new session would otherwise have to rediscover.
3. Yes. Sections 0-9 cover decisions, background, goals, state, dead ends,
   findings, exact next actions, constraints, access, and risks, including every
   relevant repository, commit, run, build, revision, URL, and secret boundary.
4. Yes, checked line by line. The only owner-dependent statements in Sections
   1-9 are the already-settled all-17 scope, central-policy architecture,
   private-data boundary, direct DesignFlow sandbox acceptance, and keep-open
   rule; all five appear in Section 0. Nothing currently needs a new ruling.
