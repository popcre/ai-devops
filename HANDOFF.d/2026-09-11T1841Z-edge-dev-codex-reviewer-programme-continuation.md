---
issue: 159
status: OPEN
owner: codex/159-fresh-session-20260911
---

# Reviewer programme continuation after #333 and #395

## 0. Decisions only the owner can make

None — nothing in this workstream currently needs Albert. The remaining work is
already authorized by #159 and #337. Do not ask him to merge, approve, contact
the shared-database orchestrator, change database structure, reorder #398, or
run #166 early.

Already settled — do not re-ask:

- 2026-09-11: run independent reviews in parallel without the reviewer queue.
- 2026-09-11: skip preview except for the most risky change.
- 2026-09-11: preserve maintenance round
  `0c62f3dffce145c4b2768855b912b958`; #398 runs last inside #337, then #166
  runs last for #159.
- 2026-09-11: do not contact the shared-database orchestrator or change database
  structure in this workstream.

If a later phase discovers a genuinely new owner-only choice, present the whole
current list to Albert in one short message before the first blocked action.

## 1. What this application is

`popcre/ai-devops` is POP Creations' public recovery toolkit for installing and
operating several AI reviewers consistently across Windows and Linux. It is not
an application service or database. GitHub is the source of truth; installation
from the canonical `C:/repos/ai-devops` checkout is its deployment mechanism.

The active reviewer programme is #337 under repository-throughput parent #159.
Its goal is trustworthy exact-source reviews, truthful terminal outcomes and
usage, durable evidence, bounded provider/runner waits, and installed live proof.
The separate shared-database throughput plan was read for boundary consistency;
its Step 0 is complete and Steps 1–10 remain separately owned. This handoff does
not authorize or advance that plan.

## 2. What we set out to do this session, and why

Continue #159 from the 11:52 UTC handoff by diagnosing #417's failed landing
evidence, repairing #395's five CI regressions, completing exact-head review,
CI, merge, installation and live verification, and preserving the maintenance
round and final ordering. Albert also asked that reviews bypass the queue and
run in parallel, with preview only for the riskiest action.

The phase also finished #333 because its merged accounting work shared the same
installation and final acceptance boundary. The purpose was to close real child
outcomes, not merely prepare branches or make checks quiet.

## 3. Current state — what is true right now

- #333 is CLOSED. PR #420 merged as
  `d2e4327d9ef5d2b80219a874e4a4a605b2a19595`. Exact head
  `19b261bb9f87282010722c39d1606ea22cac6981` received independent Muse
  `APPROVE`; CI run `34612122556` passed Linux, all Windows sections and the
  designed fallback. Installed accounting proof is recorded in
  `tests/verification/reviewer-reliability/issue-333-truthful-usage.md`.
- #395 is CLOSED. PR #421 merged as
  `972d03b601dd18815627e1d268f3a7375516820b`. Exact integrated head
  `aa3285e2c7dab53c6d03e8686e7aa9c40154b037` received independent Muse
  `APPROVE`; CI run `34627124091` passed product suites and fallback. The
  installed private probe deleted the source evidence and recovered the exact
  report and binary patch without a provider request. Public evidence is in
  `tests/verification/reviewer-reliability/issue-395-durable-evidence.md`.
- All 33 formerly ambiguous records in maintenance round
  `0c62f3dffce145c4b2768855b912b958` remain incidents. Each now references the
  #395 merge, CI, exact review and installed proof. Their historical causes
  remain explicitly unknown. The round is still active; #398 alone closes it.
- PR #436, the documentation-only acceptance record, merged as
  `85a5b4ccca4d4d68a9e21d02a2c2047822554d1c`. At handoff drafting,
  `origin/main` and canonical `C:/repos/ai-devops` both point there.
- Installed launchers for GLM, Grok, Muse, DeepSeek, reviewer-issue and
  review-packet point to canonical current-main source. The #395 installed probe
  retained `source_removed=true`, exact report and binary recovery true, and
  `provider_submissions=0` in private temporary evidence.
