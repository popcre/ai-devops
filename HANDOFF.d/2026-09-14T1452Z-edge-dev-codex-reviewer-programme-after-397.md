---
issue: 159
status: OPEN
owner: codex/397-qualification-closure
---

# HANDOFF — reviewer programme after #397 delivery (2026-09-14 14:52 UTC, edge-dev/codex)

## 0. DECISIONS ONLY THE OWNER CAN MAKE

None. The remaining #159 programme is already authorized. Do not ask Albert to
merge, approve, reduce coverage, change the dependency order, or treat a busy
EDGE-RUNN-ENVY runner as a machine-wide stop.

Already settled: preserve all reviewer capabilities and tests; keep GitHub-hosted
Linux/Windows, EDGE-RUNN-ENVY and Blacksmith capacity; preserve frozen round
`0c62f3dffce145c4b2768855b912b958`; run #398 last inside #337 and #166 last
inside #159. No database or production-cloud mutation is authorized.

## 1. What this application is

`popcre/ai-devops` is POP Creations' public recovery and governance toolkit for
AI reviewers on Windows and Linux. GitHub `main` is the source of truth;
installation from canonical `C:/repos/ai-devops` is deployment. Reviewer
programme #337 is a child of throughput programme #159. It must provide exact
source, truthful outcomes, durable evidence, same-session recovery and bounded
CI without weakening privacy or safety.

## 2. What we set out to do this session, and why

Continue issue #159 from the 2026-09-11 handoff and finish every remaining
child in dependency order. This session concentrated on #397 provider execution
and exact-session recovery, including implementation, independent review, CI,
merge queue, canonical installation, live canaries and incident reconciliation.
Albert invoked closeout before later children began.

## 3. Current state — what is true right now

- Current `origin/main`, checked 2026-09-14 14:52 UTC, is
  `22a7f22b88198e1bcc26ec99ebc135819b8f06f4`.
- PR #447 landed the main #397 recovery matrix as `24279f17`; exact source head
  `6bf539b9` received independent APPROVE. Required run `34837962149` and queue
  run `34842163354` passed.
- Installed Qwen and GLM canaries proved local publication recovery without a
  second paid turn. The live gate found two additional DeepSeek defects instead
  of concealing them.
- PR #453 repaired protected lifecycle identity and ordinary continuation after
  source movement. Exact head `cbfec602` received independent APPROVE; DeepSeek
  passed 131/0/0 including 26/0/0 recovery; required run `34848157010` and queue
  run `34852705794` passed. It landed and was installed as `3098a89a`; the
  canonical machine-tools doctor passed.
- Installed Muse returned APPROVE and continued the same conversation from a
  separate wrapper process. Installed DeepSeek retained one governed session
  from durable BLOCKED through large attachment evidence to exact-head APPROVE.
- DeepSeek incident `20260911T005524Z-edge-dev-deepseek-294011` is RESOLVED.
  Qwen incident `20260910T081507Z-edge-dev-qwen-1166` remains open for #393
  because it concerns stale PR-base identity, not session recovery.
- #397 is still OPEN. Comment
  `https://github.com/popcre/ai-devops/issues/397#issuecomment-5665892204`
  records delivery. Its last gate is current-main drift run `34856869730` on
  exact `22a7f22b`; at 14:52 UTC Linux, complete hosted Windows and preferred
  EDGE-RUNN-ENVY reviewer jobs were active with no reported failure.
- Worktree `C:/repos/ai-devops-worktrees/397-qualification-closure`, branch
  `codex/397-qualification-closure`, contains three uncommitted session-owned
  prose files: this handoff plus updates to
  `tests/verification/reviewer-reliability/issue-397-session-recovery.md` and
  `plan_reviewer-reliability-and-efficiency.md`. The draft marks #397 acceptance
  complete but must not be committed until run `34856869730` passes; if it
  fails, revise the wording honestly first.
- A separate Codex task `01a09d96-91f5-7471-81f9-4fdda96c3591` is actively
  repairing the PR #452 required-check/merge-queue race while preserving all
  runners and tests. Do not duplicate or overwrite that work.
- #394, #393, #271, #398/#337 and #166/#159 remain unstarted by this session.
  The required order is #397, #394, #393, #271 disposition, #398/#337, #166,
  then #159.

## 4. Everything we tried that did NOT work

- Passive waiting consumed too much of this long session. A busy self-hosted
  runner was initially treated too broadly even though GitHub-hosted and
  Blacksmith lanes remained usable. The runner-policy defect is now separated
  into task `01a09d96-91f5-7471-81f9-4fdda96c3591`.
