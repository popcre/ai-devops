# fix_test_ai — the AI reviewer test suites were non-deterministic

**Written:** 2026-08-26 (edge-dev / claude) — diagnosis
**Updated:** 2026-08-27 (edge-dev / claude) — **PARTIALLY FIXED. Do not read this
file as closing issue #89.** Section 3 rewritten: the original attribution was
inferred from code inspection and was wrong on both suites. The causes below are
measured, and the fix below is real but insufficient.

**What the fix achieved, measured over six local runs:** the blast radius of a
failure shrank from four checks to one, and the surviving failure now names
itself as a fixture problem with its ceiling and baseline instead of appearing as
an anonymous `FAIL`. That was the single most expensive property of #89.

**What it did not achieve:** the suite still failed once in six runs (~17%, down
from ~33%). The remaining cause is confirmed, not suspected: the timing baseline
is measured exactly once at `tests/test-ai-grok-review.sh:216` and every later
ceiling is derived from that one frozen number, while the failing wait sits
several hundred seconds further down the file. A machine that degrades after the
measurement is judged against a computer that no longer exists.

**Do not fix this by raising the multiplier.** A ceiling large enough for a
degraded machine no longer detects a genuine hang, which is what these checks
exist to catch. The correct fix is a progress-sensitive wait.

**Status 2026-08-28: that wait is now written, not yet measured.** Commit
`fe7c0606` converts the three drift-exposed waits in
`tests/test-ai-grok-review.sh` to stall detection - they fail only when nothing
observable has changed for the stall window, so a slow-but-advancing machine is
no longer failed while a genuine hang still is. No multiplier, timeout, retry, or
quarantine was added. The mechanism is proven by `tests/test-lib-test-timing.sh`
(10 checks, 10 passed).

The flake rate is **still unmeasured**. Two local ten-run series were abandoned -
see `tests/verification/reviewer-flake-89/2026-08-28-local-series-abandoned.md`,
which also records the rule that this machine hosts either the CI checks or a
local series, never both. Read that file and
`tests/verification/reviewer-flake-89/2026-08-27-ten-run-series.md` together;
they are the evidence any later claim of "fixed" must be measured against.

**Affects:** `tests/test-ai-grok-review.sh`, `tests/test-ai-kimi.sh`, and — after
a sweep — `tests/test-ai-deepseek-agent.sh`, `tests/test-ai-muse.sh`,
`tests/test-ai-gemini.sh`, `tests/test-ai-qwen.sh`, `tests/test-ai-glm.sh`.

---

## 1. The short version

Both suites passed in GitHub Actions and failed intermittently on a developer
machine, on the **same commit**, with **no code change between runs**. They were
not detecting a defect when they failed. They were measuring how fast the
machine happened to be at that moment.

This matters because a suite that cries wolf teaches people to ignore it. These
files hold some of the most important safety assertions in the repository — the
Grok early-return regression test, and the "a run that never completes is a
failure" rule — and those are exactly the assertions that get waved away once
"oh, that one's just flaky" becomes the habit.

**Nothing here was caused by the identity-guard work in `fix_to_gh_org.md`.**

---

## 2. The evidence that it was non-determinism, not a defect

Runs on `edge-dev`, 2026-08-25/26, all on the same tree. The **total check count
is constant** — 191 for Grok, 203 for Kimi — while the pass/fail split moves. A
check that flips `ok` → `FAIL` → `ok` with no input change is flaky by
definition.

Controlled comparison, both suites launched at the same moment on the same
machine:

| | Result |
|---|---|
| Original `test-ai-grok-review.sh` | 190 passed, **1 failed** |
| Fixed `test-ai-grok-review.sh` | **191 passed, 0 failed** |

Meanwhile GitHub Actions was green on all three jobs for the same commit. CI
passing is not evidence the suites are sound; it is evidence that an idle
single-purpose runner wins every race. See section 4.

---

## 3. Root cause — MEASURED

> The first version of this section named the fixed `sleep 5` before the
> heartbeat assertion and the 3-second timeout ceilings as the likely culprits.
> **Both were wrong.** The `sleep 5` passed in every run captured under load.
> The three real causes were only found by reproducing under artificial load and
> reading the full output rather than a tail. Do not trust code inspection over
> a reproduction.

### 3.1 A fixture with a self-destruct shorter than the test (Grok)

The single biggest cause, reproduced **six times**, and absent from the original
diagnosis entirely.

`list_shows_active_reviews_across_clones_and_callers` and
`list_reports_start_elapsed_pid_checkout_and_owner_state` assert on what `list`
reports about a review that is **still running**. That long-running review is
the stub in `hold` mode — which released itself after **60 seconds**:

```
for _i in $(seq 1 60); do [ -f "$TMPDIR_FOR_TEST/release-grok" ] && break; sleep 1; done
```

