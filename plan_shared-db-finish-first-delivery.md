# IMPLEMENTATION PLAN — replace the perpetual shared-db orchestrator with finish-first delivery (2026-08-18)

Paired handoff: [`HANDOFF.d/2026-08-18T1404Z-edge-dev-codex-shared-db-finish-first-plan.md`](HANDOFF.d/2026-08-18T1404Z-edge-dev-codex-shared-db-finish-first-plan.md)

Evidence and diagnosis: [`shared-db_orchestrator_failure_analysis.md`](shared-db_orchestrator_failure_analysis.md)

## STATUS

| Step | State | Date | Evidence |
|---|---|---|---|
| 1. Freeze the old incentives and define the new outcome contract | ⬜ open | 2026-08-18 | Required edits and tests are in §9.1. |
| 2. Replace three author lanes with the durable 1+1 delivery model | ⬜ open | 2026-08-18 | Required manager behavior and race tests are in §9.2. |
| 3. Add the read-only health audit and early delivery preflight | ⬜ open | 2026-08-18 | Required audit classes and fixtures are in §9.3. |
| 4. Rewrite the shared-db and installed operating rules | ⬜ open | 2026-08-18 | Required source, router, and drift checks are in §9.4. |
| 5. Prove the complete model in disposable fixtures | ⬜ open | 2026-08-18 | End-to-end scenarios are in §9.5. |
| 6. Obtain exact-plan Grok and Kimi agreement and resolve every objection | ✅ done | 2026-08-18 | [`docs/shared-db-finish-first-plan-consensus-2026-08-18.md`](docs/shared-db-finish-first-plan-consensus-2026-08-18.md) records both named sessions, every objection/resolution, and both final `NO MATERIAL OBJECTION TO THE ENTIRE PLAN` verdicts. |
| 7. Land, install, and activate the replacement safely | ⬜ open | 2026-08-18 | Landing and rollback gates are in §9.7. |
| 8. Recover the genuinely unfinished application outcomes | ⬜ open | 2026-08-18 | Current outcomes and the finish-first sequence are in §9.8. |
| 9. Measure the first five delivered outcomes and retire transition artifacts | ⬜ open | 2026-08-18 | Trial metrics and completion gates are in §9.9. |

**Fresh-session starting point:** begin at Step 1 after re-reading §§1, 6–9 and checking both repositories for newer commits. Update this table in the same commit as each completed step. A completed row must cite a test artifact, commit SHA, or exact rerunnable command.

## 1. The ultimate goal — what we are trying to achieve

When an application needs a shared-database structure change, one owner must carry that request from intake until the required behavior is live in the correct environment, verified, and the application can continue. Albert must receive predictable delivery dates and plain explanations of genuine blockers, not days of occupied lanes, tooling pull requests, reviewer recovery, classifications, and handoffs while the application remains blocked.

The replacement must preserve every control that prevents demonstrated database damage: globally unique migration versions, exact database-object collision protection, target-database proof, one-at-a-time preview/merge/production, exact-head independent review, forward-only correction, safe migration ordering, and live behavior verification.

The perpetual coordinator session, automatic lane refilling, three-lanes-full target, speculative platform expansion, and “merged means done” reporting must end.

**If any step below conflicts with this goal, the goal wins — stop and flag it.**

## 2. What these repositories are

### `u2giants/ai-devops`

Local path: `C:\repos\ai-devops`. Target branch: `main`. This public repository distributes the global Codex/Claude instructions, shared skills, reviewer wrappers, Windows setup, and workflow documentation. It does not host an application or database.

Files that own the current orchestration behavior include:

- `skills/shared/shared-db-orchestrator/SKILL.md`
- `skills/shared/shared-db-orchestrator/references/operating-manual.md`
- `skills/shared/shared-db-orchestrator/references/sub-agent-brief-template.md`
- `skills/shared/shared-db-handover/SKILL.md`
- `templates/system/AGENTS-global-codex.md`
- `templates/system/CLAUDE-global.md`
- `docs/skills-map.md`
- `AGENTS.md`

### `u2giants/shared-db`

Local path: `C:\repos\shared-db`. Target branch policy: branch plus pull request; AI may merge after all governed checks. This repository is the source of truth for structural changes to the shared Supabase/Postgres backend used by several applications.

Files that own durable coordination and database delivery include:

- `AGENTS.md`
- `scripts/manage-migration-author-lanes.mjs`
- `scripts/manage-migration-author-lanes.test.mjs`
- `scripts/check-migration-ledger-drift.mjs`
- `scripts/check-migration-ledger-drift.test.mjs`
- `scripts/check-sql.sh` and the repository test commands named in `AGENTS.md`
- `HANDOFF.d/` for unfinished session state

Production Supabase project: `<removed-protected-project-ref>`. Preview branch/project reference: `<removed-protected-project-ref>`. These identifiers must be proved immediately before any write; they are never inferred from intent.

## 3. What triggered this work

Albert reported that five applications had waited for days while the shared-db orchestrator ran interminably, declared chains of dependencies, and rarely completed jobs. The full evidence is in `shared-db_orchestrator_failure_analysis.md`.

The 2026-08-16 orchestrator marker ran for roughly 17 hours. Priority issues #853 and #764 crossed into later sessions. #1049 was initially treated as complete at merge although production had not run. #1090 and #1115 accumulated tooling and history prerequisites. Sample Tracking issue #975 closed while its live outcome remained unfinished. Non-database issue #1113 consumed orchestrator attention. The session opened five more handover issues while inherited application blockers remained.

As of the read-only GitHub check on 2026-08-18:

- shared-db #1090 and handover #1147 were open;
- shared-db #1115 and handover #1148 were open;
- Sample Tracking handover #1149 had closed at 13:41 UTC, so the recovery plan must not invent it as unfinished;
- the open `db-work` list still contained many stale handover, application, source-data, maintenance, and owner-decision issues, proving that the label is not a trustworthy delivery queue.

