---
issue: 401
status: OPEN
owner: codex/401-fresh-handoff-2240
---

# 0. Decisions only the owner can make

No owner decision is needed to resume PR #2738 or Steps 1-7, 9, and 10. Continue the already-authorized work without asking again.

Later owner gates, already settled and not to be raised early:

- Step 8 repository transfer and live GitHub ruleset changes still require Albert to name the exact transfer/settings action under shared-db #2530. Recommendation: wait until Steps 1-7 are proven, then ask once with the exact action.
- The production-policy activation formerly tracked through #2716 must be consumed from its landed ai-devops #416 evidence and independently owned shared-db PR #2750; do not ask Albert to choose migration version numbers.
- Owner rulings already in force on 2026-09-11: remove the numeric author-lane limit entirely; skip reviewer queues and run independent reviews in parallel; preview only database-affecting or genuinely risky changes; agents report only completion or a genuine blocker; do not touch marker #2714 or duplicate existing owners.

The successor should present the whole list only if a new owner decision actually becomes current. None blocks the immediate work.

# 1. What this application is

`popcre/ai-devops` is POP Creations' public recovery and AI-operation toolkit. Issue #401 coordinates a throughput repair in `u2giants/shared-db`, the public source-of-truth repository for shared Supabase/Postgres structure. The business outcome is faster delivery from database request to verified live application behavior without weakening object conflicts, exact-head review, CI, serialized shared stages, production evidence, or live proof.

Primary plan: `C:/repos/ai-devops/plan_shared-db-complete-throughput-repair.md`. Previous closeout: `HANDOFF.d/2026-09-11T1154Z-edge-dev-codex-shared-db-throughput-401-closeout.md`.

# 2. What this session set out to do, and why

Resume issue #401 from the 11:54Z handoff, first land shared-db PR #2738, prove its admission/refusal behavior on landed `main`, then execute the plan's ordered Steps 1-10. Albert also required maximum safe concurrency, no reviewer queue, preview only for risky/database-affecting work, no author-lane limit, no duplicate owners, no changes to marker #2714, and completion/blocker-only agent reports.

# 3. Current state — verified 2026-09-11 22:40Z

- ai-devops `origin/main`: `1470868d319966a44f68dd208382e86111b8b7e1`.
- shared-db `origin/main`: `26d9345b3a0ee015d8d02c0705002dd10b7f3f4e`.
- PR #2738 is OPEN, not draft, remote head `bdd560d1830a4fe4ecfc26e85db2712af419562e`, and CONFLICTING because `main` moved. Its latest completed functional work includes the admission/outcome lifecycle, workflow identity/permission repairs, unlimited authors, and disabled reviewer queue. It is not merge-ready.
- PR #2738 last proven local evidence before the latest `main` movement: generation 44; 727/727 required Node tests, 242/242 Python guard tests, 33/33 contract tests, truth audit 279, transport scan 221, exact 21-file evidence equality. Re-resolve rather than trusting these as current.
- A new critical risk was discovered after head `bdd560d1`: guarded merge and reviewer commands serve both structural and repository-maintenance PRs, but the new admission gate accepts structural DDL only. Unconditional admission can self-lock every future non-structural code PR. The intended repair/refresh onto `26d9345b` was interrupted by this fresh-session request and was not pushed.
- PR #2795 is OPEN DRAFT at `ed59740839e1b2851fd7c36d759013e27230383b`; do not advance before #2738 and #2750.
- PR #2750 is OPEN DRAFT at `91b3f9e807cb67be5355e91da43653a9d69184fd`; its existing owner remains responsible. ai-devops PR #416 merged at `ce97c710578e1b693f763e18df7ba3227027bf54` on 2026-09-11 22:05Z, so that prerequisite should be re-verified as installed/live before #2750 refreshes.
- PR #2736 is OPEN DRAFT at `286aef9a4fac4ba7e079730b11657aff8c5a551d`; it remains held behind #2738 and retains its own owner.
- Prepared Step 4-5 branch `codex/issue-2728-events-preflight-repair` head `4b42a6895b6bdf89192bcf4b2c63af4b580a9e10` passed 34/34 focused and 1023/1023 combined tests and independent adversarial review. It is not opened or landed.
- Prepared Step 6 branch `codex/issue-2729-step6-train-repair` head `02dd3b8d1a5d1f72c8651671d7f80d66ce13796a` passed 11/11 focused and 74/74 full tests and independent review. It is not opened or landed.
- Prepared Step 10 branch `codex/401-step10-acceptance-report` head `1ce86bf14b033be97f870a3ed2a2f7ed52fc6f00` passed 16/16 focused and 1005/1005 full tests and independent review. It is not opened or landed.
- Step 7 remains groundwork only and must not be claimed complete; production assignment-start/liveness and runner dispatch contracts are not yet live.
- No preview, production, database, shared-cloud, marker #2714, or marker #2758 mutation was performed by this session.