- #337 and #159 remain OPEN. Component issues #393, #394, #396, #397 and #271
  remain OPEN. #398 remains OPEN and last inside #337. #166 remains OPEN and
  last for #159.
- Current relevant open PRs: #416 for #396; #418 and #419 for #394 stacked on
  #422; #422 and #424 for #397; and #428 for separate GLM project-stall issue
  #430. PRs #418/#419/#422/#424 still show failures from their pre-#395 heads;
  update them from current main before interpreting those failures. PR #416 has
  no product failure, only the bounded primary reviewer cancellation. PR #428
  still has active checks and does not by itself close #430.
- Runners at the final refresh: `EDGE-ALIEN` and `edge-dev-win` online/idle;
  `EDGE-RUNN-ENVY` online/busy with unrelated work. There were 91 registered
  worktrees; preserve them unless a separately authorized cleanup proves each
  target is finished and unique work is retained.
- The closeout secrets sweep found no credential-shaped additions and no `.env`
  changes. The documentation pass found no stale operating instruction outside
  this handoff and the two programme plans updated by PR #438.
- Two other sessions' handoffs are stale because their named issues are closed:
  `2026-09-01T1709Z-edge-dev-codex-issue-161-fast-ci.md` owned by
  `codex/issue-161-fast-ci`, and
  `2026-09-10T1402Z-edge-dev-codex-issue-167-finalization-proof.md` owned by
  `codex/issue-167-shared-harness`. They were deliberately not deleted during
  closeout; the successor must apply the three-part retention proof first.

## 4. Everything tried that did not work

- #417 landing run `34585150426`, job `103217520332`, failed because it checked
  required PR run `34581933978` while that run was still queued. This was a
  fail-closed evidence timing race, not a product failure. Do not rerun it as a
  product repair without a changed diagnostic purpose.
- #395 originally exposed five real regression groups: GLM partial evidence,
  Grok doctor evidence, Kimi/Qwen stale-head archives, and the retired recorder.
  Merely rerunning inherited branches would reproduce them; PR #421 repaired the
  shared contracts instead.
- Two parallel Grok exact-review attempts reached their bounded 20-turn end
  without a verdict. Their sessions were preserved. Muse completed the required
  exact-head approval; do not call the Grok cancellations approvals or retry an
  unchanged review merely to obtain a second verdict.
- The first installed recovery probe hit Windows read-only Git-file deletion.
  A private probe retry added a permission-clear step and then passed. The
  product repair was not weakened.
- A redundant parallel post-install wrapper run contended on shared test locks
  and was stopped by exact owned process tree. It was not used as acceptance;
  exact CI and the isolated installed probe are the authoritative gates.
- `gh pr merge --delete-branch` is rejected while merge queue is enabled. Merge
  documentation-only PRs with `--squash --admin`, verify the merged state, then
  delete the remote branch separately if appropriate.

## 5. Root causes and key findings

- #417's landing evidence consumer can observe a required producer run before
  that producer completes. The safe behavior is failure; diagnosis must separate
  this timing state from a failing product check.
- Reviewer evidence must be durably published before cleanup or interruption.
  `ai-review-packet verify-retained` now verifies the seal, schema, manifest,
  ordinary and binary patches, and multipart recovery; ordinary verification
  remains strict.
- The 31 missing reports and two unknown interruptions cannot be reconstructed.
  Correct closure records that limitation and proves future retention rather
  than inventing history.
- A primary safety lane ending at its designed 30-minute bound is not sufficient
  alone; the fallback and all product suites must pass on the exact head.
- The shared-database throughput plan already contains its downstream re-read
  rule. The reviewer plan did not state the reciprocal rule strongly enough;
  this handoff's documentation PR adds it under section 11.

## 6. Exact next steps

