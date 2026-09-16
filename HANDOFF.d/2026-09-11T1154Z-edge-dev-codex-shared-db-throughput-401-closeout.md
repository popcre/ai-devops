---
issue: 401
status: OPEN
owner: codex/401-session-closeout-20260911
---

# HANDOFF — shared-db throughput programme #401 closeout (2026-09-11 11:54Z, edge-dev/codex)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

### Blocking later, but not yet actionable

- After Steps 0–7 are verified, Albert must perform the repository transfer and access/settings action defined by Step 8: transfer public `u2giants/shared-db` to `popcre/shared-db`, retain `u2giants` as admin, give `devopswithkube` write, keep organization default read, and activate the one-PR ALLGREEN native merge queue plus the additive `Merge queue gate`. Recommendation: execute that exact action only when the Step 8 preconditions in the plan are green. It blocks Steps 8–10, but it does not block the current next action, which is finishing Step 2/3 PR #2738.

### Already settled — do not re-ask

- 2026-09-11: this chat authorized execution of the complete plan, including the #2716 automatic-promotion policy through its natural cross-repository owner. A fully qualified train may promote automatically; missing or ambiguous proof must refuse to an engineer. Do not ask Albert to name migration versions.
- 2026-09-11: #2705 and #2709 belonged to their existing sessions; their merged live evidence was consumed without duplicating or taking ownership.
- 2026-09-11: #2715 and #2716 are repository-maintenance/policy work, not structural-orchestrator work. Keep them with their natural owners.
- 2026-09-11: only genuine database structure/schema work enters the live shared-db orchestrator. Sender labels are never trusted as proof; the orchestrator independently reclassifies the actual proposed diff.
- 2026-09-11: do not close ai-devops #401 or retire the paired 04:25Z handoff until all Steps 0–10 and five consecutive measured live structural outcomes pass.

The next session must present the single future Step 8 action above to Albert only when Steps 0–7 are complete. There are no other owner decisions hidden in §§1–9 or the agent blocks.

## 1. What this application is

This is a reliability and throughput programme spanning two public repositories:

- `C:\repos\ai-devops` / `popcre/ai-devops` is POP Creations' recovery toolkit and owns sender-side classification, reviewer tooling, installed operating rules, the plan, and tracking issue #401.
- `C:\repos\shared-db` / `u2giants/shared-db` owns governed shared-database structure changes, migration claims, review evidence, preview/production application, and live verification.

The programme's business outcome is that an application-requested structural database change starts promptly and one governed owner carries it through direct live application proof. It must preserve unique migration versions, object-conflict protection, target proof, forward-only migration, independent exact-head review, serialized writes, dependency closure, and live behavior verification.

The authoritative implementation plan is `C:\repos\ai-devops\plan_shared-db-complete-throughput-repair.md`. Its original durable context is `C:\repos\ai-devops\HANDOFF.d\2026-09-11T0425Z-edge-dev-codex-shared-db-throughput-plan-401.md`. This file is a successor session handoff, not a replacement for either document.

## 2. What we set out to do this session, and why

Albert asked this session to implement ai-devops issue #401 and execute every STATUS step from 0 through 10, using fresh worktrees, independent owners, and direct live verification. The triggering problem is that shared-db work can appear busy or complete at claims, reviews, merges, previews, or migration application while the requesting application is still blocked.

The session re-resolved the live repositories, consumed independently owned prerequisite evidence, implemented and merged the baseline/status groundwork, coordinated Steps 2–3, and kept non-structural maintenance out of the live database orchestrator. The full programme did not reach completion before the explicit session-closeout request.

## 3. Current state — what is true right now

Moving facts below were refreshed at 2026-09-11 11:53–11:58Z.

### Repository and programme truth