# 4. What did not work

- GLM reviewed #2738 head `e54d7c50` and found workflow callers omitted admission identity, creating a post-merge self-lock. Its final verdict omitted the required full SHA, so the governed wrapper correctly recorded no rejection artifact. Do not retry that head.
- Several repaired heads became stale because unrelated PRs repeatedly moved `main`; only `.agent/contract.json` and `.agent/completion.json` conflicted during refreshes. Each stale reviewer was stopped rather than duplicated.
- One generation recorded an invented expansion of short SHA `e49c5ad5`; generation 35 corrected the true implementation SHA. Always obtain full SHAs with `git rev-parse`, never expand them manually.
- Gemini was selected twice but its local live qualification failed to reserve durable evidence. Those exact-head assignments were replaced as local dependency failures, not provider failures. Do not bypass its doctor.
- Grok reviewed `a4fb74ef`, cost $0.34877744, and rejected legacy resolver parity plus untrusted completion parsing. Its durable verdict could not record after its active lease moved; findings were preserved locally and repaired later.
- Kimi review of `a84c5d69` timed out after 1025 provider seconds with an incomplete, non-authorizing artifact. It nevertheless exposed a valid top-level `issues: write` least-privilege leak, which was repaired at `bdd560d1`. Do not treat the incomplete artifact as approval.
- CI successively caught missing workflow permissions, a missing changed-file entry, job-level permission overrides, and a stale least-privilege test. All were repaired before `bdd560d1`, but exact-current-head CI is still required.
- Reviewer assignment/replacement can contend on `refs/db-coordination/author-acquisition`. Use bounded retries; a release-readback refusal may occur after the durable assignment was created, so inspect exact refs before retrying.

# 5. Root causes and key findings

- The two-sided structural admission design is sound only when applied at structural boundaries. Shared merge/reviewer machinery also serves repository-maintenance code; unconditional structural admission there creates a new deadlock. The fix must classify actual impact and require admission for structural/mixed/unknown work while allowing deterministically non-structural repository maintenance through its natural guarded code checks.
- Effective GitHub permissions are job-scoped: a job-level map overrides workflow-level permissions. Tests must inspect the actual admission-calling jobs, not merely find `issues: write` somewhere in YAML.
- Re-admission can reopen and comment on an issue, so the exact admission jobs need `issues: write`; unrelated validation, dry-run, and review jobs stay read-only.
- Untrusted completion comments must be filtered before parsing/counting. Trusted malformed, duplicate, multi-fence, or identity-mismatched records still fail closed without mutation.
- Evidence contracts must use exact equality with the canonical sorted Git changed-file set; stale or omitted paths invalidate CI.
- Repeated current-main refreshes are the remaining throughput hazard until native merge queue Step 8, but they do not justify freezing or stealing other owners.

# 6. Exact next steps

