---
issue: 335
status: OPEN
owner: codex/issue-335-phase4-continuation
---

# HANDOFF — Issue #335 Phase 4 after backend and BFF rollout

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

None. Albert has already assigned the continuation to one Codex task and told it
to proceed. Do not ask him to choose branches, deployment mechanics, or whether
to continue.

Already settled — do not re-ask:

- All 17 canonical repositories are in scope; central enforcement remains in
  `popcre/ai-devops`, and consumer declarations may strengthen but never weaken
  it (2026-09-08).
- Raw transcript archives and licensed source rows must not be opened
  (2026-09-08).
- Issue #335 DesignFlow acceptance lands directly on each current
  `sandbox-albert` branch without waiting for `develop` or Uma. An existing
  automatic sandbox deployment is an accepted consequence of that Git push;
  Codex must not operate deployment controls itself (2026-09-09/10).
- Issue #335 remains open through Phase 5. Phase 5 cannot start until all 17
  coverage rows are landed (2026-09-09).
- PR #330 is unrelated Qwen work. Do not cancel, rerun, or diagnose it here
  (2026-09-09).

## 1. What this application is

`popcre/ai-devops` is POP Creations' shared engineering-governance and recovery
toolkit. Issue #335 makes the declared scope of AI work machine-checkable across
17 repositories so a small task cannot silently start expensive review,
deployment, database, infrastructure, production, UI, or private-data work.

The central engine is `bin/ai-task-gates`, version 1.0.0, with its policy and
schema under `config/`. Consumer repositories receive a thin
`.ai-devops/task-gates.json`, a focused refusal/rollback fixture, a read-only
GitHub verification job, and only the smallest router pointer needed to find
them. DesignFlow sandbox pushes automatically build and deploy through existing
Google Cloud Build triggers; the rollout changes no trigger or application code.

## 2. What this session set out to do, and why

This session began Phase 4 from the 17-repository inventory. It first reconciled
a duplicate Issue #335 handoff created by PR #356, then started Step 4.1 in the
required order. The goal was to land service-specific declarations while
preserving every repository's stronger local rules and proving the real gate,
test, GitHub, build, and sandbox result.

The duplicate-handoff repair merged in `popcre/ai-devops` PR #360 as
`21cabd77c37161ab0f353977c79d234409cd4263`. It deleted the redundant 2352Z
handoff, kept the detailed Phase 4 playbook authoritative, corrected the stale
plan index, and recorded sole ownership. This handoff now succeeds and retires
that older Phase 4 playbook after carrying forward all remaining obligations.

## 3. Current state — what is true now

Phases 0–3 remain complete. Phase 4 is in progress. Two of the five remaining
DesignFlow repositories are landed and verified; 11 repositories remain.

### DesignFlow backend — complete for Phase 4

- The policy landed on `sandbox-albert` at
  `0b584a3bc4646177e9710609868f5bc2652ceb63`. The branch later advanced through
  unrelated HTS work; the Phase 4 commit remains in its history. Do not overwrite
  or revert the newer branch head.
- The declaration protects rulebooks, workflows, Cloud Build/container/runtime
  configuration, database connection targets, the full mirrored `shared-db/`
  tree, Sequelize model shape, legacy startup DDL, schema routing, and possible
  app-owned migrations. Database-class work routes to `u2giants/shared-db` and
  forbids database action here.
- Local evidence passed 19/19 policy checks, schema validation, and 116/116 Jest
  suites with 1,059/1,059 tests. Claude Opus 5 exact-head review approved
  `0b584a3` after the brief was narrowed to its direct parent so unrelated HTS
  changes were not misattributed.
- GitHub Task Gates runs `34427405974` and `34427408794` passed; Forbid Shared DB
  Bypass run `34427408744` passed.
- Automatic Cloud Build `ad4efd39-7c1d-4b9e-b57e-b5f00c91f8c4` succeeded and
  produced digest
  `sha256:e5d056b2a25de060a166f3009ef12fee265e0dbe6383ccbec0396de42a23fff9`.
  Ready revision `popcre-albert-core-sandbox-00322-292` served 100% of sandbox
  traffic and reported Ready, Active, and ContainerHealthy.