- `popcre/ai-devops` `origin/main`: `c44c10278a7db965f25f22e58ed6a27384606963`.
- `u2giants/shared-db` `origin/main`: `d530f85bc54d2b3c1f3ac52fcb9ee8d57c17fe3e`.
- Maximum migration filename visible on shared-db `origin/main`: `20260910123636`.
- ai-devops #401 is OPEN: <https://github.com/popcre/ai-devops/issues/401>.
- The plan STATUS table currently marks only Step 0 complete. That is conservative and correct: Step 1 still lacks #2716; Steps 2–3 have unreviewed WIP; Steps 4–10 are not accepted.
- Live orchestrator marker #2714 remains open and belongs to a different active orchestrator session: <https://github.com/u2giants/shared-db/issues/2714>. This programme session is not that orchestrator and must not close, edit, or inherit its marker.

### Completed and verified

- Step 0 baseline/evidence landed through ai-devops PR #407 at `fed454efe47e9b56768b0835f5364208eb15bd08`; the plan wording correction landed through PR #414 at `189814089242186f417d4604c33be80e584543aa`. Evidence is `tests/verification/shared-db-throughput/2026-09-11-live-baseline.md`.
- #2709 stale-base review packet repair landed in ai-devops PR #402 / main `b6922ea8`; installed shims matched and live stale-base behavior passed. The issue is closed.
- #2705 allocator repair landed in shared-db PR #2717 / main `5af3fafac265067f8ee793de229cd63bee95252b`; 562 tests and live allocation proved unusable Kimi/Qwen are skipped. The issue is closed.
- #2715 docs-only admission repair landed in shared-db PR #2737 / main `1b50c414128c172cd0546f49fec40979dffd4ceb`. Prose canary PR #2751 received required success in run 34583013218 and merged as `d530f85bc54d2b3c1f3ac52fcb9ee8d57c17fe3e`. Mixed executable canary PR #2752 was correctly refused in run 34583160198 and closed unmerged. Branch protection was restored with admin enforcement and all required contexts intact. #2715 is closed.
- #2734's production run 34595295842 succeeded at main `d530f85`; live ledger event `20260911052640` and three indexes were reported valid/ready. This is migration application evidence only, not programme acceptance: the concurrent authenticated application count still took about 7.8 seconds while the page path was about 494 ms. Issue #2501 remains open.

### In progress and preserved

- Steps 2–3: shared-db PR #2738 is OPEN/BLOCKED at pushed head `35581fa43a1ecb9c01f85118263367c0119b06a2`, branch `codex/issue-2727-steps2-3`, clean worktree `C:\repos\shared-db-worktrees\issue-2727-steps2-3`. The last complete green validation, before the current WIP, was 1011/1011 exact workflow, 658/658 focused, 215 transport files, and truth audit 277. The current commit safely saves the second-review repair but has only syntax/diff checks; it needs adversarial tests, full validation, regenerated contract evidence, and a new exact-head review.
- #2716: shared-db PR #2736 is OPEN/DIRTY at `178aea970ce7f26872c1c68caa1f768cf521a671`, clean worktree `C:\repos\shared-db-worktrees\issue-2716-auto-promotion`. ai-devops PR #412 is OPEN/CLEAN at `3070b4a3d56464433a217d1f403bae8a795d5280`, clean worktree `C:\repos\ai-devops-worktrees\issue-2716-auto-promotion`. Previously recorded validation was 157/157 shared-db tests and 26/26 ai-devops routing tests plus global/session/install fixtures. Both PRs are intentionally held until #2738 lands; neither is deployed or active.
- Existing draft shared-db PR #2640 remains OPEN/DIRTY at remote head `28883256aca6169d390cb75fbcac7b7f958547e8`. Prepared local commit `17082bc1dd81a86015480f6cfcccf0ec957c86c5` is in `C:\repos\shared-db-worktrees\continue-2640`, branch `codex/continue-2640`. Its owned source changes are committed, but the worktree is deliberately dirty with six untracked `.ai` evidence/log files. Fresh pre-integration validation was 608/608 Node and 239/239 Python. It must follow #2738 and must continue the existing PR rather than create a duplicate.
- #2728 (Steps 4–5) and #2729 (Steps 6–7) are open intake issues with no accepted implementation from this session. Steps 8–10 are not started.
- #2726 remains blocked by an uncertain Grok review assignment: assignment 2323, work `a0a3851d973304e52f03d2bfb73dd8da`, provider session `01a08f72-c3ff-7182-9fe0-06543dcfb4f0`, request `840ea4fc-0636-411c-a5e2-46b54486e4b0`. It timed out after provider contact with exit 124 and no verdict; remote cancellation is unconfirmed, so the paid lock is correctly retained. The ai-devops #159 natural-owner task was asked to implement a supported terminal-failure transition, but no exact landed repair was supplied before closeout and that task subsequently hit its Codex usage limit.