1. Re-resolve shared-db `origin/main`, PR #2738 head/state, exact refs, CI, reviewer assignments, marker #2758, and marker #2714. Do not modify #2714. Success: one timestamped exact baseline and no duplicate owner.
2. In a fresh isolated worktree, refresh remote PR head `bdd560d1` onto current `main` if still current. Repair the mixed routing boundary: structural PRs must require two-sided admission before reviewer/shared merge stages; deterministically non-structural repository-maintenance PRs must retain applicable code review/CI without fabricated DDL admission; mixed/unknown impact fails closed. Add adversarial tests covering all three classes. Success: no structural bypass and no repository-maintenance self-lock.
3. Preserve every repair already on #2738: effective issue permissions, legacy parity, trust filtering, completed-outcome no-reopen, unlimited author lanes, reviewer queue disabled, #2780 carry-forward, exact evidence lists, and no Step 7. Run contract, focused, required, Python, truth-audit, transport, and diff checks; reseal a new immutable generation with real full SHAs. Success: all suites green and Git/contract/completion file sets exactly match.
4. Run independent reviews in parallel against the same exact head, using the durable selected reviewer without a queue plus a separate adversarial read-only review. Stop stale-head work immediately. Success: one durable exact-head approval and no unresolved finding.
5. Wait event-aware for exact-head CI. Ignore the expected documents-only refusal for code; require every substantive/required check including ephemeral database. Success: all required contexts green.
6. Dispatch `.github/workflows/guarded-migration-merge.yml` for PR #2738 with its exact reviewed head. Re-run only if a production freeze explicitly revoked the authorization. Success: PR merged and the intended commit is on current `origin/main`.
7. On exact landed `main`, run the five targeted admission/outcome tests named in the prior handoff: structural admission, disguised non-structural refusal, migration-required reviewer/stage admission, mandatory admission before claim/reviewer/stage, and typed refusal with return/reopen evidence. Success: 5/5 pass on landed bytes and live issue/ref behavior is recorded without database mutation.
8. Continue the plan in dependency order. Consume #416 live/install evidence; let existing #2750 owner refresh and land after #2738; then refresh/review/land #2795. Refresh and land Step 4-5, then Step 6, then Step 10 only after newly landed `main`, with new evidence/review/CI each time. Keep Step 7 excluded until its real producers exist. Success: each step's plan gate, not merely a PR, is satisfied.
9. Re-read every downstream plan phase through Step 10 at each phase end and report any changed assumption, interface, identifier, decision, or evidence requirement before starting the next phase. This reciprocal drift check is mandatory.
10. Do not execute Step 8 transfer/settings without Albert's exact current-chat authorization. Do not close #401 until five live outcomes satisfy Step 10 and the plan's STATUS/definition of done is updated.

# 7. Constraints and gotchas

- GitHub is source of truth; re-resolve every moving fact. Handoffs are context, never live proof.
- Fresh current-upstream worktrees for writes; canonical checkouts are landing/read-only. Verify Albert's Git identity before every commit and stage only owned files.
- Do not delete claims, refs, branches, worktrees, evidence, or another session's files. Do not disturb marker #2714. Do not duplicate #2750, #2736, #2795, #2530, or other live owners.
- No numeric author-lane limit. Exact object/version conflicts remain mandatory. Preview, merge, and production remain serialized.
- Skip database preview only when deterministic classification proves no database structure, behavior, permission, or data impact. Ambiguous/mixed work stays governed.
- Reviewers run in parallel, without the reviewer queue, but every merge needs one durable exact-head approval. Never treat an incomplete/local artifact as approval.
- Polling is bounded and event-aware. Agents report only completion or genuine blockage.
- No production or shared-cloud mutation without exact current-chat authority. No raw transcripts, secrets, licensed data, or private evidence in public repos.

# 8. Access and environment

- Host: `edge-dev`, Windows PowerShell and Git Bash.
- `gh` is authenticated as `u2giants`; verify before mutation.
- ai-devops canonical checkout: `C:/repos/ai-devops`; shared-db canonical checkout: `C:/repos/shared-db`.
- Current handoff branch/worktree: `codex/401-fresh-handoff-2240` at `C:/repos/ai-devops-worktrees/401-fresh-handoff-2240`.
- Database/deployment secrets live in 1Password vault `vibe_coding`; no values were read or exposed this session.
- Secrets sweep: clean; no new secret, token, connection string, or `.env` was created or surfaced.
- Docs pass: nothing outside this handoff is newly stale; the plan STATUS remains open correctly because no programme step has landed completely.

