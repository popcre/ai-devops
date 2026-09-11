---
issue: 159
status: OPEN
owner: codex/reviewer-hierarchy-closeout-159
---

# HANDOFF — reviewer hierarchy and implementation continuation (2026-09-11 04:41Z, edge-dev/codex)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

**Blocking later, not blocking the next engineering child:** #166 changes the live GitHub required-check ruleset. Repository policy requires Albert to authorize that exact settings change when #337 and the other prerequisites are complete. Recommendation: do not ask now; present the complete, reviewed ruleset diff once #166 is genuinely ready. This blocks only the final #159 cutover.

**Already settled — do not re-ask:** On 2026-09-11 Albert directed the reviewer backlog to be reorganized around coding root causes rather than adding fixes to old symptom tickets. Preserve all reviewer capabilities, safety checks, private evidence, and the frozen 198-entry maintenance round. The next session must not reopen the hierarchy design unless live evidence proves a concrete ownership collision.

No other owner decision is needed. The next session should begin the highest-priority unblocked child and make ordinary reversible engineering choices itself.

## 1. What this application is

`popcre/ai-devops` is a public recovery and automation toolkit for Albert Hazan's multi-model development workflow. It contains reviewer wrappers, read-only evidence packets and sandboxes, lifecycle tools, CI policy, installers, and maintenance-ledger tooling for nine reviewer providers. It is not an application server or database. GitHub `popcre/ai-devops` is authoritative; source installation into the local supported commands is deployment. Private reviewer reports, prompts, responses, incident records, and source paths stay in the ignored local evidence store.