- PR #452 later merged on top of the #397 repair even though its exact-head run
  `34850679812` failed five Windows Kimi cleanup-timing tests. Merge-group run
  `34852834767` also ran too early and failed because that PR run was still in
  progress. This is a merge-policy race, not permission to weaken or skip tests.
- A local full Kimi diagnostic began only after collision preflight returned
  clear, but live GitHub state then showed physical Windows jobs active. It was
  interrupted immediately to preserve the no-overlap rule. Do not restart it
  while an exact-main physical runner job is active.
- The first Muse blocked-report-directory attempt correctly refused before the
  provider, so it was not live post-completion recovery proof. A later proper
  installed restart/continuation canary supplied that evidence.
- Qwen's first live verdict was REVISE because it correctly found the DeepSeek
  stale-source fence. PR #453 fixed the finding and received a new exact-head
  independent APPROVE; the earlier review was not mislabeled.
- Grok 1.0.13 can export a retained transcript but exposes no authoritative
  remote run-status or acknowledged cancel command. The uncertain turn remains
  fenced and was not retried; this is a documented supported-tool limitation.
- Bare `bash` on this Windows host resolves unusable WSL. Use
  `C:/Program Files/Git/bin/bash.exe` for repository Bash suites.

## 5. Root causes and key findings

- Recovery must bind the original repository, source packet, caller, model,
  runtime and paid turn; it may publish retained bytes but never resubmit an
  uncertain paid request.
- Protected 1Password re-entry had dropped `AI_REVIEW_EVENT_RUN_ID`, preventing
  governed DeepSeek evidence publication. The repair preserves that identity.
- An ordinary DeepSeek retained turn could become permanently fenced when HEAD
  moved before finalization. The repair permits a fresh explicit continuation
  while keeping stale completion non-authorizing.
- A single runner being busy is not a global stop. Collision checks are scoped
  to the physical Windows host; GitHub-hosted and Blacksmith lanes remain
  independently usable.
- PR #452 exposed a separate policy defect: merge evidence can be evaluated
  before the exact PR run reaches a terminal result. The separate runner task
  owns this finding.
- #397's exact suites cover provider restart/continuation, two repository/caller
  identities, concurrent names and changed-identity refusal. Qwen/GLM live
  canaries satisfy the issue's explicit paid-provider acceptance.

## 6. Exact next steps

1. Poll run `34856869730` once. If green, add its exact result to the #397
   qualification file; if red, record the exact failing cases and hand them to
   the already-running runner task when they are its scope. Do not rerun an
   unchanged failure. Gate: every required current-main job is terminal green
   or an exact external blocker is documented.
2. Review the three-file prose diff, run `git diff --check`, verify
   `git var GIT_COMMITTER_IDENT`, commit and push branch
   `codex/397-qualification-closure`, open a PR, confirm its changed-file list is
   prose-only, and squash/admin merge immediately. Gate: the docs PR is MERGED
   and its merge commit is on `origin/main`.
3. Close #397 only after step 1 and the installed evidence remain valid. Delete
   predecessor handoff
   `HANDOFF.d/2026-09-11T2238Z-edge-dev-codex-reviewer-programme-after-396.md`
   in the closeout PR only after confirming every surviving obligation is in
   this handoff/plan. Gate: #397 is CLOSED and no unique predecessor obligation
   was lost.
4. Start #394 from then-current upstream in a fresh worktree. Port the Qwen
   semantic status changes (`2d12b759`, `c4987867`), Muse pre-session
   `start_failed` reasons from `2d708e6d`, and Grok commits in order
   `2d708e6d`, `82b94e36`, `f22d77a9`, `03c6c394`; exclude #397 recovery hunks.
   Gate: owning full suites, parity checks, exact-head independent review,
   required CI/queue, install/live proof and incident reconciliation all pass.
5. Complete #393 governed source comparison against GitHub's exact base/head/file
   set, negative stale/missing/truncated/digest cases, real-consumer terminal
   verdict and incident reconciliation. Do not touch frozen round
   `0c62f3dffce145c4b2768855b912b958`. Gate: exact end-to-end source identity is
   proven and obsolete PR #344 is reconciled.
6. Re-evaluate #271 against the current supported Codex runtime. Preserve both
   intended-source read and outside-root/network denial; if native Windows still
   cannot enforce it and WSL/Docker remain unavailable, retain an honest external
   blocker. Gate: either full capability is proven or the issue states the exact
   current external blocker without weakened containment.