The failure is architectural, not just reviewer latency: the system has no hard boundary on critical-path platform work, no stable fast path for ordinary changes, and no primary measure of live application outcomes.

## 4. Scope — in and out

### In this plan

- Retire the perpetual shared-db coordinator session and marker as the normal operating model.
- Preserve the GitHub-backed reservation and lock book as a small durable safety gate.
- Replace three occupied author lanes with one delivery outcome in the shared stages plus at most one isolated authoring outcome.
- Allow the isolated outcome to enter shared stages only when the active outcome is finished or waits solely on an Albert business decision.
- Keep one open outcome card per request until live behavior is verified.
- Add an early preview ledger/catalog preflight.
- Add a read-only health audit for aged claims, orphaned reservations, stale stage locks, missing migration files, stale pull-request heads, and malformed routing.
- Remove automatic refill, prepare-next-work, reviewer scorecards in the database critical path, and generalized platform work triggered by one incident.
- Add a one-business-day honesty checkpoint.
- Update source skills, global templates, repository rules, tests, routers, memory, installed copies, and machine drift verification.
- Recover the currently proven unfinished application outcomes after the replacement is activated.

### NOT in this plan

- Weakening preview, review, merge, production, identity, collision, or live-verification safeguards.
- Deleting durable migration-version reservations merely because work is old.
- Automatically cleaning locks, branches, worktrees, issues, preview history, or database state. The new health audit is read-only.
- Implementing the Kimi wrapper repair. That remains owned by `plan_kimi-windows-execution-reliability.md`; database delivery must not wait for it.
- Completing all historical `db-work` issues. They must be classified and routed, not treated as one deliverable.
- Ordinary application-owned row writes, source portal scraping, application code, documentation-only work, or outside-sourced Master Data imports except for correct routing.
- Database schema changes for this operating-model implementation. The implementation changes coordination code and instructions only.
- A new daemon, service, dashboard, permanent scheduler, privileged broker, or second backlog database.
- Automatic production promotion without the existing governed risk and identity proofs.

## 5. Current state of the code

### What already exists and must be preserved

- `shared-db/scripts/manage-migration-author-lanes.mjs:11` defines `MAX_AUTHOR_LANES = 3`.
- `parseQueueScope`, `buildDynamicQueues`, and `assertLaneAvailable` parse routed work, build three queues, protect exact objects, include open pull requests, and fail closed on unreadable claims.
- GitHub-backed permanent version references and claim issues survive crashed sessions and machines.
- Exclusive preview, merge, and production references serialize the shared stages and prevent merge during production.
- Claim release is explicit, owner checked, and refuses an open pull request.
- `--audit`, `--queue-audit`, and `--cleanup-stale` exist, but the audit reports occupancy/malformed claims rather than the full aging/orphan health required after the standing coordinator is removed.
- `check-migration-ledger-drift.mjs` and catalog verification tools already cover parts of environment drift; the implementation must compose proven checks rather than duplicate them.
- The incident ledger records the measured reasons for unique versions, exact object locks, forward-only fixes, one-at-a-time preview, target proof, live behavior assertions, and owner risk decisions.

### What currently drives the failure

- `shared-db/scripts/manage-migration-author-lanes.mjs:11,103,179` and tests enforce three author lanes.
- `--queue-audit` prints `REFILL REQUIRED NOW` when eligible issues exist (`manage-migration-author-lanes.mjs:989-993`).
- `shared-db/AGENTS.md:646-712` requires up to three concurrent authors, immediate refill, and more safe preparation while authors wait.
- `ai-devops/skills/shared/shared-db-orchestrator/SKILL.md` requires at most three authors, automatic same-turn refill, and a standing coordinating session.
- The operating manual requires reviewer-comparison documentation after every database review and still contains provider rotation rules that have moved to the reviewer-repair track.
- Current outcome completion is spread across implementation issues, claims, pull requests, handovers, and production artifacts. No single card is required to remain open until live verification.
- The shared primary checkout is concurrently edited. Implementation must use isolated branches/worktrees and stage only owned files.

### Commit and deployment state

At plan drafting, `ai-devops/main` was at `384c42d50b3a152ea4f64d69871ea6ca66224385` with unrelated uncommitted Windows SSH work. `shared-db/main` was locally at `d6752de69e8a68fa1e6108e45d7848d48e68772e` and two commits behind `origin/main`. A fresh implementation session must fetch and remeasure both before editing. No code from this plan has been implemented, installed, or applied to any database.

## 6. Key findings and root cause

1. **Utilization replaced throughput.** Three occupied claims produced more moving `main` heads, stale reviews, merge ordering problems, and work waiting at one serialized preview environment.
2. **The platform repaired itself in front of customers.** #853 and #764 turned bounded database work into claim-manager, atomic-runner, and version-replacement programs before the application outcome could finish.
3. **Safety gates were scheduled late.** Preview history and catalog drift appeared after authoring and review rather than in one early preflight.
4. **Review safety was correct; scheduling was wrong.** Exact-head evidence must remain, but final review must start only when prerequisites are merged and a quiet merge window can be held.
5. **Repository events were mistaken for delivery.** #1049 and #975 prove merge or issue closure does not mean the live application outcome is complete.
6. **Routing was inherited rather than reclassified.** #1113 entered shared-db despite not being structural database work.
7. **The standing coordinator accidentally provided one useful tripwire.** Its startup audit exposed malformed claims, stale handoffs, and routing mistakes. Removing it without a read-only replacement would let durable locks and abandoned work rot invisibly.
8. **Durable state is necessary; a durable session is not.** The version/object/stage lock book prevents measured damage across machines. The 17-hour coordinating conversation owns no state that cannot be derived from GitHub, Git, and preview.
9. **One shared delivery lane plus one isolated authoring lane is the correct bound.** Preview, merge, and production are serialized. More than one outcome competing for them increases staleness. A second isolated author can usefully prepare work without touching shared stages.
10. **The owner-decision exception needs an enforced yield.** When the active outcome waits only on Albert and holds no shared-stage lock, the isolated outcome may take the delivery role. If Albert answers mid-operation, no preemption occurs; ordinary lock acquisition decides order.
11. **A one-day deadline is for truth, not unsafe speed.** Complex work such as #1090 may legitimately take longer. After one business day, expansion stops and Albert receives the essential dependency chain and a date.
12. **Reviewer-wrapper repair is independent.** Kimi/Grok/GLM transport failures must reroute or fail visibly, but shared-db must not open reviewer-recovery work as a database dependency.

