# fix_test_ai — the two AI reviewer test suites are non-deterministic

**Written:** 2026-08-26 (edge-dev / claude)
**Status:** DIAGNOSIS ONLY — nothing has been changed. No fix has been applied.
**Affects:** `tests/test-ai-grok-review.sh`, `tests/test-ai-kimi.sh`

---

## 1. The short version

Both suites pass in GitHub Actions and fail intermittently on a developer
machine, on the **same commit**, with **no code change between runs**. They are
not detecting a defect when they fail. They are measuring how fast the machine
happened to be at that moment.

This matters because a suite that cries wolf teaches people to ignore it. These
two files hold some of the most important safety assertions in the repository —
the Grok early-return regression test, and the "a run that never completes is a
failure" rule — and those are exactly the assertions that get waved away once
"oh, that one's just flaky" becomes the habit.

**Nothing here is caused by the identity-guard work in `fix_to_gh_org.md`.**
Neither suite touches any file that change modified. This was found while
running the full suite as a check on that work.

---

## 2. The evidence that it is non-determinism, not a defect

Runs of `tests/test-all.sh` and of the two files individually, all on the same
tree (`eeb510f`), on `edge-dev`, 2026-08-25/26:

| Run | `test-ai-grok-review.sh` | `test-ai-kimi.sh` |
|---|---|---|
| Full suite | suite reported `tests=54 failures=1` | (same run) |
| Per-test scan | **passed 188, failed 3** | **passed 202, failed 1** |
| Targeted rerun | passed 191, failed 0 | passed 203, failed 0 |
| Repeat run 1 | passed 191, failed 0 | — |

The total check count is constant — 191 for Grok, 203 for Kimi. So three Grok
checks and one Kimi check **flipped from `ok` to `FAIL` and back again with no
input change**. That is the definition of a flaky test. Note also that the full
suite and the per-test scan disagreed with each other, which is why the failure
could not be identified from the first log.

Meanwhile, on the same commit, GitHub Actions was green on all three jobs:

- `linux-offline` (whole Bash suite) — pass, 9m13s
- `windows-offline` (whole Bash suite, **on Windows**) — pass
- `windows-reviewer-safety` (runs `test-ai-grok-review.sh` specifically) — pass

So this is not Windows-specific either. A clean idle Windows runner passes; a
busy developer Windows machine does not.

---

## 3. Root cause

Both suites assert on **wall-clock timing** against budgets far too tight to
survive a loaded machine, in three distinct ways.

### 3.1 Sub-5-second timeout budgets where process startup is slow

`tests/test-ai-grok-review.sh` drives the wrapper with a **3-second** ceiling at
line 249, and again at line 262 for the orphan case:

```
TIMED_OUT="$( cd "$OTHER" && AI_GROK_WAIT_TIMEOUT=3 bash "$SCRIPT" new bounded-timeout --prompt x 2>&1 )"
```

`tests/test-ai-kimi.sh` uses a **2-second** ceiling in at least seven places
(lines 184, 393, 420, 439, 448, 455, 479), against a stub whose `slow` and
`timeoutpartial` modes `sleep 30`.

The production default for both wrappers is **900 seconds**
(`bin/ai-grok-review:90`, `bin/ai-kimi:82`). The tests compress that by a factor
of 300 to 450.

The assertions then depend on fixture work completing *inside* that window. For
example `configured_timeout_stops_the_local_grok_process` requires the stub to
have written `hold-child-pid` before the 3-second ceiling fires:

```
check "configured_timeout_stops_the_local_grok_process" \
  "test '$TIMED_OUT_RC' -ne 0 && ... && test -s '$TMP/hold-child-pid' && ..."
```

On Git Bash for Windows, spawning `bash`, then the wrapper, then the stub, and
having the stub write a file, routinely costs more than 3 seconds when the
machine is busy — antivirus scanning a fresh temp tree makes it worse. When it
does, the ceiling fires **before the fixture is ready**, `hold-child-pid` is
empty, and the check fails. The wrapper behaved correctly; the fixture lost the
race.

### 3.2 A fixed `sleep` used as a synchronisation primitive

`tests/test-ai-grok-review.sh:236-241`, with `AI_GROK_HEARTBEAT_INTERVAL=2` set
at line 196:

```
sleep 5
touch "$TMP/release-grok"
wait "$FIRST_PID"
...
check "slow_turn_emits_truthful_bounded_heartbeats" "... grep -c 'does not prove provider activity' ... -ge 2"
```

The test sleeps 5 seconds, then demands that **at least two** heartbeats were
emitted at 2-second intervals. That is a 5-second budget for something needing a
minimum of 4, with no margin for the held review to even reach its heartbeat
loop. Under load the count comes back as 1 and the check fails.

This is the classic anti-pattern: a fixed sleep standing in for "wait until the
condition is true". The same file already knows better — it uses bounded polling
at lines 191, 213 and 219. The heartbeat case was never converted.

`tests/test-ai-kimi.sh:187-188` has the same shape:

```
AI_KIMI_WAIT_TIMEOUT=30 run start durable-cancel --prompt review >/dev/null
sleep 1
CANCEL_OUT="$(run cancel durable-cancel 2>&1)"
```