### Preview, production, and local checkout state

- This programme coordinator applied nothing to preview and nothing to production, and wrote no database rows.
- Protected preview is not claimed clean. The separate live orchestrator owns its current rehearsal state; issue #2501 records the current application-performance follow-up. Re-resolve preview identity and applied migration ledger before any future write.
- The canonical `C:\repos\shared-db` checkout is dirty with unrelated pre-existing files and must remain landing/read-only. Do not clean or stage them.
- This session's unused, clean, read-only shared-db worktree `C:\repos\shared-db\.codex\worktrees\issue-401-orchestrator` remains at `f3eff56d`; it contains no unique changes. It is safe for the successor to retire only through the `cleanup-worktree` procedure after confirming no process holds it.

## 4. Everything we tried that did NOT work

1. The first #2738 delivery evidence omitted `.agent/contract.json` and `.agent/completion.json` from `files_changed`, so the agent-work contract failed. The evidence was regenerated, but later code changes have made generation 7 stale again.
2. Exact-head review of #2738 at `618c92cd` rejected two safety defects: legacy unadmitted issues could still appear in live queue audit, and admission was not bound to the exact database objects requested by `--claim`. The first repair passed its full suites.
3. Exact-head review of the repaired #2738 at `e764ca94` rejected two deeper binding defects: reviewer/shared-stage admission did not prove the PR closed the admitted issue, and completion could be satisfied by an unrelated merged PR/object set. Commit `35581fa4` saves the repair, but adversarial tests and fresh review are still missing.
4. Treating the successful #2734 migration application as the #2501 outcome did not work: the direct authenticated application count remained about 7.8 seconds. Keep application behavior, not migration success, as the acceptance gate.
5. The Grok review for #2726 contacted the provider but timed out without a verdict or authoritative remote cancellation. Manual lock deletion, a fake verdict, or replaying the same paid slot would destroy truth and is forbidden. Existing ai-devops PR #422 explicitly preserves this uncertain fence and therefore was not assumed to solve #2726.
6. A broad live-fact command dumped the full worktree and `db-work` queue and was truncated. The useful moving facts were re-queried narrowly; do not infer anything from the truncated listing.
7. A PowerShell closeout command tried to assign `$host`, which is a read-only automatic variable. It failed before changing state; the retry used `$machineName`.

## 5. Root causes and key findings

- Routing must be established from the actual diff twice: first by the sender and independently by the shared-db orchestrator. Repository location, issue label, handoff text, or sender assertion cannot convert documentation, application code/data, CI, reviewer tooling, workflows, or repository maintenance into database structure work.
- A single authoritative outcome must bind issue, PR, exact DDL object set, review/CI, merge, production decision, application, and direct live verification. Without those bindings, unrelated evidence can falsely complete a request. The active implementation is in PR #2738; inspect its diff and the two sealed review artifacts under its `.ai/reviews/` before changing it.
- Completion at claim, review, merge, preview, or migration apply is the central false-positive. #2501 demonstrates why direct application proof is mandatory.
- Reviewer uncertainty is a state, not a failure that can be erased. After provider contact and timeout, the paid slot remains fenced until a supported terminal transition proves what happened or a separately authorized slot/provider continues without reusing the uncertain work.
- Docs-only routing is now proven by both a successful prose canary and a refused mixed executable canary. Do not weaken the classifier to make future mixed changes pass.
- The plan's five-outcome trial counts only consecutive structural outcomes measured after the new model is installed. Earlier migrations and canaries are supporting evidence, not trial outcomes.