## 7. Approaches considered and REJECTED

1. **Keep the current orchestrator and tune its prompts. Rejected.** The harmful incentives are encoded in scripts, skills, queue output, and owner instructions. A better prompt cannot override `REFILL REQUIRED NOW` and a three-lane cap.
2. **Remove all coordination. Rejected.** Duplicate migration versions have silently skipped migrations, and concurrent full-body function replacements have erased fixes without merge conflicts.
3. **Make the safety gate stateless. Rejected.** Reservations and object claims must survive crashes and operate across computers.
4. **Keep three outcome lanes instead of three author lanes. Rejected.** All three still converge on one preview/merge/production path and recreate stale evidence.
5. **Force every application blocker live in one day. Rejected.** It would pressure sessions to skip real gates or lie about completion. One day is the honesty checkpoint.
6. **Allow one supporting tooling pull request, then require ceremony for the second. Rejected.** A count does not distinguish essential safety from speculative generalization. The test is whether the current outcome is unsafe without the exact correction.
7. **Build a new dashboard or scheduler. Rejected.** It creates another state store and platform project. One read-only command can derive health from existing authority.
8. **Automatically clean aged claims or preview drift. Rejected.** An expired claim may protect work already applied to preview. Cleanup remains explicit and owner verified.
9. **Use parent/child issue hierarchies for every internal step. Rejected.** The prior system already generated issue chains. One outcome card plus code/PR evidence is enough.
10. **Wait for reviewer-system or Kimi repairs before changing database delivery. Rejected.** Review failures amplify the problem but do not cause the orchestration architecture failure.
11. **Ask a fourth model before drafting. Rejected.** Codex, Grok 4.6, and Kimi K3 already agree on the corrected target model. The higher-value gate is exact review of this complete plan by Grok and Kimi, followed by bounded rebuttal until all material plan objections are resolved. A fourth opinion is used only if those reviewers remain materially split after the allowed debate.
12. **Treat every open `db-work` label as an application blocker. Rejected.** The current list includes stale handovers, application work, source data, maintenance, and owner decisions. Route and status fields, not the label, determine eligibility.

## 8. Design decisions already made

### LOCKED, agreed 2026-08-18 by Codex, Grok 4.6, and Kimi K3

1. Retire the perpetual coordinator session; keep durable locks and reservations.
2. One owner carries one outcome through live verification.
3. At most one outcome may hold the `shared` delivery role. At most one other counted structural claim may exist. That second claim is either isolated authoring or a yielded waiting-owner claim. Zero claims and one claim are valid; two authoring claims, two shared claims, or a third counted claim are refused.
4. The isolated outcome may enter shared stages only after the active shared outcome is `live-verified`, or is `waiting-owner`, holds no preview/merge/production lock, and has atomically yielded. A waiting-owner claim still counts against the two-claim maximum and still protects its objects and migration version.
5. No automatic lane refill and no utilization target.
6. One open outcome card remains authoritative until live behavior and required generated types are verified.
7. Platform work enters the critical path only when the outcome is unsafe without that exact smallest permanent correction.
8. One business day triggers an honesty report and stop-expansion review, not a forced deployment.
9. Final review begins only in a stable merge window after known prerequisites merge.
10. Reviewer transport failure reroutes immediately through the Full Access main task or another governed reviewer; it never creates shared-db platform work.
11. Add a read-only aging/orphan health audit before removing the standing coordinator.
12. Fix shared preview/history drift once before resuming affected application outcomes.
13. Withdraw the prior owner instructions to keep three lanes full and close every open issue.
14. Preserve all incident-backed safety controls named in §§1 and 11 and in `skills/shared/shared-db-orchestrator/references/incident-ledger.md`. Section 6 is diagnosis, not the authoritative control list.
15. Encode `role: authoring | shared` on the existing `db-author-lease`. Do not add a second lock book or another GitHub reference family.
16. Preview, merge, preview-recovery, and production acquisition must refuse a claim whose role is not `shared`. An isolated author may have a branch and pull request but cannot acquire a shared-stage lock.
17. Merge does not release the shared claim. Release is allowed only after `live-verified` or owner-verified safe abandonment. Delete current instructions that release a claim at merge.
18. Keep `status`, `work_type`, and `route` independent. Add `delivery_state`, `live_environment`, and `live_verification` to the existing `db-work-scope`. Yield requires `status: owner-decision`, `delivery_state: waiting-owner`, the unchanged route, and no held shared-stage lock.
19. Delete the exclusive orchestrator-marker single-session rule rather than renaming it. Two computers may start delivery-owner sessions; the durable lock book serializes claims and stages. Keep the route value `shared-db-orchestrator` and skill folder name temporarily for compatibility.

### Locked implementation names and defaults, 2026-08-18 exact-plan review

1. Work-issue fields are `delivery_state`, `live_environment`, and `live_verification`. The claim-lease field is `role`. Existing `--claim` creates `role: authoring`; new commands are `--promote-shared`, `--yield-shared`, and `--health`. Existing `--release-claim` gains the live-verification/abandonment precondition.
2. Implement `--health` on `scripts/manage-migration-author-lanes.mjs`. Compose preview/ledger readers outside the claim mutex path; do not add a parallel `delivery-health.mjs` state owner.
3. Default alert thresholds are 24 hours for author/outcome inactivity and two hours for preview/merge/production locks. Tests may override them. Expiry alerts only and never unlocks. The one-business-day honesty checkpoint uses `America/New_York` weekdays.
4. Do not add a daily scheduler in the first implementation. Every session touching shared-db runs `--health` first. Reconsider scheduling only from the five-outcome trial.

