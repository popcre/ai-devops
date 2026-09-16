---
issue: 159
status: OPEN
owner: codex/397-acceptance-record-20260914
---

# Reviewer programme: #397 acceptance and preserved successors

## 0. Decisions only the owner can make

For #394, recommend GLM 5.3's proposal: preserve old Qwen answers privately as
incomplete, but prevent them from approving changes when their original error
evidence is missing. This removes the former ability to finalize those legacy
records as accepted reviews, so Albert's standing capability-preservation rule
requires approval before release. A consequence-based approval question was
asked in this continuation; no answer has been received at this checkpoint.
Do not ask him to judge the technical mechanism. No saved answer is to be
deleted or automatically rerun. This blocks #394 release, not #397 acceptance.

Already settled: consult GLM 5.3 (completed); preserve saved answers and missing
historical evidence honestly; continue #397 after the separate merge-policy
repair (now landed). The #271 platform gap is a technical blocker, not a request
to approve an unspecified operating-system or infrastructure change.

## 1. What this repository is

`popcre/ai-devops` is Albert's public toolkit for recovering and operating a
multi-provider AI development workflow. Its deployment mechanism is local
installation from canonical main; it is not a hosted application or database.
The canonical Windows checkout is `C:/repos/ai-devops` on EDGE-DEV. Governed
review consumers live in the private `u2giants/shared-db` repository.

The preceding full context is
[`2026-09-14T1653Z-edge-dev-codex-reviewer-sequence-blockers.md`](2026-09-14T1653Z-edge-dev-codex-reviewer-sequence-blockers.md),
merged through PR458. Retain it: its #394/#393/#271/#398 obligations and private
evidence locations remain relevant. This file supplies the new landing,
comparison, failure, and acceptance facts; it does not erase predecessor proof.

## 2. Objective and sequence

Continue #159 from fresh current main, reuse preserved work, and resolve #397
first. The order remains **#397 → #394 → #393 → #271 → #398 → #337 → #166 → #159**,
with #396 consumer follow-through reconciled before #398. A child or session
completion never closes the parent programme.

Task `01a09d96-91f5-7471-81f9-4fdda96c3591` was interrupted/notLoaded and then
reported corrupted by Albert. This session did not take it over or duplicate
its work. Its successor landed PR459 at
`7f3b3b8eea6e6bf886cf2f23b87e4a25a54c531c`; the live ruleset requires
`verification-closure`. Albert explicitly released the #397 dependency.

## 3. Current state and exact evidence

### #397 complete Windows scheduling

Preserved head `5859f02f` was rebased cleanly onto PR459 as
`e666899d3ce41a757f9b42eb005c1ad129a6dbe2`. The six-file change partitions every
discovered Bash suite across five independent complete Windows jobs, runs every
PowerShell suite once in manifest owner 3, and retains the 105-minute bound,
ordinary PR assignments, and unsectioned local behavior. Current inventory is
75 Bash and 18 PowerShell suites; selection is dynamic, not hardcoded to 75.

Selection tests passed 48/0 on Windows; workflow-policy passed 52 named checks
plus its mutation checks. Those summaries do not report skipped counts. GLM 5.3
approved the rebased exact head in the existing session
`issue397-complete-windows-20260914`.

PR460's first Linux run `34889342001` failed one of 75 suites: selection reported
46 passed/2 failed, in the oversized-complete and incomplete-PR refusal-message
assertions. A fixture-only correction captures the actual PowerShell exception
message rather than host-rendered error text and prints diagnostics on failure.
Both original assertions still require a nonzero exit, the exact refusal reason,
and no executed Bash or PowerShell suite. Corrected head
`b841a7d78e22c12dcd2658efda6bf4a9f888103a` passed 48/0 on Windows and received
exact-head GLM APPROVE. Linux then passed all 75 suites, including both cases.