- Existing PR #87 to `develop` remains open. Do not self-merge it and do not wait
  for it for Issue #335 acceptance.

### DesignFlow BFF — complete for Phase 4

- The policy landed on `sandbox-albert` at
  `9f3c2bd26c12a8add01bba8ae25eaef185586b4a`. The current remote branch and open
  PR #26 head were still this commit at cutover.
- The declaration protects rulebooks, the core OIDC proxy, workflows, Cloud
  Build/container/dependency/environment files, backend target routing, the
  mirrored `shared-db/` tree, and possible app-owned migrations. It preserves
  `.run.app` OIDC audiences, fail-closed CORS, no-self-merge, and database
  boundaries. `/.ai/reviews/` was added to `.gitignore` so exact-head reviews can
  run without exposing or tracking their reports.
- Local evidence passed 16/16 policy checks, schema validation, and 11/11 Jest
  suites with 65/65 tests. Claude Opus 5 exact-head review approved `9f3c2bd`.
- Both GitHub Task Gates runs (`34428750660`, `34428754136`) and Forbid Shared DB
  Bypass run `34428754137` passed.
- Automatic Cloud Build `9db8844d-31bf-4437-905e-8c872de12502` succeeded and
  produced digest
  `sha256:f68050408e7576e6d8d73e6c6fc3668019d4acdfecd06a52aaa36a04e25fcdae`.
  Ready revision `popcre-albert-bff-sandbox-00087-cfl` served 100% of sandbox
  traffic.
- Existing PR #26 to `develop` remains open. Do not self-merge it and do not wait
  for it for Issue #335 acceptance.

### Not yet started

Step 4.1 still needs, in order: `designflow-data-syncing`,
`designflow-item-master`, then `designflow-tracking`. Step 4.2 still needs
`popcrm-web`, `poppim-web`, `popdam3`, `backrest-wiz`,
`licensor-source-data`, and `ai-devops-transcripts`. Step 4.3 still needs
`popcre/infrastructure` and `u2giants/ansible`. Central coverage evidence has
not yet been updated for backend/BFF; update it only with complete landed facts,
and run the final mixed/missing guard after all 17 rows are complete.

## 4. Everything tried that did not work

- The 2352Z handoff created by PR #356 declared itself OPEN while pointing to a
  different OPEN Phase 4 handoff. Claude identified the conflict and Grok 4.6
  independently agreed. PR #360 removed the redundant file and corrected the
  stale plan index. Never recreate a pointer-only OPEN handoff beside the actual
  playbook.
- The first interpretation of "do not mutate deployment" treated an automatic
  sandbox build as a blocker. Grok clarified the settled route: push the thin
  commit as instructed, then observe the existing automatic build read-only;
  do not run deploy commands or change triggers, traffic, infrastructure, or
  production.
- Backend's first local test attempt used `npm ci`, but that repository has no
  lockfile, so Jest was unavailable. `npm install --no-package-lock` in the
  isolated worktree installed dependencies without changing tracked files.
- Backend `sandbox-albert` advanced from `18d49e2` to `7d01208` during testing.
  The exact-head guard stopped the push. A new integration worktree was created
  from `7d01208`, the policy commit was cherry-picked, and every focused/full
  check was rerun before push. Preserve this collision pattern for later repos.
- Backend's first reviewer examined the full sandbox-to-develop divergence and
  rejected unrelated HTS documentation/runtime work. A direct-parent review
  brief constrained the reviewer to the Phase 4 files. Subsequent exact-head
  reviews approved. Always name the Phase 4 commit and direct parent in the
  brief for long-diverged DesignFlow sandboxes.
- Backend review exposed missing connection-config gates and a stale "no GitHub
  Actions" sentence. Both were corrected before landing. BFF review exposed the
  core OIDC proxy as a stronger security path and a broad-looking fixture
  cleanup; both were tightened before landing.
- BFF's first review launch refused because `.ai/reviews/` was not Git-ignored.
  Adding the anchored `/.ai/reviews/` rule fixed it without affecting the
  already tracked mirrored `shared-db/.ai/reviews/` content.
