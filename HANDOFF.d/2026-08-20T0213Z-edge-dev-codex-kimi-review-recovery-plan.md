---
issue: 46
status: OPEN
owner: main / edge-dev Codex / Kimi review recovery plan
---

# HANDOFF — Kimi review recovery plan (2026-08-20T0213Z, edge-dev/codex)

Implementation plan: [`../plan_kimi-review-failure-recovery.md`](../plan_kimi-review-failure-recovery.md)

## 0. DECISIONS ONLY THE OWNER CAN MAKE

### BLOCKING

None for offline implementation. Kimi must remain out of reviewer rotation until
the merged installed wrapper passes live qualification.

### RECOVERABLE

If Kimi allowance has not refreshed when live qualification is ready, decide
whether to purchase extra allowance. Recommendation: do not purchase it solely
for testing; wait for the normal billing-cycle refresh unless business urgency
changes. This delays only live qualification and restoring Kimi to rotation.

### NOT PART OF THIS WORK, AND NOBODY IS ON IT

None found.

### Already settled — do not re-ask

- 2026-08-20: keep Kimi quarantined until issue #46 is proven complete.
- Preserve structural read-only review, exact-head binding, exact-session resume,
  private review snapshots, and fail-closed verdict handling.
- Partial output may be recovered as evidence but can never approve a change.
- Do not overwrite the concurrent uncommitted reviewer-wrapper work.

## 1. What this application is

`u2giants/ai-devops` is Albert Hazan's public toolkit for operating AI coding
reviewers and machine setup on Windows and Ubuntu. It contains Bash commands,
PowerShell setup, tests, documentation, and reusable Claude/Codex skills. It has
no web application, database, container, or hosted service.

The affected command is `bin/ai-kimi`, which runs Kimi Code as a structurally
read-only reviewer in a private repository snapshot and records durable job state.

## 2. What we set out to do this session, and why

Albert asked why Kimi had become unusable, asked for the diagnosis to be reviewed
by Gemini, then requested a comprehensive implementation plan and a GLM 5.3
review. The goal is to make every Kimi assignment yield either a complete durable
review or a truthful durable failure, without losing findings or mistaking silence
for approval.

## 3. Current state — what is true right now

- The complete zero-context build specification is
  `plan_kimi-review-failure-recovery.md`; all eight STATUS rows are open.
- Tracking issue #46 exists at
  `https://github.com/u2giants/ai-devops/issues/46`.
- Historical findings truncation and false-success behavior were already fixed by
  commit `f65cc77315e4b119d918ae3a4fb12f463f04c430`.
- Active defects remain in ignored-folder detection, artifact ownership,
  partial-review recovery, typed terminal presentation, and temporary-copy
  persistence.
- Planning-time job-record inspection found nine usage-limit exits and one
  unexplained exit 127 across sequences 214–234, but the original narrative says
  repeated exit 127. The plan now makes a per-sequence re-read a mandatory stop
  gate before implementation. Sequence 202's raw stream contains complete findings.
- Gemini independently agreed Kimi must remain quarantined and confirmed the
  active defects. Its machine-local report is under `.ai/reviews/`; every
  load-bearing conclusion is copied into the plan.
- At plan creation `main` and `origin/main` matched at `ed30a42`, but another
  session had uncommitted changes in every reviewer wrapper and test. The Kimi
  changes introduce `local_dependency_unavailable`. They must not be overwritten.
- No issue-46 implementation code is committed, pushed, installed, or live-tested.

## 4. Everything we tried that did NOT work

1. Reading only `docs/reviewer-issues.md` did not explain Kimi; that file is the
   evidence-recording procedure. The actual details were in local issue packages
   and raw job records.
2. The issue report claimed nine exit-127 deaths. Planning-time inspection found
   nine explicit usage-limit exits and one exit 127, but GLM correctly flagged
   that the durable narrative contradicts this. The plan now requires a redacted
   per-sequence matrix and stops if repeated exit 127 is confirmed.
3. Treating sequence 202 as current findings truncation was wrong. Its raw stream
   contains the complete findings and verdict; the historical tail extractor was
   already fixed by `f65cc77`.
4. Testing `git check-ignore` against `.ai/reviews` reproduced a false negative
   for the repository's `.ai/reviews/` rule. The correct test target is a child
   report path, including negation behavior.
5. The first Gemini call returned empty and created no session. A second contained
   review using only tracked files plus redacted observed facts completed and
   produced the independent report. Do not depend on ignored local evidence being
   visible inside a reviewer snapshot.
6. “Fix quota in the wrapper” is impossible. The wrapper can classify and preserve
   the HTTP 403; account allowance must refresh or be purchased.

## 5. Root causes and key findings

- Provider/account failures, historical wrapper failures, active wrapper defects,
  and one unproven internal failure were conflated.
- `reviews_dir()` tests the directory rather than a child report path, falsely
  preventing repository reports.
- Both the durable worker and foreground result path can write review reports.
  The worker must be the single owner because it survives waiter death.
- Repository-only storage is unsafe when the invoking repository is itself a
  disposable copy. Private wrapper state must hold the canonical artifact.