No other design question is open. A fresh implementer must not reintroduce three lanes, automatic refill, a standing coordinator, automatic cleanup, or merge-as-complete reporting.

## 9. Ordered implementation plan

### Phase A — change the contract before changing mechanics

#### 9.1 Freeze the old incentives and define one outcome card

Change in `ai-devops`:

- `skills/shared/shared-db-orchestrator/SKILL.md`
- `skills/shared/shared-db-orchestrator/references/operating-manual.md`
- `skills/shared/shared-db-orchestrator/references/sub-agent-brief-template.md`
- `skills/shared/shared-db-handover/SKILL.md`

Change in `shared-db`:

- `AGENTS.md`
- `scripts/manage-migration-author-lanes.mjs` parser contract
- `scripts/manage-migration-author-lanes.test.mjs` fixtures

Required behavior:

- Rename the role in prose from “orchestrator” to “delivery owner” while keeping the skill name temporarily for trigger compatibility.
- Delete automatic refill, three occupied lanes, prepare-next-issue, close-every-open-issue, and reviewer-scorecard requirements.
- Keep `status`, `work_type`, and `route` unchanged and independent. Allowed status remains `ready | blocked | owner-decision`; the compatibility route remains `shared-db-orchestrator`.
- Add three fields to the same `db-work-scope` block for structural work only: `delivery_state: queued | authoring | shared | waiting-owner | live-verified`, `live_environment: preview | production`, and `live_verification`, which is empty until proven. Non-structural routes omit these fields and `objects`.
- Require one exact application/business outcome and verification criterion in the same issue body. Do not create child tracking issues for internal tooling.
- Keep work-type and route classification independent. A successor is reclassified from scratch.
- Define completion: `live-verified` may be written only by an explicit manager update receiving a non-empty evidence pointer, either a workflow URL or a repository artifact path plus commit SHA. Claim, promote, merge, and classification paths refuse to write it.
- Provide a backwards-compatible adoption path. Missing delivery fields on an already-open structural issue become health class `LEGACY_SCOPE_MISSING_DELIVERY_FIELDS`; health and candidate listing still parse it, but claim/promotion/live-verification refuse until an owner-verified adoption fills the fields.
- Add the one-business-day honesty comment format: exact essential blockers, deferred process work, delivery owner, and forecast date, measured in `America/New_York` weekdays. The manager never automatically closes, yields, or changes priority at 24 hours.

Dependencies: none. This contract must land before capacity code changes so the manager has a stable schema.

**You’ll know it worked when:** new `--claim`, `--promote-shared`, and live-verification updates refuse a structural issue that lacks the three delivery fields; `live_verification` may be present and empty until the `live-verified` transition; health and candidate listing still parse already-open issues missing those fields as `LEGACY_SCOPE_MISSING_DELIVERY_FIELDS`; `live-verified` is refused without a non-empty evidence pointer; non-structural routes are accepted without objects; and repository searches find no active instruction to refill lanes or treat merge/classification as completion.

#### 9.2 Replace three lanes with the durable 1+1 model

Change `shared-db/scripts/manage-migration-author-lanes.mjs` and `.test.mjs`:

- Replace `MAX_AUTHOR_LANES = 3` with maximum capacity, never a fill target: counted structural claims `<= 2`, `role: shared <= 1`, and `role: authoring <= 1`. Legal states include empty, shared only, authoring only, shared plus authoring, and shared plus a yielded waiting-owner claim. A yielded waiting-owner claim occupies the one non-shared slot.
- Preserve permanent version reservation and exact-object collision checks for both roles.
- Add `role: authoring | shared` to the existing lease. `--claim` always creates authoring. `--promote-shared` is the only route to shared and uses the existing acquisition mutex/readback. `--yield-shared` atomically returns the claim to the counted non-shared role without releasing objects or its permanent version.
- Promotion requires current issue state, exact claim ownership, no conflicting open pull request/object, and no active preview/merge/production lock owned by another outcome.
- The active delivery outcome may yield only when its issue is `waiting-owner`, the machine route remains unchanged, and it holds no shared-stage lock. Yield never releases objects or its migration version.
- If Albert answers while another outcome has the shared role or a shared-stage lock, do not preempt. The answered issue changes to `status: ready`, keeps `delivery_state: queued`, and keeps its counted non-shared claim. It may promote only after the current shared claim completes/yields and every acquired stage lock releases. No third claim may start meanwhile.
- `acquireExclusive(preview|preview-recovery|merge|production)` requires exactly one live claim for the pull-request branch with `role: shared`. Convention alone is insufficient.
- `--release-claim` after merge alone is refused. It requires `delivery_state: live-verified`, or exact owner plus confirmed safe abandonment, no open pull request, and no held stage lock.
- Legacy three-claim state refuses all new claims/promotions and prints an adopt/finish instruction; it is never silently dropped.
- Remove dynamic queue auto-refill output. Replace it with an ordered read-only candidate list that exits zero when candidates exist. Selection is oldest genuine application blocker first unless one shared environment repair blocks multiple outcomes.
- Preserve all exclusive-stage, owner-readback, network ambiguity, expiry, and permanent-version behavior.

Dependencies: §9.1 issue contract.

**You’ll know it worked when:** real-process race tests admit one shared claim and one isolated authoring claim, reject a third, reject two simultaneous promotions, allow a guarded yield only for `waiting-owner`, preserve all object/version refs across yield, and show that a late owner answer cannot preempt an already acquired stage lock.

#### 9.3 Add the read-only health audit and early delivery preflight

Change or add in `shared-db`:

- Add `--health` to `scripts/manage-migration-author-lanes.mjs`; keep GitHub/claim/orphan/lock classes in this command.
- For preview identity and ledger, call or import read-only helpers from `scripts/check-migration-ledger-drift.mjs --target preview` after proving ref `<removed-protected-project-ref>`. Exit 2 or unreadable state is `GITHUB/ACCESS UNAVAILABLE`, never `CLEAN`. Do not import these readers into the claim mutex path.
- Do not reuse `production_catalog_verification.py` or `historical_preview_recovery.py` as a generic preflight engine; they serve post-apply/recovery purposes.
- Add tests beside each affected script.

