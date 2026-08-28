---
issue: 89
status: OPEN
owner: claude/reviewer-flake-89-progress-waits
machine: edge-dev
created: 2026-08-28T11:00Z
---

# Progress-wait misuse guard — open plan, no implementation started

**The plan is the brief:**
[`plan_progress-wait-misuse-guard.md`](../plan_progress-wait-misuse-guard.md).
Read its STATUS table first. Do not re-derive or re-plan it.

## 0. What a reader needs to decide anything

Nothing is blocked on Albert. This is unfinished work with a written plan and
zero implementation done.

**Owner decisions outstanding:** none.

**Out of scope asks recorded elsewhere:** the deferred conversion sweep across
six other reviewer suites (`fix_test_ai.md`), and the ten-run flake series
(`plan_repo-throughput-restructure.md` step 1.2).

## 1. State

- Branch `claude/reviewer-flake-89-progress-waits`, HEAD `4f8482a3`, pushed.
- PR [#142](https://github.com/popcre/ai-devops/pull/142) is **OPEN and was
  ejected from the merge queue** by run
  [33144576111](https://github.com/popcre/ai-devops/actions/runs/33144576111),
  which failed `windows-offline` on three checks in the "ask" concurrency block
  of `tests/test-ai-grok-review.sh`. Its three ordinary checks had passed.
- The plan file above is committed. **No step of it has been started.**

## 2. Why this exists

`poll_until_progress` fails a wait when its progress signal stops changing. If
the signal was chosen badly and never changes at all, the wait gives up early and
reports a "stall" — which reads as though the code under test hung. It does not.
This session read that message and spent hours on two wrong diagnoses (machine
saturation, then network failure) before finding it.

The plan makes the tool say which of the two situations it is in, covers that in
unit tests, and writes the rule at the definition site.

## 3. Next step

`plan_progress-wait-misuse-guard.md` **Step 0** — reproduce the three failures
locally on an idle `edge-dev` and confirm or refute the root cause. Every later
step depends on that answer, and Step 0 carries an explicit stop-and-re-plan
branch if the root cause is wrong.

## 4. Dead ends — do not repeat

- Diagnosing the failure as CPU saturation. Measured: 24% sustained, run queue
  ~0, 12 GB free. A single `Win32_Processor` sample said 71% and was wrong.
- Diagnosing it as a network fault. 12 consecutive TLS connections to github.com,
  all under 70 ms, none failed. The socket aborts in the runner log were the
  *consequence* of a job being torn down at its `timeout-minutes`.
- Raising a ceiling or restoring `budget 40 120` as a fix. Decision B forbids it
  and it does not fix the class of bug.
- Writing the rule in documentation only. Already done once; this session read it
  and still made the mistake.
- Running a local test series while CI runs on the same machine. Causes the job
  timeouts, and a name-matched cleanup once cancelled live job `98712820009`.

## 5. Delete this file when

Step 5 of the plan completes: PR #142 `MERGED` with a recorded SHA.