- Plain `yarn` was unavailable in PowerShell. `corepack yarn` used the pinned
  Yarn 1.22.22 path successfully. Plain Bash launches WSL on EDGE-DEV; use
  `C:\Program Files\Git\bin\bash.exe`.

## 5. Root causes and key findings

- The safest consumer policy comes from the repository's own router, not a
  copied generic list. Backend required Sequelize/connection/schema paths; BFF
  required OIDC proxy, target URLs, environment files, and the entire mirrored
  shared-db prefix.
- Long-diverged `sandbox-albert` branches make default reviewer and
  `ai-task-gates explain` comparisons include unrelated work. Use explicit
  `--paths-from` fixtures for classification and an exact commit/direct-parent
  review brief. Never repair unrelated findings from a different owner inside
  this rollout.
- GitHub Task Gates can run twice for the same DesignFlow commit because the push
  updates both `sandbox-albert` and its existing PR to `develop`. Both exact-head
  results must be green; duplication is expected, not a reason to cancel one.
- An automatic build is not proof of acceptance. Record the exact branch commit,
  green GitHub gates, Cloud Build ID and image digest, ready revision, and 100%
  traffic. All cloud interaction in this rollout is read-only observation.
- Phase 4 declarations create a ratchet: policy/workflow/security paths require
  stronger review on their next change. Keep local fixtures self-protecting and
  rehearse byte-exact rollback in a disposable Git repository.

## 6. Exact next steps

1. Start a fresh current-`origin/main` ai-devops worktree and re-read the STATUS
   table plus this handoff. Re-resolve Issue #335, the 17-repository manifest,
   open PRs/worktrees, and current remote heads. You will know this worked when
   Phase 4 is the first OPEN row, backend/BFF commits are ancestors of their
   current sandbox branches, and no competing Phase 4 owner exists.
2. Continue Step 4.1 with `designflow-data-syncing`, then item master, then
   tracking. For each: read its full `AGENTS.md`; work from current
   `origin/sandbox-albert` in an isolated worktree; measure existing routers;
   add only a service-specific thin policy, focused refusal/rollback fixture,
   verification-only GitHub workflow, evidence record, and one lean route if
   needed. You will know each is ready when its focused policy/schema checks,
   unchanged repository tests, and exact-commit/direct-parent independent review
   pass.
3. Immediately before each push, fetch `origin/sandbox-albert` and compare it to
   the candidate's direct parent. If it moved, rebuild on the new head and rerun
   evidence; never force-push. You will know the landing is safe when the push is
   fast-forward and preserves every intervening commit.
4. After each DesignFlow push, verify every exact-head GitHub task-gate/shared-db
   job, automatic Cloud Build, image digest, ready revision, and 100% sandbox
   traffic. Do not run deployment commands or merge the `develop` PR. You will
   know acceptance is complete when the landed commit is represented by the
   ready image/revision and every required job is green.
5. Execute Step 4.2 across the six application/private-data repositories using
   each repository's current workflow. Never open licensed rows or raw
   transcripts; inventory those two repositories using metadata and routing
   files only. You will know each row is complete when its highest-risk dry
   fixture refuses correctly and its policy is landed.
6. Execute Step 4.3 for infrastructure and Ansible. Production mutation remains
   denied; use fixtures/read-only inspection only. You will know each row is
   complete when apply/deploy scenarios refuse before action and no resource
   changed.
7. Update all 17 central coverage rows with policy version, landed commit/PR,
   routing before/after, trigger result, local verification, and remaining
   exception. Re-run the four-pilot suite only if the central schema changes.
   You will know Phase 4 is complete when the mixed/missing guard passes with no
   incomplete row.
8. Before cutting to Phase 5, re-read every Phase 5 step through plan completion
   and record any drift Phase 4 introduced. Write a new Phase 5 handoff and
   retire this file only after all obligations are carried forward. Do not start
   Phase 5 in the Phase 4 session. You will know the cut is sound when a new
   session can start at Step 5.1 without this chat.

## 7. Constraints and gotchas in force

