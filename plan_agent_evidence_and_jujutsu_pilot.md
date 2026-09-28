# Implementation plan — reduce agent evidence churn and pilot Jujutsu

## STATUS — read first

Planning date: 2026-09-27 EDT. Parent: [ai-devops #903](https://github.com/popcre/ai-devops/issues/903). This is a planning document; it authorizes no production change or default-tool switch. [This session's handoff](HANDOFF.d/2026-09-28T0250Z-edge-dev3-codex-agent-evidence-jj-plan.md) carries the next-session brief.

| Step | Outcome | State | Acceptance evidence |
|---|---|---|---|
| 0 | Reconcile current owners and establish a measured baseline | Open | Dated report under `tests/verification/repo-throughput/` with reproducible Git/GitHub queries |
| 1 | Finish shared-db task-evidence isolation under its existing owner | Open; existing work partially landed | Existing [shared-db workflow refactor](https://github.com/popcre/shared-db/blob/main/plan_shared_db_workflow_refactor.md) Step 1 gate and live PR traces |
| 2 | Remove avoidable evidence-only commit/review loops left after Step 1 | Open | Positive and refusal fixtures; two independent real PRs land without an evidence-only refresh |
| 3 | Close only proven unrelated-main review invalidation gaps | Open | Exact content/policy identity tests and current-main integration proof; actual implementation changes still invalidate |
| 4 | Run a reversible Jujutsu pilot in disposable clones | Open | Dated side-by-side task trials, recovery and GitHub export proofs |
| 5 | Decide adoption from measured results and verify GitHub continuity | Open | Published go/no-go report, rollback drill, and owner-approved rollout only if warranted |

Fresh session: re-read §1, §5, §8, §9 and the live STATUS of each referenced plan, then take **only the first unticked child** on parent #903. Finish that child, tick it with an artifact, comment the next child on the parent, and stop. Do not bundle unproven live outcomes. At each phase boundary use `fresh-session` and re-read downstream steps against current `origin/main`.

## 1. Ultimate goal

Albert should receive safe code and database changes sooner. Unrelated agents' work should not force a fresh review or a series of bookkeeping commits when the substance of an agent's change has not changed. Each agent should still be able to recover its own work, and all accepted code must remain on GitHub. **If a step conflicts with this goal, the goal wins — stop and flag it.** Speed is measured from request to verified outcome, not by hiding failed checks or loosening database safety.

## 2. What these repositories are

`popcre/ai-devops` is the public recovery toolkit for Albert's Codex, Claude and other AI clients. It contains review wrappers, sealed review packets, CI, installers, skills and operating instructions. `popcre/shared-db` is the canonical Supabase/PostgreSQL schema repository for CRM, DAM, PIM and DesignFlow PLM. Consumer copies of `shared-db/` are generated mirrors. Both repositories use protected GitHub `main`, task branches, isolated worktrees and pull requests. `ai-devops` uses a merge queue; shared-db uses a guarded merge path, with native merge-queue work separately owned by shared-db #2530 (**non-orchestrator work**). Their GitHub repositories remain the authoritative code and backup destination throughout this plan. No database or application deployment is part of planning.

Definitions: *evidence-only commit* changes work contract, completion, proof binding or generated audit metadata without changing implementation; *review equivalence* means independently verified identical reviewable implementation plus unchanged relevant policy and producer identity; *forward movement* means the recorded base commit remains an ancestor of the current branch tip; *exact head* is the particular source commit whose bytes a merge gate authorizes. A Git branch with the same filename set is not automatically equivalent.

## 3. Trigger and reproducible observations

Albert asked on 2026-09-27 to address repeated agent collisions, moving `main`, micro-commit churn, and delivery delay while keeping code backed up on GitHub. A read-only local history count for September 22–28 found 505 commits reachable from shared-db `origin/main`, 244 with evidence-related subjects and 59 with merge/refresh subjects (categories may overlap). These are commits **reachable** through merge commits, not 505 independent PRs. Reproduce with `git log origin/main --since=2026-09-22 --until=2026-09-29 --format=%s` and subject classification; record the exact base SHA and query in Step 0. The local transcript sample contained 84 session files, but current operating rules and incident documents supply the stronger historical examples.

Concrete incidents: [ai-devops review-packet race plan](plan_review-packet-race-and-evidence-speed.md) §3 records two review rounds lost after unrelated `main` movement during slow tests; fix #639 is already merged. [shared-db workflow refactor](https://github.com/popcre/shared-db/blob/main/plan_shared_db_workflow_refactor.md) §3 records conflicting shared `.agent/` files, and its STATUS shows the scoped-evidence migration partly landed. [shared-db bounded handover plan](https://github.com/popcre/shared-db/blob/main/plan_bounded_session_handover.md) §6 records repeated refresh/review work despite unchanged migration/test bytes. [Throughput incident](plan_shared-db-complete-throughput-repair.md) §3 records evidence-only commits voiding approvals, reviewer failures, a claim/version deadlock and unrelated work held behind production. A first-party [shared-db merge protocol](https://github.com/popcre/shared-db/blob/main/docs/agents/merge-protocol.md) records a conflict-dirty PR that started no normal PR checks at all. These are distinct failure classes; do not call all of them GitHub defects.

## 4. Scope

Included: measure evidence-only churn and review invalidations; finish or explicitly defer existing scoped-evidence work through its existing owner; remove remaining redundant commit/review cycles only where proof can be detached safely; test review equivalence for unrelated `main` advances; trial Jujutsu (`jj`) in disposable clones of both repositories; measure recovery, conflict handling and export back to GitHub; document a no-go as a valid result.

**NOT in this plan:** database shape or application row changes; production, preview or infrastructure writes; changing the required number of reviewers; accepting an old APPROVE on new implementation bytes; weakening exact-head, source, policy, test, claim/version or merge/production gates; replacing GitHub, moving issues/CI to Forgejo, adopting DeltaDB, installing Jujutsu fleet-wide, rewriting historical commits, mass-cleaning worktrees, or making jj the default before the pilot qualifies. Shared-db Steps 1 and 8 of its existing refactor remain with their current owners; this plan does not fork their code work or make their entire programme a prerequisite.

## 5. Current state of the code

Re-resolve every line and SHA at Step 0; these references describe the planning snapshot, not a promise that `main` stays fixed.

- In ai-devops, `bin/ai-review-packet:275–330` already accepts a forward-moving target ref while retaining sealed base/head/tree identity. `tests/test-ai-review-packet.sh:325–380` covers forward movement and rewrite refusal. [Fix #639](https://github.com/popcre/ai-devops/pull/639) is merged; **do not reimplement it**. `plan_workflow-efficiency.md` STATUS already owns broader CI/evidence reuse under #650; its P9 remains open in the inspected snapshot.
- In shared-db, `scripts/lib/pr-content-equivalence.mjs`, `scripts/check-exact-head-approval.mjs` and `scripts/check-main-tip-freshness.mjs:260–309` already classify certain content-preserving refreshes. `.agent/work/<issue>/<generation>/` evidence is present; `scripts/agent-work-contract-git-evidence.mjs`, `scripts/refresh-code-pr-branch.mjs`, `.github/workflows/agent-work-contract.yml` and their tests own the remaining transition. [Workflow refactor STATUS](https://github.com/popcre/shared-db/blob/main/plan_shared_db_workflow_refactor.md) Step 1, as inspected 2026-09-27 EDT, was partial and may now have advanced.
- Shared-db `docs/agents/current-workflow.md` keeps unlimited authors/reviewers but exclusive preview, merge and production mutations. `scripts/check-exact-head-approval.mjs` still requires a defensible exact-head authorization; content-equivalence cannot be asserted by the PR author alone. Native merge queue is separately tracked by shared-db #2530 (**non-orchestrator work**).
- Jujutsu is not installed on this planning host (`command -v jj` returned no executable); no jj checkout, pilot branch or default-switch code exists. The [official Git compatibility documentation](https://github.com/jj-vcs/jj/blob/main/docs/git-compatibility.md) describes its Git backend and GitHub pushes. The [working-copy documentation](https://github.com/jj-vcs/jj/blob/main/docs/working-copy.md) describes multiple workspaces. Installation is a Step 4 test prerequisite only, via a supported user/project-owned package, never by replacing OS Git.

## 6. Key findings and root causes

1. Bookkeeping shares the reviewed branch. An evidence update changes the commit head even where implementation is identical; callers then risk drawing reviewers again. Shared paths caused real PR conflicts; scoped evidence removes that class but does not prove every evidence commit is avoidable. See shared-db refactor Step 1 and `scripts/lib/pr-content-equivalence.mjs`.
2. Some callers historically tied validity to the moving `main` pointer rather than the sealed source and verified ancestry. Ai-devops packet validation has already repaired one instance; other shared-db callers need a live call-site audit, not a blanket predicate change. See `bin/ai-review-packet:301–330`, shared-db `scripts/check-main-tip-freshness.mjs:260–309` and bounded handover §6.
3. A real integration conflict, altered policy/producer, changed SQL/code, missing checks or unsatisfied database stage must still block. Review reuse is not merge authorization by itself; current integration and current required checks must be proven under the merge lock. See shared-db `scripts/check-exact-head-approval.mjs` and guarded merge workflow.
4. Git worktree isolation is already required. Jujutsu can improve local change management and recovery, but it cannot eliminate simultaneous edits to one logical object, reviewer scarcity, shared database locks, or GitHub merge/CI stages. This is a pilot hypothesis, not a premise.

## 7. Approaches considered and rejected

- Replace GitHub with Forgejo: Forgejo still uses Git branches and merge integration, while migrating issue, CI and approval machinery adds a new risk. GitHub backup alone would not preserve those workflows. Not part of this pilot.
- Replace Git with DeltaDB: [Delta currently keeps commits in Git](https://delta.dev/docs/concepts/delta-and-git), and its own [roadmap](https://delta.dev/roadmap) identifies beta and incomplete integration features. It may improve conversation/code context, but does not prove fewer shared-db conflicts.
- Rebuild forward-main tolerance in ai-devops or a second shared-db equivalence cache: both already exist; duplicating them increases disagreement between gates.
- Ignore arbitrary `.agent/` or JSON files in review diffs: an attacker could hide executable/policy content or inherit another task's evidence. Only validated, task-bound records qualify.
- Copy an old approval to a new head without a fresh, machine-verifiable equivalence authorization: risks merging content the reviewer never saw. The new head must be bound to the reviewed implementation, policy, producer and current integration.
- Squash or delete all micro-commits as the first fix: this hides the symptom in history but does not remove repeated checks, stale approvals or conflicting files. A final squash may remain a presentation choice after all gates pass.
- Move protected evidence only to local files or GitHub comments without trusted immutability/readback: crashes, edits or retention loss could turn an unproven claim into authorization. Any off-branch evidence design must satisfy the existing trust contract first.

## 8. Decisions

**Locked, 2026-09-27 EDT:** GitHub stays authoritative and receives all accepted code; existing protected review, CI, database, production and rollback gates remain; shared-db refactor Step 1 and ai-devops #650 keep their own implementation ownership; jj is a reversible, disposable-clone trial. The parent issue routes one child per session. No production write is authorized.

**Open to implementer judgment:** after Step 0, whether any avoidable evidence-only commits remain outside already-owned repairs; which one proven caller still mishandles unrelated forward movement; the smallest safe evidence transport (existing immutable GitHub ref/status/record preferred); exact jj version and supported user-local installation method; pilot acceptance thresholds based on a comparable baseline. If measurements show no material win or safety regression, record no-go and keep Git worktrees. Policy changes and default rollout require a separate reviewed decision; routine test-fixture and module naming do not.

## 9. Executable steps

Common contract: each write-capable session uses a fresh `origin/main` worktree in the repository it changes, reads that repo's `AGENTS.md` and routed files, runs `ai-task-gates start --class <actual class>`, checks the gate before review/PR wait/ship, stages owned files, and uses the repo's protected PR path. Refresh issue/PR ownership before edits. Keep every shared-db issue labelled **non-orchestrator** in reports unless it actually changes database structure. No child starts merely because an older STATUS says open.

### Step 0 — Baseline and ownership map

**Files:** new dated `tests/verification/repo-throughput/<date>-agent-evidence-jj-baseline.md` in ai-devops; this plan STATUS and parent #903. Inspect ai-devops `plan_workflow-efficiency.md` #650/P9, review-packet #639; shared-db `plan_shared_db_workflow_refactor.md` Step 1/Step 8, `plan_bounded_session_handover.md` Step 4, and current open PRs. Use `bin/ai-gh` for GitHub calls. For each sample, record source SHA, file list, reason for head change, reviewer state, actual check names, elapsed intervals and final result. Separate content changes from evidence-only and clean refreshes. Count Git history via reproducible commands; do not treat a commit count as a PR or collision count. Sample at least ten affected PRs across both repos if available, otherwise report exact coverage. Never put private transcript text in the public report.

**Gate:** a reader can rerun every count, open each cited PR/run, see which current owner holds every overlap, and identify at most one remaining gap for Steps 2–3. If nothing remains, mark those steps `N/A — already repaired` with live proof. This step is read-only except for its report/STATUS/issue comment; no shared-db claim or production access.

### Step 1 — Complete existing shared-db scoped evidence, without taking it over

**Files/owner:** shared-db [workflow refactor](https://github.com/popcre/shared-db/blob/main/plan_shared_db_workflow_refactor.md) Step 1, existing issue #2708 (**non-orchestrator work**) and its current successor #3380 (**non-orchestrator work**) only if live state confirms they still own it. Primary modules: `scripts/agent-work-contract-git-evidence.mjs`, `scripts/lib/task-evidence.mjs` if present, `scripts/refresh-code-pr-branch.mjs`, `scripts/lib/pr-content-equivalence.mjs`, `.github/workflows/agent-work-contract.yml`, associated tests. The assigned shared-db session executes its existing plan; this cross-repo parent records its outcome and does **not** start a duplicate PR.

**Gate:** two unrelated task PRs land sequentially without a shared evidence-file conflict or unnecessary re-review; wrong-task, duplicate, edited generation and changed implementation still refuse. Save PR heads, merged SHAs and check traces. If the existing owner is active, leave this child assigned there and advance independent Step 4 preparation; do not hold a new worker idle or claim ownership by inference. Any landed but unproved behavior gets exactly one live-proof issue from the landing session.

### Step 2 — Remove remaining avoidable evidence-only commits

**Dependency:** Step 0 and Step 1's validated reader/writer state for shared-db. Ai-devops P9 remains independently owned by #650; coordinate its exact file set before implementation. **Files/functions to audit first:** shared-db `scripts/refresh-code-pr-branch.mjs` (`rebindCompletion`), `scripts/agent-work-contract-git-evidence.mjs`, `scripts/lib/task-evidence.mjs` when present, `scripts/check-exact-head-approval.mjs`; ai-devops `bin/ai-review-packet`, `plan_workflow-efficiency.md` P9 and its test/evidence consumers. Select one actual recurrent commit cause proven in Step 0. Prefer storing a derived, immutable, task-bound receipt outside the implementation branch **only if** existing validators can authenticate and read it at PR and guarded merge. Otherwise keep the commit and record why it is necessary.

Implement the selected narrow change in its owning repo/issue. Preserve producer identity, repository, task, reviewed implementation digest, policy version, source head, creation time, immutable readback and retention. Do not allow a receipt to be overwritten by a later PR or to claim another task. Update the existing writer, reader, refresh path and test fixtures together; do not create a second evidence service. A generation/reference update that changes no implementation must not force a new substantive review, but any altered implementation must.

**Gate:** extend the selected module's existing tests with `unchanged_implementation_needs_no_new_evidence_commit`, `changed_implementation_invalidates_receipt`, `wrong_task_receipt_refuses`, `missing_or_mutated_receipt_refuses`, `producer_or_policy_change_refuses`, and crash-before/after-write idempotency. Run the relevant repository full required suite and two genuine PR traces before claiming the reduction. If no safe candidate survives Step 0, publish a no-change verdict, not a speculative transport.

### Step 3 — Review survival on unrelated `main` movement

**Dependency:** Step 0. Do not touch ai-devops packet validation if current #639 behavior holds. Trace remaining real callers of shared-db `scripts/check-main-tip-freshness.mjs`, `scripts/lib/pr-content-equivalence.mjs`, `scripts/check-exact-head-approval.mjs`, `scripts/orchestrator-flow/classify-invalidation.mjs` and the guarded merge workflow. Pin the reviewed base/head/implementation digest and relevant trusted producer/policy inputs. For a pure forward movement of `main`, re-evaluate current merge tree, required checks, object/version claims and intervening changes. Issue a **new** head-bound machine authorization when equivalence is proven; never relabel an older verdict as if the reviewer saw new content. Policy, global interaction, SQL, implementation, force-push and unknown differences keep the existing refusal/review path.

**Gate:** named tests `unrelated_forward_main_keeps_reviewable_content`, `implementation_edit_forces_new_review`, `policy_or_producer_edit_forces_new_review`, `rewritten_main_refuses`, `missing_checks_refuse`, `real_file_conflict_refuses`, `object_or_version_conflict_refuses`, and `old_rejection_remains_effective` pass in the existing equivalence/approval/merge test modules. One live PR with an unrelated intervening merge proceeds without substantive re-review; one changed-head refusal is demonstrated without merging unsafe code. The exact review and merge gate still approves only the actual landing head.

### Step 4 — Jujutsu pilot, first offline and reversible

**Files:** dated `tests/verification/repo-throughput/<date>-jujutsu-pilot.md` in ai-devops; optional test harness under `tests/verification/repo-throughput/` only if manual runs cannot be reproduced. Use no changes to shared repo files or installed global routing during the first trial. Install a pinned `jj` version by supported user-local package method in an isolated test environment; record binary source/version and digest. Official references: [Git interoperability](https://github.com/jj-vcs/jj/blob/main/docs/git-compatibility.md), [workspaces](https://github.com/jj-vcs/jj/blob/main/docs/working-copy.md), [concurrency limits](https://jj-vcs.github.io/jj/latest/technical/concurrency/).

Use disposable clones of `popcre/ai-devops` and `popcre/shared-db` from known commits. Trial the same three bounded scenarios with Git worktrees and jj workspaces: (a) two agents edit disjoint files while `main` advances; (b) two agents edit the same file and resolve a conflict; (c) an agent is interrupted after uncommitted edits and resumes or rolls back. Add a fourth shared-db scenario that touches a migration **only in the disposable clone** and proves the existing claim/version guard would still be required; do not create or push a live migration. Record task setup, manual interventions, lost work, elapsed time, output branch/tree digest, `.git` tool compatibility, submodule/ignored file behavior and recovery operations. Do not concurrently mutate one colocated jj/Git repository across machines: official docs identify that combination as insufficiently tested. Export a harmless trial branch to a **separate test remote or bare repository**, compare Git tree hashes, then delete only the disposable target after inspecting it. A live GitHub PR is optional only after offline parity and normal repository gates; no `main` push.

**Gate:** all four scenarios preserve edits or yield an explicit recoverable conflict; jj-created changes round-trip as ordinary Git commits with equal file-tree content; repo CI/review tooling can inspect the exported Git branch; rollback to ordinary Git worktrees requires no data conversion for already-exported commits. Any untracked/secret-bearing import is a stop and privacy review, not a pilot success.

### Step 5 — Adopt only if measured, then close the parent

**Files:** final dated comparison beside the Step 0 baseline; this STATUS; parent #903. Compare median and p90 request-to-verified-outcome and evidence-only commits per comparable PR, with count and inclusion rules; report small samples as inconclusive. Require zero lost changes, unauthorized approvals, skipped required checks, or broken GitHub exports. If jj saves meaningful agent handling time without adding unsafe or manual recovery, propose a separate reviewed opt-in rollout (one repo/client first, with immediate Git worktree fallback). If not, mark no-go and keep Git. The trial itself never changes the default.

**Gate:** a reviewer can reproduce both measurements and every safety refusal from linked artifacts; GitHub contains every accepted code commit and `main` matches the verified landed SHA; the parent records either a qualified rollout owner or a no-go and closes when all accepted children are complete. No production deployment is needed for a no-go. A future opt-in installation requires installed-client proof and its own issue/PR.

## 10. Required tests and adversarial cases

Use the exact existing suites discovered in Step 0. Minimum ai-devops regression: `tests/test-ai-review-packet.sh`, reviewer wrapper identity tests and required `tests/test-all.sh` via CI. Minimum shared-db regression: `scripts/lib/pr-content-equivalence.test.mjs`, `scripts/check-exact-head-approval.test.mjs`, `scripts/check-main-tip-freshness.test.mjs`, `scripts/agent-work-contract-git-evidence.test.mjs`, `scripts/refresh-code-pr-branch.test.mjs` when present, plus normal required PR checks and guarded merge. Never treat a green subset as the full required set; record actual check names at the live head.

| External/untrusted input | Hostile case | Required test |
|---|---|---|
| PR changed-file list and `.agent/work/` path | Missing page, traversal, symlink, wrong issue/generation | `wrong_task_receipt_refuses`, existing task-evidence path tests |
| Git `main` ref | Forward move vs rewrite or missing ancestor | `unrelated_forward_main_keeps_reviewable_content`, `rewritten_main_refuses` |
| Reviewed source head/diff | One-line implementation change under same task | `implementation_edit_forces_new_review`, `changed_implementation_invalidates_receipt` |
| Reviewer/producer record | Forged, moved, stale, missing or prior REJECT | `producer_or_policy_change_refuses`, `old_rejection_remains_effective` |
| CI/status API | Incomplete context list, failed/cancelled job, unavailable API | `missing_checks_refuse` plus existing preflight tests |
| jj checkout/export | Ignored or secret file import, conflict, interrupted operation | disposable-clone cases (b), (c), privacy stop and Git tree-digest comparison |

Every proposed test name is an acceptance behavior; fit it into the existing test framework rather than creating a second test runner. The first formal code-review request must include this table and its executed results.

## 11. Constraints and gotchas

Use `AGENTS.md` in each repository and only its task-routed documents. Stage only owned files. Run `git var GIT_COMMITTER_IDENT` before the first commit; expected identity is Albert Hazan's GitHub noreply address. Sign GitHub posts with the current Codex chat ID and machine. Use `bin/ai-gh` for GitHub access from ai-devops. Documentation-only PRs may use the repository's documented fast merge route; instruction/router changes may be classified stronger by `ai-task-gates` and must honor its refusal. Shared-db structure changes, if independently discovered, need their own orchestrator issue; all planned tooling work is **non-orchestrator**. Production and shared cloud remain read-only. Do not weaken exact-object/version claims, two migration reviews, preview/merge/production exclusive writes, or authenticated approval. Do not create a new active plan, status source or scheduler if an existing one owns the work. Jujutsu's operation log and Git colocation are local conveniences; GitHub PRs/checks remain the delivery contract. Guard against a conflict-dirty PR silently missing normal checks by counting required contexts.

## 12. Access and environment

Target repositories: `https://github.com/popcre/ai-devops` and `https://github.com/popcre/shared-db`; target branch `main`. The planning host `edge-dev3` has authenticated Git/GitHub access through the installed `bin/ai-gh`; recheck auth and repository identity in each implementation session. Local normal checkout roots on this host are `/home/ahazan/repos/ai-devops` and `/home/ahazan/repos/shared-db`; use separate fresh worktrees for writes. Node tests run with the repo-pinned runtime; Bash suites use `tests/test-all.sh` or focused scripts. The jj pilot uses only disposable local clones and a separate test remote. No database credential, test login, 1Password item, preview target, production target or external model account is required for Steps 0, 4 or the no-go decision. If a later live database proof becomes necessary, resolve its target and secret **location** from the current shared-db runbook; never copy a value into this plan, command argument or report.

## 13. Definition of done, risks and open questions

Planning deliverable: this file and linked write-once handoff are committed, pushed, linked from the router, merged through the repo's appropriate PR path, and confirmed on `origin/main`. Implementation deliverable: every parent child has an artifact-backed state; safe reductions pass positive/refusal tests and required CI; the exact landed SHA is verified on GitHub; the jj decision is measured and reversible; no accepted code exists solely on a local disk. Update this STATUS and the parent after **each** child. A code change merged without one required live proof creates exactly one proof issue before that session ends.

Primary risks: a false equivalence could accept unreviewed bytes; a missing CI context could look green; detached evidence could lose trusted provenance; jj/Git interleaving could misplace a bookmark; a public report could leak transcript or secret material. Fail closed, retain old validated readers during any evidence transition, keep old Git worktrees and GitHub branches until export is verified, and roll back only the new writer/default after proving all prior records still readable. Unknowns are the size of the remaining gap and jj's actual advantage. Step 0 and Step 4 measurements decide those; an inconclusive pilot means no default change.

## Self-audit — final answers

1. **Fresh session executable? Yes.** §§2–6 define the systems, incidents and exact existing owners; §9 gives files, dependencies and observable gates; §§10–12 give tests, safety rules and access. It starts from STATUS and parent #903 without this chat.
2. **Background and rejected routes complete? Yes.** §§3, 5–8 carry the proven incidents, already-landed repairs, rejected host/tool swaps and locked decisions. Current state is explicitly rechecked because `main` moves.
3. **Goal usable when a step is wrong? Yes.** §1 states Albert's outcome and the stop/flag rule; §§8–9 permit a proven no-change or jj no-go rather than an unsafe implementation.

Checklist: all 13 sections, status, scope exclusions, exact files, adversarial cases, tests, access, handoff backlink, landing and rollback are present. The memory-entry instruction in the skill is intentionally omitted: session memory updates require Albert's explicit request.