## 6. Exact next steps

1. Resume `C:\repos\shared-db-worktrees\issue-2727-steps2-3` at `35581fa4`. Add adversarial tests for exclusive PR/issue linkage, exact object binding, unrelated completion rejection, and safe reopen of an auto-closed linked issue; update affected IO fixtures and the #2716 resolver expectation. Run the exact workflow, focused, transport, and truth suites; regenerate contract/completion evidence; obtain a new independent exact-head review; pass CI; guarded-merge PR #2738; verify the landed behavior on `origin/main` with read-only live admission/refusal evidence; close #2727 and update plan Steps 2–3 in the same evidence commit. You'll know it worked when the exact merged head is on shared-db main and both structural admission and non-structural refusal are demonstrated live.
2. Rebase shared-db PR #2736 on the post-#2738 main, regenerate its evidence, rerun targeted/full validation, obtain exact-head review, and merge through the governed route. Then rebase ai-devops PR #412 on current main, reconcile installed-rule pointers, rerun its targeted validation and required independent review, merge, install from main, and prove fully-qualified promotion plus every refusal path. Close #2716 and update plan Step 1. You'll know it worked when #2705/#2709/#2715/#2716 are all closed with installed/live behavior proof and ambiguous evidence still refuses.
3. Continue existing draft PR #2640 from `C:\repos\shared-db-worktrees\continue-2640`; do not open a duplicate. Rebase its prepared commit onto the post-#2738 main, reconcile only its evidence files, rerun Node/Python suites, regenerate exact evidence, review, and guarded-merge. You'll know it worked when PR #2640 is merged, its exact behavior is on main, and the six local evidence files are either committed intentionally or safely retired by their owner.
4. Implement #2728 Steps 4–5 in a fresh isolated worktree: durable event snapshots, successor resume, and early automatic delivery preflight/evidence registration. Keep only real structural work routed to the orchestrator. You'll know it worked when a successor resumes from one generated snapshot and missing sidecar/producer/claim/base/dependency evidence refuses before expensive review or CI.
5. Implement #2729 Steps 6–7 after consuming the natural ai-devops reviewer owner's terminal-transition repair: immutable approved-migration trains and bounded truthful reviewer/runner reroute. Do not clear #2726's uncertain Grok lock manually. You'll know it worked when compatible migrations share one governed train, incompatible ones refuse by name, and an unstarted reviewer/runner reroutes within its SLO without cancelling healthy work or replaying paid uncertainty.
6. Re-read the plan STATUS and all Step 8 preconditions. Once Steps 0–7 are genuinely green, send Albert the single consolidated action in §0 and execute/verify the repository transfer, access, native merge queue, and additive gate exactly as the transfer plan specifies. You'll know it worked when the new canonical repository and one-PR queue pass the plan's live verification without weakening ALLGREEN.
7. Execute Step 9: reconcile canonical and installed operating rules without a flag day, preserving valid legacy in-flight work. You'll know it worked when source and installed hashes/routing agree and old valid work remains executable.
8. Execute Step 10 with five consecutive new structural application outcomes. For each, commit request-to-dispatch, implementation, review/CI, merge, production decision/apply, and direct live application timings; separate owner waits/outages. Repair any failed stage rather than lowering a gate. You'll know it worked only when all five end in direct live application proof and meet the plan's targets.
9. Only then update every STATUS row, close ai-devops #401 with exact evidence, and retire both the original 04:25Z handoff and this handoff in the closing commit. You'll know it worked when #401 is closed, both handoffs are absent from main, and their full history remains in Git.

## 7. Constraints and gotchas in force