- Use a fresh isolated current-upstream worktree per repository. Preserve dirty
  canonical checkouts, unrelated branches, PRs, and all concurrent work. Never
  broad-stage, reset, clean, stash, force-push, or self-merge DesignFlow.
- Declare the task class before edits and recheck the real change set before
  review, push, merge, wait, or protected action. Consumer policies can only
  strengthen central version 1.
- Do not inspect raw transcript archives, licensed rows, secrets, or private
  evidence. Do not mutate database, application data, deployment controls,
  infrastructure, or production. Existing automatic DesignFlow sandbox builds
  are observed read-only after the authorized branch push.
- Use `C:\Program Files\Git\bin\bash.exe` on Windows. Use `corepack yarn` where
  Yarn is not on PATH. Do not trust a successful push, build, or HTTP 200 alone;
  finish the repository's full evidence chain.
- Exact-head independent review briefs for DesignFlow must name the candidate
  commit, its direct parent, and the owned file list so unrelated sandbox
  divergence does not become this rollout's work.
- Keep Issue #335 open. Do not start Phase 5, update #159 as complete, unblock
  #166, or update the shared installed command until every Phase 4 row lands.

## 8. Access and environment

- EDGE-DEV is Windows 11. GitHub CLI, Git, Google Cloud CLI, Node/Corepack, and
  the ai-devops reviewer wrappers are authenticated. Git commits must remain
  `Albert Hazan <u2giants@users.noreply.github.com>`.
- The exact current toolkit command is under a fresh ai-devops worktree's `bin/`;
  the canonical shared checkout must remain landing-only and is not to be
  fast-forwarded while MCP launchers use it.
- DesignFlow sandbox reads use Google Cloud project `lithe-breaker-323913`,
  region `us-east4`. Backend service is `popcre-albert-core-sandbox`; BFF is
  `popcre-albert-bff-sandbox`.
- The supported independent review entry is `ai-review claude final-check` from
  Git Bash with `AI_REVIEW_BRIEF_FILE` pointing to a private untracked brief.
  Never send secrets. Secrets, if ever needed later, live in 1Password vault
  `vibe_coding`; Phase 4 needs none.

## 9. Open questions and risks

- No owner question is open. A future repository may expose a genuine conflict
  between its local rule and central policy; stop only that repository, continue
  safe independent rows, and ask one plain owner question only if weakening or
  a materially different outcome would otherwise be required.
- Backend's sandbox branch advanced after `0b584a3` due concurrent HTS work.
  Verify ancestry rather than expecting it to remain the branch head.
- The remaining repositories may have moved, gained PRs, or changed triggers
  since the initial inventory. Treat all SHAs and ownership outside the two
  completed rows as historical until refreshed.
- Central `config/repository-coverage.json` still carries the Phase 0 metadata
  shape and has not recorded backend/BFF landing evidence. The final Phase 4
  update may require extending evidence storage without changing the central
  schema; if a common schema change is genuinely necessary, version it once and
  rerun all four pilots before resuming consumers.
- Phase 5 assumptions remain valid after this session: supported-machine install
  is still deferred; the nine dry acceptance scenarios remain required; success
  is measured by preventing unnecessary expensive gates, not merely smaller
  routers; Issue #335/#159/#166 closeout order is unchanged.

## Self-audit

1. Yes. Sections 1–3 define the system, goal, exact landed commits, tests,
   reviews, runs, builds, digests, revisions, traffic, and remaining repository
   count for a developer with no chat context.
2. Yes. Sections 4–5 preserve every expensive dead end and non-obvious lesson:
   duplicate handoffs, deployment interpretation, dependency commands, branch
   collision, divergent-review scope, safety gaps, reviewer ignore rules, and
   Windows shell behavior.
3. Yes. Sections 0–9 cover background, intended outcome, current state,
   failures, decisions, constraints, risks, ordered actions, complete evidence,
   and the Phase 5 downstream audit. Every next step has a verification gate.
4. Yes. A line-by-line owner sweep of Sections 1–9 found no new decision. All
   owner-dependent statements are already-settled instructions listed in
   Section 0; the only hypothetical future conflict is explicitly conditional
   and has a bounded stop/continue rule.