Between that review starting and the `list` assertions, the test clones two more
repositories, starts two more reviews, creates a fourth repository and runs a
review in it. On a loaded machine that exceeds 60 seconds, so the held review
had already finished and `list` correctly reported nothing. The wrapper was
right; the fixture had expired.

**Fixed:** the hold is a last-resort escape hatch (900s), not a timer, and the
cleanup trap releases stragglers.

### 3.2 A compressed wait ceiling losing to process startup (Grok)

`AI_GROK_WAIT_TIMEOUT=15` was the suite-wide default against a 900-second
production default. The `cancelled` stopReason case is not testing the ceiling
at all, but on Windows the wrapper spawns Git Bash, then a Python supervisor,
then the stub; under load that exceeded 15 seconds, so the wrapper reported a
timeout instead of the cancellation message and took three checks down together:

- `cancelled has cancellation recovery message`
- `cancelled message names the session`
- `cancelled recommends a fresh session`

Note the wrapper counts its ceiling in **poll iterations, not wall-clock
seconds** (`sleep "$POLL_INTERVAL"; waited=$((waited + POLL_INTERVAL))`), so
under load a ceiling of N takes appreciably more than N seconds to fire. Any
fixture that must outlive a ceiling has to do so in that same distorted clock.

### 3.3 Fixture-readiness waits far too short (Kimi)

Three loops gave a worktree-creating `implement` launch **five seconds** to
register its owner file:

```
for _ in 1 2 3 4 5; do ... sleep 1; done
```

Under load this produced `concurrent refusal starts no second provider turn`,
`implement interrupt removes worktree` and `incomplete export cleans worktree`
— 1, 2 and 5 failures across three concurrent runs of the unmodified suite.

### 3.4 A fixture wait that could never succeed (Kimi)

Found only after the launch stopped discarding its output to `/dev/null`.

`concurrent refusal starts no second provider turn` waited for the first
`implement` to register by searching `-path '*/same-name/owner.json'`. The
wrapper names that directory `kimi.<rid>-<caller>-<name>`, so no component is
ever literally `same-name`. **The pattern could never match.**

The check passed anyway, by luck: the loop burned its full five seconds and gave
up, and five seconds happened to be shorter than the stub's thirty-second sleep,
so the first run was still alive and the duplicate was correctly refused. The
check was passing for a reason unrelated to what it appeared to verify — and on
a loaded machine, where five seconds elapsed before the wrapper had even
launched, it failed.

**A passing check is not proof of coverage.** This one tested nothing for its
entire life.

### 3.4a A confirmation wait bounded by a knob meant for something else

`durable cancel is worker-confirmed` failed roughly one run in six with
`cancel-request-unconfirmed`. `cmd_cancel_job` waits for the worker to reach a
terminal phase, bounded by `STARTUP_TIMEOUT` — the same knob that bounds how
long a worker may take to start. On a slow machine the confirmation can outlast
it. Both quantities are machine-dependent, so both now scale; see 3.5, which is
the same mistake in a different place.

### 3.4b A fixture whose ceiling was shorter than the duplicate's startup (Grok)

Found from CI timestamps, not locally: the ask-concurrency block failed four
checks on `main` in roughly one CI run in three.

```
14:55:21  ok   different_named_sessions_can_ask_concurrently
14:57:25  FAIL same_next_ask_turn_is_serialized      <- 124s later
```

The duplicate `ask` that must be refused builds a review packet first - several
git operations - and on the `windows-2025` runner that took 124s against the
first turn's 110s ceiling. So the first turn timed out and released its session
lock **before the duplicate reached the lock check**, and the duplicate was then
allowed for an entirely correct reason. Same disease as 3.1: an assertion about a
fixture that had already expired.

The held turns now take the wide ceiling that section 16's held review already
had. They are released explicitly by the test, so a wide ceiling costs nothing.

**Note for the record:** the `windows-reviewer-safety` runner measures an 11s
baseline - it is *not* a fast machine, and the assumption that CI always sits at
the ceiling floors is wrong.

### 3.4c A fixture wait that fell through instead of waiting (issue #148, Muse)

Two `test-ai-muse.sh` interrupt checks failed on `main` on an idle machine and
were reported as a probable race in the `ai-muse` shutdown path. They were not.
Every fixture wait in that suite polled a baseline-scaled ceiling and then
**continued regardless**, so on a slow run the signal was delivered before the
fixture reached the state the check was about, and the suite blamed the wrapper.

A ceiling alone cannot tell "the worker is still working" apart from "the worker
died". The eleven waits now use `poll_worker_until PID CEILING WHAT COND` in
`tests/lib-test-timing.sh`: the background worker responsible for producing the
state is the moving signal, so the wait returns as soon as that worker exits,
keeps waiting while it lives, and prints a distinct `fixture:` line on stderr
naming which of the two happened. No ceiling was raised and no check was
weakened.