- Read both repositories' current `AGENTS.md` before resuming and follow the plan completely. Re-resolve `origin/main`, PR heads, required checks, marker, claims, reviewer leases, stage locks, runner state, target identity, and production freeze before every relevant action.
- Use a current-upstream isolated worktree per writer and single-writer ownership. Canonical checkouts are landing-only. Never reset, broad-stage, force-push, or clean another owner's work.
- Do not duplicate #2705/#2709 or steal active owners. #2715/#2716 remain maintenance/policy work through natural owners, never the structural orchestrator.
- Only genuine schema/structure changes may enter the live orchestrator. Application data belongs to the application; curated external Master Data uses its separate governance route.
- Production/shared infrastructure is read-only unless the current chat names the exact action/resource. Prove the target database immediately before every authorized write.
- Independent exact-head review is mandatory where required. A stale review, successful CI, merge, preview, migration application, or deployment is never direct application acceptance.
- Keep the #2726 Grok uncertainty fenced. Do not invent cancellation, delete the lock, fake a verdict, or rerun the same paid assignment.
- Lightweight checks are appropriate only for plans and declarative routing/index/skill pointers. Mixed or executable changes retain their appropriate code path.
- Do not close marker #2714; it belongs to the live orchestrator. Do not dispatch non-structural #401 work into that session.

## 8. Access and environment

- `gh` is authenticated for the repositories used here. Git identity was verified before this closeout work as `Albert Hazan <u2giants@users.noreply.github.com>`.
- Local paths: `C:\repos\ai-devops`, `C:\repos\shared-db`, and isolated worktrees named in §3 and the agent blocks.
- GitHub repositories: <https://github.com/popcre/ai-devops> and <https://github.com/u2giants/shared-db>.
- Tracking: <https://github.com/popcre/ai-devops/issues/401>; active structural children #2727, #2728, #2729; maintenance prerequisite #2716.
- Secrets belong only in 1Password vault `vibe_coding`. This closeout swept the owned diff and named worktree statuses; no new credential, token, connection string, `.env`, or secret was found. No vault write was needed.
- This session performed no preview or production write. A future authorized writer must re-resolve target identity and live migration state; never rely on the SHAs or maximum version in this handoff after the timestamp above.

## 9. Open questions and risks

- PR #2738's current repair is not validated or reviewed; its earlier green counts do not apply to commit `35581fa4`. The principal risk is another evidence-binding bypass. The exact adversarial tests in §6 are mandatory.
- PR #2736 is dirty against current main and intentionally frozen. Rebasing it before #2738 lands would repeat integration and could invalidate its policy evidence.
- PR #2640's local branch is ahead of its remote PR and contains untracked evidence logs. They are preserved intentionally; another session must not clean them as debris.
- The ai-devops reviewer natural-owner task hit a usage limit while broader #159 work was active. No supported #2726 terminal-transition repair was confirmed. Re-resolve current ai-devops PRs/issues rather than assuming #422 or any later merge solved it.
- Protected preview and the live application state can change under marker #2714. All preview/production facts in this file are time-stamped observations, not authority to write.
- Repository SHAs, PR mergeability, checks, queue order, leases, locks, and migration maxima are moving facts and may already be stale when this is read.
- Docs pass: nothing outside this handoff became newly false during closeout. The plan STATUS remains deliberately conservative because unfinished implementation must not be recorded as complete.

## Part B — dispatched agent state, separated by owner

### Agent: `/root/prereq_2715`

- **Asked to do:** implement repo-maintenance issue #2715 independently, prove prose admission and mixed/executable refusal, then continue existing draft PR #2640 without duplicating it.
- **Actually did:** merged PR #2737 (`1b50c414...`), ran/merged prose canary #2751 (`d530f85...`), refused/closed mixed canary #2752, restored protected-branch admin enforcement, closed #2715, and prepared local #2640 commit `17082bc1...` after 608/608 Node and 239/239 Python validation.
- **Found:** branch-protection bootstrap needed a temporary try/finally lift; the successful and refused canaries together are necessary to prove the classifier boundary.
- **PR / branch:** #2640 remains draft; remote `codex/issue-2301-phase-a` at `28883256...`; local `codex/continue-2640` at `17082bc1...`.
- **Worktree:** `C:\repos\shared-db-worktrees\continue-2640` is live/resumable and dirty only with six preserved untracked `.ai` evidence/log files.
- **Deliberately did NOT do, and why:** did not rebase/merge #2640 because #2738 must establish the new admission contract first; did not clean the live worktree or create a duplicate PR.

