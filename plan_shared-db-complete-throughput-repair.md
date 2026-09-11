# Implementation plan — complete shared-db throughput repair

Paired handoff: [`HANDOFF.d/2026-09-11T0425Z-edge-dev-codex-shared-db-throughput-plan-401.md`](HANDOFF.d/2026-09-11T0425Z-edge-dev-codex-shared-db-throughput-plan-401.md)

Tracking issue: [popcre/ai-devops #401](https://github.com/popcre/ai-devops/issues/401)

## STATUS — read first

| Step | State | Date | Evidence / completion gate |
|---|---|---|---|
| 0. Reconcile the live baseline and establish one programme ledger | ⬜ open | 2026-09-11 | Commit a redacted baseline that resolves every dependency named in §9.0. |
| 1. Consume the four independently owned prerequisite repairs | ⬜ open | 2026-09-11 | #2705/#2709/#2715/#2716 have their own sessions; this programme verifies and integrates their landed behavior without duplicating it. |
| 2. Enforce two-sided structural admission, urgent application-unblock priority, and finish-first scheduling | ⬜ open | 2026-09-11 | Sender and orchestrator both reject non-structural work; urgent outcomes dispatch first without weakening object conflicts. |
| 3. Make one outcome card authoritative through live verification | ⬜ open | 2026-09-11 | A request cannot close at merge and exposes entered/dispatched/built/live timestamps. |
| 4. Replace manual polling and session handoffs with durable events and resumable snapshots | ⬜ open | 2026-09-11 | A successor resumes from one generated snapshot and no unchanged-state polling is required. |
| 5. Add one early, automatic delivery preflight and evidence registration | ⬜ open | 2026-09-11 | Missing sidecar/producer/claim/base/dependency evidence fails before expensive CI or review. |
| 6. Add the governed approved-migration train | ⬜ open | 2026-09-11 | A compatible exact list uses one consolidated preview/apply proof; incompatible items refuse by name. |
| 7. Bound reviewer and runner waits with truthful fallback | ⬜ open | 2026-09-11 | An unstarted reviewer or queued runner changes route within its SLO without cancelling healthy work. |
| 8. Transfer to `popcre` and activate GitHub's native merge queue | ⬜ open | 2026-09-11 | Complete the gates in `u2giants/shared-db` plan `plan_shared_db_popcre_transfer_merge_queue.md`. |
| 9. Rewrite and install the operating rules without a flag day | ⬜ open | 2026-09-11 | Canonical and installed rules agree; legacy in-flight work remains safely executable. |
| 10. Run a five-outcome live acceptance trial and close the programme | ⬜ open | 2026-09-11 | Five application outcomes meet §13 with timestamps and live behavior evidence. |

**Fresh-session starting point:** begin at Step 0. Before every later phase, re-read the downstream steps and this STATUS table, then update the table in the same commit as implementation evidence. A row is never complete merely because an issue or pull request exists.

## 1. Ultimate goal

When an application needs a shared-database change, safe work starts promptly and one owner carries it until the application works live. Albert should see a predictable delivery time and only genuine decisions—not a week of queue movement, reviewer recovery, handoffs, and “still waiting” checks.

The repair must preserve globally unique migration versions, exact database-object conflict protection, target-database proof, forward-only migrations, independent exact-head review, serialized preview/merge/production writes, dependency closure, and live behavior verification.

**If a step conflicts with this goal, the goal wins — stop and flag it.**

## 2. What these repositories and systems are

### `popcre/ai-devops`

Public toolkit repository. Local canonical path `C:\repos\ai-devops`; target branch `main`. It owns the installed Claude/Codex rules, the `shared-db-orchestrator` and `shared-db-handover` skills, reviewer wrappers, task gates, CI wait behavior, and cross-repository throughput programme #159.

### `u2giants/shared-db`

Public source-of-truth repository for the shared Supabase/Postgres structure used by DesignFlow and other POP applications. Local canonical path `C:\repos\shared-db`; target branch `main` through branch and pull request. It owns database migrations, object/version claims, reviewer allocation, exclusive preview/merge/production leases, coordination events, blocker timing, and production evidence.

Current repository move plan: `plan_shared_db_popcre_transfer_merge_queue.md`, tracked by shared-db #2530. The move and live GitHub settings changes remain owner-controlled operations.

### Environments

- GitHub is the durable coordination authority.
- Preview and production are shared, mutable environments and remain one writer at a time.
- Production writes are not authorized by this plan.
- The private transcript archive supplied the aggregate diagnosis; raw transcripts and private artifacts must never enter either public repository.

## 3. What triggered this work

On 2026-09-10 Albert asked for a review of the latest four shared-db orchestrator transcripts and three latest non-orchestrator transcripts because application work was waiting about a week for database delivery.

The review found:

1. unrelated structural work waits behind one coordinator even when author capacity exists;
2. coordination commands, delegated workers, reviewer recovery, and waits dwarf implementation effort;
3. small corrections can stale review and restart the proof chain;
4. reviewer and runner availability become indefinite dependencies;
5. session closeout and successor startup repeatedly rebuild the same state;
6. production incidents are not consistently fast-tracked;
7. old maintenance and tooling defects compete with application outcomes;
8. unchanged-state polling consumes work without dispatching anything;
9. already-authorized work sometimes stops for a second authorization;
10. no single live measure exposes queue entry through application verification.

Concrete examples were the DCP repair polled repeatedly while undispatched, ten approved migrations queued rather than applied by their non-orchestrator session, PR #2627 blocked by omitted producer bookkeeping after substantive checks passed, and the Property Matches repair delayed by misclassification and an unnecessary deployment confirmation.

## 4. Scope

### In scope

- Urgent application-unblock service class and dispatch rules.
- Finish-first stage scheduling while retaining up to eight non-conflicting author lanes.
- One outcome record from intake through live application verification.
- Durable event-triggered transitions and machine-readable session snapshots.
- Early automatic evidence/route qualification.
- Compatible batching of already-approved migrations.
- Reviewer correctness, liveness, replacement, and runner fallback.
- Native GitHub merge queue through the already-written transfer plan.
- Queue-to-live measurements and a five-outcome acceptance trial.
- Canonical and installed rule changes in both repositories.

### Not in this plan

- Removing or weakening any database safety assertion.
- Concurrent writes to preview, merge, or production.
- An unguarded or judgment-free production promotion path. Issue #2716's proposed automatic path belongs only if every existing machine-verifiable gate passes and any uncertainty escalates to an engineer.
- Treating urgency as permission to skip review, CI, preview, risk, identity, or live verification.
- Replacing claims with optimistic Git merge-conflict detection.
- Deleting claims, refs, branches, worktrees, or evidence because they are old.
- Making ordinary application row writes or repository maintenance into orchestrator work.
- Rebuilding completed Phase 1/2 throughput controls.
- Reimplementing #2705, #2709, #2715, #2716, #2530, or ai-devops #159 in competing files or sessions.
- Committing raw transcripts or private application data.

## 5. Current state of the code and work

Baseline captured 2026-09-11; every implementation session must re-resolve it.

### Already implemented and preserved

- `shared-db/scripts/manage-migration-author-lanes.mjs:55` sets eight active author lanes. Exact read/write claims keep non-conflicting authors parallel while protected blocked claims retain object/version safety.
- `buildDynamicQueues` at approximately line 714 groups work by conflicts and dependencies.
- `shared-db/scripts/db-coordination-events.mjs` and the manager's capacity events provide durable lifecycle facts.
- `shared-db/scripts/orchestrator-flow/` already contains route qualification, preview dependency, evidence bundle, and throughput reporting components.
- `shared-db/scripts/guard-throughput-report.mjs` and `scripts/throughput-guard/` already record causal blocker classes. Extend these; do not create a second metrics store.
- `plan_orchestrator_throughput_phase_2.md` is complete: capacity/protection separation, content-addressed evidence, invalidation classification, preview dependencies, concurrent reviewer reservations, route preflight, and blocker transitions are live.
- `plan_orchestrator_throughput_guard_truth.md` is complete: false guard diagnoses and causal blocker timing are covered.
- `plan_multi_agent_database_coordination_hardening.md` is complete: read/write conflicts, typed dependency outcomes, contracts, events, and fenced exclusive stages exist.
- `popcre/ai-devops` #159 has landed focused CI, bounded Windows sections, event-aware waits, merge-queue convergence logic, and shared test infrastructure. Reviewer programme #337 and final cutover #166 remain open.
- `u2giants/shared-db/plan_shared_db_popcre_transfer_merge_queue.md` comprehensively plans the organization transfer and native queue; all execution rows remain open.

### Partially addressed now

- [shared-db #2705](https://github.com/u2giants/shared-db/issues/2705) covers only allocation of a reviewer whom the same preflight declares unusable. PR #2717 was open at head `1f686f0e` on 2026-09-11 and had failing contract/collision checks; re-resolve before acting.
- [shared-db #2709](https://github.com/u2giants/shared-db/issues/2709) covers only the wrong comparison base in governed reviewer packets after updating from `main`. `popcre/ai-devops` PR #402 was open at head `407fedbe` on 2026-09-11; re-resolve before acting.
- [shared-db #2715](https://github.com/u2giants/shared-db/issues/2715) covers the docs-only pull-request deadlock caused by requiring a migration guarded-merge status that no lightweight path posts. It belongs in this programme as a prerequisite to removing maintenance from the orchestrator, but must be implemented by its own repo-maintenance session, not the orchestrator.
- [shared-db #2716](https://github.com/u2giants/shared-db/issues/2716) proposes automatic serial production promotion after governed review, guarded merge, post-merge preview, dry-run, and automatic evidence gates. It directly addresses repeated technical authorization asks and the unapplied-migration backlog. It belongs in this programme, but its cross-repository policy/workflow implementation must remain independently owned and must not be performed inside the orchestrator context.
- `plan_shared-db-finish-first-delivery.md` correctly diagnoses outcome-vs-utilization failure, live-verification completion, early preflight, and handoff waste. Its proposed 1+1 capacity premise is superseded by the later owner-approved eight-author model and completed Phase 2 conflict controls. This plan supersedes it for future implementation.

### Still missing

- Sessions still use judgment-heavy routing and over-send work to the orchestrator; the orchestrator can accept non-structural work instead of deterministically refusing and returning it.
- No enforced urgent application-unblock class.
- Queue ordering optimizes numeric priority/eligibility, not “finish the live blocker first.”
- No authoritative outcome state spanning intake to live application proof.
- Event records do not yet eliminate manual five-minute monitoring or manual successor launch.
- Evidence checks remain distributed; producer registration can still be discovered late.
- No first-class approved-migration train.
- Reviewer start and runner pickup have no bounded reroute contract.
- Native merge queue is planned but not activated for shared-db.
- Existing measures do not publish request-entered, dispatched, implementation-complete, and live-verified timestamps together.

## 6. Key findings and root cause

1. **The bottleneck is scheduling, not SQL.** Eight author lanes exist, but unrelated work still converges on one manually operated coordinator and serialized stages without a business-impact fast path.
2. **Safety and throughput were conflated.** Object/version claims and exclusive writes are safety. A perpetual conversation, repeated queue audits, manual handoffs, and unchanged polling are not.
3. **Completed components are disconnected.** Events, evidence bundles, blocker timing, route qualification, and parallel claims exist but do not form one outcome-driven state machine.
4. **Late discovery multiplies cost.** Wrong review bases, unusable reviewers, missing producer entries, and unavailable runners are often detected after assignment or expensive checks.
5. **“Busy” is not “delivering.”** Automatic refill and maintenance work can maximize activity while the application blocker remains undispatched.
6. **Merge queue is useful but insufficient.** It removes merge races and current-main rebuilds. It does not dispatch work, supply reviewers/runners, authorize production, or verify the application.
7. **Session state is derivable.** Durable GitHub refs, issues, contracts, events, PRs, and Actions runs contain the authority. A long-lived human-launched conversation should not be the only scheduler.

## 7. Approaches considered and rejected

1. **Move to an organization and call the problem solved.** Rejected: merge itself was measured at 87 seconds in one delayed closeout; most delay occurred before the merge gate.
2. **Restore the old 1+1 author model.** Rejected: later work safely separated protected claims from capacity and raised active authors to eight. Reducing safe authoring would recreate waiting.
3. **Increase author lanes again.** Rejected: preview, merge, and production remain serialized; more work-in-progress without finish-first scheduling increases staleness.
4. **Let urgent work bypass gates.** Rejected: urgency changes scheduling, never evidence or safety.
5. **Use a fixed timeout to kill running reviewers.** Rejected: a quiet healthy review is not dead. The SLO applies to failure to start or lack of durable liveness, with provider-specific evidence.
6. **Add another dashboard/database.** Rejected: use existing GitHub events and throughput ledgers.
7. **Poll every few minutes.** Rejected: unchanged state is expected and creates cost without progress. React to issue/ref/workflow events and use bounded waits only while a state transition is expected.
8. **Batch every pending migration.** Rejected: incompatible risk, dependencies, superseded migrations, missing roles, or missing evidence must split or refuse.
9. **Auto-approve production.** Rejected: exact migration lists and business-risk decisions remain explicit owner gates.
10. **Close an outcome at merge.** Rejected: the application is still blocked until correct environment and behavior are verified.
11. **Duplicate #2705/#2709 fixes in this programme.** Rejected: consume their proven results as prerequisites.

## 8. Design decisions

### Locked decisions — 2026-09-11

1. Keep up to eight non-conflicting active authors; claims, not a global author mutex, determine safe parallelism.
2. Keep preview, merge, and production writes globally serialized.
3. Add service classes `urgent-application`, `standard-application`, and `maintenance`. Only a reproducible live outage, blocked application release, security exposure, or owner-declared business deadline qualifies as urgent.
4. Within the same safety eligibility, order shared-stage work by service class, then finishable critical path, then `createdAt`, then issue number. Never use urgency to jump an object conflict or missing dependency.
5. One outcome issue remains open through `live_verified`; claims and PRs are supporting records.
6. Reuse existing coordination events and blocker ledger as the state store.
7. Reviewer/runner SLOs govern start/reroute, not cancellation of healthy active work.
8. Native merge queue activation follows #2530 exactly and preserves all required checks.
9. An approved-migration train is an immutable exact list with dependency closure, risk compatibility, target proof, and per-migration live assertions. If #2716 is authorized and lands, a fully machine-qualified train promotes automatically and serially; any missing or ambiguous proof stops for an engineer, not a non-technical version-number choice from Albert.
10. Owner authorization is consumed once for its stated scope. A session must not ask again for the same fix/deploy action, and must not ask Albert to judge migration identifiers that the governed evidence already decides.
11. Routing is enforced twice: the sending session must classify from the actual proposed change, and the orchestrator must independently admit only database structure/schema work. A handover, `db-work` label, repository location, or sender assertion is never sufficient.

### Open implementation judgment

- Exact event names may follow existing naming conventions, provided §9 tests prove all transitions.
- The runner fallback may use GitHub-hosted, qualified self-hosted, or Blacksmith capacity based on the live workflow's capabilities. It must be additive and fail closed.
- The urgent start target begins at ten minutes. After five live outcomes, Step 10 may tighten or relax it based on measured evidence without exceeding thirty minutes.

### Owner-only decisions

- Transfer `u2giants/shared-db` to `popcre/shared-db` and mutate its live GitHub ruleset: follow #2530; planning is not authorization.
- Activating #2716 changes the standing production policy across global instructions, shared-db rules, and workflow behavior. Its implementing session must present that exact policy change to Albert once before activation unless a current-chat ruling already authorizes it; after activation Albert is not asked to name machine migration versions.

## 9. Numbered implementation plan

### Phase A — reconcile and remove known false blockers

#### Step 0 — freeze one live dependency baseline

In a fresh worktree in each repository, re-resolve `origin/main`, #401, shared-db #2530/#2705/#2709/#2715/#2716, ai-devops #159/#166/#337, open PRs, required checks, active marker, claims, reviewer leases, stage locks, and runner labels. Write a redacted baseline under `tests/verification/shared-db-throughput/` in ai-devops. Map every item in this plan to an existing owner or a new #401 child; never create duplicate implementation owners.

**Dependencies:** none. **Parallel:** read-only shared-db and ai-devops inventory may run together.

**Verification gate:** the baseline names exact SHAs/states and `gh issue/pr view` commands that reproduce every drift-prone claim; no private transcript or secret is present.

#### Step 1 — consume #2705, #2709, #2715, and #2716 without stealing ownership

Do not edit #2705 or #2709 from this programme while their current chat sessions own them. For #2705, verify the landed allocation path filters candidates through the same reconciled `reviewerExecutionPreflight` eligibility used at run time before a durable assignment consumes a slot, while preserving run-time defense in depth.

For #2709, verify the landed `ai-review-packet` and governed wrappers accept and record the contract-declared base SHA, verify ancestry, and compute the patch from the real merge-base. Never reuse the pull request's original base after an update-from-main merge.

Execute #2715 in its own repo-maintenance session. Add a fail-closed prose classifier path that posts the required successful status without dispatching the database guarded-merge workflow. Apply the same principle in ai-devops: a plan plus declarative discoverability pointers in plan indexes, task routers, AGENTS files, and skill links uses a lightweight lane limited to changed-link validation, Markdown validation, routing consistency, and syntax/parse checks. Those pointer edits do not become code merely because they live beside operating instructions. Any executable instruction change, workflow, script, test, configuration, migration, or behavior-changing rulebook edit retains its targeted or full code path. This removes docs, plans, and handoff blockage without weakening checks for behavior changes.

Execute #2716 in its own cross-repository policy/workflow session after its one policy-activation gate. Align global instructions, shared-db rules, risk gate, dry-run, workflow, serial production lock, evidence assertions, and engineer escalation atomically. Never ask Albert to name migration versions after the approved policy is live.

Do not restart these implementations if their current PRs have landed. Verify, consume their evidence, and close only the remaining gap.

**Verification gate:** an unusable provider is never durably assigned; a branch updated from main produces only branch-owned files; a prose-only PR receives its required success without migration dispatch; an ai-devops plan with only declarative routing/index/skill pointers runs only the lightweight checks, while an executable or behavior-changing edit still selects the appropriate code suite; a fully qualified migration promotes serially after dry-run while every missing/ambiguous proof refuses to an engineer. All four issues close with merged/live evidence from their own owners.

### Phase B — make application outcomes control scheduling

#### Step 2 — enforce two-sided structural admission, then urgent and finish-first dispatch

First make routing non-judgmental. In canonical global/task-gate/shared-db skills, classify the actual proposed change: only schema, table, column, view, function, trigger, RLS, index, constraint, migration, or governed curated-Master-Data structure enters the orchestrator. Database reads, application rows, application code, docs, CI, reviewer tooling, workflows, repository maintenance, and “may need a database fix” remain with their natural owner until exact evidence proves a structure change.

Then add a required `--admit-issue` gate in `shared-db/scripts/manage-migration-author-lanes.mjs`. It independently derives work type and refuses claim, dispatch, reviewer assignment, or shared-stage acquisition for non-structural work. On refusal it posts a typed `rejected_non_structural` event with `return_to` and the evidence needed to reopen classification. The orchestrator may not override it merely because a sender used `db-work`, called it a handover, or placed it in shared-db.

Extend `parseQueueScope`, its schema/fixtures, and `buildDynamicQueues` with `service_class` and a required `impact` block for urgent work. Add deterministic admission that verifies `return_to`, reproduction evidence, affected environment, and qualifying impact. A tooling or maintenance issue cannot self-promote to urgent.

Replace automatic refill ordering with: safety eligibility; urgent service class; already-started/nearest-live critical path; dependency-transitive blocking impact; `createdAt`; issue number. Preserve separate conflict components and all eight author slots. When an urgent issue is eligible and capacity is full, do not revoke another claim; publish `urgent_waiting_capacity` and finish/relinquish the nearest safe slot.

Update `shared-db/AGENTS.md`, the canonical orchestrator skill, operating manual, and tests together.

**Verification gate:** sender fixtures route each structural/non-structural class correctly; adversarial misrouted issues are rejected again by the orchestrator; no non-structural issue can claim a lane or shared stage; two unrelated structural authors run concurrently; conflicting objects never do; urgent application work starts before maintenance; no active work is destructively preempted.

#### Step 3 — add the authoritative outcome lifecycle

Extend coordination events and outcome validation with `entered`, `classified`, `dispatched`, `implementation_complete`, `review_ready`, `preview_verified`, `merged`, `production_authorized`, `production_applied`, `live_verified`, `blocked`, and `yielded`. Require each structural intake issue to identify its application return address and live assertion. A PR merge may advance `merged`; it cannot produce `live_verified`.

Add `--outcome-status <issue>` and `--complete-outcome <issue> --evidence <ref>` to the manager. Completion must re-derive the merge/application evidence, generated types where applicable, and the live assertion. Update `scripts/db-coordination-events.mjs`, audit/report code, schemas, and scenario tests.

**Verification gate:** attempts to close at PR merge, preview-only proof, missing return address, or missing live assertion refuse; a full fixture produces one readable outcome history.

### Phase C — remove conversation and bookkeeping latency

#### Step 4 — event-driven dispatch and resumable orchestrator snapshots

Build a read-only `--orchestrator-snapshot` from current marker, claims, PR heads/checks, reviewer leases, stage locks, outcome events, and eligible queues. Hash and attach it to the marker/issue; a successor verifies freshness and resumes without a prose reconstruction. Keep prose handoffs only for unresolved judgment, failure history, and private/non-derivable context.

Publish durable events on eligibility, dependency completion, author-capacity release, review availability, merge-queue completion/ejection, preview completion, production decision, and live verification. Update canonical skills so unchanged state produces no repeated status task. Use bounded event-aware waits only when an operation has actually started.

The current manual owner-authorized marker succession remains until Codex/Claude can prove an authenticated automatic continuation. If no supported continuation API exists, the snapshot plus one fixed launch action is the fallback; never pretend notification or continuation occurred.

**Verification gate:** a fixture successor reconstructs the exact active map from the snapshot; an unchanged queued item produces zero repeated comments/polls; each meaningful transition wakes once.

#### Step 5 — one early delivery preflight and automatic evidence registration

Compose existing qualification, work-contract, object collision, dependency, sidecar, producer, migration-order, reviewer-capacity, and runner-capacity checks into `scripts/orchestrator-flow/delivery-preflight.mjs`. Run it before author completion and again only when an input digest changes.

Replace the hand-maintained sidecar producer omission class with a single declarative registry or safe discovery rule owned by `production_business_risk_gate.py` and `check_production_verification_sidecars.py`. The change must still prove every runtime-opened producer file is pinned; discovery may not silently widen trust.

Store the preflight input/output digest in the evidence bundle. A later phase reuses green results only when the invalidation classifier proves no relevant input changed.

**Verification gate:** historical #2627-shaped fixtures fail before PR/review when registration is absent; a valid new sidecar needs one declaration, not a second repair PR; unrelated documentation movement does not rerun expensive gates.

### Phase D — shorten shared stages safely

#### Step 6 — implement the approved-migration train

Add a machine-readable train manifest and manager commands to propose, validate, authorize, dispatch, and close an immutable exact migration list. Validation must prove every file is merged on current main, unapplied on the exact target, not superseded or forbidden, dependency-closed, role-compatible, risk-compatible, and covered by preview/production assertions.

One compatible train receives one consolidated preflight, preview operation, production-policy evaluation, serialized apply, and verification report. Each migration retains its own hash and assertion result. When #2716 is active, a completely qualified train promotes automatically after the production dry-run. Any missing, failed, or ambiguous proof refuses and escalates to an engineer. A failure stops the train, records the exact applied prefix from the live ledger, and permits only forward recovery—never replay guesses.

Integrate with `.github/workflows/shared-supabase-migrations.yml`, `production_business_risk_gate.py`, current batch/rehearsal code near the manager's existing post-merge batch logic, and ledger drift checks.

**Verification gate:** fixtures cover ten compatible migrations, missing dependency, superseded migration, absent database role, mixed risk classes, mid-train failure, stale authorization, and successful live verification without `--include-all`.

#### Step 7 — bound reviewer and runner start waits

After Step 1, add an assignment-start event and a ten-minute “not started” SLO. If the selected reviewer is unusable or never produces durable start/liveness evidence, return the slot through the existing governed terminal/unstarted path and draw the next eligible provider. Do not kill a healthy active review and do not fabricate a failure verdict.

Inventory shared-db workflows' actual runner requirements. Add at least one independent compatible lane for queue-sensitive jobs and a stable aggregate required context, following ai-devops #209/#210 patterns where applicable. Preflight capacity before dispatch. If a preferred lane is unpicked at the SLO, route a new run to an already-qualified compatible lane; never launch a same-run fallback that competes invisibly or weakens coverage.

**Verification gate:** injected unavailable/quarantined/unstarted/busy reviewer cases reroute once; active quiet review remains intact; injected runner non-pickup produces one qualified replacement run; every required assertion still executes exactly once in the accepted result.

#### Step 8 — execute the organization transfer and native merge queue plan

Do not duplicate the existing plan. Execute `u2giants/shared-db/plan_shared_db_popcre_transfer_merge_queue.md` from its STATUS Step 0 after Albert names the exact transfer/settings action. Preserve repository identity, redirects, integrations, required checks, consumer sync, and direct guarded merging until the native queue is proven.

Configure one PR per merge group initially, zero batching wait, and all required workflows on `merge_group`. Feed queue completion/ejection events into Step 4 and preserve exact PR-head review plus synthetic-group integration proof.

**Verification gate:** the plan's harmless canary and first genuine migration pass; no stale required context exists; merge races and manual base-update review churn are absent.

### Phase E — activate, measure, and close

#### Step 9 — rewrite, install, and stage activation

Update the canonical ai-devops skills, globals, task router, and shared-db rulebook to the new outcome/service-class/event model. Remove active automatic-refill, repeated polling, duplicate authorization, and prose-only successor requirements only after their tested replacements are live. Preserve compatibility for in-flight legacy issues and claims.

Land shared-db code first, then ai-devops canonical rules. Install through supported commands and verify canonical/installed hashes. Activate on one urgent and one standard outcome before general use. Roll back by reviewed revert and canonical reinstall; retain all claims/evidence.

**Verification gate:** instruction tests reject the old active phrases; installed rules match source; legacy claims remain protected; the pilot completes without manual queue reconstruction.

#### Step 10 — five-outcome acceptance trial

For five consecutive structural application outcomes, generate a committed report from the existing event ledger containing request-to-dispatch, dispatch-to-implementation, implementation-to-review, review/CI wait, merge, production-decision wait, production apply, and live-verification time. Separate owner waits and external outages.

Acceptance targets:

- urgent eligible work dispatches within ten minutes, or publishes one exact blocking dependency/owner decision;
- standard eligible work dispatches within one business hour;
- no unchanged-state polling;
- no manual successor rebuild of derivable state;
- no repeated authorization request for the same scope;
- no false reviewer base or unusable-provider assignment;
- no safety regression;
- median request-to-live time improves by at least 50% from the Step 0 comparable baseline, with raw `n` and exceptions shown.

If a target fails, keep #401 open, classify the exact stage, and repair that stage. Do not lower a safety gate or redefine completion.

**Verification gate:** the five-outcome report links exact live evidence, all targets are met or explicitly owner-accepted, #401 closes, and the paired handoff is retired in the closing commit.

## 10. Tests required

### shared-db unit and scenario tests

- Urgent admission: qualifying outage/release/security/deadline; maintenance self-promotion refusal; missing impact/return address refusal.
- Queue ordering: urgent vs standard vs maintenance; transitive blocker; created-at tie; issue-number tie; object conflict; full capacity; no destructive preemption.
- Outcome lifecycle: every legal transition; every illegal skip; merge-not-live; evidence re-derivation; generated-type requirement.
- Events/snapshot: deterministic hash; stale input; one wake per transition; no unchanged poll; successor reconstruction.
- Delivery preflight: sidecar/producer/claim/base/dependency/route/reviewer/runner cases and digest invalidation.
- Migration train: all eight cases named in Step 6.
- Admission: every structural type accepted; application rows/code, docs, CI, reviewer tooling, workflows, and repository maintenance rejected by both sender and orchestrator; sender misclassification cannot acquire a claim/stage.
- Reviewer: #2705 allocation cases, #2709 base cases, unstarted reroute, healthy quiet review, all providers busy.
- Independent prerequisites: #2715 prose/mixed/rulebook paths and #2716 fully-qualified/refusal/dry-run/serial-lock/engineer-escalation paths.
- Runner: pickup, non-pickup, replacement, duplicate prevention, aggregate truth.
- Existing manager, coordination scenario, throughput guard, sidecar, production gate, ledger, SQL, and contract suites remain green.

### ai-devops tests

- Canonical skill/global/router parity and installation hash checks.
- Forbidden active behavior: automatic refill as success metric, repeated unchanged polling, merge-as-completion, duplicate authorization, and mandatory prose reconstruction.
- Event-aware wait tests and existing #159 CI/reviewer suites.
- Exact-head independent review for wrapper/evidence safety changes.

### live acceptance

- Read-only baseline and snapshot on the live repository.
- #2705/#2709 exact-head live qualification and #2715/#2716 live behavior proof from their independently owned sessions.
- Native merge-queue canary after authorized transfer.
- One urgent and one standard pilot, then the five-outcome trial.
- Production proof only under separately recorded exact authority.

## 11. Constraints, standing rules, and gotchas

- Work in fresh current-upstream worktrees; preserve concurrent changes.
- Shared-db uses branch/PR/governed merge. ai-devops uses branch/PR/native queue.
- Verify `Albert Hazan <u2giants@users.noreply.github.com>` before every commit.
- Production/shared cloud is read-only unless Albert names the exact action/resource in the current chat.
- No migration version reuse, applied-file edit, broad include, claim deletion, or unproved target.
- Preview, merge, and production remain one at a time.
- Reviewer failure is not a code finding; runner cancellation is not a test result.
- A merge queue supplements rather than replaces exact-head approval and production freeze.
- Classification follows behavior, not directory or filename: plans and declarative discoverability pointers use the lightweight lane; executable instructions, behavior-changing rules, workflows, scripts, tests, configuration, and migrations retain targeted or full code checks.
- Raw transcripts, secrets, licensed data, and private evidence stay outside public repositories.
- Update this STATUS table whenever implementation changes reality.
- At every phase boundary, use a fresh session and re-read all remaining downstream phases.

## 12. Access and environment

- `gh` is authenticated as Albert's correct repository identity; verify with `gh auth status` before mutation.
- ai-devops: `C:\repos\ai-devops`, GitHub `popcre/ai-devops`, target `main`.
- shared-db: `C:\repos\shared-db`, GitHub currently `u2giants/shared-db`, target `main`; expected future owner `popcre` only after Step 8.
- Windows host nickname: `edge-dev`; PowerShell and Git Bash are available.
- GitHub Actions supplies CI. Runner labels and availability are drift-prone and must be read live.
- Database and deployment secrets live in 1Password vault `vibe_coding`; use existing repository-specific items and never record values.
- Supabase project identity must be queried immediately before any write. This plan itself requires no database write.

## 13. Definition of done, risks, rollback, and open questions

### Definition of done

- [ ] Every STATUS row cites an artifact, commit, live run, or rerunnable command.
- [ ] #2705, #2709, #2715, and #2716 are genuinely repaired by their independent owners, not merely closed.
- [ ] Sending sessions and the orchestrator independently reject non-structural work; misclassification cannot consume a lane or shared stage.
- [ ] Urgent and finish-first scheduling is enforced and tested.
- [ ] Eight safe author lanes remain available for non-conflicting work.
- [ ] One outcome card remains open through live application verification.
- [ ] Polling and manual state reconstruction are replaced by durable events/snapshots.
- [ ] Early preflight catches all named late bookkeeping failures.
- [ ] Compatible approved migrations can move as one governed train and, after #2716 policy activation, promote automatically only when every existing machine gate passes.
- [ ] Reviewer and runner non-start waits reroute within the tested SLO.
- [ ] Shared-db is in the organization with its native merge queue proven, after explicit authorization.
- [ ] Canonical and installed operating rules agree.
- [ ] All existing and new tests pass; exact-head review approves affected safety code.
- [ ] Five live outcomes meet the acceptance trial without weakened safety.
- [ ] Both repositories are committed, pushed, merged, and verified on `origin/main`.
- [ ] #401 closes and this handoff retires only after the whole outcome is complete.

### Principal risks and rollback

1. **Urgency abuse:** fail closed unless the impact contract is verifiable; downgrade classification, never bypass safety.
2. **Event loss/duplication:** events are idempotent and snapshot state is derived from authoritative refs/issues/runs; fall back to bounded manual audit.
3. **Batch partial failure:** stop, read the exact target ledger, record the applied prefix, and fix forward.
4. **Runner duplication:** stable aggregator accepts exactly one qualified result per required assertion.
5. **Reviewer false release:** only unstarted/terminal evidence may return a slot; active liveness protects the lease.
6. **Transfer integration break:** follow #2530 recovery pack and keep the old guarded path until native queue proof.
7. **Instruction drift:** canonical/installed hash and forbidden-phrase tests block activation.
8. **Programme expansion:** every new defect maps to one existing phase/owner; otherwise #401 records why it is genuinely outside scope.

Rollback is a reviewed revert of the affected phase plus supported rules reinstall. Never roll back by deleting durable claims/evidence, editing applied migrations, weakening required checks, or restoring blind polling.

### Open questions

No engineering design choice blocks Step 0. Step 8 requires Albert's explicit repository-transfer/settings authority. Issue #2716 requires one explicit policy-activation ruling unless its implementation session can cite a current-chat ruling that authorizes the exact global/workflow change; after activation, individual machine version lists do not return to Albert. These are execution gates, not gaps in this plan.

## Coverage of the throughput review

| Review recommendation | Plan owner |
|---|---|
| Urgent application-unblock lane | Steps 2–3 |
| Parallel non-conflicting authorship | Preserve current eight lanes; Steps 2 and 9 |
| Binding classification fast path and orchestrator refusal | Steps 1, 2, and 5; #2715 |
| Batch approved migrations | Step 6 |
| Automatic evidence | Step 5 |
| Bounded reviewer waits | Steps 1 and 7 |
| Durable orchestrator/context rollover | Step 4 |
| Event-driven rather than polling | Step 4 |
| Stop repeated authorization asks and technical version naming | Steps 1, 3, 6, and 9; #2716 |
| Queue-to-live measurement | Steps 3 and 10 |
| Organization/native merge queue | Step 8 |

## Mandatory implementation-plan self-audit

1. **Could a brand-new AI session execute this plan without asking Albert anything? Yes for every reversible planning and implementation step.** §§2, 5, 9, 10, and 12 identify repositories, current components, concrete files/functions, dependencies, commands/evidence, environments, and verification gates. §8 and §13 isolate the only later owner actions: repository transfer/settings and exact production lists.
2. **Does the plan carry the complete background, nuance, and rejected reasoning? Yes.** §§3, 5–8 preserve the seven-transcript findings, distinguish completed controls from gaps, explain #2705/#2709's narrow reviewer coverage and #2715/#2716's independent ownership, enforce two-sided non-structural refusal, reject the superseded 1+1 premise, and preserve every safety boundary.
3. **Is the ultimate goal clear enough for correct judgment when a step is wrong? Yes.** §1 makes live application delivery the outcome, safety preservation the invariant, and explicitly says the goal wins.

Checklist result: all 13 sections are present; the STATUS table, zero-context background, explicit scope, current state, root cause, rejected approaches, locked/open decisions, file-level steps, named tests, access, landing proof, risks, rollback, owner gates, plan/handoff cross-links, discoverability route, and full recommendation coverage are included. No secret or private transcript content is present.