Offline/GitHub health output must report without mutation:

- claims older than the configured threshold, with owner, issue, branch, worktree, last activity, and whether the PR remains open;
- permanent reserved versions with no migration file and no open PR;
- preview/merge/production stage locks older than threshold;
- malformed or duplicate outcome/claim records;
- non-structural or incorrectly routed issues carrying object claims;
- open PRs behind current `main` or lacking one exact outcome claim;
- open handover issues whose named work issue is already closed;
- GitHub-read failure distinctly from dirty state.

Credentialed early preflight, run once before authoring an outcome, must prove read-only:

- exact preview identity `<removed-protected-project-ref>`;
- repository migration files versus preview ledger;
- unknown remote-only versions;
- required predecessor versions;
- a bounded existence/definition check for only the exact objects named on the outcome card, using existing read-only `to_regclass`, `pg_get_viewdef`, or equivalent repository patterns; report present, missing, or unreadable without building a catalog inventory platform;
- no production write and no automatic ledger repair.

Output must distinguish `CLEAN`, `SHARED ENVIRONMENT BLOCKER`, `OUTCOME BLOCKER`, and `GITHUB/ACCESS UNAVAILABLE`. Alerts never release or mutate state.

Dependencies: §9.2 claim roles for ownership reporting. The read-only portions may be developed in parallel.

**You’ll know it worked when:** fixtures reproduce expired-but-protective claims, an orphan reservation, an aged stage lock, a remote-only preview migration, a missing catalog object, a misrouted issue, and a GitHub outage; every case produces the correct class and zero mutation, while the existing owner-verified cleanup remains the only destructive path.

**Natural fresh-session cut:** after Phase A. Update STATUS with test artifacts, start a fresh implementation session, and re-read §§6–9 before Phase B.

### Phase B — rewrite every active instruction and prove drift cannot restore the old model

#### 9.4 Rewrite source rules, routers, templates, and installed copies

Change in `ai-devops`:

- `skills/shared/shared-db-orchestrator/SKILL.md` and references
- `skills/shared/shared-db-handover/SKILL.md`
- `templates/system/AGENTS-global-codex.md`
- `templates/system/CLAUDE-global.md`
- `docs/skills-map.md`
- `AGENTS.md`
- `shared-db_orchestrator_failure_analysis.md` with a short “replacement plan” link only; preserve the postmortem text
- add a secret-free memory fact under `memory/shared-db/` pointing to this plan’s STATUS table
- update `bin/ai-install-skills` or drift tests only if needed to prove installed-source equality

Change in `shared-db`:

- `AGENTS.md`
- affected documentation routers and handover text found by repository-wide search
- do not rewrite another session’s `HANDOFF.d` file

Required wording:

- Delete the exclusive orchestrator-marker rule and the sentence that shared-db runs one orchestrator session at a time. Do not rename them. No standing coordinator chat or marker is needed for normal delivery.
- Any authorized shared-db delivery owner starts with `--health`, claims one outcome, and owns it to live verification.
- One shared outcome plus one isolated authoring outcome; owner-decision yield rule exactly as §9.2.
- Platform fixes require the essential-safety test.
- Review happens only at stable head; provider transport failure routes outside shared-db.
- One-day honesty checkpoint.
- Daily/status reporting uses live outcomes, oldest blocker age, exact blocker/forecast, handovers, and delivery-versus-platform time.
- All incident-backed safety rules remain.
- Rewrite `skills/shared/shared-db-handover/SKILL.md`: path A stops mutation, writes or updates one outcome card/handover issue, and stops; there is no standing session to receive work. Path B closes out only outcomes the current delivery owner actually claims, never seeds a refill queue, and replaces the coordinator/sub-agent two-halves register with the standard past-facing outcome state.
- Supersede `memory/shared-db/always-delegate-work-to-subagents.md`: a delivery owner may do the work in the main task; sub-agents are optional isolation, not a requirement that leaves a coordinator idle.

Add drift tests that fail on active phrases including `REFILL REQUIRED NOW`, “three migration authors,” “fill every lane,” “prepare the next issue,” active Qwen rotation, reviewer scorecards on the database critical path, or a standing marker requirement. Allowlist whole historical files or fenced historical sections by stable identifier, never a line number. Allow evidence that Qwen is paused; fail only instructions that rotate work to it.

Install only through the normal skill/global adoption commands. Never edit installed `~/.codex` or `~/.claude` copies by hand.

Dependencies: Phase A behavior finalized.

**You’ll know it worked when:** source tests pass, drift searches find the old incentives only in allowlisted historical records, installed hashes match canonical source on this machine, and a clean-context routing probe sends structural work to one delivery owner while leaving reads and ordinary app data writes ungated.

#### 9.5 Prove the complete model in disposable fixtures

Add an end-to-end fixture suite in `shared-db` using temporary Git repositories and fake GitHub/database readers. It must prove:

1. ordinary additive structural change: intake → preflight → author → stable review → preview → merge → production proof → `live-verified`;
2. two unrelated requests: one shared, one isolated authoring, third refused;
3. owner decision: active outcome yields with no lock release; isolated outcome enters shared stages; owner answer does not preempt;
4. shared preview drift blocks affected outcomes once and is repaired as one shared environment outcome;
5. essential safety repair stays inside the outcome; speculative generalization is deferred;
6. immediate reviewer transport failure reroutes without creating a shared-db issue; this is an `ai-devops` instruction/routing test, not a shared-db manager test;
7. stale claim/orphan reservation is reported but not cleaned;
8. GitHub outage pauses shared actions while allowing explicitly safe offline preparation;
9. merge alone cannot close the outcome;
10. live ledger success without behavior proof cannot close the outcome;
11. non-structural successor is rejected from shared-db routing; this is an `ai-devops` routing test plus the manager parser's existing refusal to claim objects for non-structural work;
12. one-day checkpoint produces the required plain-English issue comment fields without weakening gates; it is not a manager clock.