### 3.4d Three grok concurrency checks that stall on identical code (issue #177)

`main` went red on `529d5408` — a documentation-only commit — when
`tests/test-ai-grok-review.sh` reported `passed 193, failed 3`. The three
failures are `different_named_sessions_can_ask_concurrently`,
`same_next_ask_turn_is_serialized`, and `uncertain_ask_blocks_its_exact_retry`,
all with a genuine stall report: the progress signal advanced, then nothing
changed for 135s after 389s against a 9s baseline.

This is **not** the frozen-baseline pattern of 3.4a: the wait is already
progress-sensitive and reported honestly. The open question is whether the
concurrent-ask path really stalls or whether these fixtures' signals go blind
during a quiet phase, the same question 3.4b answered for three other waits.

What makes it load-bearing: the commit under test changes only Markdown, so the
code is byte-identical to the tree the merge queue passed at `7adaefd8` less
than three hours earlier. The same code both passes and stalls, which is the
definition of the unmeasured flake rate that issue #160 exists to close. Do not
raise the stall window, add a retry, or quarantine these checks (Decision B).

Evidence: run `33237124406`, `windows-offline`, log line ~1031.

### 3.5 Two quantities sharing one knob

This pattern caused three separate regressions while fixing the above, and is
the thing to watch for in this repository:

- The `slow` stub's lifetime served both "outlive the wall deadline" and "die
  before you starve the next fixture's repository lock". Scaled up, later
  fixtures starved; scaled down, the deadline test lost its race.
- `AI_KIMI_STARTUP_TIMEOUT` (default 60s) served both "how long this machine
  needs to boot a detached worker" and "how long the deadline under test may
  take". Left unscaled it expired first, and the run died of `startup-timeout`
  before the deadline it exists to test could fire.

No compromise value exists when two requirements point in opposite directions.
Separate them.

### 3.6 Why the machine is contended in the first place

`edge-dev` is **not** short of resources — 20 CPUs, 241 GB free disk. The cost is
Windows process startup: every wrapper call spawns several processes before
doing any work, and that multiplies when sessions run concurrently. Measured
cost of one wrapper round trip:

| Condition | Baseline |
|---|---|
| GitHub Actions runner | ~1s |
| edge-dev, one suite | ~15s |
| edge-dev, two suites | 26–72s |
| edge-dev, four-suite storm | 82s |

---

### 3.7 A progress signal that goes blind while the work is healthy

Replacing a frozen-baseline deadline with a stall window only helps if the thing
being watched actually changes while the system is *healthily waiting*. The first
version of `ai_test_fingerprint` measured directory entry counts and file byte
sizes. A Grok wrapper building its review packet creates no file, takes no lock,
and writes no stderr for minutes; it touches and rewrites files instead. That
phase was therefore invisible, and under CI contention it outlasted the
120-second stall window — so three healthy checks were failed and PR #142 was
ejected from the merge queue (run `33144576111`, 2026-08-28).

Two rules follow, both now enforced in `tests/lib-test-timing.sh`:

- **A fingerprint must sense modification time, not only size and count**, and
  should watch the whole tree the fixture works in, not one subdirectory.
- **A wait that gives up must say whether its signal ever moved.** A signal that
  never moved once is a defect in the test and is reported as such; a signal that
  moved and then stopped is a hang in the code under test. Calling both a "stall"
  is what cost this session hours on two disproved diagnoses.

Before using a stall window, name something that demonstrably changes during the
wait. If you cannot, use `poll_until` with a fixed ceiling instead. Never widen a
ceiling to fix this (Decision B).

## 4. Why CI does not protect us here

CI passing is evidence that **an idle single-purpose runner is fast enough to
win every race**, not that the races are gone. Two consequences:

1. A real regression could be masked — the same checks that fail spuriously
   under load could pass spuriously when a genuine bug makes the wrapper
   *faster*, which is precisely what `await_blocks_until_terminal_json` exists
   to catch.
2. Developers could not trust a local run, and the honest response to an
   unexplained `failures=1` after fifty minutes is to rerun — another fifty
   minutes.

---

## 5. What the fix does

Every wait ceiling is now derived from **one measured baseline** taken at suite
start, instead of a hard-coded constant.

- `budget FACTOR FLOOR` never returns less than `FLOOR`, so **on an idle CI
  runner every ceiling keeps exactly the value it had before**. No assertion is
  weaker than it was.
- The baseline is **capped** (default 45s, `AI_TEST_BASELINE_CAP`). Scaling
  exists to survive a busy machine, not to let one inflate the suite without
  limit. Past the cap the suite says so loudly rather than stretching silently.
- Fixed sleeps became condition polls. A poll that exhausts its ceiling prints a
  distinct `fixture:` line naming what never became ready, so "the fixture was
  not ready" can never again be mistaken for "the wrapper misbehaved".