7. Run #398 only after component children close: resume, never reset, the frozen
   198-candidate round; account for every candidate, run installed nine-provider
   matrix and bounded recurrence scan, reconcile incidents, then close #337.
   Gate: all 198 have durable dispositions and the round completes once.
8. Finish remaining #159 obligations, execute #166 last, prove the live ruleset
   on a throwaway PR and merge queue, then close #159. Gate: every child is
   closed with production evidence and `origin/main` contains the final record.

## 7. Constraints and gotchas in force

- Canonical checkout is landing/install only; all edits use fresh current-main
  worktrees. Stage only owned files; never reset, clean, force-push or weaken a
  test.
- Reviewer-safety code needs read-only exact-head independent review. Every code
  PR must pass required CI and merge queue before canonical installation/live
  proof. Documentation-only PRs merge promptly after verifying file scope.
- Do not overlap local full suites with a GitHub job on the same physical Windows
  host. A busy remote runner does not block unrelated hosted lanes.
- No database, production-cloud, credential, private transcript or raw incident
  data belongs in this public repository. Secrets live only in 1Password vault
  `vibe_coding` and must never appear in arguments, logs or commits.
- Preserve Grok's uncertain state, the #398 frozen round and every no-replay,
  identity, privacy and fail-closed boundary.

## 8. Access and environment

- Repository: `C:/repos/ai-devops`; GitHub remote
  `https://github.com/popcre/ai-devops`; `gh` is authenticated as the correct
  owner identity.
- Current closure worktree/branch:
  `C:/repos/ai-devops-worktrees/397-qualification-closure`,
  `codex/397-qualification-closure`.
- Canonical installation checkout: `C:/repos/ai-devops`.
- Git Bash: `C:/Program Files/Git/bin/bash.exe`.
- Private reviewer incidents and live reports remain under ignored `.ai` state;
  do not copy them into this public handoff. Secrets, if a later live gate needs
  them, are in 1Password vault `vibe_coding`.
- No shared-db credential, checkout or production access is needed.

## 9. Open questions and risks

- Run `34856869730` was still active at handoff time; its result is deliberately
  not inferred. A failure may invalidate the drafted “acceptance complete” row.
- The separate runner-policy task may land a new main commit while #397 prose is
  closing. Re-fetch and rebase/merge current upstream before opening the docs PR;
  never overwrite that task's work.
- PR #452's merge despite failed/incomplete exact-head evidence is a systemic
  closure risk until the separate task proves the corrected gate live.
- #271 is likely still an external platform blocker, but runtime versions and
  machine capabilities are drift-prone; verify rather than copying this belief.
- No item currently requires Albert's decision.
- Secrets sweep: the session-owned diff and untracked-file list contain no new
  credential, token, connection string, password or `.env` material.
- Documentation pass: the #397 qualification and programme status were the only
  durable records made stale by this session; no other standing document is
  known to require a change.

## Parallel-agent accounting

### Agent `/root/audit_397`

- Asked to independently review exact #397 heads and later read current-main CI.
- Confirmed exact approvals and that run `34856869730` was active with no failure
  at 14:52 UTC. Made no edits, provider calls, commits or installations.
- Work is finished; deliberately did not infer a result from an active run.

### Agent `/root/audit_394`

- Asked to map the surviving #394 changes without crossing #397 boundaries.
- Produced the semantic port order recorded in step 4. Made no edits or external
  changes. Work is finished; deliberately did not start #394 before #397 closes.

### Agent `/root/audit_393_271`

- Asked to map #393 incident acceptance and #271 containment state.
- Confirmed the stale Qwen incident belongs to #393 and that #271 must retain an
  honest external blocker unless full containment is proven. Made no edits or
  external changes. Work is finished; deliberately did not touch the frozen
  #398 round or weaken sandbox requirements.

## Handoff self-audit

1. Yes. Sections 1–3 define the product, programme, exact delivery evidence,
   current main, live run, branch and uncommitted files for a newcomer.
2. Yes. Sections 4–5 preserve the failed approaches and non-obvious recovery,
   runner and merge-policy findings; agent accounting preserves delegated work.
3. Yes. Sections 6–9 give the full dependency-ordered route through #159, a
   verification gate per step, boundaries, access and every known risk.
4. Yes. A line-by-line section 1–9 and agent-accounting sweep found no owner
   decision. Section 0 states that explicitly and records settled instructions
   that must not be re-asked.