### Agent: `/root/prereq_2716`

- **Asked to do:** implement #2716 through its natural cross-repository maintenance/policy route, with fully qualified automatic promotion and fail-closed uncertainty.
- **Actually did:** prepared shared-db PR #2736 at `178aea97...` and ai-devops PR #412 at `3070b4a3...`; recorded 157/157 shared tests and 26/26 ai routing tests plus global/session/install fixtures; obtained an independent approval for the ai-devops head.
- **Found:** activation must align global instructions, shared-db rules, workflow, risk gates, dry-run, serial lock, evidence assertions, and engineer escalation atomically; mixed historical preview must refuse.
- **PR / branch:** both use `codex/issue-2716-auto-promotion`; #2736 is OPEN/DIRTY, #412 is OPEN/CLEAN.
- **Worktree:** both named #2716 worktrees in §3 are clean and resumable.
- **Deliberately did NOT do, and why:** did not rebase, merge, deploy, activate, or close #2716 because #2738 is the required predecessor and the two repositories must land in controlled order.

### Agent: `/root/steps_2_3` (Franklin)

- **Asked to do:** implement #2727 / plan Steps 2–3: two-sided structural admission, urgent finish-first scheduling, and an authoritative outcome lifecycle.
- **Actually did:** produced PR #2738; completed earlier green suites; repaired the first sealed review; saved the second-review repair in clean pushed commit `35581fa43a1ecb9c01f85118263367c0119b06a2`.
- **Found:** initial contract evidence omitted required files; first review found legacy dispatch and claim-object binding bypasses; second review found PR/issue linkage and unrelated-completion bypasses. Review artifacts are under the worktree's `.ai/reviews/`.
- **PR / branch:** <https://github.com/u2giants/shared-db/pull/2738>, `codex/issue-2727-steps2-3`, OPEN/BLOCKED at `35581fa4`.
- **Worktree:** `C:\repos\shared-db-worktrees\issue-2727-steps2-3` is clean, live, and resumable.
- **Deliberately did NOT do, and why:** after closeout freeze, did not start functional tests, regenerate evidence, request another review, merge, touch sender-side ai-devops work, integrate #2736, close #2727, or clean the worktree.

## Handoff self-audit

1. **Yes — a brand-new developer can continue without asking a question.** §§1–3 define the repositories, purpose, exact live state, paths, SHAs, PRs, issue ownership, preview/production truth, and programme boundary; §6 gives the ordered continuation.
2. **Yes — the reader can continue as effectively as this session could.** §§4–5 preserve the failed approaches, sealed-review defects, reviewer uncertainty, and the non-obvious routing/application-proof findings; Part B preserves every dispatched owner's state.
3. **Yes — all execution dimensions are present.** §2 states goals; §3 states commit/push/deploy status and evidence; §4 records failures; §5 records causes; §6 gives exact gated actions; §§7–9 cover constraints, access, decisions, uncertainties, and risks.
4. **Yes — section 0 contains every owner action or ruling found by a line-by-line sweep of §§1–9 and Part B.** The only future non-delegable action is the Step 8 transfer/settings operation; it appears in §0 with timing, recommendation, and what it blocks. The #2716 policy and all routing/acceptance choices are listed as already settled. No gap remains.

Secrets sweep: completed, nothing new. Documentation pass: nothing outside this handoff is newly stale. Queue seed: all unfinished structural programme items already have open `db-work` issues (#2716, #2727, #2728, #2729); #401 is the open programme ledger. The separate live orchestrator and its marker #2714 were deliberately left untouched.
