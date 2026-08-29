---
issue: 89
status: OPEN
owner: claude/reviewer-flake-89-progress-waits
machine: edge-dev
created: 2026-08-28T11:00Z
---

# Progress-wait misuse guard — open plan, no implementation started

**The plan is the brief:**
`plan_progress-wait-misuse-guard.md`, which lands with PR #142 on branch
`claude/reviewer-flake-89-progress-waits` and is not on `main` yet.
Read its STATUS table first. Do not re-derive or re-plan it.

## 0. What a reader needs to decide anything

Nothing is blocked on Albert. This is unfinished work with a written plan and
zero implementation done.

**Owner decisions outstanding:** none.

**Out of scope asks recorded elsewhere:** the deferred conversion sweep across
six other reviewer suites (`fix_test_ai.md`), and the ten-run flake series
(`plan_repo-throughput-restructure.md` step 1.2).

## 1. State

Branch `claude/reviewer-flake-89-progress-waits`, HEAD `b53c96b8`, pushed.
PR [#142](https://github.com/popcre/ai-devops/pull/142) is **OPEN**, checks
running. Plan Steps 0-4 are **done**; only Step 5 (green CI, merge queue, merge,
close out) remains.

## 2. What was established and built

**Step 0 answered.** The deep-`TMPDIR` rival cause is refuted: the merge-queue
checkout uses the same paths as an ordinary run, and the same commit passed and
failed on the same machine. The real cause is narrower and is recorded as
Finding G in the plan: `ai_test_fingerprint` measured entry counts and byte
sizes only, so the minutes a Grok wrapper spends building its review packet -
creating no file, taking no lock, writing no stderr - were invisible. Under the
contention of four concurrent CI runs that quiet phase outlasted the 120s stall
window and three healthy checks were failed.

Shipped on this branch:

- `tests/lib-test-timing.sh` - the fingerprint senses modification time as well
  as size and count; `poll_until_progress` reports a signal that never moved once
  as a defect in the TEST, separately from one that moved and then stopped.
- `tests/test-ai-grok-review.sh:375,732,753` - fingerprint the whole state and
  fixture trees, not the locks directory alone.
- `tests/test-lib-test-timing.sh` - 12 passed, 0 failed.
- `bin/ai-pr-wait` + `tests/test-ai-pr-wait.sh` - see below.
- `fix_test_ai.md` s3.7 and the `AGENTS.md` router carry both rules.

No ceiling, multiplier, or timeout was widened (Decision B).

**Local proof:** `bash tests/test-ai-grok-review.sh` - 191 passed, 0 failed, no
stall messages at all.

## 3. The second failure, and its guard

A monitor watching `gh pr view 142 --json state` waited 5.5 hours on a pull
request that had already been ejected from the merge queue - an ejection leaves
the state `OPEN`. Albert caught it, not the monitor.

`bin/ai-pr-wait <pr>` now exits on every terminal outcome: merged, closed, a
failing check, an ejection, or its own deadline. `tests/test-ai-pr-wait.sh`
fails CI if any file reintroduces the blind loop. It proved itself immediately:
it caught the missing executable bit on `bin/ai-pr-wait` in nine minutes.

**Use it. Do not hand-roll a wait loop.**

## 4. Next step

Plan **Step 5**: when the three checks on `b53c96b8` pass, `gh pr merge 142
--squash` into the merge queue, confirm the `merge_group` run (`gh run list
--event merge_group`), mark the plan STATUS row done with the merge SHA, update
`plan_repo-throughput-restructure.md`, and delete this file.

Still owed downstream, not started: the ten-run flake series that closes issue
#89, and `plan_ai-devops-work-claims.md` step 2, which stays blocked until it
does.

## 5. Dead ends - do not repeat

- CPU saturation. Measured 24% sustained, run queue ~0, 12 GB free. A single
  `Win32_Processor` sample said 71% and was wrong.
- A network fault. 12 consecutive TLS connections to github.com, all under 70 ms.
  The socket aborts in the runner log were the *consequence* of a job being torn
  down at its `timeout-minutes`.
- Deep `TMPDIR` path length. Checked and refuted; see Finding G.
- Raising a ceiling or restoring `budget 40 120`. Decision B forbids it and it
  does not fix the class of bug.
- Documentation alone. Already tried; this session read the doc and still made
  the mistake. Hence the enforcing test.
- Running a local test series while CI runs on the same machine. It caused the
  two job timeouts and, once, a name-matched cleanup cancelled a live job.

## 6. Delete this file when

PR #142 is `MERGED` with a recorded SHA.