For scenario 8, safe offline preparation means only editing local files, running local tests, and drafting SQL. Version reservation, claim, promotion, preview, merge, and production require readable GitHub state and remain fail-closed.

Run the existing lane-manager, migration, production-gate, and instruction-drift suites as well.

Dependencies: §§9.1–9.4.

**You’ll know it worked when:** all twelve named scenarios pass, every existing incident regression remains green, and the suite proves zero database or GitHub mutation outside the fake adapters.

#### 9.6 Obtain agreement on the complete plan and exact implementation

This plan must not rely on agreement about only the “central direction.” Use the existing persistent Grok and Kimi review procedures:

1. Before implementation starts, give Grok 4.6 and Kimi K3 this exact plan file, the postmortem, incident ledger, current manager code/tests, and both repository rule sources.
2. Require each reviewer to classify every design decision in §8 and every implementation step in §9 as `AGREE`, `REVISE`, or `OBJECT`, with evidence.
3. Maintain a consensus ledger in this plan recording each objection, evidence, resolution, changed section, and both reviewers’ final position.
4. Relay full opposing reasoning through `templates/delegation/debate-turn.md`; do not summarize away the strongest objection.
5. Allow the initial review plus at most three rebuttal turns per reviewer. Re-read the current plan every turn.
6. Stop only when both reviewers state no material objection to every section, or record the exact unresolved decision and ask Albert one plain-English question.
7. After implementation, repeat exact-head code review with independent reviewers. Plan agreement does not approve code.

A fourth model is not routine. Use GLM only if Grok and Kimi remain materially split at the debate bound or if both share the same unverified assumption. More opinions without resolving existing objections create breadth, not consensus.

Dependencies: complete draft and Phase B tests for implementation review. The initial plan consensus happens before Step 1 coding.

**You’ll know it worked when:** the consensus ledger names every §8 decision and §9 step, both reviewers explicitly accept the final text with no material objection, and no conclusion uses “agree on the central idea” as a substitute for section-by-section agreement.

### Phase C — land, activate, and recover outcomes

#### 9.7 Land, install, and activate the replacement safely

For `ai-devops`:

- verify `git var GIT_COMMITTER_IDENT` is `Albert Hazan <u2giants@users.noreply.github.com>`;
- commit only owned files, push `main` per repository policy, verify the remote SHA;
- run documented offline suites and Windows instruction/skill installation checks;
- install canonical skills/globals through `ai-install-skills`/`ai-adopt-globals` as documented, preserving machine sections;
- verify canonical and installed hashes match.

For `shared-db`:

- implement on a branch and pull request from current `origin/main`;
- run the full required suite and exact-head independent review;
- merge through the repository’s guarded path;
- do not apply any database migration because this operating-model change contains none;
- verify `origin/main` contains the manager/rule/test changes.

Activation sequence:

1. land code and tests in shared-db;
2. land source skills/global rules in ai-devops;
3. install the new rules on the active machine;
4. run `--health` read-only;
5. close the standing orchestrator-marker issue only after every unique active claim/lock is represented on an outcome card; remove the instruction to open a replacement marker;
6. formally record withdrawal of “keep three lanes full” and “close every open issue.”

Rollback: revert the operating-model commits in both repositories and reinstall canonical skills. Do not delete permanent reservations or claims. If activation fails, use one manual delivery owner with all retained safety gates; do not restart automatic refill.

Dependencies: §§9.1–9.6.

**You’ll know it worked when:** both remote SHAs are verified, tests and exact-head reviews are green, installed/source hashes match, `--health` runs read-only, no second coordinator marker is open, and no database or production state changed during activation.

#### 9.8 Recover the genuinely unfinished application outcomes

Do not use the postmortem’s old count. Re-read GitHub at activation time and create a short outcome table from issues whose current machine block is structural, correctly routed, and not live-verified.

Known starting evidence on 2026-08-18:

- #1090 / #1147: licensing Master Data production package remained open;
- #1115 / #1148: bulk OrderList relink remained open;
- #1149 for Sample Tracking had closed and must not be reopened merely to fill capacity. Before excluding Sample Tracking, prove the live application outcome, including preview structure, generated types when required, and production behavior. If it is still unfinished, open or refresh one outcome card from current evidence; handover closure is not `live-verified`;
- numerous other `db-work` issues were not eligible structural application outcomes.

Recovery order:

1. Run the read-only health audit and one preview ledger/catalog preflight.
2. If one shared environment defect blocks multiple outcomes, repair that defect first as the active outcome.
3. Ask any genuine Albert business-risk question before authoring dependent work. Never ask him technical migration questions.
4. Select the oldest verified application blocker as the shared delivery outcome.
5. Select at most one unrelated outcome for isolated authoring.
6. Carry the active outcome through stable review, preview, guarded merge, production decision, exact target proof, live behavior verification, generated types if required, and card closure.
7. Promote the isolated outcome only under the §9.2 rule.
8. At one business day, stop expansion and publish the essential chain and forecast.

Dependencies: activated replacement model.

**You’ll know it worked when:** each selected application confirms its required behavior can proceed, the outcome card contains live evidence rather than a merge reference, no new reviewer/tooling/handover dependency has entered shared-db unnecessarily, and the next outcome starts only under the 1+1 rule.

#### 9.9 Measure five outcomes and retire transition artifacts

For the first five structural outcomes after activation, record in a committed verification report:

- request-opened to live-verified elapsed time;
- time in requested database delivery versus platform/governance work;
- number and cause of prerequisites;
- number of stale reviews;
- number of session handovers;
- owner-decision wait separately from engineering time;
- safety gates that caught a real defect;
- whether the one-day honesty checkpoint was required and forecast accuracy.

Do not auto-rank reviewers or create another dashboard. The report is a one-time acceptance trial. Compare against the postmortem examples, not an invented percentage target. Success requires all five outcomes to finish without automatic refill, no outcome closed at merge, no speculative platform project in the critical path, and no safety-control regression.