- Preconditions are checked, not assumed: the ask-concurrency block waits for
  the specific session locks by label rather than counting locks globally, and
  selects its target lock by label rather than by `find -print -quit`, which
  returned an arbitrary match and then deleted it.
- Shared helpers live in `tests/lib-test-timing.sh`, sourced by all seven
  reviewer suites, so there is one copy of this logic rather than seven.

**Check counts are unchanged.** Assertion sites, `HEAD` vs now: grok 197, kimi
218, deepseek 65, muse 135, gemini 65, qwen 96, glm 256 — identical in every
file.

---

## 6. Proof the tests can still fail

A green suite proves nothing on its own. Each guarded defect was deliberately
reintroduced and the relevant check confirmed red:

| Injected defect | Check that failed |
|---|---|
| `await_result` returns before a terminal record | `await_result returned too early — the early-return bug is NOT caught` |
| Heartbeat emission silenced | `slow_turn_emits_truthful_bounded_heartbeats` |
| Kimi: any output counts as a terminal record | `message names the terminal record` |

These injections also caught a bug in the fix itself — a precondition poll that
released too early — which is the argument for doing them at all.

---

## 7. Verification results

**Ten consecutive `test-ai-kimi.sh` runs, 203 passed / 0 failed each.** The last
four ran concurrently with `test-ai-grok-review.sh`, which was 191/0 in every one.

Controlled comparison, both suites launched at the same moment on the same
machine: original 190/1, fixed 191/0.

The five swept suites: deepseek 71, gemini 62, qwen 90, glm 244, muse 128 — all
0 failed.

**Assertion counts unchanged in every file** (grok 197, kimi 218, deepseek 65,
muse 135, gemini 65, qwen 96, glm 256), so no coverage was removed.

### 7.1 CI passed a commit with a known-failing check

Worth recording, because it is section 4 demonstrated rather than argued. All
three CI jobs — `linux-offline`, `windows-offline`, `windows-reviewer-safety` —
**passed** on a pushed commit that the local full suite had already failed on
`concurrent refusal starts no second provider turn`.

`main` itself has also failed two of its last four `verify.yml` runs. The
flakiness reaches CI; CI just loses the race less often.

**Do not close a flaky-test issue in this repository on the strength of green
CI.** It is not evidence.

### 7.2 CI cost of this change

Each suite now performs one baseline probe at start — a real wrapper round trip
in the two large suites, 40 process spawns in the other five. Measured effect on
the longest job:

| | `windows-offline` |
|---|---|
| `main`, recent runs | 65-67 min |
| this change | 70 min |

About 3-5 minutes. Relevant to issue #98, which is about that job's duration:
**take its baseline after this merges, not across it.**

### 7.3 Honest limits of this verification

- The clean rounds ran with measured baselines of 9-19s, while the runs that
  originally failed measured 55-72s: other sessions on the machine had quietened
  in between. The concurrency structure was identical but the machine was not as
  loaded. A run under genuinely heavy contention may still hit the cap, and when
  it does the suite says so rather than failing silently.
- **The `durable cancel is worker-confirmed` mechanism is inferred, not proven.**
  It failed roughly one run in six with `cancel-request-unconfirmed`, and the
  fix — giving `cancel`'s confirmation wait the same scaled budget as worker
  startup, which is what the wrapper bounds it by — rests on a plausible story
  about the worker being busy finalizing. Ten clean runs are *consistent* with
  that story without confirming it. The check now prints how long `cancel`
  actually waited against its budget, so a recurrence will settle it.

## 7.4 Carried forward

The `#89` handoff is retired with this change. Its remaining open items did not
belong to this workstream and are now issue
[#125](https://github.com/popcre/ai-devops/issues/125): six `HANDOFF.d/` files
whose issues are closed, and six with no contract block at all.

Its question about whether `edge-dev` has an unrelated resource problem is
answered in section 3.6: it does not.

## 8. Method notes for whoever works on these suites next

- **Never judge `tests/test-all.sh` by a piped exit code.** `bash tests/test-all.sh | tail`
  returns `tail`'s status. Read the `OFFLINE BASH SUMMARY tests=N failures=N`
  line. This produced one false "it passed" report.
- **Never edit a test file while a copy of it is running.** Bash reads a script
  incrementally from disk; the edit corrupts the in-flight run. This destroyed
  three measurement runs. Run from a snapshot copy inside `tests/` (the suites
  compute their repo root from their own path).
- **Do not discard fixture output.** `>/dev/null 2>&1` on a fixture launch hid a
  test that had never worked (3.4). Capture it and print it when the fixture
  fails.
- **Do not create your own storm and then certify against it.** Running four
  suites at once inflated the baseline to 82s and produced failures that did not
  reproduce at realistic load. Useful for finding bugs, useless as a verdict.