One second to get a worker registered before cancelling it, then an assertion
that the cancel was *worker-confirmed*. If the worker has not registered yet,
the cancel is recorded differently and the check fails.

### 3.3 Bounded polls whose ceiling is also a wall-clock guess

`tests/test-ai-grok-review.sh:219-220`:

```
for _i in $(seq 1 30); do [ "$(find ... -name 'work--*.lock.d' | wc -l)" -ge 3 ] && break; sleep 1; done
check "same_repo_different_caller_and_work_run_concurrently" "... -ge 3"
```

Polling is the right shape, but the 30-second ceiling is still a guess, and the
check that follows fails **silently** when the ceiling is hit rather than
reporting "the fixture never became ready". Three concurrent wrapper launches,
each cloning a git repository, can exceed 30 seconds on a contended machine.

### 3.4 Why the machine is contended in the first place

Not hypothetical. `edge-dev` runs **multiple concurrent AI sessions** and had
**seven registered git worktrees** at the time of these runs; several of those
sessions run their own suites. The CI runners have none of that: one job, one
clean VM, nothing competing.

That is the entire difference between green in CI and red locally.

---

## 4. Why CI does not protect us here

CI passing is currently read as "the suites are fine". It is not evidence of
that. It is evidence that **an idle single-purpose runner is fast enough to win
every race**. The races are still in the tests; CI simply never loses them.

Two consequences:

1. **A real regression could be masked.** The same checks that fail spuriously
   under load could pass spuriously when a genuine bug makes the wrapper
   *faster* — for example returning early, which is precisely the bug
   `await_blocks_until_terminal_json` exists to catch.
2. **Developers cannot trust a local run.** The full suite takes roughly 50
   minutes on Windows. Fifty minutes ending in an unexplained `failures=1` that
   evaporates on rerun is worse than no local suite, because the honest response
   is to rerun — another 50 minutes.

---

## 5. What a fix must and must not do

**Must not:** weaken or delete any of these assertions. The Grok early-return
regression test and the Kimi "never completes is a failure" test are
load-bearing safety checks. Raising a timeout until the check stops meaning
anything, marking a test allowed-to-fail, or deleting it, are all symptom
suppression, not repair. The suites must still fail when the wrapper is wrong.

**Must:** make the assertions depend on **observable state**, not elapsed
wall-clock time.

Recommended direction, in priority order:

1. **Replace fixed sleeps with condition polling.** `sleep 5; assert >= 2
   heartbeats` becomes: poll until the heartbeat count reaches 2, up to a
   generous ceiling, failing with a distinct message if the ceiling is hit. Same
   for the Kimi `sleep 1` before cancel — poll until the worker is registered.
2. **Separate "the fixture was not ready" from "the wrapper misbehaved".** Every
   bounded poll should report which one happened. Today a fixture that never
   became ready produces the same red as a genuine defect, which is why the two
   cannot be told apart from the log.
3. **Scale the compressed timeouts to the machine, not to a constant.** Keep the
   compression — a 900-second ceiling in a test is useless — but derive it from a
   measured baseline (time one trivial wrapper invocation at suite start and
   multiply), or raise the floor to something a loaded Windows box can meet. A
   2-second ceiling on a platform whose process startup alone can cost seconds
   is not testing the ceiling logic, it is testing the hardware.
4. **Make timing-sensitive cases announce themselves.** A timing-dependent check
   should print the measured value on failure. `await returned too early (2s)`
   at `tests/test-ai-kimi.sh:518` is the right pattern; most others do not do it.
5. **Add a load-aware guard, not a skip.** If the suite cannot meet its own
   timing preconditions, it should say so loudly on a distinct exit path — never
   silently skip, never quietly pass.

---

## 6. How to verify a fix

A fix is proven when **all** of these hold:

1. Both suites pass 10 consecutive local runs on `edge-dev` **while other work
   is running on the machine**. An idle box already passes today and proves
   nothing.
2. Both suites still **fail** when the defect they guard is reintroduced.
   Deliberately break the wrapper — for example make `await_result` return
   before a terminal record exists — and confirm the relevant check goes red. A
   test that cannot fail is not a test.
3. All three CI jobs stay green.
4. Total check counts are unchanged or higher — 191 for Grok, 203 for Kimi. A
   fix that reduces the count has removed coverage.

---

## 7. What was NOT investigated

- **Whether the same pattern exists in the other reviewer suites**
  (`test-ai-deepseek-agent.sh`, `test-ai-muse.sh`, `test-ai-gemini.sh`,
  `test-ai-qwen.sh`, `test-ai-glm.sh`). Not examined. Given a shared authorship
  lineage it is likely, and worth a sweep.
- **The exact identity of the four checks that flipped.** The failing runs were
  captured by tail only, so the counts are known (3 Grok, 1 Kimi) but the names
  are not. Section 3 names the checks most likely responsible from code
  inspection; a session fixing this should reproduce under artificial load
  rather than trust that attribution.
- **Whether `edge-dev` has an unrelated resource problem** (disk, antivirus
  policy, a runaway process from an abandoned worktree). The contention
  explanation fits the evidence but was not measured.