After the trial, retire this plan/handoff only when all STATUS rows are evidenced. Keep the postmortem and incident ledger as historical records.

Dependencies: five completed outcomes after §9.7 activation.

**You’ll know it worked when:** the committed trial report links five live-verification artifacts, the plan STATUS table cites that report and merged SHAs, the paired handoff is deleted under the successor rule, and no open transition-only marker or duplicate handover remains.

## 10. Tests required

### `shared-db/scripts/manage-migration-author-lanes.test.mjs`

- 1+1 capacity and real-process races.
- Third claim refusal.
- One shared-role promotion winner under concurrency.
- Empty, shared-only, authoring-only, shared-plus-authoring, and shared-plus-yielded-waiting-owner states are legal; any third counted claim is refused.
- Owner-decision yield prerequisites and no-preemption behavior.
- Yield preserves object and permanent version protection.
- A yielded waiting-owner claim still counts against capacity after Albert answers and remains queued until the current shared claim/stage releases.
- Preview, merge, preview-recovery, and production acquisition refuse `role: authoring`.
- Legacy three-claim state fails with explicit recovery guidance.
- Outcome fields and delivery-state transition validation.
- `live-verified` requires an evidence reference and cannot be set by merge alone.
- Claim release is refused before `live-verified` except for exact owner-confirmed safe abandonment.
- Candidate ordering does not auto-dispatch.
- Existing network ambiguity, readback, collision, version, stage-lock, and owner-release tests remain green.

### Health and preflight tests

- Aged active claim, expired protective claim, orphan reservation, aged stage lock, missing migration file, stale PR head, malformed route, stale handover, and GitHub outage.
- Preview identity mismatch, remote-only ledger version, missing predecessor, catalog mismatch, and clean baseline.
- Ledger-drift exit 2 or unreadable state can never be reported as `CLEAN`.
- Every health/preflight path is read-only.
- No alert triggers cleanup or ledger repair.

### Instruction and routing tests in `ai-devops`

- Canonical skills, global templates, routers, and installed copies contain the 1+1 model and finish-first completion definition.
- Forbidden active phrases are absent outside allowlisted historical records.
- Reads and ordinary application data writes remain open.
- Structural changes route to one delivery owner.
- Non-structural successors are reclassified from scratch.
- Reviewer transport failures route outside shared-db.

### End-to-end fixture scenarios

All twelve cases in §9.5 are mandatory by name. “Add integration tests” is not sufficient.

### Existing suites

The implementing session must read the then-current repository test commands. At minimum run:

- `node scripts/manage-migration-author-lanes.test.mjs` in shared-db;
- `node scripts/check-migration-ledger-drift.test.mjs` in shared-db;
- the full shared-db SQL/contract suite required by `AGENTS.md`;
- affected `ai-devops` Bash and PowerShell skill/instruction tests;
- `bash tests/test-ai-install-skills.sh` or its then-current equivalent;
- the exact-plan and exact-head reviewer gates in §9.6.

## 11. Constraints, standing rules, and gotchas

- Production and shared cloud infrastructure remain read-only by default. This plan authorizes no production write.
- Every actual database write still requires immediate target proof and the shared-db production process.
- Never remove permanent version refs because a lease expired.
- Never mechanically merge competing full-body `CREATE OR REPLACE` functions.
- Applied migrations are immutable; fix forward.
- Never use `--include-all` or equivalent to promote unrelated pending migrations.
- Preview contains production-sensitive data and is one-at-a-time.
- A successful ledger row does not prove behavior; assert live objects and behavior.
- Reviewer findings are verified against code before blocking.
- Reviewer transport failure is not a review finding.
- GitHub-backed state fails closed during outages; use offline preparation, not retry storms.
- One shared outcome plus one isolated authoring outcome is a maximum, not a utilization target.
- The health audit is read-only. Cleanup remains explicit and recoverable.
- Do not rewrite root `HANDOFF.md` or another session’s `HANDOFF.d` file.
- Update the plan STATUS table whenever implementation changes reality.
- Verify Albert’s Git identity before commits.
- GPT-5.6 reasoning stays low or medium.
- No secret values enter plans, prompts, logs, commits, or review artifacts.

## 12. Access and environment

- Machine: `edge-dev`, Windows 11, PowerShell 7 and Git Bash.
- `ai-devops`: `C:\repos\ai-devops`, GitHub `u2giants/ai-devops`, target `main`.
- `shared-db`: `C:\repos\shared-db`, GitHub `u2giants/shared-db`, branch plus PR.
- `gh` is authenticated as `u2giants`; re-verify before relying on live issue/PR state.
- Supabase CLI and database access are needed only for the read-only preflight and later governed outcome delivery. Prove project identity before use.
- Preview ref: `<removed-protected-project-ref>`; production ref: `<removed-protected-project-ref>`.
- Secrets remain in 1Password vault `vibe_coding`; this plan needs no new credential. Never record values.
- Reviewer wrappers: `ai-grok-review` and `ai-kimi`; use exact named sessions and the skills’ read-only rules. Kimi’s returned model/tokens/cost remain unavailable.
- Concurrent uncommitted work exists in the primary ai-devops checkout. Use isolated worktrees and stage only owned paths.

## 13. Definition of done, risks, and open questions

### Definition of done

- [ ] Every STATUS row cites reproducible evidence.
- [ ] Perpetual coordinator and auto-refill requirements are removed from active source and installed rules.
- [ ] Durable unique-version, object, stage, identity, review, forward-only, ordering, and live-verification controls remain proven.
- [ ] The manager enforces the 1+1 model and owner-decision promotion rule under real races.
- [ ] The health audit and delivery preflight are read-only and cover every named failure class.
- [ ] One outcome card cannot close before live verification.
- [ ] Full existing and new test suites pass.
- [ ] Grok and Kimi explicitly agree section by section on the final plan; every material objection is resolved or Albert decides it.
- [ ] Both repositories are committed correctly, pushed, reviewed, merged, and verified at their remote SHAs.
- [ ] Canonical and installed instruction hashes match.
- [ ] Activation makes no database change and preserves every durable reservation.
- [ ] Genuinely unfinished application outcomes are re-derived from live GitHub state and recovered finish-first.
- [ ] Five-outcome trial evidence shows delivered live behavior without the old process expansion.
- [ ] This plan and its paired handoff are retired only after completion.

