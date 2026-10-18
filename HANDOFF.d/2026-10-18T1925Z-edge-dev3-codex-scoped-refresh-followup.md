---
issue: none
status: OPEN
owner: codex/wrapup-4348
---

No new issue was opened because the owner invoked the wrap-up scope freeze. This handoff records newly discovered follow-up only; the original delivery is tracked on [shared-db #4348](https://github.com/popcre/shared-db/issues/4348), whose closure does not complete the unrelated follow-up below.

# 0. Business decisions only the owner can make

None. No business judgement or human technical approval is needed. Already settled on October 18, 2026: finish the authorized shared-db retirement and owner-no-reviewer bootstrap, never touch [claim #4337](https://github.com/popcre/shared-db/issues/4337), and start no new repair after wrap-up. The next session must follow technical review and task gates without asking Albert to approve them.

# 1. What this application is

[ai-devops](https://github.com/popcre/ai-devops) is the public scripts-and-documentation toolkit used by Albert and AI coding sessions on development machines. It installs reviewer wrappers and client instructions, not a business application or hosted service. [shared-db](https://github.com/popcre/shared-db) governs shared Supabase structure, with separate exact-object claims, exact-head review and guarded merge. This follow-up concerns toolkit documentation and reviewer source-identity handling, not database structure or a production deployment.

# 2. What this session set out to do

Resume [shared-db PR #4394](https://github.com/popcre/shared-db/pull/4394), obtain and publish genuine assigned approval, merge the owner-no-reviewer policy, then reconcile the older retirement checklist on [#4348](https://github.com/popcre/shared-db/issues/4348) with a subagent. The original retirement requires both merged instructions and installed local Claude/Codex proof. The owner later invoked wrap-up, so additional findings are recorded here instead of repaired.

# 3. Current state

Original source work is committed, pushed and merged:

- [shared-db PR #4394](https://github.com/popcre/shared-db/pull/4394) merged as [4abcca6e](https://github.com/popcre/shared-db/commit/4abcca6e1afe78edaf6cdea482743b5247e030c4). Assigned DeepSeek approval was published; [Guarded Merge 39142764649](https://github.com/popcre/shared-db/actions/runs/39142764649) succeeded. The owner-no-reviewer path and policy are on main; 115 approval tests passed.
- [shared-db PR #4436](https://github.com/popcre/shared-db/pull/4436) merged as [2af76a71](https://github.com/popcre/shared-db/commit/2af76a71d3cd1d5847f4bc6b7579712fd6cc3dae). Assigned StepFun exact-head approval and [Guarded Merge 39149210549](https://github.com/popcre/shared-db/actions/runs/39149210549) succeeded. All 25 changed files match approved source; 1,199 scoped tests passed. Historical occurrences were audited, not falsely asserted absent.
- [ai-devops PR #1838](https://github.com/popcre/ai-devops/pull/1838) merged as [a8add035](https://github.com/popcre/ai-devops/commit/a8add03543cfae445091219e855dc94888ada6aa): global shared-db instructions no longer require the retired coordinator role.
- [ai-devops PR #1843](https://github.com/popcre/ai-devops/pull/1843) merged normally as [a8f35ee8](https://github.com/popcre/ai-devops/commit/a8f35ee814b9c2573cf7873c07d0df6155626bbf). The scoped installer safely admits selected global-only skills from reviewed merged source without a full toolkit update. A fresh genuine DeepSeek final-check approved this exact merged SHA, report SHA256 `947571a27d4cea5ef2ed457a6962cc2fb71d4a208f44598427a7cd025ffa1767`; 44 installer cases, 454 gate checks and 105 reviewer dependencies passed.

The live scoped installation succeeded on edge-dev3 at approximately 3:24 PM EDT on October 18, 2026. It selected four exact skill names, six client directories and fourteen tracked copies, with recoverable backups and an authenticated scoped receipt. The primary installed checkout, launcher and full-install manifest did not advance. Final independent evidence and original issue closure are recorded in [the #4348 closing comments](https://github.com/popcre/shared-db/issues/4348). Re-read that record rather than inferring fleet installation: only this host was refreshed.

New findings below have NOT been repaired, committed or deployed. This document is the continuation artifact, not permission to claim those findings fixed.

# 4. Attempts that did not work

1. The old generic deploy gate correctly refused a narrow skill refresh from a reviewed candidate because it requires the installed primary checkout and full receipt. Neither bypassing that gate nor updating the whole toolkit was acceptable. PR #1843 added a separate bounded, reviewed route.
2. Initial route review found a nested first-sync writer-lock deadlock and an existing full-install cache symlink regression. Those were fixed before merge through validated inherited-lock custody and preserved full-install cache support. Do not reintroduce a global lock bypass.
3. Fixture review reproduced audit-log symlink traversal, hardlink and backup-plan substitution hazards. The merged helper rejects noncanonical paths and binds the prepared plan digest, original inventory and backup proof before issuing a receipt.
4. Early tests accidentally inherited real HOME for an audit log and empty lock. No actual skills, primary checkout, launcher or full-install manifest changed. The test HOME isolation was fixed. Existing audit evidence was retained rather than silently erased.
5. Generic reviewer source identity once became stale only because origin/main moved; HEAD, digest and merge base were unchanged and ancestry held. The completed report was not reused. Fresh reviews pinned an explicit immutable base. The generic-core comparison issue itself remains unrepaired; do not fabricate a report or relax HEAD/digest/base equality.
6. The first public installer CI failed because the Windows dependency walker interpreted classification metadata as runtime imports and treated a conditional Linux-only helper as unconditional. The scoped semantic walker correction retained real policy/runtime dependency assertions. Final CI passed; no guard or required check was disabled.
7. PR #1843 used squash, so the reviewed branch SHA was not an ancestor of merged main. The old approval was correctly inadmissible for install. A fresh merged-SHA review and bound tests passed before any live write.
8. A shared-db source worktree disappeared during review due to an UNKNOWN external actor. The stale review was refused, source recovered and locked, and genuine tests/review rerun before guarded merge. See [the custody incident](https://github.com/popcre/shared-db/issues/4348#issuecomment-6252796854). Do not attribute or delete unrelated worktrees without evidence.

# 5. Root causes and remaining findings

## A. Stale scoped-refresh instruction (actionable documentation)

[The reviewer-issues instruction](https://github.com/popcre/ai-devops/blob/a8f35ee814b9c2573cf7873c07d0df6155626bbf/docs/reviewer-issues.md#L24-L29) says to run the same scoped selection without dry-run. Since PR #1843, the real write also requires an exact-source reviewer-approval report and the qualified Linux route. The linked [deployment procedure](https://github.com/popcre/ai-devops/blob/a8f35ee814b9c2573cf7873c07d0df6155626bbf/docs/deployment.md#install) is correct. The stale direct instruction fails closed; it cannot bypass the gate. DeepSeek rated this medium, with no critical/high finding, and approved the exact merged source. Update the sibling prose to defer to the full procedure rather than duplicating an incomplete command. Do not change the installer to make an unsafe short command succeed.

## B. Generic reviewer target-ref drift (separate technical repair candidate)

The report-custody issue in section 4.5 needs a narrow diagnosis of [the generic whole-identity comparison](https://github.com/popcre/ai-devops/blob/a8f35ee814b9c2573cf7873c07d0df6155626bbf/tools/lib/review-lifecycle-core.sh#L752-L757) and existing tests before any patch. The pool already tolerates target ancestry in one path; the generic core compared the entire identity including the mutable target-ref tip. Preserve exact HEAD, digest, merge base, repository and source receipt checks. Only a provably unrelated forward target advance may be considered. Reproduce with a fixture before dispatch; do not spend a live reviewer run merely to reproduce it.

## C. Recorded nonblocking observations

DeepSeek noted valid but cramped JSON rule formatting in [the task policy](https://github.com/popcre/ai-devops/blob/a8f35ee814b9c2573cf7873c07d0df6155626bbf/config/task-gates.json#L487), and that mode-only drift is conservatively logged as local edits with a backup in [the installer](https://github.com/popcre/ai-devops/blob/a8f35ee814b9c2573cf7873c07d0df6155626bbf/bin/ai-install-skills#L443-L447). Neither blocks the verified installation; no cosmetic fix is required for original issue closure. The independent baseline also found two preexisting external plan links outside the selected skill directories. Those were preserved, not newly broken or repaired; use the original audit evidence referenced in #4348 if undertaking a separate link cleanup.

# 6. Exact next steps and verification gates

1. Start from current upstream in a dedicated worktree and read current repository rules plus [the deployment install procedure](https://github.com/popcre/ai-devops/blob/main/docs/deployment.md#install). Confirm [#4348](https://github.com/popcre/shared-db/issues/4348) original closure proof; do not reopen or adopt its claim. Success: no misunderstanding that local installation equals fleet installation, and no operation on #4337.
2. Fix only the stale reviewer-issues prose in a new documentation task. Refer to the authoritative procedure, including approval, platform and clean merged-source requirements. Success: every direct instruction in that paragraph is executable under the documented gate and cannot imply full installed-checkout pull.
3. Validate the prose using the repository's exact-head documentation safety check, then publish and merge normally under current prose-only policy. Success: approved final prose is on main; source code and installed bytes remain unchanged. No discretionary paid review is needed for ordinary prose.
4. If continuing the separate generic identity issue, first locate the whole-object comparison and add a regression reproducer for forward target-ref advancement with unchanged source identity. Retain negative tests for changed HEAD/digest/base, nonancestor targets and foreign custody. Success: the test fails for the precise old behavior and passes only under the intended narrow ancestry rule. This is reviewer-safety scope and requires assigned exact-head review before merge or installation.
5. Close this handoff only when actionable findings have been resolved or explicitly consolidated into a durable owned tracker. Verify every remaining obligation before retiring it. Success: no pending instruction repair or unexplained source-identity failure is discarded as a mere housekeeping candidate. Cosmetic observations may remain documented without generating busywork.

# 7. Constraints and gotchas

Claim #4337 is untouchable. No database or reaper apply action was performed or authorized by this handoff. Do not change shared-db structure to repair toolkit prose. No human technical approval is requested. Use machine-wide paced GitHub calls and bounded event-aware waits. No direct push to protected main. No full toolkit update, primary-checkout pull or install-receipt rewrite to refresh one skill. Preserve exact reviewed source, lifecycle report and bound tests. Scoped receipts are separate from full installation receipts. Serialize existing older writers too: a new lock cannot retroactively coordinate old binaries. Unique ignored review evidence and recovery worktrees are intentionally retained; do not delete another session's data or handoff. All human-facing times use America/New_York with EDT/EST named.

# 8. Access and environment

This session used authenticated GitHub access through the paced repository wrapper on edge-dev3. The primary installed toolkit was at commit 92ad5416 immediately before and after the scoped operation and retained the same full-install receipt across that operation. An earlier independent baseline had a4d0c665; another full installation advanced it before this operation, as described in section 9. The scoped release is [a8f35ee8](https://github.com/popcre/ai-devops/commit/a8f35ee814b9c2573cf7873c07d0df6155626bbf). The successor must recheck access and current policy; no old assigned review authorizes new code. Credentials belong only in 1Password vault `vibe_coding`; no credential appeared or was stored during this work. Private review, installation, backup and comparison artifacts are retained on the original host and identified by hashes in the #4348 closeout record; reconstruct fresh public-source evidence on another host rather than inventing access to private files.

# 9. Open questions and risks

As of October 18, 2026, no business decisions are pending. The generic reviewer race remains a separate unimplemented repair, with exact source identities preserved by the failed attempt; its scope must be reproduced before editing. Local skill proof is host-specific; Windows and other development machines are UNKNOWN for these changes. The independent early baseline was stale by the actual scoped operation: another installation advanced the clean primary from a4d0c665 to 92ad5416 and changed the full receipt plus seven launcher fingerprints before the scoped write. The orchestrator backup bytes already matched current source, with mtimes approximately 3:04 PM EDT; the scoped operation at approximately 3:24 PM EDT corrected modes and verified bytes. Do not claim 437 fingerprints unchanged across the entire session: use the locked immediate before/after evidence to bound this operation. The two old external plan links are preexisting and outside original delivery. The predecessor MiMo handoff remains untouched as recovery evidence; issue closure alone is not deletion authority. Report-only housekeeping found many foreign/unknown candidates, which were not cleaned or treated as failures. Source worktree disappearance attribution remains UNKNOWN and was not investigated under wrap-up freeze.

# Part B. Subagent handoffs

## reconcile_4348

Asked to reconcile the older checklist on shared-db #4348, without touching #4337. Delivered PR #4436, 1,199 tests, assigned StepFun approval, guarded merge and exact 25-file merged equality. It audited residual role references and removed operative reaper marker dependence while strengthening active/unreadable-claim protection. Its clean locked recovery worktree is retained for unique evidence. It performed no database/reaper apply or claim #4337 mutation. Its source work is finished; installation was delegated separately.

## global_skill_4348

Asked to remove the retired live coordinator route from global skills. Delivered PR #1838 with genuine test-bound DeepSeek approval and merged-source equality. Captured the independent baseline for fourteen tracked files, six directories/markers, 437 unrelated fingerprints, the primary checkout and existing external-link findings. Prepared an independent read-only comparator for installed files, committed modes, backup custody, receipt binding and operative instructions. Final comparison and evidence are in #4348. It did not install or alter the original claim. Its clean source/evidence worktree remains intentionally retained.

## scoped_install_route

Asked to restore a supported narrow installation route after the old gate refused it, without a full update or bypass. Delivered PR #1843, fixture security repairs, passing public CI, normal queue merge, fresh merged-head DeepSeek approval and supported live scoped installation at approximately 3:24 PM EDT. Source44/gate454/reviewer105 checks passed. Root inspected source, reports and gate before merge/install decisions. It retained backups, reports and locked clean source/release worktrees. It did not advance primary/full receipts, apply database changes or touch #4337. Independent final comparison is owned by the other subagent and recorded on #4348.

# Self-audit

1. YES: newcomer continuity is covered by sections 1-3 (purpose and exact delivery), 4-5 (failures/root causes) and 6 (ordered next steps and proof).
2. YES: sections 4, 7-9 and Part B preserve source custody, failed paths, precise boundaries, access and agent roles; no replay of stale review or claim authority is needed.
3. YES: every file/commit reference is a portable GitHub URL; merged/installed/deferred states are distinguished; section 6 gates each continuation action; no secrets or machine-local file paths are embedded.
4. YES: an end-to-end owner-judgement sweep of sections 1-9 and Part B found no business decision. Section 0 states none and preserves settled owner rulings; all technical gates stay with AI reviewers and the executing session.

Posted by Codex chat 01a14fae-745e-7a01-87ef-4af6528b4d3d on edge-dev3