1. Start in a fresh current-upstream worktree. Read `AGENTS.md`,
   `docs/task-router.md`, both root programme plans, and this handoff; refresh
   GitHub, runners, installed hashes and worktrees. Do not inherit a branch from
   another child. Gate: the new session can name current main, every open child,
   its exact PR head/base, runner state and installed source before editing.
   Verify the two stale handoffs named in section 3 satisfy the successor rule;
   retire them only when their landed work, transferred obligations and unique
   decisions are all proven.
2. Finish #396 from its own worktree. Rebase or merge current main into PR #416,
   inspect its exact delta and current issue acceptance, run focused tests,
   parallel independent exact-head review, CI, merge, install and live
   cooldown/concurrency proof. Reconcile only its affected private incidents.
   Gate: #396 closes with merged current-main evidence, not merely the existing
   Kimi slice or a doctor result.
3. Finish #394 and #397 by dependency, preserving the existing stacked work:
   update base PR #422 first, then #418/#419/#424 against the resulting current
   base. Treat inherited five-suite failures as stale until refreshed; repair
   only failures that reproduce on the updated exact head. Evaluate #428/#430
   separately and do not claim project-isolation closure from idle-retirement
   alone. Gate: each issue has terminal/recovery matrices, exact reviews, green
   CI, merge, installed behavior and truthful incident reconciliation.
4. Reconcile #393's remaining governed live comparison and affected incidents;
   do not equate its already installed nine-wrapper source contract with full
   closure. Complete #271 only if the original Codex read-only capability and
   its safety boundaries are directly proven. Gate: each open issue closes only
   against its own documented acceptance, with capability preserved.
5. Run #398 only after every component child above is closed. Use frozen round
   `0c62f3dffce145c4b2768855b912b958`; preserve all 198 dispositions and the 33
   incident records, run the installed nine-provider matrix and bounded
   recurrence scan, update programme evidence, then close #337. Gate: the round
   closes exactly once with no unknown silently converted to non-defect.
6. Continue remaining #159 work, then run #166 last. Do not close #159 when only
   #337 finishes. Gate: required-check cutover and throughput proof land after
   every predecessor, and current main plus installed state prove the outcome.
7. At the end of every phase above, re-read every downstream phase through the
   end of both applicable plans and report any changed assumption, interface,
   identifier, decision or evidence requirement before handing off or starting
   the next phase. Gate: the phase closeout explicitly says either “no downstream
   drift” or names the plan update that resolves it.

## 7. Constraints and gotchas in force

- Keep canonical checkouts landing/install only; all edits use a fresh
  current-upstream worktree. Preserve every existing worktree and concurrent
  change unless separately proven safe to retire.
- Work on a branch and PR; never push to main. Verify committer identity before
  every first commit. Stage only owned files.
- Reviewer safety changes need one read-only exact-head final review. Albert
  authorized parallel direct reviews and skipping the queue. Preview only the
  riskiest action.
- Do not run a full local Windows suite while a GitHub runner is active. Use
  bounded event-aware CI waits and do useful independent work while waiting.
- Do not contact the shared-database orchestrator, alter database structure, or
  mutate production/shared cloud infrastructure.
- Preserve capabilities and every safety check. Do not bypass, disable, remove
  or replace a failing reviewer to make a gate green.
- This repository is public. Never commit raw transcripts, provider exports,
  credentials, private incident packages or private temporary proof.
- Do not reorder closure: #398 last inside #337; #166 last for #159.

## 8. Access and environment

- Repository: `C:/repos/ai-devops`; remote `https://github.com/popcre/ai-devops`.
  GitHub CLI is authenticated as the repository owner. Git Bash is
  `C:/Program Files/Git/bin/bash.exe`.
- Installation state and private reviewer incidents are under Albert's managed
  local ai-devops directories. Do not move private evidence into this public
  repository. The #395 private installed proof was under the Windows temporary
  directory and is also referenced by the 33 private resolution records.
- Secrets, if a later live provider gate needs them, remain in 1Password vault
  `vibe_coding` and managed configuration. Load `secrets-to-1password`, serialize
  access, and never expose a value in chat, command arguments, logs or commits.