- Failed partial streams can contain valuable leads, but they must be labeled
  `INCOMPLETE — NO VERDICT` and remain nonzero.
- Sequence 216 proves only that Kimi emitted its version and later exited 127 with
  no stderr. It does not prove the local Kimi binary was missing.
- GLM 5.3 confirmed the engineering design but found six plan gaps: disputed
  failure counts, planning-session ownership ambiguity, generic rather than exact
  ignore probing, missing recovery after worker death, identical sibling-wrapper
  probes, and ambiguous implementation-mode artifact behavior. All six were
  incorporated into the plan before handoff.
- GLM 5.3 re-read the revised files and returned `APPROVE PLAN` with no remaining
  Critical, High, or Medium defect. Its four Low tightenings were also added:
  tracked destinations are unsafe mirrors, missing job records keep the matrix
  unproven, stale line-number dependence was avoided in favor of function names,
  and each sibling wrapper's STEP 0 header must be read before its probe changes.

## 6. Exact next steps

1. Open `plan_kimi-review-failure-recovery.md`, read it fully, and start at Step
   9.1. You'll know this worked when the live dirty state is reconciled without
   losing another session's Kimi/runtime-classification changes.
2. Create the redacted fixtures and durable incident reconciliation before code
   changes. You'll know it worked when each active defect fails against pre-fix
   source and unsupported report claims are corrected with reproducible evidence.
3. Follow Steps 9.2–9.6 in order, updating the plan STATUS in the same commit as
   each proven phase. You'll know it worked when one durable worker-owned artifact
   survives waiter and temporary-copy death and every failure stays nonzero.
4. Take the required fresh-session cut, run Step 9.7's complete offline/hostile
   suites, then perform Step 9.8 only when Kimi allowance is available. You'll
   know it worked when installed live canaries and exact-head independent review
   pass with no unresolved material finding.
5. Close issue #46 and retire this handoff only after the plan's full definition
   of done is met. You'll know it worked when source and installed hashes match,
   evidence is linked from the closed issue, and this file is absent from main.

## 7. Constraints and gotchas in force

- Main-only; preserve concurrent work and stage only owned paths.
- Verify Albert's noreply Git identity before committing.
- Never weaken Kimi's read-only profile or increase its deadline as a repair.
- Never point a reviewer at a raw linked worktree or add a second folder boundary.
- Never accept partial output as approval.
- Never invent Kimi model/token/cache/cost evidence.
- Never inspect, copy, broaden, or commit Kimi OAuth/config state.
- Keep raw private evidence out of this public repository.
- Do not edit root `HANDOFF.md` or another session's handoff.

## 8. Access and environment

- Machine: `edge-dev`, Windows 11, PowerShell 7 and Git Bash.
- Repository: `C:\repos\ai-devops`; remote `u2giants/ai-devops`; branch `main`.
- `gh` is authenticated as `u2giants`.
- Kimi uses existing protected machine-local OAuth. No new secret is required.
- Run credentialed Kimi calls only from the Full Access main task with
  `AI_KIMI_CALLER=codex`.
- There is no hosted deployment. Installation is the canonical machine setup
  followed by source/install hash and live-command verification.

## 9. Open questions and risks

- Kimi allowance refresh timing controls live qualification. Recommendation is
  to wait rather than buy extra usage solely for testing.
- Exit 127's internal cause remains unknown. The repair must capture better safe
  diagnostics without claiming an answer the evidence does not support.
- Concurrent reviewer changes can overlap the plan. The implementing session must
  stop rather than overwrite them.
- Durable reports can contain private review content. They must stay in user-only
  private state or an ignored repository folder and must never be committed.

## Mandatory self-audit

1. **Can a zero-context developer continue without asking a question? Yes.**
   §§1–3 define the toolkit, exact issue, plan, commit history, active defects,
   repository state, and unfinished work; §6 gives ordered actions and gates.
2. **Can they continue as effectively as this session? Yes.** §§4–5 preserve the
   evidence corrections, failed Gemini attempt, quota distinction, duplicated
   artifact ownership, and unproven exit-127 conclusion.
3. **Are failed attempts and their reasons included? Yes.** §4 records every dead
   end and why it failed.
4. **Is every next step concrete and verifiable? Yes.** §6 points to exact plan
   phases and gives observable completion conditions.
5. **Are uncommon paths, identifiers, and environments defined? Yes.** §§1, 3,
   6, and 8 define the repo, issue, commits, state, command, machine, and access.
6. **Was the owner-decision sweep run? Yes.** A line-by-line sweep of §§1–9 found
   only the possible allowance purchase; it appears in §0 with a recommendation.

Final synthesis:

1. Yes, this handoff is comprehensive enough for a brand-new developer to resume.
2. Yes, it carries all relevant planning-session knowledge and background.
3. Yes, background, goal, state, failures, decisions, constraints, risks, exact
   actions, and evidence are present here and in the directly linked plan.
4. Yes, Section 0 exposes every owner decision: only whether to buy allowance if
   immediate live qualification is desired.

Self-audit passed.