Parent issue [#159](https://github.com/popcre/ai-devops/issues/159) owns repository throughput. Its reviewer work is the registered programme child [#337](https://github.com/popcre/ai-devops/issues/337). Final required-check cutover [#166](https://github.com/popcre/ai-devops/issues/166) runs only after #337 and all other prerequisites complete.

## 2. What we set out to do this session, and why

Albert rejected the append-only collection of reviewer fixes. The session audited every live #159 child and the open reviewer-related issues, then rebuilt the work into coding-boundary children. The goal was one clear implementation owner for the three newly identified engineering fixes, four uncovered provider failures, all unfinished #337 work, and final reconciliation of the 198 maintenance candidates.

This session changed issue organization and planning only. It did not implement any reviewer repair, alter an installed wrapper, run a paid provider, change shared-db, or mutate production/cloud infrastructure.

## 3. Current state — what is true right now

- The hierarchy and plan refactor merged through PR [#399](https://github.com/popcre/ai-devops/pull/399) as `15b383c22294946e34857fb097c55fa200380dd2`. Canonical `C:/repos/ai-devops` was fast-forwarded to that exact `origin/main` commit.
- #159 now has completed CI/queue children, open reviewer programme #337, and final cutover #166. Live GraphQL verification showed #209 restored under #159 after it was unexpectedly parentless.
- #337 has ten direct children: completed #160 plus open #169, #271, #333, and new #393–#398. The current map is in `plan_reviewer-reliability-and-efficiency.md:11-25` and the parent structure is in `plan_repo-throughput-restructure.md:13-34`.
- #393 owns source identity and complete input. Older #179, #180, #188, and #189 are nested beneath it and closed as superseded tracking, not as fixed. PR #344 is open at `a5baf1dae10dc42ca728aeb0adfde4b4ee250f7a`; it now points to #393, but `windows-reviewer-safety` and `windows-reviewer-fallback` are failing and remain real blockers.
- #394 owns terminal outcomes and diagnostics, including the new DeepSeek Windows encoding, Qwen content-filter classification, Muse start-evidence, and Grok turn-limit failures. #182, #183, #217, and #218 are nested and closed as superseded.
- #395 owns central durable evidence and interruption provenance. Completed #212 is nested beneath it. Its historical scope is 31 missing referenced reports plus two interruptions without retained cause.
- #396 owns availability, cooldown, allocation, locks, and different-task concurrency. #304 is nested and closed as superseded.
- #397 owns provider execution, progress, finalization, restart, and same-session recovery. #172, #177, #233, and #351 are nested and closed as superseded.
- #271 is the canonical Codex Windows containment issue; duplicate #290 is nested and closed. It represents 33 confirmed maintenance records. One further ambiguous record was a legitimate evidence-based BLOCKED review and needs no repair.
- #333 owns truthful usage/cache reporting and measured context efficiency. #169 owns only proven shared wrapper primitives. #398 runs last inside #337 and owns installed nine-provider qualification plus complete reconciliation of the frozen maintenance round.
- Maintenance round `0c62f3dffce145c4b2768855b912b958` was restored by merged PR #391 (`b5a08cb55b0b4f71debcad272c591b3d3a026cc3`). It contains 198 evidence candidates and must be resumed, never reset. The private 67-record map is `C:/repos/ai-devops/.ai/reviewer-issues/maintenance/0c62f3dffce145c4b2768855b912b958-ambiguous-root-causes.json`.
- The planning source and exact boundaries are recorded at `plan_reviewer-reliability-and-efficiency.md:51-75`; ordered implementation gates begin around line 130. The current execution summary is also in `HANDOFF.d/2026-09-08T1957Z-edge-dev-codex-reviewer-reliability-plan.md:49-55`.
- This closeout handoff is the only unmerged file from this session. It is being committed and merged on branch `codex/reviewer-hierarchy-closeout-159` before closeout finishes.

## 4. Everything we tried that did NOT work

1. The first hierarchy mutation script used PowerShell's reserved `$PID` variable and malformed inline GraphQL quoting. It produced no successful parent changes despite misleading local progress text. The corrected script read each GitHub `node_id` through the REST endpoint, used non-reserved variables, checked exit status, and then live-verified the graph. Do not reuse the first pattern.
2. One multi-file patch failed atomically because the expected handoff lines did not exactly match current text. No partial edit landed. The files were patched separately after reading the exact section.
3. The first documentation-only PR merge attempted `--delete-branch`; GitHub refused that flag while merge queue was enabled. Retrying the same authorized squash/admin merge without branch deletion succeeded. This was a command-shape failure, not a failed merge.
4. Live hierarchy verification found closed runner issue #209 had become parentless. The cause was not established during this session. It was explicitly reattached to #159 and verified. Future sessions must re-resolve hierarchy live rather than trusting a plan snapshot.
5. Do not interpret closed symptom tickets as completed repairs. Every transfer comment explicitly says closure means superseded ownership only; the open canonical child still owes the tests and live proof.

## 5. Root causes and key findings

- The old structure mixed business outcomes, shared infrastructure, provider symptoms, and final acceptance at one level. That made multiple issues appear to own the same code and left newly observed problems without tested promises.
- The durable design is one programme (#337) with children aligned to components: packet identity (#393), terminal contract (#394), evidence publication (#395), availability/allocation (#396), provider execution/recovery (#397), Codex containment (#271), usage/efficiency (#333), shared primitives (#169), and integrated closure (#398). See `plan_reviewer-reliability-and-efficiency.md:62-75`.
- The 198 log entries are evidence candidates, not 198 fixes. The 67 ambiguous records were classified as 33 Codex containment failures, one legitimate BLOCKED result, 31 missing reports, and two unknown interruptions. Those facts drove #271 and #395 rather than 67 tickets.
- The four newly uncovered failures share the terminal/diagnostic code boundary even though they come from different providers. #394 therefore promises provider-shaped regression tests instead of four unrelated patches.
- Active PR #344 covers only part of #393. Passing packet/sandbox unit counts do not override its failing reviewer-safety checks, and it must not be merged or treated as complete until those failures are repaired and exact-head acceptance passes.
- #398, not an individual provider child, owns the final accounting equation: every candidate must be classified, linked, resolved, partially resolved, or carried forward with exact evidence, and totals must reconcile to 198. Historical evidence that no longer exists stays unknown rather than being guessed.

## 6. Exact next steps

1. Start in a new current-upstream Worktree for `C:/repos/ai-devops`. Read `AGENTS.md`, `docs/task-router.md`, `plan_repo-throughput-restructure.md`, and `plan_reviewer-reliability-and-efficiency.md`; run `ai-task-gates start` with the class selected from the real change. Verify success when current `origin/main`, live issue hierarchy, installed launchers, active PRs/worktrees, and Windows runner activity are all recorded without modifying them.
2. Inspect PR #344 and its two failing checks before choosing #393. Read the exact failing log sections and current diff; do not rerun unchanged failures. If its branch has an active owner, leave it there and select another unblocked coding child. Verify success when one child has exclusive file/issue ownership and no concurrent branch is duplicated.
3. Implement only that child's full contract from its GitHub body and the plan. Diagnose the root cause before changing behavior; add provider-shaped positive and negative tests, preserving reads, safety controls, exact identity, paid-work uncertainty, and private-data boundaries. Verify success when the original failure is reproduced before the change and prevented afterward without removing the intended capability.
4. Deliver the child completely: focused tests, required suites without overlapping protected Windows CI, exact-head independent review for reviewer safety-path changes, commit/push, PR/merge queue, `origin/main` proof, installation, live supported-path canary, and affected incident dispositions. Verify success when the canonical child body and plan STATUS cite immutable merged, installed, and live evidence.
5. Repeat through all component children. Run #398 only after #169, #271, #333, and #393–#397 satisfy their gates. Resume maintenance round `0c62f3dffce145c4b2768855b912b958`; never reset it. Verify success when all 198 dispositions reconcile, the installed nine-provider matrix passes, and a bounded next interval shows no recurrence of repaired causes.
6. Close #337 only after every registered child is complete. Then prepare #166's exact required-check/ruleset proposal and present the single owner decision from §0. Verify success when a throwaway PR proves every intended context reports, red safety blocks, merge-queue admission works, no stale context remains, and final measurements permit #159 to close.
7. When the next session completes a successor step and proves every obligation here is carried into the plans or its own handoff, delete this handoff under the successor rule. Verify success when the deletion lands with that step and Git history retains this record.

## 7. Constraints and gotchas in force

- Use an isolated current-upstream worktree for every write; canonical `C:/repos/ai-devops` is landing-only. Work through branch, PR, merge queue, and verified `origin/main`.
- Preserve the original reviewer capability. Never disable a reviewer, weaken read-only enforcement, delete checks, inflate timeouts, quarantine tests, fabricate a verdict, or replay uncertain paid work to make a symptom disappear.
- Reviewer-wrapper, packet, sandbox, evidence, or safety-test changes require one independent read-only exact-head final review before merge.
- Never run the local full Windows suite while a GitHub runner is active on that host. Use bounded event-aware waiting and inspect a changed failure before retrying.
- Private evidence stays under ignored `.ai/` storage. Never commit or paste raw reports, provider bodies, transcripts, licensed source paths, credentials, or secrets.
- `u2giants/shared-db` owns governed allocation and verdict-recording consumer code. If #396 needs that repository, re-resolve its current router and create a separate worktree; no database structure or row change is implied.
- Investigation-mode #253–#257, reviewer-assisted diagnosis #198, and DeepSeek credential maintenance #326 are separate workstreams. Do not silently pull them into #337.
- Closed nested symptom issues preserve reproduction history. Do not reopen them as parallel implementation owners; update the canonical child.
- #166 is always last and requires the owner decision in §0 only when its exact live ruleset diff is ready.

## 8. Access and environment

- Host: `edge-dev`, Windows, repository `C:/repos/ai-devops`.
- GitHub CLI is authenticated for `popcre/ai-devops`; PR #399 and the live issue hierarchy were created and verified through it.
- Local Git identity was verified as `Albert Hazan <u2giants@users.noreply.github.com>` before the planning commit.
- Installed reviewer launchers and private incident storage are local machine state; verify their source digest before relying on them. `bin/ai-reviewer-issue path`, `list`, and `maintenance show` discover the ledger without exposing its contents.
- Secrets belong in 1Password vault `vibe_coding`. No secret value is required for hierarchy work and none belongs in this handoff.
- Production and shared cloud infrastructure remain read-only unless Albert names the exact mutation in the current chat.

## 9. Open questions and risks

- Which coding child is first depends on live ownership. PR #344 makes #393 the likely first path, but its active owner/check failures may require choosing another disjoint child. This is a technical scheduling choice, not an owner decision.
- #209 was unexpectedly parentless once during the refactor and was restored. GitHub hierarchy can drift through concurrent edits; always verify it live before declaring plan alignment.
- The 31 missing reports and two unknown interruptions cannot recover historical causes without evidence. #395 must prevent recurrence and record truthful unknown dispositions; it must not manufacture certainty.
- Provider availability and authenticated live canaries can change. A quota/provider outage may block a specific live proof, but it does not authorize removal, bypass, repeated spending, or false completion.
- The final #166 ruleset mutation remains intentionally unauthorized until the exact reviewed proposal is ready; this is fully indexed in §0.

## Final self-audit

1. **Yes — a brand-new developer can continue without chat context.** Sections 1–3 define the toolkit, repositories, issue hierarchy, exact merge and runtime evidence; §6 gives an ordered start and verification gates.
2. **Yes — the handoff preserves the session's effective knowledge.** Sections 3 and 5 record every canonical owner, the 198/67 evidence interpretation, PR #344's precise state, and the distinction between transferred versus fixed issues.
3. **Yes — all execution dimensions are present.** §2 states the goal; §3 the exact state; §4 all failed attempts; §5 root causes; §6 actions and gates; §7 constraints; §8 access; §9 risks; §0 the only owner decision.
4. **Yes — the section-0 sweep passed.** Reading §§1–9 found one owner-only action: the eventual #166 live ruleset change in §§6, 7, and 9. It appears in §0 with timing, consequence, and recommendation. All other choices are technical, already settled, or separately scoped and require no current owner ruling.
