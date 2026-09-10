---
issue: 167
status: OPEN
owner: codex/issue-167-shared-harness
---

# HANDOFF — #167 finalization proof (2026-09-10T1402Z, edge-dev/codex)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

None — nothing in this workstream needs Albert's decision. The next session
should continue the already-authorized #167 repair and close it only after all
evidence gates pass.

Already settled — do not re-ask:

- #167 is the current #159 child; #169 follows and #166 is deliberately last.
- Preserve every assertion, the complete scheduled/manual Windows backstop, the
  stable `windows-offline` aggregate, and #260's fail-closed reviewer coverage.
- Do not rerun an unchanged timeout or reduce coverage to make the timing pass.

## 1. What this application is

`popcre/ai-devops` is POP Creations' public recovery toolkit for its AI-assisted
engineering workflow. It contains shell and PowerShell tools, reviewer safety
controls, machine setup, and offline verification; it is not a deployed web
application. Parent issue #159 makes concurrent work finish safely rather than
stalling in duplicate or unreliable checks.

## 2. What we set out to do this session, and why

Resume #167, which consolidates duplicated offline Bash test helpers without
changing assertions or failure behavior. The preceding exact-head manual
matrices proved a separate workflow defect: the full Windows suite finished at
the 100-minute job ceiling, then GitHub cancelled finalization and the stable
aggregate failed despite a successful suite.

This session made the smallest measured repair: commit `3ec1af0a` changes only
the complete-matrix allowance from 100 to 105 minutes and locks the value in
the workflow-policy test. The five minutes are finalization allowance, not a
coverage reduction or an open-ended timeout increase.

## 3. Current state — what is true right now

- PR #371, `Consolidate the offline Bash test harness (#167)`, is OPEN at
  `3ec1af0a23ff4cccc882f0a335d04e80e48f9ddd` on
  `codex/issue-167-shared-harness`; commit is pushed.
- `tests/test-workflow-policy.sh` passed locally in Git Bash after the repair;
  it now rejects every complete-matrix timeout except exactly 105. `git diff
  --check` passed before commit and Git identity was Albert Hazan's GitHub
  noreply identity.
- The evidence file
  `tests/verification/repo-throughput/issue-167-shared-harness.md` records the
  exact prior measurements and repair rationale.
- Manual exact-head run `34479418193` is still IN PROGRESS. Its Linux and
  self-hosted reviewer-safety jobs passed; `windows-offline-complete` is the
  remaining full, unsectioned Windows backstop. Do not start a duplicate run.
- The ordinary PR run `34479365020` passed Linux and all four hosted Windows
  sections, then its self-hosted `windows-reviewer-safety` job failed; the
  hosted fallback passed. Inspect that failed job's logs before calling it a
  code failure or rerunning it.
- The first exact-head independent final review, local artifact
  `.ai/reviews/codex-final-check-20260910T125501-13026-28174.md`, correctly
  returned REJECT only because complete-matrix proof was not yet available. It
  found no code defect and requires a fresh exact-head APPROVE after the run.
- No handoff or source file is uncommitted at this closeout. This new handoff is
  the only pending local change until it is committed and pushed.

## 4. Everything we tried that did NOT work

1. Exact-head manual runs `34445127896` and `34445717137` on `c0199e8f` were
   cancelled at the old 100-minute complete-Windows ceiling. Their substantive
   suite steps succeeded at 99m56s and 99m59s, but the job could not publish its
   completion result. Repeating them unchanged was not acceptance.
2. The first independent review of `3ec1af0a` could not approve before the new
   complete-matrix run existed. This was correct evidence gating, not a reason
   to bypass review.
3. The ordinary PR reviewer lane failed after the repair while the fallback
   passed. No diagnosis or workaround was started during closeout; the next
   session must inspect its exact logs first.

## 5. Root causes and key findings

- `.github/workflows/verify.yml` defines the complete unsectioned Windows
  backstop at the `windows-offline-complete` job. Its prior 100-minute timeout
  included setup, suite execution, cleanup, and result publication, leaving no
  reliable finalization margin once the suite reached roughly 100 minutes.
- The repaired bound is `timeout-minutes: 105`; the nearby comments cite the
  two measured runs and state why #166 must still set any required-check ceiling
  from a completed run.
- `tests/test-workflow-policy.sh` now reads that job's timeout and requires
  exactly 105, preserving a bounded guardrail against silent future inflation.
- The full manual route uses `windows-offline-complete`; ordinary pull requests
  use four hosted sections plus the stable `windows-offline` aggregate. Those
  are distinct proof routes and must not be confused.

## 6. Exact next steps