- No database credentials or shared-database access are needed for the next
  reviewer steps.

## 9. Open questions and risks

- 2026-09-11: PR #416 and the #394/#397 stack may drift again before pickup.
  Refresh exact heads, bases, reviews and checks; do not use this snapshot as
  live merge authority.
- 2026-09-11: #430 says PR #428 limits session growth but does not solve both
  shared-project causes. Treat it as a separate incomplete incident unless live
  evidence and the issue contract prove otherwise.
- 2026-09-11: #393 and #394 remain open despite completed slices. Read their
  current issue bodies and evidence before deciding what remains; never close a
  parent from one landed slice.
- 2026-09-11: the 33 historical causes remain unknowable. Future recurrence
  should now retain exact evidence; absence of recurrence is not retroactive
  proof about old events.
- No current item needs Albert's decision. If scope expands to a database,
  production mutation, capability reduction, or closure-order change, stop and
  raise the complete owner-decision list together.

## Parallel reviewer accounting

### Agent: Hubble / `review_glm_failures`

- **Asked to do:** independently review #395's exact integrated head while the
  other provider reviews ran in parallel.
- **Actually did:** completed a read-only Muse review of
  `aa3285e2c7dab53c6d03e8686e7aa9c40154b037` and returned `APPROVE`. The private
  retained report hashes to
  `d446784ac70a198916eb2cfd97a825b647338d30e6d1828151e12f404d17babe`.
- **Found:** the approved #395 behavior remained intact after the upstream merge;
  no actionable merge defect.
- **PR / branch:** reviewed PR #421; created no branch or commit.
- **Worktree:** no separately owned worktree; read-only work finished.
- **Deliberately did NOT do, and why:** made no edits or database contact because
  this was an independent final review.

### Agent: Halley / `review_grok_doctor`

- **Asked to do:** run an independent Grok exact-head review in parallel.
- **Actually did:** preserved the session after the governed 20-turn limit ended
  without a verdict; no report was created and no approval was claimed.
- **Found:** no usable terminal verdict or findings.
- **PR / branch:** inspected #395 evidence; created no branch or commit.
- **Worktree:** no separately owned worktree; provider attempt finished.
- **Deliberately did NOT do, and why:** did not retry an unchanged provider
  attempt or fabricate a verdict; Muse supplied the required independent gate.

### Agent: Boyle / `review_kimi_archive`

- **Asked to do:** inspect the Kimi stale-archive race failure independently.
- **Actually did:** performed read-only analysis and created no changes.
- **Found:** the fixture orders provider completion, abort recording and owner
  release; current code permits an abort-requested job to complete. The code was
  unchanged from prior 244/244 passing evidence, so no real race defect was
  established.
- **PR / branch:** inspected the #395 repair context; created no branch or commit.
- **Worktree:** no separately owned worktree; analysis finished.
- **Deliberately did NOT do, and why:** did not weaken or rewrite the test; if the
  symptom recurs, the next run must retain final metadata and saved output first.

## Handoff self-audit

1. Yes. Sections 1–3 give a newcomer the application, purpose, exact current
   state, commits, runs, issues and open PR topology; section 6 gives ordered
   steps with a verification gate for every step.
2. Yes. Sections 4–5 retain the failed approaches, timing race, five regression
   groups, reviewer dead ends, Windows probe issue and durable-evidence findings;
   the parallel reviewer blocks preserve each agent's exact contribution.
3. Yes. Sections 0–9 and the parallel reviewer accounting cover goals, state,
   failures, findings, constraints, environment, risks, exact actions,
   merge/install/live proof, fixed order and every delegated result.
4. Yes. A line-by-line sweep of sections 1–9 found no current owner decision.
   The parallel reviewer blocks also contain none. Section 0 says so explicitly,
   preserves all settled rulings, and tells the next session how to raise any
   genuinely new decision in one message.