[PR460](https://github.com/popcre/ai-devops/pull/460) is MERGED at
`3194b163ae3cb8eb716298724f4c51cc7809820e`, verified on origin/main. Corrected PR
run `34891922168` passed Linux, all five ordinary Windows sections, all 18
PowerShell suites, and the hosted reviewer lane. Reviewer logs report Codex
49/0 (skip count unreported), its helper 7/0/0, and Grok 234/0/0. Merge-group
run `34896562246` passed on the exact landing commit. No queue gate was bypassed.

### Acceptance-launch repair

The first `ai-verify-run start` on the landing SHA failed before dispatch:
GitHub's missing-tag lookup returned error JSON on stdout with exit 1, but an
inner `|| true` preserved that JSON as a supposed SHA. The equality guard
correctly refused; the intended tag-creation path was unreachable.

Fresh-main branch `codex/397-verify-dispatch-20260914` is in
`C:/repos/ai-devops-worktrees/397-complete-windows-shards-20260914` (the same
owned worktree is reused so the existing GLM conversation can continue).
Head `549024aa510a259517242be445b441307209f082` changes only `bin/ai-verify-run`
and `tests/test-ai-verify-run.sh`. A failed initial lookup now discards stdout;
creation, reread, exact SHA, duplicate protection, provenance, and cancellation
guards remain. The realistic JSON fixture failed before the repair, then the
full owning suite passed, including existing/created mismatches, failed
creation, and failed reread. Numeric assertion/skip counts are not emitted.
Bash syntax also passed. GLM 5.3 approved this exact head.

[PR461](https://github.com/popcre/ai-devops/pull/461) merged at22:35:46Z as
`f3d3144080c2129a500fa8f752c7c8f2c7b0c4d9`, confirmed on origin/main.
CI34899250878 and merge-group34903218130 succeeded. Linux ran75 suites with0
failures; hosted reviewer Codex49/0 (skips unreported), Grok234/0/0.
Permanent installation was completed after PR462, as recorded below.

The reviewed corrected controller then live-qualified its normal start path:
it created and verified the immutable tag and dispatched exactly the merged
PR460 SHA at `2026-09-14T21:31:07Z`, with task and purpose. No direct workflow
bypass or cancellation was used. Complete acceptance run
[`34899253151`](https://github.com/popcre/ai-devops/actions/runs/34899253151)
completed all five complete sections with the two failures detailed below;
its hosted reviewer fallback passed and the run is terminal FAILURE.
This failed run was retained as diagnostic evidence. The later repaired run and
installed proof are recorded below; running jobs are never acceptance.

### Complete-run failure and Windows fixture repair

Run34899253151 section2 failed `test_evidence_changed_source_is_not_sealed`:
`AssertionError: Blocked not raised`. Its full 15-suite section completed in
1638 seconds with one failed suite. The production `physical()` function
canonicalizes DOS aliases before snapshotting; the test compared its original
temporary report path without canonicalization and consequently never injected
the late output on a short-path temporary directory. A real Windows DOS-alias
fixture reproduced the same failure locally before the repair and passed after.

Branch `codex/397-windows-evidence-fixture-20260914` in the original #397
worktree starts from current main3194 and commits only the test repair at
`7b1505318f538b1388a654cf82ccbdceb662365d`. It compares resolved paths, retains
the original required rejection, and additionally proves late output retained
and no report receipt sealed. Production code is unchanged. Owning Windows
suite: 152 passed, 0 failed, 4 skipped; the Python component ran97 with4 skipped.
Short-path reproduction: one test passed. GLM5.3's final verdict is APPROVE for
exact head7b150531 against base3194; report suffix
`3889d17fe67038a7087bf1e072bdb278a76f28eb44934aa2b9e48482ae0eda0d`.
[PR462](https://github.com/popcre/ai-devops/pull/462) initially ran fixture-only
CI34902393530, subsequently superseded by the combined repair. Scratch evidence is
`C:/Temp/397-evidence-short-path.py`, `397-evidence-owner.log`, and
`397-evidence-glm.log`. The unchanged failed run was not repeated; the repaired
candidate now has a separate full acceptance run after current-main
reconciliation. The original run retained every other result; none was cancelled.

### Second complete-run failure: preflight timing

The same run's section4 completed its15 Bash suites in3118 seconds with one
failure: `invalid Kimi credential fails under ten seconds`. Authentication
refusal and classification passed, but expensive sandbox creation and packet
build/verification preceded the doctor. All five sections completed75 Bash
suites and18 PowerShell suites within the unchanged105-minute limits; sections
2 and4 each had one failed suite, so this is not acceptance.

A targeted old-code regression reproduced the timing failure and proved review
evidence was prepared before rejecting the unhealthy provider. The production
repair moves the unchanged full doctor before the unchanged complete isolated
packet preparation, retaining every successful-path gate before PASS. Existing
registry, quarantine, scoped admission, qualification, Git HEAD/base checks,
failure classification and cleanup remain. A traced local invalid-credential
check changed from about9.9 seconds to0.8 seconds; the original ten-second
assertion was not changed. New operation observers prove unhealthy refusal
precedes evidence creation, healthy admission retains the real full packet
checks/cleanup, and failed packet verification still refuses a healthy doctor.
Owning Windows suite:95 passed,0 failed; skip count unreported. Bash syntax
passed. Scratch logs: `397-preflight-red.log`, `397-preflight-timing.log`,
`397-preflight-timing-fixed.log`, `397-preflight-owner.log` in `C:/Temp/`.

Both complete-run fixes were consolidated in PR462, initially head
`70bb5902c0418be7447d4df676f3039779d4fd29`, branch
`codex/397-windows-evidence-fixture-20260914` in the original #397 worktree.
The temporary `codex/397-preflight-windows-bound-20260914` branch has no unique
commit or outstanding work. New CI run34904589624 supersedes the earlier
fixture-only PR run because source changed. GLM5.3 approved exact70bb5902
against3194 in report suffix
`0f86c622cf79a4e3ab707198d165bd242e3c5f59e4fd061b37223d4b90627a8e`;
auto-merge was re-enabled after that review. The reviewer noted an optional
cosmetic tool-version bump; source commit and installed byte hashes remain
the exact behavioral identity, so no unrelated version change was added.
No manual acceptance run was cancelled or restarted unchanged.

### Current-main reconciliation and repaired acceptance run

PR461 advanced main while PR462's earlier CI was running. Current main was
merged normally into the preserved branch, without force-pushing: final head
`dfac0198e70f3522f1c489422557079aa1ed06a8`, base
`f3d3144080c2129a500fa8f752c7c8f2c7b0c4d9`. The owned three-file diff is
byte-for-byte identical to the approved70bb5902 diff against3194. Final GLM5.3
APPROVE binds dfac0198/f3d31440; report suffix
`8e2b06a2f4a6e6774cf31ebdcd6bd4fa9067b1891225adc3e1b0fc350adaa341`.
Its minor digest question is resolved by distinguishing the Git tree object ID
from the packet's differently scoped SHA-256 digest; these are not interchangeable.

The normal merged controller dispatched repaired full run34905839047 at
22:47:40Z on exactdfac0198. Ordinary CI34905796159 passed. The Git
tree object ID is `44dad99fcc6ecb0a7b03e79489748d7e00796693`; the landed
tracked source exactly matches this fully tested candidate.
Candidate qualification is not installed delivery. PR462 auto-merge was enabled
only after the refreshed exact-head final review. Earlier PR-head CI was
superseded because its source changed; neither manual run was cancelled.

Run34899253151 is terminal FAILURE, with only the two diagnosed complete-suite
failures. Its hosted fallback passed Codex49/0 (skips unreported), Grok234/0/0,
and the reviewer aggregate passed. Preferred timeout is not review completion.
Current watch logs: `397-repaired-complete-watch.log`, `397-pr462-wait.log`;
current review log: `397-current-main-glm.log`, all in `C:/Temp/`.

The original PR watch spanned superseded heads and reached its85-minute
deadline after a transient read error. Fresh GitHub inspection confirmed the
current head was green and queued, not failed. Its renewed wait correctly
rejected the old `code` declaration because the added preflight repair is
protected `reviewer-safety`. The task was re-declared at that stronger class,
without waiver; required gates are exact-head independent review, installed
routing proof and local tests. Current queue run34909141150 tests
`e298568452879055c88c4178689ed4cb7c5d7353`, whose Git tree exactly matches
candidate44dad99f. A new bounded50-minute queue watch uses
`397-pr462-queue-wait.log`. Keep that distinction from a CI timeout or rerun.

PR462 merged through the successful queue34909141150 as
`e298568452879055c88c4178689ed4cb7c5d7353`, verified on origin/main. Its Git tree
is exactly44dad99f, equal to the full-run candidate. All five complete Windows
sections succeeded: 15 Bash suites each, 75 unique tracked suite names with no
omission or duplicate, and all18 PowerShell suites exactly once in section3.
Bash durations in section order:2059,1665,1894,3040,2117 seconds; all remained
below105 minutes. Section2's formerly failing evidence owner now reports
155 passed,0 failed,1 skipped; section4's preflight reports95 passed,0 failed
(skip count unreported). Machine-readable coverage and per-log SHA256 evidence:
`C:/Temp/397-complete-coverage-proof.json` and
`C:/Temp/397-repaired-complete-section1.log` through `section5.log`.
The whole [run34905839047](https://github.com/popcre/ai-devops/actions/runs/34905839047)
is terminal SUCCESS. Linux completed75 suites with0 failures. Hosted reviewer
completed Codex49/0 (skips unreported), helper7/0/0 and Grok234/0/0. No job
failed, was cancelled, or remains unfinished. The preferred lane reached its
30-minute bound; its outer success is not counted as completion. The successful
hosted fallback supplies that proof. Logs: `397-repaired-complete-linux.log`,
`397-repaired-complete-reviewer.log`, `397-repaired-preferred.log` in `C:/Temp/`.
The issue's event history showed closure at PR460's21:23:22Z landing, before
acceptance. This continuation reopened #397 with the explicit remaining gate;
the later final closure must cite the completed run and published evidence.

### Installed recovery and incidents

The four installed Qwen/GLM/Muse/DeepSeek shims resolve to the canonical toolkit.
Against live-canary commit `3098a89a`, Qwen, Muse, DeepSeek, packet, and sandbox
code remain unchanged; GLM's sole intervening wrapper change is a preservation
warning naming lost-evidence reconciliation. This was revalidated after landing;
no unchanged paid canary was replayed.

Serialized EDGE-DEV installation fast-forwarded clean canonical main from7f3b3b8e
to e2985684. Fresh task inventory found only this task active for ai-devops;
the old task remained notLoaded. Physical-host collision check reported the
edge-dev-win runner idle. The51 persistent canonical processes were existing
`mcp-secret-launch.ps1` launchers, not active reviewer turns; none was stopped.
No configuration, service, credential or package was changed.

The machine-tools doctor passed and all seven installed provider/preflight/
packet/sandbox command shims were checked against the canonical targets.
Eight installed source hashes (also including the canonical verify controller)
equal the reviewed candidate bytes; exact hashes are retained privately in
`C:/Temp/397-installed-source-proof.json`. The installed synthetic invalid-auth
probe passed5/0 with the original under-ten-second bound, refusal before packet
creation, correct classification and isolated quarantine. The actual default
installed command, `ai-review-preflight check deepseek` against a committed
synthetic repository, returned PASS with packet=verified and health=ok. It used
the ordinary full doctor and real isolated packet gates, not a mock or paid
provider replay. Logs: `397-installed-machine-doctor.log`,
`397-installed-refusal.log`, `397-installed-healthy.log` under `C:/Temp/`.

DeepSeek incident `20260911T005524Z-edge-dev-deepseek-294011` remains RESOLVED,
with its original installed Unicode/attachment/exact-session live proof and
append-only repair commits. Qwen `20260910T081507Z-edge-dev-qwen-1166` remains
open under #393's source-identity acceptance. Grok's unproven remote cancellation
and paid-work fence remain intact. Nothing was reclassified in the frozen round.

PR422 remains at `13625aa6ccbfc1baa32eff6f96ea97cf4d5207b3`; PR424 remains at
`6257622b881d626cce0caf8528814da414c9eff9`. They are still open. The prior semantic
audit found no unique unlanded changes; PR447/PR453 remain merged. Close these
obsolete PRs only after #397 acceptance, with the replacement evidence.

### #396 comparison completed; no duplicate implementation

The prepared source and test delta in
`C:/repos/shared-db-worktrees/396-consumer-followthrough-20260914` has **zero
added/removed-line differences** from merged PR2750's source and test delta.
Its admission logic and all acceptance cases are identical. Do not copy or
reimplement it, reopen #2694, or merge the old candidate over current main.

PR2750 is on current shared-db main at
`1c436f46a7ae4b9c0dde15bb9b6b11558c92bade`; guarded merge run `34876172210`
is successful. The issue's delivery record identifies contract generation 9,
two durable exact-head approvals at `0e5bfc4580e990fe5f26065028812ce48138be92`,
and 552 passed/0 failed/0 skipped owning tests plus the 285-site truth audit.
This is delivered tooling, not proof of #398's integrated installed matrix.
The uncommitted preparation is preserved; no cleanup or evidence rewrite occurred.

### Preserved successors

- #394 toolkit: `C:/repos/ai-devops-worktrees/394-terminal-parity-20260914`,
  branch `codex/394-terminal-parity-20260914`, head `0d521f449410ef0af3ac19672c5c80f945b858ef`,
  locally committed and unpushed. Its existing GLM session
  `issue394-terminal-review-20260914` has no remaining reported code defect,
  but final approval/release gates and section 0 remain pending. The advisory
  report ending `7e899205368f8456e352faa3411b464363e99be3791a178a741686df6b046cc1.md`
  recommends KEEP the legacy restriction; it is not final approval.
- #394 consumer: `C:/repos/shared-db-worktrees/394-terminal-consumer-20260914`,
  two uncommitted governed-runner/test files. Deliver before #393 because they
  touch the same owners. Preserve the predecessor's 52/0 and focused 2/0/0 evidence
  with its stated limits; do not copy old contract or approval files.
- #393 consumer: `C:/repos/shared-db-worktrees/393-source-consumer-20260914`,
  two uncommitted governed-runner/test files. Owning 65/0/0 plus POSIX 1/0/0
  evidence is preserved, including real Windows long/8.3 receipt identity proof.
  Shared-db #2707/PR2749 remains the existing terminal/source workstream; PR2749
  is open at `798bef8266d910c434c049c983b96aee112303d8` at this refresh.
- #271 remains open. The predecessor proved that supported native Windows
  containment could not deny the filesystem root while permitting the snapshot;
  no OS, ACL, runtime, network, or sandbox bypass is authorized. Recheck supported
  current behavior at its turn, following `docs/codex-windows-containment-2026-09-11.md`.
- #398 retains round `0c62f3dffce145c4b2768855b912b958`: 198 candidates, 36
  incident-linked, 162 unclassified at the frozen checkpoint. Proposal sidecars
  remain private and non-authoritative. The 22 proposed links, 140 unknowns,
  and 89 additional metadata links are preparation, not dispositions.
- #166 remains last. Retain PR459's actual required-closure evidence and address
  the documented pre-existing Blacksmith `/4` versus five-section mismatch in
  its proper scope. Final timing percentiles, rebuild counts, failure injection,
  recovery, and landed-versus-handoff measures remain required.

The phase-end audit reread both plans through final #166/#159 closure. Drift is
explicit: PR459's dependency is delivered; #397 adds the three merged repairs
and installed complete-coverage evidence; #396's consumer is already delivered
through PR2750. No successor authority or acceptance gate was weakened. The
latest shared-db refresh still shows #2707/PR2749 open at798bef82. The frozen
round's started record remains SHA256
`aad9e0f327a135d8b684f03768b702aa675981f738924b468215ef61aeefa8f0`.
Historical four-section/74-suite language is retained as baseline history;
current complete coverage is75 Bash/18 PowerShell over five hosts. This single
completed measurement does not substitute for #166's required percentiles.

## 4. Failed approaches and why they must not be repeated

- Do not resume or duplicate the corrupted merge-policy task; its successor
  delivered PR459 and the dependency is cleared.
- The first PR460 Linux failure was real test failure, not a timeout or an
  acceptable skip. Setting local `COLUMNS=80`/`TERM=xterm` did not reproduce it;
  do not claim that experiment established the precise rendering difference.
  Inspecting raw exception messages removed the display dependency without
  weakening either assertion; corrected Linux CI proves the repair.
- `gh run view --log-failed` refused while other jobs were running. A completed
  job's `gh api repos/popcre/ai-devops/actions/jobs/JOB/logs --allow-escape-sequences`
  saved its log to a private scratch file; only failure/summary lines were read.
- `ai-verify-run` did not dispatch when its tag lookup returned JSON. The new
  test reproduced that exact failure before the minimal repair. No unchanged
  acceptance retry, manual tag bypass, or direct workflow dispatch was used.
- The first PR wait reached its 60-minute observation limit after PR checks
  had passed and the queue's Linux job had run only about 13 minutes. A further
  bounded 25-minute observation of the same queue run completed; no tests restarted.
- Linux host reconnaissance found no PowerShell on `vps2`; `seafile` SSH host
  verification refused. No host key bypass, package install, or server change
  was made to obtain an alternate test environment.

## 5. Root causes and evidence locations

Verified implementation anchors at final candidate dfac0198:
`bin/ai-verify-run:54` discards failed lookup output;
`bin/ai-review-preflight:387` runs the unchanged doctor and
`:412`/`:416` retain isolated preparation/verification before success;
`tests/test-ai-review-preflight.sh:197` retains the ten-second assertion and
`:208` refuses a healthy doctor after failed packet verification;
`tests/reviewer_maintenance_cases.py:1095`/`:1101` exercise the canonicalized
mutation hook; `tests/test-all.sh:181` and `tests/test-all.ps1:62` own complete
selection and the single PowerShell owner. All paths are repository-relative.

`tests/test-all.sh` owns dynamic complete selection; `tests/test-all.ps1` owns
PowerShell routing and pre-execution validation. `tests/test-windows-bash-selection.sh`
now captures exception messages through a miniature-repository invocation
fixture. `bin/ai-verify-run` initial tag lookup must not turn a failed API body
into successful identity evidence; its post-create read still fails hard.

Private local evidence is under `C:/Temp/`:
`397-rebased-selection.log`, `397-rebased-policy.log`,
`397-pr460-linux.log`, `397-selection-exception-message.log`,
`397-pr460-corrected-linux.log`, `397-pr460-powershell.log`,
`397-pr460-reviewer.log`, `397-verify-tag-red.log`, and
`397-delivery-progress.json`. Watch logs are `397-pr461-wait.log` and
`397-complete-watch.log`. The corrected GLM reports are under the original
#397 worktree's `.ai/reviews/`, ending `c372197b2c53483da0662de3f2ccb0ff0d3a1fcede7c6191c7f43626a38aaa55.md`
and `7a5f723a08ad33e502225e3652e5001049ad7625851c812b556e16d94502fdea.md`.
All provider turns are complete; metadata status `active` is not a live worker.

## 6. Exact continuation and acceptance gates

1. #397 code delivery is complete: PR460/461/462 are merged, queue34909141150
   passed and code landing e2985684 has the exact tested candidate tree44dad99f.
   Reuse that proof; do not restart its completed runs.
2. Complete Windows acceptance is complete: all75 discovered Bash suites once,
   all18 PowerShell suites once, zero failed suites and all five sections inside
   105 minutes. Whole run34905839047 and its hosted reviewer fallback succeeded.
3. Installed acceptance is complete: serialized canonical update, launcher and
   source hashes, normal installed health/packet proof and refusal checks passed.
   Existing recovery canaries remain valid after explicit source comparison.
4. This prose delivery publishes the existing #397 evidence and both owning
   plans. Close #397 and PR422/PR424 as superseded after verifying publication.
   If continuing from a future task, refresh those states; never repeat the
   completed code, installation, paid canaries or full run just to close records.
5. Resolve section 0 before #394 release. Rebase preserved #394 work only after
   fresh main/ownership checks; reuse its existing GLM session for exact-head
   approval, verify owning suites and normal governed live Qwen/Muse/Grok paths,
   deliver its consumer, and reconcile the four incidents partially where needed.
   Do not provoke paid content filters or turn limits. Gate: wrapper and durable
   consumer agree, live paths work, and historical uncertainty remains explicit.
6. Shared-db: reread current AGENTS/contracts/ownership. Publish prospective
   maintenance contracts before implementation reaches the remote branch;
   create fresh contract/completion evidence, obtain assigned durable exact-head
   review and CI, and use the guarded merge workflow. No migration-author claim
   or database write applies to these tooling slices. Gate: guarded landing.
7. Deliver #393 after #394 consumer, using a real governed synthetic rename,
   delete, and change case with packet/receipt/source/head/base bindings. Reconcile
   the stale-base incident and obsolete PR344 only after acceptance.
8. Continue supported #271 qualification, then #398's actual dispositions,
   nine-provider/consumer matrix, bounded recurrence scan and legacy audit.
   Keep external blockers explicit; never substitute preparation for completion.
9. Only then close #337 and finish #166's final measured cutover before #159.
   At EVERY phase end reread all downstream phases through plan-end in both
   `plan_reviewer-reliability-and-efficiency.md` and
   `plan_repo-throughput-restructure.md`; record identifier/interface/authority,
   assumption, and evidence drift before advancing.

## 7. Constraints and gotchas

Preserve paid results, uncertain-work fences, every test and runner capability,
the frozen round, and all three private consumer preparation worktrees. No
timeout increase, force push, broad staging, source reset, secret output,
database write, production/cloud mutation, or OS/security bypass. Keep canonical
landing-only. Worktree-local reviewed qualification is not installed deployment.
Never replay a provider merely because its already-valid code is unchanged.

The repaired complete run includes the merged controller and both exposed
failures' fixes. Its exact candidate Git tree must match the landed source;
do not describe candidate qualification as installed proof or accept the earlier
failed run. The ordinary PR manifest remains smaller than the complete matrix.

## 8. Access and environment

Authenticated `gh` uses `u2giants`. Git Bash is
`C:/Program Files/Git/bin/bash.exe`; invoke it explicitly from PowerShell.
Set `AI_GLM_CALLER=codex` and reuse the named sessions through `ai-glm`, never
direct provider APIs or OpenCode calls. Credentials remain in managed indirection
and 1Password vault `vibe_coding`; none was read or changed here.

The retained private incident/maintenance store is the canonical checkout's
`C:/repos/ai-devops/.ai/reviewer-issues`. From an isolated worktree, set
`AI_REVIEWER_ISSUE_DIR` to that existing store for read-only reconciliation;
the default otherwise points at the worktree's separate, empty store. Never
mistake that empty default for missing incidents or permission to start a new
maintenance round. The fresh read confirms DeepSeek294011 resolved and Qwen1166
still open for #393. Keep the four #394 records distinct:
`20260910T223006Z-edge-dev-qwen-94730`,
`20260910T223025Z-edge-dev-muse-95504`,
`20260910T192734Z-edge-dev-grok-8417`,
`20260911T054028Z-edge-dev-grok-419831`.

This evidence branch is `codex/397-acceptance-record-20260914` in
`C:/repos/ai-devops-worktrees/397-verify-missing-ref-20260914`. That initially
empty owned worktree was repurposed for prose; it contains no competing control
implementation. The combined fixes and GLM session remain in the original #397
worktree on `codex/397-windows-evidence-fixture-20260914`; earlier code branches
retain their commits. The corrupted predecessor is still notLoaded and was not
resumed. The latest app inventory showed only this task active for ai-devops;
recheck that boundary immediately before canonical installation.

## 9. Open risks and continuation ownership

PR462 is merged and installed, and the full acceptance run succeeded. This
prose publication and subsequent issue/obsolete-PR reconciliation finish #397's
delivery record. No automation or background notification service was created.
The section 0 authorization, #271 support boundary, #398 unknown dispositions,
and #166 final measurements remain distinct gates. Shared-db main and contract
generations are dynamic; the old PR is not fresh approval.

No sub-agents were dispatched in this continuation. Earlier agents' preserved
work is listed in the predecessor, and none was resumed or duplicated here.

### Final self-audit

1. Can a developer with no project or session context continue? Yes: sections1–3
   identify the repositories, purpose, exact sequence, landed source, completed
   checks, installed proof and preserved successors; sections6–8 give the next
   gates, constraints, branches, private evidence store and access route.
2. Can they continue as well as this session could? Yes: sections3–5 retain
   exact review/run identities, failed attempts, causal repairs, unchanged paid
   canaries and #396's completed comparison; sections6–9 preserve remaining
   ownership and release boundaries. The predecessor is retained for additional
   unique future evidence rather than retired prematurely.
3. Are background, goals, outcome, state, failures, decisions, constraints,
   risks, next actions and verification evidence included? Yes: sections1–2
   cover purpose,3 and5 cover evidence,4 covers failed approaches,0 covers the
   decision,6 covers executable continuation, and7–9 cover safety/access/risks.
   The audit corrected stale pending-landing text and an obsolete no-owner-
   decision statement; acceptance now cites the actual successful terminal run.
4. Does section0 contain every owner decision? Yes: a line-by-line sweep of
   sections1–9 found only #394's legacy approval-authority choice. It is in
   section0 with the consequence and GLM5.3 recommendation. #271's support gap,
   #398's unknown evidence and #166's measurements are technical gates, not
   choices delegated to Albert. No extra infrastructure or destructive action
   is proposed. No separate part(b) introduces another decision.
