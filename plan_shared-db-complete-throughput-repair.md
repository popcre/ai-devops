# Implementation plan — complete shared-db throughput repair

Paired handoff: [`HANDOFF.d/2026-09-16T0030Z-edge-dev-claude-programme-401-final-acceptance.md`](HANDOFF.d/2026-09-16T0030Z-edge-dev-claude-programme-401-final-acceptance.md) (2026-09-15 final acceptance audit; retires the earlier `-401` handoffs)

Tracking issue: [popcre/ai-devops #401](https://github.com/popcre/ai-devops/issues/401)

## STATUS — read first

| Step | State | Date | Evidence / completion gate |
|---|---|---|---|
| 0. Reconcile the live baseline and establish one programme ledger | ✅ complete | 2026-09-11 | Redacted live ledger: `tests/verification/shared-db-throughput/2026-09-11-live-baseline.md`; source tips `b6922ea8` / `f3eff56d`. |
| 1. Consume the four independently owned prerequisite repairs | 🟨 code landed, not accepted | 2026-09-15 | #2705, #2709 and #2715 are CLOSED. #2716 is still OPEN: shared-db PR #2736 merged, and the ai-devops policy half merged as PR #412 (`9d02b382`). NOT ACCEPTED: shared-db #2716 is still OPEN and no live fully-qualified automatic promotion or live refusal-path proof exists. Live proof owner (routed 2026-09-16): [shared-db#3027](https://github.com/u2giants/shared-db/issues/3027). |
| 2. Enforce two-sided structural admission, urgent application-unblock priority, and finish-first scheduling | 🟨 code landed, not accepted | 2026-09-15 | Code: #2727 CLOSED via shared-db PR #2738 (`5d89c5e2`). NOT ACCEPTED: the 2026-09-15 additions (named lease/conflict only, safe re-reservation without closing a PR, no unrelated production hold) have no linked live acceptance evidence. Live proof owner (routed 2026-09-16): [shared-db#3027](https://github.com/u2giants/shared-db/issues/3027). No further steps may be added to #3027. |
| 2A. Add a fail-closed no-database-preview fast lane | 🟨 code landed, not accepted | 2026-09-15 | Code: #2912 CLOSED via shared-db PR #2795 (`585a9d2b`), prerequisite PR #2750 (`1c436f46`). NOT ACCEPTED: no authenticated live sender-to-receiver canary is linked. Live proof owner (routed 2026-09-16): [shared-db#3027](https://github.com/u2giants/shared-db/issues/3027). |
| 3. Make one outcome card authoritative through live verification | ⬜ open | 2026-09-15 | A request cannot close at merge and exposes entered/dispatched/built/live timestamps; the outcome owner produces the live proof itself instead of waiting on another session (2026-09-15 addition). NOT ACCEPTED: no linked outcome shows the owner dispatching application proof within 30 minutes of `production_applied` without waiting on Albert or another session. Live proof owner (routed 2026-09-16): [shared-db#3027](https://github.com/u2giants/shared-db/issues/3027). No further steps may be added to #3027. |
| 4. Replace manual polling and session handoffs with durable events and resumable snapshots | 🟨 code landed, not accepted | 2026-09-15 | Code: #2728 CLOSED via shared-db PR #2861 (`c7c9a7a2`). NOT ACCEPTED: no linked live successor-resume proof, and no proof that the two-hour no-progress alarm is installed and fires. Live proof owner (routed 2026-09-16): [shared-db#3027](https://github.com/u2giants/shared-db/issues/3027). No further steps may be added to #3027. |
| 5. Add one early, automatic delivery preflight and evidence registration | 🟨 code landed, known gap | 2026-09-15 | Code: early-preflight/pass-2 merged under #2728. KNOWN OPEN REQUIREMENT: #2728 records that the single sidecar declaration registry does not exist, so the complete evidence-registration gate is unproven. Live proof owner (routed 2026-09-16): [shared-db#3028](https://github.com/u2giants/shared-db/issues/3028). |
| 6. Add the governed approved-migration train | 🟨 code landed, not accepted | 2026-09-15 | Code: #2729 CLOSED via shared-db PR #2862 (`89ec62d2`). NOT ACCEPTED: no live train proves compatible batching and incompatible refusal by name. Live proof owner (routed 2026-09-16): [shared-db#3027](https://github.com/u2giants/shared-db/issues/3027). No further steps may be added to #3027. |
| 7. Bound reviewer and runner waits with truthful fallback | 🟨 code landed, not accepted | 2026-09-15 | Code: reroute landed under #2729; reviewer verdict-store cap #2987 CLOSED via shared-db PR #2984 (`1f7dbe47`). NOT ACCEPTED: no live reviewer/runner non-start proves reroute within the tested SLO without cancelling healthy work. Live proof owner (routed 2026-09-16): [shared-db#3027](https://github.com/u2giants/shared-db/issues/3027). No further steps may be added to #3027. |
| 8. Transfer to `popcre` and activate GitHub’s native merge queue | ➡️ moved out of #401 | 2026-09-16 | Albert ruled on 2026-09-16 that the transfer is its own workstream. It is owned by [u2giants/shared-db #2530](https://github.com/u2giants/shared-db/issues/2530) and its plan `plan_shared_db_popcre_transfer_merge_queue.md` (12 steps, all open). It is no longer a #401 closure condition. Nothing was transferred and no setting changed. |
| 9. Rewrite and install the operating rules without a flag day | ✅ complete | 2026-09-16 | Canonical and installed rules agree; legacy in-flight work remains safely executable. PR #412 (`9d02b382`) removed the canonical contrary evidence and its drift tests now guard every copy. 2026-09-16 fleet proof (`tests/verification/shared-db-throughput/2026-09-16-step9-installed-rules-fleet.md`): edge-dev, al8960ofc, 916, hetz `ai` and hetz `root` all drifted, were repaired through the supported sync route, and now equal main `ece11e45`. EDGE-ALIEN and EDGE-RUNN-ENVY are not applicable (CI runners without Claude/Codex, owner ruling 2026-09-16). NOT ACCEPTED: t16 is on Tailscale but its SSH port 22 times out, so it is unmeasured. Live proof owner (routed 2026-09-16): [popcre/ai-devops#496](https://github.com/popcre/ai-devops/issues/496). Albert ruled 2026-09-16 that t16 is out of scope; every in-scope machine matches. |
| 10. Run a five-outcome live acceptance trial and close the programme | ⬜ open | 2026-09-15 | Five application outcomes meet §13 with timestamps and live behavior evidence. ENTIRELY UNPROVEN: no committed report exists, so dispatch targets, unchanged polling, manual state rebuild, repeated authorization, reviewer selection validity, safety regressions, live-proof timeliness, idle periods and the required ≥ 50% median request-to-live improvement (with raw `n` and exceptions) all lack evidence. Live proof owner (routed 2026-09-16): [shared-db#3029](https://github.com/u2giants/shared-db/issues/3029). |

**Legend.** ✅ complete — accepted with live evidence. 🟨 code landed, not accepted — the
implementation merged on `main` but the plan’s live behavior gate has no linked proof.
⬜ open. ➡️ moved to its own issue and no longer gates #401.
A Live proof owner cell names at most one unproven step and one issue. Do not route a new unproven step onto an issue that already owns a different unproven step. Session job-sizing: plan_live-proof-session-sizing.md (#511).

**Acceptance audit of 2026-09-15** (recorded on popcre/ai-devops#401) rechecked every row
against live GitHub. `u2giants/shared-db` main was `921fef3a`. Merged programme work proves
landed implementation only; it does not satisfy the five-outcome live gate in Step 10.
**Do not close #401** until every row above is ✅.

**Fresh-session starting point:** begin at Step 1 and consume the completed Step 0 ledger rather than rebuilding it. Before every later phase, re-read the downstream steps and this STATUS table, then update the table in the same commit as implementation evidence. A row is never complete merely because an issue or pull request exists.

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

### Second trigger — the 2026-09-15 twelve-hour orchestrator stall

On 2026-09-15 Albert found that one shared-db orchestrator session had run about twelve hours and closed zero of its database issues. A read of that session's transcript (private archive; not reproduced here) showed that it did deliver production changes, but nothing reached `closed`. Five separable causes, each now owned by a step below:

1. **Closure depended on another session.** #2792 (bounded stale-file reconciliation) and #2860 (style-guide search speed) both reached `production_applied`, but `--complete-outcome` refused because the evidence block needs a live proof from the consuming application (`u2giants/popdam3`). The orchestrator asked Albert to get the PopDAM session to post it and then waited for hours. It only moved when Albert ruled "produce the live proofs yourself via a subagent." → **Step 3.**
2. **Four delivery-system defects stopped real work:**
   - The contract-test database rebuild ("pass 2") re-ran an older migration that re-created `public.deactivate_stale_sg_files` after #2934's migration had dropped it, so contract 3 failed. Tooling fix PR #2948 (merged `7c314992`) replayed later drops but skipped a routine that already existed before the re-run. #2934 failed again at PR #2958 head `e5f00d38`, and a further follow-up (PR #2964) was still open at the time of writing. → **Step 5.**
   - `--prepare-preview-dispatch` refused #2792 with `already-applied versions require exactly one validated immutable preview apply or ledger-reconciliation run; found 0`. The migration had already been applied to preview before merge (claim mode), and that run's dispatch commit differed from its applied commit. #2860 hit the same shape. Both needed a manual recovery run. → **Step 6.**
   - After the sanctioned recovery run succeeded, the "Automatic production qualification and dispatch" job was skipped because it fires only on `merged_preview_source_pr`, while recovery sets `historical_preview_source_pr`. Production was then dispatched by hand, so #2883 (automatic production proof) could not be proven. → **Step 6.**
   - Renumbering #2934 after main gained a later migration version deadlocked: a new claim refused on object collision with the held claim, and the held claim refused release while its PR was open. The only way out was closing PR #2944 and opening replacement PR #2958. → **Step 2.**
3. **Unrelated merge-ready work was held serially.** Green, approved PRs (#2955, #2948) were told to wait "until #2860's production run finishes" to avoid collisions. Each hold cost 30–60 minutes although the items did not share a database object. → **Step 2.**
4. **Reviewer fragility.** A Grok review hit `turn_limit_cancelled` without a verdict. A GLM review stopped at `ai-glm doctor did not answer within 60s` (a local dependency fault). A reviewer draw handed back the same slot. Every evidence-only or refresh commit moved the head and voided recorded approvals. → **Step 5** (invalidation) and **Step 7** (reroute).
5. **Status narration hid the stall.** The orchestrator sent dozens of near-identical "nothing new / still open" summaries and never told Albert that nothing was closing. Albert discovered it by asking. → **Step 4.**

Albert's standing rule from that session: never wait on another session for something an agent can produce, and never let a wait run for hours without raising it immediately.

## 4. Scope

### In scope

- Urgent application-unblock service class and dispatch rules.
- Finish-first stage scheduling with no numeric limit on non-conflicting authors.
- One outcome record from intake through live application verification.
- Durable event-triggered transitions and machine-readable session snapshots.
- Completion-or-blocked agent check-ins: tell agents to report only when assigned work finishes or becomes genuinely blocked, eliminating routine progress narration from the shared-db orchestrator context.
- Early automatic evidence/route qualification.
- A fail-closed no-database-preview fast lane for work proven unable to alter database structure, behavior, permissions, or data.
- Compatible batching of already-approved migrations.
- Reviewer correctness, liveness, replacement, and runner fallback.
- Native GitHub merge queue through the already-written transfer plan.
- Queue-to-live measurements and a five-outcome acceptance trial.
- Canonical and installed rule changes in both repositories.

### Not in this plan

- Removing or weakening any database safety assertion.
- Concurrent writes to preview, merge, or production.
- An unguarded or judgment-free production promotion path. Issue #2716's proposed automatic path belongs only if every existing machine-verifiable gate passes and any uncertainty escalates to an engineer.
- Treating urgency as permission to skip any applicable review, CI, database preview, risk, identity, or live verification gate.
- Exempting a migration or any database-affecting change from preview because it looks low-risk.
- Replacing claims with optimistic Git merge-conflict detection.
- Deleting claims, refs, branches, worktrees, or evidence because they are old.
- Making ordinary application row writes or repository maintenance into orchestrator work.
- Rebuilding completed Phase 1/2 throughput controls.
- Reimplementing #2705, #2709, #2715, #2716, #2530, or ai-devops #159 in competing files or sessions.
- Committing raw transcripts or private application data.

## 5. Current state of the code and work

Baseline captured 2026-09-11; every implementation session must re-resolve it.

### Already implemented and preserved

- `shared-db/scripts/manage-migration-author-lanes.mjs` currently imposes a numeric active-author ceiling. [shared-db #2773](https://github.com/u2giants/shared-db/issues/2773) removes that ceiling while retaining exact read/write conflict claims, permanent migration-version reservations, lease recovery, and fail-closed unreadable-state behavior.
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
- `plan_shared-db-finish-first-delivery.md` correctly diagnoses outcome-vs-utilization failure, live-verification completion, early preflight, and handoff waste. Its proposed 1+1 capacity premise and the later eight-author ceiling are superseded: exact conflict claims, not a numeric author count, control safe authorship. This plan supersedes it for future implementation.

### Still missing

- Sessions still use judgment-heavy routing and over-send work to the orchestrator; the orchestrator can accept non-structural work instead of deterministically refusing and returning it.
- There is no general, machine-enforced no-database-preview route for documentation, plans, handoffs, reviewer/queue tooling, CI/workflow maintenance, read-only audits/reporting, tests, or application-only changes that provably cannot affect database structure, behavior, permissions, or data.
- No enforced urgent application-unblock class.
- Queue ordering optimizes numeric priority/eligibility, not “finish the live blocker first.”
- No authoritative outcome state spanning intake to live application proof.
- Event records do not yet eliminate manual five-minute monitoring or manual successor launch.
- Evidence checks remain distributed; producer registration can still be discovered late.
- No first-class approved-migration train.
- Reviewer start and runner pickup have no bounded reroute contract.
- Native merge queue is planned but not activated for shared-db.
- Existing measures do not publish request-entered, dispatched, implementation-complete, and live-verified timestamps together.
- (2026-09-15) Live verification has no self-service path: `--complete-outcome` needs evidence from the consuming application repository, and nothing lets the outcome owner produce it without a second session.
- (2026-09-15) The contract-test pass-2 rebuild does not faithfully reproduce drop/re-create history. PR #2948 handles drops of routines absent before the re-run; the pre-existing case is open (PR #2964 at the time of writing, re-resolve).
- (2026-09-15) Preview-evidence lookup rejects a pre-merge claim-mode preview apply, and the recovery lane never qualifies automatic production.
- (2026-09-15) A claim cannot re-reserve its version while its PR is open, so renumbering forces closing and replacing the PR.
- (2026-09-15) There is no no-progress alarm: a session can report "still waiting" indefinitely without escalating.

## 6. Key findings and root cause

1. **The bottleneck is scheduling, not SQL.** Independently safe work still converges on one manually operated coordinator, a numeric author ceiling, and serialized delivery stages without a business-impact fast path.
2. **Safety and throughput were conflated.** Object/version claims and exclusive writes are safety. A perpetual conversation, repeated queue audits, manual handoffs, and unchanged polling are not.
3. **Completed components are disconnected.** Events, evidence bundles, blocker timing, route qualification, and parallel claims exist but do not form one outcome-driven state machine.
4. **Late discovery multiplies cost.** Wrong review bases, unusable reviewers, missing producer entries, and unavailable runners are often detected after assignment or expensive checks.
5. **“Busy” is not “delivering.”** Automatic refill and maintenance work can maximize activity while the application blocker remains undispatched.
6. **Merge queue is useful but insufficient.** It removes merge races and current-main rebuilds. It does not dispatch work, supply reviewers/runners, authorize production, or verify the application.
7. **Session state is derivable.** Durable GitHub refs, issues, contracts, events, PRs, and Actions runs contain the authority. A long-lived human-launched conversation should not be the only scheduler.
8. **(2026-09-15) Closure, not production, is the real finish line, and it had a cross-session dependency.** Twelve hours produced production applies but zero closures because the last gate needed another session's output and no one owned producing it.
9. **(2026-09-15) The recovery paths are second-class.** Each safety tool (pass-2 rebuild, preview-evidence lookup, recovery lane, claim release) is correct on the happy path but refuses or misbehaves on legitimate edge histories. Every edge case became a manual detour lasting an hour or more.
10. **(2026-09-15) Over-serialization spread from stages to whole pipelines.** The rule "one preview/merge/production writer at a time" was applied as "one item's whole pipeline at a time," which is not a safety requirement.

## 7. Approaches considered and rejected

1. **Move to an organization and call the problem solved.** Rejected: merge itself was measured at 87 seconds in one delayed closeout; most delay occurred before the merge gate.
2. **Restore the old 1+1 author model.** Rejected: protected claims are already separate from worker capacity. Any numeric ceiling makes independently safe work wait.
3. **Raise the author ceiling again.** Rejected: another arbitrary number preserves artificial waiting. Remove the ceiling entirely; exact read/write conflicts remain the admission control, while preview, merge, and production remain serialized.
4. **Let urgent work bypass gates.** Rejected: urgency changes scheduling, never evidence or safety.
5. **Use a fixed timeout to kill running reviewers.** Rejected: a quiet healthy review is not dead. The SLO applies to failure to start or lack of durable liveness, with provider-specific evidence.
6. **Add another dashboard/database.** Rejected: use existing GitHub events and throughput ledgers.
7. **Poll every few minutes.** Rejected: unchanged state is expected and creates cost without progress. React to issue/ref/workflow events and use bounded waits only while a state transition is expected.
8. **Require periodic agent progress check-ins.** Rejected: intermediate narration consumes orchestrator context and tokens without changing a decision. Durable evidence carries progress; agents report only completion or a genuine blocker requiring coordination.
8. **Batch every pending migration.** Rejected: incompatible risk, dependencies, superseded migrations, missing roles, or missing evidence must split or refuse.
9. **Trust caller-asserted or otherwise unqualified automatic production approval.** Rejected: exact migration lists and business-risk decisions remain governed gates. The accepted #2716 path promotes only when the immutable exact list and every machine-verifiable review, preview, dry-run, risk, identity, serialization, and evidence gate qualify; any missing or ambiguous proof refuses to an engineer.
10. **Close an outcome at merge.** Rejected: the application is still blocked until correct environment and behavior are verified.
11. **Duplicate #2705/#2709 fixes in this programme.** Rejected: consume their proven results as prerequisites.
12. **Preview everything because it is safer.** Rejected: database preview cannot prove non-database work and forcing that work through the structural queue adds delay without adding evidence. The correct control is fail-closed impact classification plus the checks applicable to the actual change.
13. **Skip preview for changes described as low-risk.** Rejected: prose labels and perceived risk do not prove impact. Every migration and every change that can alter database structure, behavior, permissions, or data retains database preview.
14. **(2026-09-15) Drop the live-proof requirement so issues close at `production_applied`.** Rejected: it would close outcomes before the application works, which contradicts §1. Instead the outcome owner produces the proof itself (Step 3).
15. **(2026-09-15) Ask Albert to relay proof requests between sessions.** Rejected: it made Albert the scheduler, and that wait was the single largest idle block of the stall.
16. **(2026-09-15) Quarantine or weaken contract 3 so #2934 could merge.** Rejected by the #2934 author at the time: it suppresses the symptom. The rebuild itself must reproduce history (Step 5).
17. **(2026-09-15) Hold every merge until the previous item's production finishes "so runs don't collide."** Rejected: the stage leases already serialize writers. Holding whole pipelines adds waiting without adding safety (Step 2).
18. **(2026-09-15) Solve the stall with only the "produce proofs yourself" rule.** Rejected as insufficient: it fixes cause 1 only. Causes 2–5 each need their own step.
19. **(2026-09-15) Periodic "still open" summaries as the visibility mechanism.** Rejected: repeated unchanged lists hid the lack of closures. Visibility comes from a no-progress alarm plus transition-only reports (Step 4).
20. **(2026-09-15) Ask Albert a question whose answer is already recorded.** Rejected: on #2802 the orchestrator asked Albert several times "who knows which style guide files show a real person's likeness." The answer was already in `u2giants/shared-db` `docs/style-guides-characters-and-royalties.md` §2 and `docs/business-rules/licensing-master-data.md`. Making Albert re-supply what the repo or chat already holds is the same failure as asking him to copy and paste (Step 4).

## 8. Design decisions

### Locked decisions — 2026-09-11

1. Remove the numeric author-lane limit entirely. Any number of non-conflicting authors may hold leases; exact read/write claims, permanent version reservations, and fail-closed state determine safe parallelism.
2. Keep preview, merge, and production writes globally serialized.
3. Add service classes `urgent-application`, `standard-application`, and `maintenance`. Only a reproducible live outage, blocked application release, security exposure, or owner-declared business deadline qualifies as urgent.
4. Within the same safety eligibility, order shared-stage work by service class, then finishable critical path, then `createdAt`, then issue number. Never use urgency to jump an object conflict or missing dependency.
5. Cut the check-ins themselves: every dispatched agent reports to the shared-db orchestrator only when its assignment finishes or becomes genuinely blocked. Routine progress, unchanged waits, and “still working” messages are suppressed; durable commits, events, checks, and evidence remain the source of truth.
5. One outcome issue remains open through `live_verified`; claims and PRs are supporting records.
6. Reuse existing coordination events and blocker ledger as the state store.
7. Reviewer/runner SLOs govern start/reroute, not cancellation of healthy active work.
8. Native merge queue activation follows #2530 exactly and preserves all required checks.
9. An approved-migration train is an immutable exact list with dependency closure, risk compatibility, target proof, and per-migration live assertions. If #2716 is authorized and lands, a fully machine-qualified train promotes automatically and serially; any missing or ambiguous proof stops for an engineer, not a non-technical version-number choice from Albert.
10. Owner authorization is consumed once for its stated scope. A session must not ask again for the same fix/deploy action, and must not ask Albert to judge migration identifiers that the governed evidence already decides.
11. Routing is enforced twice: the sending session must classify from the actual proposed change, and the orchestrator must independently admit only database structure/schema work. A handover, `db-work` label, repository location, or sender assertion is never sufficient.
12. Database-preview eligibility follows proved impact, not perceived risk. Documentation/plans/handoffs, reviewer and queue tooling, CI/workflow maintenance, read-only audits/reporting, tests, and application-only work may use the no-database-preview lane only when deterministic inspection proves they cannot alter database structure, behavior, permissions, or data. Uncertainty fails closed to the ordinary governed route.
13. The no-database-preview lane skips only the database rehearsal and structural orchestrator. It retains every applicable code, test, review, security, deployment, and live-behavior gate, records a machine-readable exemption reason, and targets no more than ten minutes from PR-ready to merge-ready when runner capacity is available.

### Locked decisions — 2026-09-15 (from the twelve-hour stall, Albert's ruling in chat)

14. **The outcome owner produces the live proof.** When `live_verified` needs evidence from a consuming application, the orchestrator dispatches its own agent to produce and record that evidence against the application repository's default branch. It never waits for, or asks Albert to prompt, another session. Any production write needed for that proof still requires the exact authority named in §11.
15. **Wait only on a named exclusive stage.** Merge-ready work may wait only for the specific preview, merge, or production lease it needs, or for an exact object/dependency conflict. "Wait until another item's production finishes" is forbidden unless the two items share an object or dependency.
16. **No-progress alarm.** If no owned outcome makes a stage transition for two hours, the orchestrator must tell Albert immediately: what is stuck, the exact blocker, and the one action that unblocks it. Unchanged "still open" summaries are not reports.
17. **Edge-history refusals are defects, not decisions.** When a delivery tool refuses a legitimate history (a pre-merge preview apply, a recovery run, a drop-then-recreate rebuild, a renumber), the repair goes into the tool with a regression fixture. The orchestrator does not route each occurrence through a manual detour more than once.
18. **Answer from the record before asking Albert.** Before any question goes under "What I need from you", the orchestrator and its agents search the repository docs, the issue and its comments, and the current chat. They ask Albert only for a decision recorded nowhere, and the question names where they looked. They never ask him to relay, copy, or re-paste anything already in the chat, the repo, or another session. (Albert, 2026-09-15.)
19. **GitHub calls go through the machine-wide throttle; never trip a GitHub rate limit again (#401).** On 2026-09-15 the orchestrator and several sub-agents, all sharing one token, ran 60-second watcher loops (`gh run watch`, sleep loops). From 19:25 to 19:37 UTC GitHub refused with `gh: API rate limit exceeded for user ID 55610577` — the PRIMARY 5000-requests-per-hour user limit (evidence request ID `F95F:1E2E31:F1BFCA:3218145:6AA99BB1` at 19:25Z). A later `gh api rate_limit` reading of 5000/5000 only meant a new window had started (reset 20:30Z); it was first misread as the secondary burst limit. A transient "token in keyring is invalid" also appeared, so the undiagnosed failure mode itself is a defect. It was the second such incident. Enforced fix: every AI session calls GitHub through `bin/ai-gh` — cross-process lock and minimum spacing; an hourly budget read from the free `rate_limit` endpoint (the x-ratelimit-* values), cached and decremented locally, that slows calls below 40% remaining and pauses the whole machine until reset below 20%; detection of primary ("API rate limit exceeded", back-off until reset) and secondary (HTTP 403/429, "secondary rate limit", Retry-After, back-off max(Retry-After, 600 s)) refusals with no automatic retry; the exact refusal text in `refusals.log`; every failed call's HTTP status and message body, plus the rate-limit headers and request ID from a rate_limit request made right after it, credentials redacted, in `failures.log`; and refusal of `gh run watch` and `--watch`. Waiting uses `bin/ai-gh-wait` (minimum 300-second interval) or `bin/ai-pr-wait` (now routed through the throttle with the same 300-second floor). Rule for every waiter and sub-agent brief: GitHub calls at most every 5 minutes per waiter, use the throttle helper, never `gh run watch`. This is the concrete mechanism behind Step 10's "no unchanged-state polling" target. (Albert, 2026-09-15.)

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

Replace automatic refill ordering with: safety eligibility; urgent service class; already-started/nearest-live critical path; dependency-transitive blocking impact; `createdAt`; issue number. Preserve separate conflict components but remove numeric author slots and every full-capacity wait/refusal. An eligible non-conflicting author starts immediately; a conflicting author waits on the exact blocking claim, never on an arbitrary global count.

**Stage-scoped holds (2026-09-15, locked decision 15).** Merge-ready work may wait only for the lease it needs (preview, guarded merge, production) or an exact object/dependency conflict. In `manage-migration-author-lanes.mjs`, add an explicit `hold_reason` to any recorded hold. It must name the blocking lease holder or conflicting claim/object. A hold whose reason is another item's unrelated pipeline stage refuses. The orchestrator skill and sub-agent brief must stop instructing "hold the merge until X's production finishes" unless X shares an object or dependency. Real example: PRs #2955 and #2948 were green and approved but held 30–60 minutes each behind #2860's production run with no shared object.

**Version re-reservation without closing the PR (2026-09-15).** When main gains a later migration version than a claim's reserved version, the backdated-migration SQL guard correctly refuses. Add a manager operation such as `--re-reserve-version <claim>` that atomically burns the old version, reserves a fresh one for the same claim, and keeps its object reservations and open PR. Today a new claim refuses (`object collision with claim #2943`) and releasing the old claim refuses (`claim branch ... still has an open pull request`). That forced closing PR #2944 and opening PR #2958. The operation must keep versions permanent (the burned one is never reused) and must not open an object-collision window.

Update `shared-db/AGENTS.md`, the canonical orchestrator skill, operating manual, and tests together.

**Verification gate:** sender fixtures route each structural/non-structural class correctly; adversarial misrouted issues are rejected again by the orchestrator; no non-structural issue can claim a lane or shared stage; two unrelated structural authors run concurrently; conflicting objects never do; urgent application work starts before maintenance; no active work is destructively preempted; a hold naming an unrelated item's production refuses while a hold naming the held production lease is accepted; a #2934-shaped fixture (claim behind a newer main version, PR open) re-reserves in one command, burns the old version, keeps the PR, and never leaves the objects unreserved.

#### Step 2A — add the fail-closed no-database-preview fast lane

Extend `shared-db/scripts/orchestrator-flow/qualify-change.mjs`, `scripts/orchestrator-flow/select-preview-route.mjs`, and their tests with an explicit `DATABASE_PREVIEW_REQUIRED` or `NO_DATABASE_PREVIEW` decision plus a stable reason code. Reuse `scripts/lib/orchestrator-admission.mjs` and Step 2's actual-change classification: a filename, label, author statement, or claimed risk level is never sufficient. Every migration and every change that can affect database structure, behavior, permissions, database-executed code, roles/grants/RLS, or data remains `DATABASE_PREVIEW_REQUIRED`. Missing, mixed, generated, or ambiguous impact evidence also requires preview.

For `NO_DATABASE_PREVIEW`, return the work to its natural owner before structural claim, database-reviewer reservation, preview lock, migration guarded-merge dispatch, or structural queue entry. Eligible classes are documentation/plans/handoffs; reviewer and queue tooling; CI/workflow maintenance; read-only audits/reporting; tests that do not mutate a database; and application-only changes proven not to change database structure, behavior, permissions, or data. The classifier must emit the exact class, inspected inputs and digest, exemption reason, applicable non-database checks, and invalidation conditions. A changed input invalidates the decision and reruns classification.

In ai-devops, extend `tools/ci/classify-changes.sh`, `config/task-gates.json`, their schema/selection tests, and the canonical shared-db routing instructions so the natural-owner lane runs its existing applicable checks without a database rehearsal. Reuse #2715's lightweight prose route rather than creating a competing docs classifier. Add queue-to-merge timestamps and a ten-minute PR-ready-to-merge-ready target for qualified fast-lane work; runner outage or an applicable failing check is reported separately and never converted into an exemption.

**Dependencies:** Step 1's #2715 classifier and Step 2's two-sided admission contract. **Parallel:** shared-db reason-code fixtures and ai-devops task-gate/CI-selection fixtures may be authored independently; integration waits for both contracts.

**Verification gate:** every named eligible class produces `NO_DATABASE_PREVIEW`, runs all of its applicable non-database checks, acquires no structural claim/stage/reviewer/preview ref, and records a reproducible exemption digest. Migration, SQL, database-executed code, grants/RLS, data mutation, generated or mixed changes, and ambiguous fixtures produce `DATABASE_PREVIEW_REQUIRED`. A changed file or classifier input invalidates the exemption. A harmless canary reaches merge-ready within ten minutes when qualified capacity is available, while an injected applicable-check failure blocks it.

#### Step 3 — add the authoritative outcome lifecycle

Extend coordination events and outcome validation with `entered`, `classified`, `dispatched`, `implementation_complete`, `review_ready`, `preview_verified`, `merged`, `production_authorized`, `production_applied`, `live_verified`, `blocked`, and `yielded`. Require each structural intake issue to identify its application return address and live assertion. A PR merge may advance `merged`; it cannot produce `live_verified`.

Add `--outcome-status <issue>` and `--complete-outcome <issue> --evidence <ref>` to the manager. Completion must re-derive the merge/application evidence, generated types where applicable, and the live assertion. Update `scripts/db-coordination-events.mjs`, audit/report code, schemas, and scenario tests.

**Self-service live proof (2026-09-15, locked decision 14).** The moment an outcome reaches `production_applied`, the orchestrator dispatches a live-proof agent in a fresh worktree of the issue's `application_return_to` repository (for example `u2giants/popdam3`). No other session is involved. The agent:

1. runs the issue's `live_assertion` exactly as worded (for #2792: a natural service-role call to `public.reconcile_stale_sg_files_batch` at representative production volume completes under the normal statement timeout without SQLSTATE 57014);
2. records a live evidence artifact with id and sha256 digest, plus an `application_commit_sha` on that repository's default branch;
3. writes the `db-outcome-evidence` block in the one format `--complete-outcome` accepts, then runs `--complete-outcome`.

Add a `--emit-live-proof-brief <issue>` manager command that prints the exact assertion, the required evidence fields, and the block template, so the agent cannot produce a block that refuses with `evidence reference must resolve to exactly one db-outcome-evidence block` (the #2792 refusal). If the assertion requires a production write (the #2792 check ran a real cleanup), the agent stops and the orchestrator asks Albert once for that exact action (§11). That is an authority gate, not a wait on another session. Add an ordering rule: an outcome at `production_applied` for more than 30 minutes without a live-proof dispatch is a scheduling defect and appears in the Step 4 alarm.

**Verification gate:** attempts to close at PR merge, preview-only proof, missing return address, or missing live assertion refuse; a full fixture produces one readable outcome history; a fixture reaching `production_applied` emits exactly one live-proof dispatch with no cross-session message; the emitted brief's block template passes `--complete-outcome` validation; a malformed or multiple-block evidence reference refuses with a message naming the missing field.

### Phase C — remove conversation and bookkeeping latency

#### Step 4 — event-driven dispatch and resumable orchestrator snapshots

Build a read-only `--orchestrator-snapshot` from current marker, claims, PR heads/checks, reviewer leases, stage locks, outcome events, and eligible queues. Hash and attach it to the marker/issue; a successor verifies freshness and resumes without a prose reconstruction. Keep prose handoffs only for unresolved judgment, failure history, and private/non-derivable context.

Publish durable events on eligibility, dependency completion, author-capacity release, review availability, merge-queue completion/ejection, preview completion, production decision, and live verification. Update canonical skills and the sub-agent brief so agents report only at completion or when genuinely blocked; do not send periodic progress, unchanged-wait, or “still working” check-ins into the shared-db orchestrator session. Use bounded event-aware waits only when an operation has actually started. Durable events and evidence replace intermediate narration rather than removing observability.

The current manual owner-authorized marker succession remains until Codex/Claude can prove an authenticated automatic continuation. If no supported continuation API exists, the snapshot plus one fixed launch action is the fallback; never pretend notification or continuation occurred.

**No-progress alarm and transition-only owner reports (2026-09-15, locked decision 16).** Derive from the outcome events a per-outcome "last stage transition" time. The orchestrator's owner-facing reply must:

- report only when an owned outcome changes stage, when a genuine owner decision is needed, or when the alarm fires; an unchanged "Still open" list is never sent on its own;
- fire the alarm when any owned outcome has had no stage transition for two hours, or when zero outcomes have closed in four hours of active work. The alarm names the stuck outcome, the exact blocker (lease holder, refusal text, or missing evidence), and the single action that unblocks it;
- include a closures-in-this-session count in every owner report, so "busy but not delivering" is visible at a glance.
- never ask Albert anything the record already answers (locked decision 18). The skill requires a search of repo docs, the issue thread, and the chat before any "What I need from you" question, and the question names the sources checked. Real example: #2802's likeness-source question, answered in `docs/style-guides-characters-and-royalties.md` §2.

Implement the timer in `--orchestrator-snapshot` output (a `stalled_outcomes` list with minutes since last transition). Put the reporting rule in the canonical `shared-db-orchestrator` skill. The real example: about 12 hours of repeated summaries, and zero closures surfaced only when Albert asked.

**Verification gate:** a fixture successor reconstructs the exact active map from the snapshot; an unchanged queued item produces zero repeated comments/polls; each meaningful transition wakes once; a simulated agent emits no orchestrator message for intermediate or unchanged progress and emits exactly one message on completion or genuine blockage; a fixture outcome idle for 121 minutes appears in `stalled_outcomes` and the skill-instruction test requires the alarm wording; a snapshot with unchanged state produces no owner report; a #2802-shaped fixture (owner question whose answer exists in a repo doc) resolves from the doc and produces no owner ask, while a genuinely unrecorded decision produces one ask citing the sources searched.

#### Step 5 — one early delivery preflight and automatic evidence registration

Compose existing qualification, work-contract, object collision, dependency, sidecar, producer, migration-order, reviewer-capacity, and runner-capacity checks into `scripts/orchestrator-flow/delivery-preflight.mjs`. Run it before author completion and again only when an input digest changes.

Replace the hand-maintained sidecar producer omission class with a single declarative registry or safe discovery rule owned by `production_business_risk_gate.py` and `check_production_verification_sidecars.py`. The change must still prove every runtime-opened producer file is pinned; discovery may not silently widen trust.

Store the preflight input/output digest in the evidence bundle. A later phase reuses green results only when the invalidation classifier proves no relevant input changed.

**Review survives evidence-only and clean-refresh commits (2026-09-15).** Apply the same invalidation classifier to reviewer approvals. A commit that changes only the evidence pair (work contract/completion report), a stored script hash, or a clean merge from main that leaves the PR's own diff identical carries recorded approvals forward. The carry-forward records the approved implementation digest and the new head. Any change to the PR's own implementation diff still voids approval. Real example: #2860's head moved three times for evidence and hash refreshes, and #2934's refresh discarded Muse's approval, each time redrawing both reviewers.

**Faithful contract-test rebuild (2026-09-15).** The pass-2 repair in `check_pass2_routine_supersession.py` (and its CI invocation) must replay the net effect of every later migration on routines, in order, whether or not a routine existed before the re-run. PR #2948 covers routines absent before the re-run. The open case, which #2934 hit at PR #2958 head `e5f00d38`, is a routine re-created by the re-run of an older migration and then dropped by a later one. Re-resolve PR #2964 before starting; consume it if it has landed and close only the remaining gap. Also cover a later `DROP` that names parameters, the GLM Low finding on #2948 with no test yet. Add a preflight check that runs pass 2 for any PR that drops or replaces a routine, so this fails before review, not after two approvals.

**Verification gate:** historical #2627-shaped fixtures fail before PR/review when registration is absent; a valid new sidecar needs one declaration, not a second repair PR; unrelated documentation movement does not rerun expensive gates; an evidence-only commit and a diff-identical main refresh keep approvals while a one-line implementation change voids them; pass-2 fixtures for create→drop, create→drop→recreate-same-signature, recreate-new-signature, pre-existing-routine→drop (the #2934 case), and named-parameter drop all end in the same routine set as a straight replay from empty.

### Phase D — shorten shared stages safely

#### Step 6 — implement the approved-migration train

Add a machine-readable train manifest and manager commands to propose, validate, authorize, dispatch, and close an immutable exact migration list. Validation must prove every file is merged on current main, unapplied on the exact target, not superseded or forbidden, dependency-closed, role-compatible, risk-compatible, and covered by preview/production assertions.

One compatible train receives one consolidated preflight, preview operation, production-policy evaluation, serialized apply, and verification report. Each migration retains its own hash and assertion result. When #2716 is active, a completely qualified train promotes automatically after the production dry-run. Any missing, failed, or ambiguous proof refuses and escalates to an engineer. A failure stops the train, records the exact applied prefix from the live ledger, and permits only forward recovery—never replay guesses.

Integrate with `.github/workflows/shared-supabase-migrations.yml`, `production_business_risk_gate.py`, current batch/rehearsal code near the manager's existing post-merge batch logic, and ledger drift checks.

**Pre-merge preview applies and recovery runs are first-class (2026-09-15).** Two defects forced manual detours for both #2860 and #2792:

1. **Preview-evidence lookup.** The validator behind `--prepare-preview-dispatch` (around lines 7340–7392 of `scripts/manage-migration-author-lanes.mjs` at the time of the stall; re-locate by searching for `already-applied versions require exactly one validated immutable preview apply`) rejected a successful claim-mode preview apply whose dispatch commit (`ffa300c7`) differed from its applied commit (`0c7ebecf`), run 34922309051. Accept a pre-merge claim-mode apply when its artifact binds the exact migration hash that later merged. Failed conditions are currently swallowed silently; make every rejected candidate report which condition failed.
2. **Recovery never qualifies automatic production.** In the migrations workflow, the "Automatic production qualification and dispatch" job keys only on `merged_preview_source_pr`. The sanctioned recovery lane sets `historical_preview_source_pr`, so a successful recovery run (34969488760 for #2860, 34970936447 for #2792) skipped automatic production and production was dispatched by hand. Let a recovery run that validates the exact merged hash qualify under the same #2716 machine gates, with no weaker gate. Also resolve the logged `POST-BATCH APP VERIFICATION BLOCKED: SHARED_DB_TEST_TOKEN is empty` line: either the step runs or the run must not report success.

Until #2716 activation, point 2 qualifies the item for the governed production decision rather than dispatching production. It never adds a production path that #2716 has not authorized.

**Verification gate:** fixtures cover ten compatible migrations, missing dependency, superseded migration, absent database role, mixed risk classes, mid-train failure, stale authorization, and successful live verification without `--include-all`; a pre-merge claim-mode apply with a matching migration hash is accepted as preview evidence, while one with a different hash refuses and names the mismatched condition; a successful recovery run reaches the automatic production qualification job (it is not skipped); an empty app-verification token fails the run rather than reporting success.

#### Step 7 — bound reviewer and runner start waits

After Step 1, add an assignment-start event and a ten-minute “not started” SLO. If the selected reviewer is unusable or never produces durable start/liveness evidence, return the slot through the existing governed terminal/unstarted path and draw the next eligible provider. Do not kill a healthy active review and do not fabricate a failure verdict.

Inventory shared-db workflows' actual runner requirements. Add at least one independent compatible lane for queue-sensitive jobs and a stable aggregate required context, following ai-devops #209/#210 patterns where applicable. Preflight capacity before dispatch. If a preferred lane is unpicked at the SLO, route a new run to an already-qualified compatible lane; never launch a same-run fallback that competes invisibly or weakens coverage.

**Observed reviewer failure modes to cover (2026-09-15).**

- **Turn-limit exhaustion:** Grok ended `turn_limit_cancelled` with no verdict. Treat this as a terminal non-verdict. Return the slot and draw the next eligible provider at the same head, even though another reviewer's verdict exists at that head. The rule forbidding replacement once any verdict exists must distinguish a provider non-verdict from a code verdict. Size review briefs so the provider's turn budget fits them, and record the brief size.
- **Local preflight timeout:** `ai-glm doctor did not answer within 60s` is a local dependency fault. Retry the same reviewer once after an automatic local-service health repair. If it fails again, reroute. Never leave the review parked.
- **Same-slot handback:** a draw for slot 2 returned slot 1's still-running assignment. Slot draws must be independent, so both reviewers run concurrently.

**Verification gate:** injected unavailable/quarantined/unstarted/busy reviewer cases reroute once; active quiet review remains intact; injected runner non-pickup produces one qualified replacement run; every required assertion still executes exactly once in the accepted result; a `turn_limit_cancelled` fixture reroutes at the same head while the other slot's verdict stays recorded; a doctor-timeout fixture retries once and then reroutes; a slot-2 draw while slot 1 is running returns a distinct assignment.

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
- no outcome waits on another session for live proof, and live proof is dispatched within 30 minutes of `production_applied` (2026-09-15);
- no hold without a named lease or conflict, and no manual recovery detour for a history class already fixed in Steps 2, 5, or 6 (2026-09-15);
- the no-progress alarm fired or was not needed, and no two-hour idle stretch went unreported (2026-09-15);
- median request-to-live time improves by at least 50% from the Step 0 comparable baseline, with raw `n` and exceptions shown.

If a target fails, keep #401 open, classify the exact stage, and repair that stage. Do not lower a safety gate or redefine completion.

**Verification gate:** the five-outcome report links exact live evidence, all targets are met or explicitly owner-accepted, #401 closes, and the paired handoff is retired in the closing commit.

## 10. Tests required

### shared-db unit and scenario tests

- Urgent admission: qualifying outage/release/security/deadline; maintenance self-promotion refusal; missing impact/return address refusal.
- Queue ordering: urgent vs standard vs maintenance; transitive blocker; created-at tie; issue-number tie; object conflict; full capacity; no destructive preemption.
- Outcome lifecycle: every legal transition; every illegal skip; merge-not-live; evidence re-derivation; generated-type requirement; one live-proof dispatch at `production_applied`; the `--emit-live-proof-brief` template validates; malformed or multiple evidence blocks refuse by field name.
- Events/snapshot: deterministic hash; stale input; one wake per transition; no unchanged poll; successor reconstruction; `stalled_outcomes` at 121 idle minutes; no owner report on unchanged state; recorded-answer question produces no owner ask (#2802 fixture).
- Holds and versions: an unrelated-production hold refuses; a named-lease hold is accepted; `--re-reserve-version` for a #2934-shaped claim keeps the PR, burns the old version, and never unreserves objects.
- Pass-2 rebuild: create→drop, drop→recreate same signature, recreate new signature, pre-existing routine→drop, named-parameter drop.
- Review carry-forward: evidence-only commit and diff-identical refresh keep approvals; an implementation change voids them.
- Preview evidence and recovery: pre-merge claim-mode apply with matching hash accepted, mismatched hash refused with the named condition; a recovery run reaches automatic-production qualification; an empty app-verification token fails the run.
- Agent reporting: intermediate progress, unchanged waits, and periodic check-ins produce no orchestrator message; completion and genuine blocker transitions each produce exactly one concise report with durable evidence.
- Delivery preflight: sidecar/producer/claim/base/dependency/route/reviewer/runner cases and digest invalidation.
- Migration train: all eight cases named in Step 6.
- Admission: every structural type accepted; application rows/code, docs, CI, reviewer tooling, workflows, and repository maintenance rejected by both sender and orchestrator; sender misclassification cannot acquire a claim/stage.
- Preview eligibility: every allowed no-database-preview class; every database-affecting, generated, mixed, and ambiguous refusal; stable reason/digest; invalidation after input change; zero structural refs or reservations for exempt work; all applicable non-database checks retained.
- Reviewer: #2705 allocation cases, #2709 base cases, unstarted reroute, healthy quiet review, all providers busy, `turn_limit_cancelled` reroute beside an existing verdict, doctor-timeout retry-then-reroute, independent slot draws.
- Independent prerequisites: #2715 prose/mixed/rulebook paths and #2716 fully-qualified/refusal/dry-run/serial-lock/engineer-escalation paths.
- Runner: pickup, non-pickup, replacement, duplicate prevention, aggregate truth.
- Existing manager, coordination scenario, throughput guard, sidecar, production gate, ledger, SQL, and contract suites remain green.

### ai-devops tests

- Canonical skill/global/router parity and installation hash checks.
- Task-gate and CI-selection fixtures prove the no-database-preview lane reuses the natural owner's existing checks, records its reason, and never treats a database-affecting or uncertain change as exempt.
- Forbidden active behavior: automatic refill as success metric, repeated unchanged polling, merge-as-completion, duplicate authorization, mandatory prose reconstruction, asking Albert to relay live-proof requests to another session, holds that name an unrelated item's production, unchanged "still open" owner reports, and owner questions already answered in the repo or chat, including any copy/paste/relay request (2026-09-15).
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
- Self-service live proof does not grant production-write authority: if a live assertion needs a production write, the orchestrator asks Albert once for that exact action, then proceeds without further asks.
- Stall-case identifiers in §3 and Steps 2–7 (PRs #2944/#2948/#2955/#2958/#2964, runs, SHAs, and line numbers) were true on 2026-09-15. Re-resolve them before relying on any of them.
- A merge queue supplements rather than replaces exact-head approval and production freeze.
- No-database-preview means no database rehearsal, not no verification. It never applies to migrations or any change that can affect database structure, behavior, permissions, or data; ambiguity requires preview.
- Classification follows behavior, not directory or filename: plans and declarative discoverability pointers use the lightweight lane; executable instructions, behavior-changing rules, workflows, scripts, tests, configuration, and migrations retain targeted or full code checks.
- Raw transcripts, secrets, licensed data, and private evidence stay outside public repositories.
- Update this STATUS table whenever implementation changes reality.
- At every phase boundary, use a fresh session, re-read all remaining downstream phases through plan-end, and report any assumption, interface, identifier, decision, or evidence drift before handing off or starting the next phase.

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
- [ ] The no-database-preview fast lane is machine-enforced, records a reproducible exemption reason/digest, keeps every applicable non-database check, fails closed on uncertainty, and meets its ten-minute qualified-capacity target in a live canary.
- [ ] Urgent and finish-first scheduling is enforced and tested.
- [ ] No numeric author-capacity limit remains; at least 100 concurrent non-conflicting claims are admitted, while the next conflicting claim is refused for its exact object conflict.
- [ ] One outcome card remains open through live application verification.
- [ ] Polling and manual state reconstruction are replaced by durable events/snapshots.
- [ ] Dispatched agents report only completion or genuine blockage; routine progress check-ins consume zero shared-db orchestrator messages.
- [ ] Early preflight catches all named late bookkeeping failures.
- [ ] Live proof is produced by the outcome owner's own agent; no outcome waits on another session or on Albert relaying a request.
- [ ] Holds name an exact lease or conflict; a claimed version re-reserves without closing its PR.
- [ ] Pass-2 rebuild, pre-merge preview evidence, and recovery-to-automatic-production handle the 2026-09-15 edge histories with regression fixtures.
- [ ] Evidence-only commits keep review; reviewer turn-limit and local-preflight failures reroute.
- [ ] The two-hour no-progress alarm and transition-only owner reports are live in the installed orchestrator skill.
- [ ] The answer-from-the-record rule (locked decision 18) is in the installed orchestrator skill, and the #2802 fixture passes.
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
8. **Programme expansion:** every new defect maps to one existing phase/owner; otherwise #401 records why it is genuinely outside scope. The 2026-09-15 stall causes were mapped this way, into Steps 2–7, rather than added as new steps.
9. **Self-service proof overreach:** a live-proof agent could be tempted to write production to satisfy an assertion. The brief must stop at any write and route it to the §11 authority gate.
10. **Approval carry-forward abuse:** only the invalidation classifier may carry approval, and only when the implementation diff digest is identical. When in doubt it voids.

Rollback is a reviewed revert of the affected phase plus supported rules reinstall. Never roll back by deleting durable claims/evidence, editing applied migrations, weakening required checks, or restoring blind polling.

### Open questions

No engineering design choice blocks Step 0. Step 8 requires Albert's explicit repository-transfer/settings authority. Issue #2716 requires one explicit policy-activation ruling unless its implementation session can cite a current-chat ruling that authorizes the exact global/workflow change; after activation, individual machine version lists do not return to Albert. These are execution gates, not gaps in this plan.

## Coverage of the throughput review

| Review recommendation | Plan owner |
|---|---|
| Urgent application-unblock lane | Steps 2–3 |
| Parallel non-conflicting authorship | Remove the numeric limit while preserving exact conflict claims; Steps 2 and 9; shared-db #2773 |
| Binding classification fast path and orchestrator refusal | Steps 1, 2, and 5; #2715 |
| No-database-preview fast lane for proven non-database work | Step 2A; reuses #2715 and Step 2 |
| Batch approved migrations | Step 6 |
| Automatic evidence | Step 5 |
| Bounded reviewer waits | Steps 1 and 7 |
| Durable orchestrator/context rollover | Step 4 |
| Event-driven rather than polling | Step 4 |
| Stop repeated authorization asks and technical version naming | Steps 1, 3, 6, and 9; #2716 |
| Queue-to-live measurement | Steps 3 and 10 |
| Organization/native merge queue | Step 8 |
| (2026-09-15 stall) Closure waited on another session's live proof | Step 3 (self-service live proof) |
| (2026-09-15 stall) Unrelated merges held behind another item's production | Step 2 (stage-scoped holds) |
| (2026-09-15 stall) Version renumber deadlock forced PR replacement | Step 2 (re-reserve version) |
| (2026-09-15 stall) Contract-test rebuild resurrected a dropped function | Step 5 (faithful pass-2 rebuild) |
| (2026-09-15 stall) Evidence-only commits voided approvals | Step 5 (review carry-forward) |
| (2026-09-15 stall) Pre-merge preview apply rejected; recovery skipped automatic production | Step 6 |
| (2026-09-15 stall) Reviewer turn-limit, local doctor timeout, same-slot handback | Step 7 |
| (2026-09-15 stall) Repeated summaries hid zero closures | Step 4 (no-progress alarm) |
| (2026-09-15) Owner asked for answers already in the repo (#2802) | Step 4 (answer-from-the-record rule) |

## Mandatory implementation-plan self-audit

1. **Could a brand-new AI session execute this plan without asking Albert anything? Yes for every reversible planning and implementation step.** §§2, 5, 9, 10, and 12 identify repositories, current components, concrete files/functions, dependencies, commands/evidence, environments, and verification gates. §8 and §13 isolate the only later owner actions: repository transfer/settings and exact production lists.
2. **Does the plan carry the complete background, nuance, and rejected reasoning? Yes.** §§3, 5–8 preserve the seven-transcript findings, distinguish completed controls from gaps, explain #2705/#2709's narrow reviewer coverage and #2715/#2716's independent ownership, enforce two-sided non-structural refusal, define the fail-closed no-database-preview boundary, reject both preview-everything and risk-label exemptions, reject the superseded 1+1 premise, and preserve every safety boundary.
3. **Is the ultimate goal clear enough for correct judgment when a step is wrong? Yes.** §1 makes live application delivery the outcome, safety preservation the invariant, and explicitly says the goal wins.

**2026-09-15 integration re-audit.** Could a fresh session implement the stall repairs without asking anything? Yes. §3's second trigger defines each cause with verbatim refusal text, PR/run identifiers, and the step that owns it. Steps 2–7 name the target file, command, or workflow job and the behavior when done, and each extends that step's verification gate. §7 items 14–19 record the rejected shortcuts, including closing at `production_applied`, quarantining contract 3, and whole-pipeline holds. §8 locked decisions 14–18 carry Albert's ruling. §10 names the new tests, and §13 extends done, risks, and the coverage table. Gap found and fixed during audit: the drift-prone identifiers needed an explicit re-resolve instruction, which is now in §11.

Checklist result: all 13 sections are present; the STATUS table, zero-context background, explicit scope, current state, root cause, rejected approaches, locked/open decisions, file-level steps, named tests, access, landing proof, risks, rollback, owner gates, plan/handoff cross-links, discoverability route, and full recommendation coverage are included. No secret or private transcript content is present.