# 9. Open questions and risks

- Immediate engineering risk, not an owner decision: the structural/non-structural boundary in reviewer/guarded-merge acquisition is not yet repaired on the PR. Treat it as the first code task.
- Main may move again during exact-head review. Refresh safely and reseal; do not freeze or take other owners merely to avoid churn.
- Reviewer active leases can move during long reviews, preventing durable recording. Inspect exact refs and use the governed replacement path; never replay a paid turn blindly.
- Preview state was not queried because this repository-maintenance work performed no preview/database operation. Re-resolve it only before a later structural rehearsal.
- Step 8 owner authorization and the remaining shared-db half of #2716/#2750 are drift-prone; re-resolve when their ordered gate arrives.

## Sub-agent: `repair_step10`

- **Asked to do:** Prepare Step 10, review/repair Steps 4-5, and repeatedly repair/reseal PR #2738 findings.
- **Actually did:** Step 10 branch `1ce86bf1`; Step 4-5 branch through `4b42a689`; #2738 repairs through remote `bdd560d1` with generation 44 and green local suites.
- **Found:** forged registry evidence, workflow admission omissions, legacy parity gaps, trust-filter ordering, issue permission and job-override defects, evidence-list omissions, and stale permission tests.
- **PR / branch:** #2738 `codex/issue-2727-steps2-3`; prepared Step 4-5 and Step 10 branches above.
- **Worktree:** `C:/repos/shared-db-worktrees/2738-urgent-repair` is finished for the last pushed head but must be treated as live evidence until the successor verifies status; do not clean it blindly.
- **Deliberately did not do:** no merge, preview, database, production, marker, Step 7, or other-owner work.

## Sub-agent: `review_2738_live`

- **Asked to do:** Repeated independent exact-head/adversarial reviews and acceptance criteria.
- **Actually did:** Found and reproduced each defect listed in §§4-5; last completed review at `a84c5d69` found only pending CI before Kimi exposed the permission leak repaired in `bdd560d1`.
- **Found:** wrong evidence SHA, missing CI, missing job permissions, incomplete file sets, stale least-privilege tests, and the mixed routing concern now awaiting repair.
- **PR / branch:** read-only; no branch or PR.
- **Worktree:** none owned; finished.
- **Deliberately did not do:** no edits, refs, comments, reviewer calls, merges, database, or marker changes.

## Sub-agent: `unblock_2738`

- **Asked to do:** Refresh/integrate #2738, design live proof, simulate downstream integration, and audit adjacent self-locks.
- **Actually did:** Clean synthetic integration simulation for Step 4-5 -> Step 6 -> Step 10 (54/54); prepared workflow-call repair commit `7d7621c5`; found missing issue-write permissions and standalone legacy parity.
- **Found:** main-refresh churn is evidence-pair-only; post-merge admission can reopen issues; direct and protected admission must share one bounded policy.
- **PR / branch:** no independent PR; repair was incorporated into #2738 by the owner lane.
- **Worktree:** old repair/simulation worktrees may remain; preserve until exact status is verified.
- **Deliberately did not do:** no push after a lease collision, no database/preview/production/marker mutation, and no Step 7.

## Handoff self-audit

1. Yes: §§1-8 give a newcomer the business purpose, repositories, exact live state, branches, evidence, access, and ordered commands/gates.
2. Yes: §§4-5 and the three sub-agent blocks preserve every expensive dead end, review finding, non-action, and recovery rule from this session.
3. Yes: §§0-9 cover background, goal, current state, failures, decisions, constraints, risks, exact next actions, evidence, commit/push/deploy status, and downstream Step 10 scope.
4. Yes: the line-by-line owner-decision sweep found only Step 8 transfer/settings and later production-policy activation; both are consolidated in §0 with recommendations. Immediate work needs no owner input.

The reciprocal instruction is present in §6 step 9 and in the plan's phase-boundary rule: at the end of each phase, re-read every downstream phase through Step 10 and report drift.