1. In `C:\repos\ai-devops-worktrees\issue-167-shared-harness`, check run
   `34479418193` with `gh run view 34479418193 --repo popcre/ai-devops --json
   status,conclusion,jobs`. Do not dispatch another full manual run while it is
   live. You will know it worked when `windows-offline-complete` and the stable
   aggregate both report success on `3ec1af0a`.
2. If that run fails or is cancelled, inspect the exact failed job log and
   timestamps before changing anything. Preserve the full backstop and make a
   targeted repair only if the evidence identifies one. You will know the
   diagnosis is sufficient when it names the job, step, conclusion, duration,
   and why the existing bound did not cover it.
3. Inspect failed ordinary PR job `102878335620` from run `34479365020` using
   `gh run view 34479365020 --repo popcre/ai-devops --job 102878335620 --log`.
   Determine whether it is an infrastructure/reviewer defect or a real code
   defect; do not accept the fallback as a substitute for a required lane. You
   will know it worked when the cause is recorded and any repair has focused
   proof.
4. Once the complete run passes, update the #167 evidence file with its run ID,
   exact head, job results, and timing. Keep the plan STATUS honest; the current
   `done` row is intended only for a landed child and was flagged by the initial
   reviewer while the issue remains open. You will know it worked when a fresh
   reader can see completed proof rather than a future-tense placeholder.
5. Run a fresh read-only `ai-codex-review final-check --tests
   "tests/test-workflow-policy.sh"` against the then-current PR head. You will
   know it worked when the report names that exact SHA and ends `APPROVE`.
6. Use `bin/ai-pr-wait 371`, resolve every required check, then merge PR #371
   through the queue. Verify its merged commit on `origin/main`, close #167,
   and retire both this handoff and the 2026-09-10T1242Z predecessor only under
   the successor rule. You will know it worked when GitHub shows PR MERGED,
   #167 CLOSED, and the evidence/plan are on `origin/main`.
7. Only then start #169 in a fresh current-upstream worktree. Start #166 only
   after every other #159 child is closed.

## 7. Constraints and gotchas in force

- This repository uses isolated worktrees, branches, pull requests, and the
  merge queue; the canonical checkout is landing-only.
- Reviewer/workflow safety changes need focused tests plus exact-head,
  read-only independent approval. A hosted fallback does not authorize leaving
  a failed required reviewer lane unresolved.
- Never run a local full suite while a Windows CI runner is active. The focused
  shell policy test is safe; the full Windows evidence belongs on GitHub.
- Do not reset, clean, weaken, skip, split away, or otherwise remove coverage.
- Do not edit another session's handoff or root `HANDOFF.md`. The old #159
  handoff remains because it carries predecessor decisions until a successor
  proves them preserved.

## 8. Access and environment

- GitHub CLI is authenticated for `popcre/ai-devops`; `gh pr view`, `gh run
  view`, `gh run watch`, and workflow dispatch worked in this session.
- Git Bash is available at `C:\Program Files\Git\bin\bash.exe`; the bare
  `bash` command invokes unavailable WSL, so use the explicit Git Bash path for
  repository Bash tests and tools.
- The independent reviewer writes ignored local evidence under `.ai/reviews/`.
- No secrets were read or changed. Durable secrets, if ever needed, belong in
  1Password vault `vibe_coding`; do not place values in this public repository.

## 9. Open questions and risks

- The remaining manual full Windows job may still expose a real timing or
  finalization boundary. The new bound is evidence-backed but is not accepted
  until that exact run succeeds.
- The PR reviewer-safety failure in ordinary run `34479365020` is unexplained;
  its successful fallback proves only that fallback coverage worked, not that
  the qualified lane is healthy.
- Parent #159 remains OPEN. At closeout, #167, #169, and #166 are unfinished;
  no parent completion claim is valid.
- Stale handoff observed but not touched:
  `HANDOFF.d/2026-09-01T1709Z-edge-dev-codex-issue-161-fast-ci.md`, owner
  `codex/issue-161-fast-ci`, while issue #161 is already closed. It was already
  known in the predecessor handoff; do not delete it until a successor satisfies
  the documented retention rule.

## Handoff self-audit

1. **Yes.** Sections 1–6 give a new developer the purpose, exact branch and
   run state, failed attempts, and ordered verification gates needed to resume
   without chat context.
2. **Yes.** Sections 3–5 retain the exact SHAs, run/job IDs, timing evidence,
   review verdict, and Git-Bash/WSL trap discovered this session.
3. **Yes.** Sections 1–9 cover background, outcome, current state, failures,
   findings, next actions, constraints, access, and risks; section 8 keeps
   secrets location-only.
4. **Yes.** The section-0 sweep found no owner judgement in sections 1–9. The
   only deferred work is evidence-led diagnosis and merge execution, already
   authorized and specified in section 6; no Albert decision is required.