### Main risks and rollback

1. **A two-claim legacy state exists during activation.** Audit and migrate explicitly. If three active claims exist, fail closed and finish/adopt them; never delete to reach the new limit.
2. **Removing the coordinator hides abandoned state.** The read-only health audit is an activation prerequisite.
3. **One lane becomes one dead owner.** Claims, issue evidence, incremental status, and “assess state first” recovery allow another session to adopt safely. The audit flags age.
4. **Owner-decision yield creates two shared owners.** Atomic role transition and stage-lock tests prevent it; rollback disables yield while keeping one active outcome.
5. **Early preflight becomes another platform project.** Compose existing readers and keep output bounded to start-state proof; no automatic repair.
6. **Instruction drift restores refill language.** Canonical-source and forbidden-phrase tests fail installation/CI.
7. **Reviewers agree superficially.** The §9.6 ledger requires a position on every decision and step, not a central-direction statement.
8. **Historical outcomes are misclassified as current.** Recovery re-reads GitHub and live evidence; it never trusts the postmortem count.

Rollback is a reviewed revert of the operating-model commits plus canonical reinstallation. Durable claims and version refs remain untouched. During rollback, operate one manual finish-first delivery owner; do not restore auto-refill.

### Open questions

No implementation names remain open after the 2026-08-18 exact-plan review; §8 locks them. If Grok and Kimi remain split after the bounded debate, ask Albert one plain-English question with a recommendation. Do not seek a fourth opinion merely to avoid resolving existing evidence.

The §9.6 consensus gate itself depends on the imperfect Kimi wrapper. Run Kimi from a stable self-contained workspace, use a plan-specific prompt, and treat directory-binding, concurrent-tree, timeout, or missing-terminal-record failures as transport failures rather than reviewer objections. The independent fix remains `plan_kimi-windows-execution-reliability.md`; do not block database delivery on its completion.

## Consensus ledger

This ledger must be completed before Step 1 implementation. The initial architecture opinions informed the draft but do not count as approval of this exact plan.

| Plan area | Codex draft position | Grok 4.6 exact-plan position | Kimi K3 exact-plan position | Resolution and changed section | Material objection open? |
|---|---|---|---|---|---|
| §§1–4 goal and scope | Proposed | AGREE | AGREE | No change required; both exact-plan reviews accepted the goal/scope | No |
| §§5–7 evidence and rejected paths | Proposed | AGREE, citation correction | AGREE, shared-db source recheck required | Preserved; implementation must fetch/remeasure shared-db | No |
| §8 locked decisions | Proposed from prior debate | REVISE then AGREE on rebuttal 1 | REVISE then `NO MATERIAL OBJECTION` on rebuttal 1 | Applied counted waiting-owner, lease role, stage gate, no merge release, marker deletion, names/defaults, safety citation, and post-answer state | No |
| §9.1 outcome contract | Proposed | REVISE then `NO MATERIAL OBJECTION` on rebuttal 2 | `NO MATERIAL OBJECTION` on rebuttal 1 and reaffirmed on rebuttal 2 | Applied additive fields, legacy adoption, evidence-only live state, and corrected verification gate | No |
| §9.2 durable 1+1 mechanics | Proposed | REVISE then AGREE on rebuttal 1 | REVISE then `NO MATERIAL OBJECTION` on rebuttal 1 | Applied maximum-not-target, role-gated stages, counted yield, no merge release, and answered-owner queued state | No |
| §9.3 health/preflight | Proposed | REVISE then AGREE on rebuttal 1 | `NO MATERIAL OBJECTION` on rebuttal 1 | Applied bounded catalog checks and composed ledger reader | No |
| §§9.4–9.5 rules and tests | Proposed | REVISE then AGREE on rebuttal 1 | REVISE then `NO MATERIAL OBJECTION` on rebuttal 1 | Applied marker deletion, handover/memory rewrite, stable allowlists, and split test ownership | No |
| §9.6 consensus method | Proposed | AGREE | AGREE; add Kimi transport risk | Kimi transport rule added to §13 | No |
| §§9.7–9.9 activation/recovery/trial | Proposed | REVISE then AGREE on rebuttal 1 | `NO MATERIAL OBJECTION` on rebuttal 1 | Applied marker retirement and Sample Tracking live proof | No |
| §§10–13 tests, constraints, done | Proposed | REVISE then AGREE on rebuttal 1 | REVISE then `NO MATERIAL OBJECTION` on rebuttal 1 | Applied state/stage/release/unknown tests, closed names, and Kimi wrapper risk | No |

## Mandatory plan self-audit

1. **Could a brand-new AI session execute this plan without asking a question? Yes.** §§2, 5, 9, 10, and 12 name both repositories, exact files/functions, environments, commands, dependencies, phase cuts, and per-step verification gates. §8 labels locked and temporarily open decisions.
2. **Does the plan carry every relevant piece of background, nuance, and rejected reasoning? Yes.** §§3, 6, and 7 preserve the issue examples, system-level cause, safety caveats, reviewer boundary, failed approaches, and why the standing coordinator cannot merely be tuned.
3. **Is the ultimate goal clear enough to guide a correct judgment if a step is wrong? Yes.** §1 defines success as live, verified application behavior with retained incident-backed safeguards and explicitly says the goal wins over a conflicting step.

Checklist result: all 13 required sections are present; scope exclusions, current commit/environment state, rejected approaches, locked/open decisions, concrete file-level steps, named tests, access, rollback, consensus requirements, definition of done, plan/handoff cross-links, and evidence-based self-audit are included. No secret value appears. The plan passed exact-plan Grok and Kimi consensus and is ready for implementation.
