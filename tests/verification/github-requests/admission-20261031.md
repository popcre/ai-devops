# GitHub admission congestion repair — October 31, 2026 EDT

Owner: Codex congestion subagent under existing programme issue #658. Occurred
on edge-dev3 Ubuntu; shared Bash code also runs in Git Bash on Windows. Windows
must be proved separately before claiming cross-platform acceptance.

## Observed failure and boundary

The parent had foreground calls time out after 120 seconds acquiring the
mutex. A 15-second local observation during investigation counted four distinct
holders and four credential-context switches; maximum observed holder age was
10 seconds. Sampled holder children were pacing sleeps, not stalled GitHub
calls. No held lock or foreign process was removed. The old acquisition loop
was an unordered `mkdir` race, so continued arrivals could overtake old waiters.

Credential-context switching can also cause quota refresh requests. This
repair does not weaken that conservative accounting, invent independent
per-token quotas or remove any primary/secondary rate protection.

## Changes and checks

- `bin/ai-gh` adds private, timestamp-ordered admission tickets ahead of its
  existing reservation mutex. New arrivals are ordered after visible tickets
  even when wall time moves backward; simultaneous creation has a stable
  suffix tie-break. Waiting tickets heartbeat; abandoned tickets expire using
  the existing staleness interval, without unreliable Windows PID tests.
  Cancellation removes only the caller's ticket. Original reservation locking
  still enforces safety with old clients that do not understand admission.
- `tools/ci/review-fixer-state.py` was the concrete repeated full-open-PR scan
  source. Cleanup planning/retirement now ask GitHub for the known base branch;
  scheduled all-target sweeps and collision inventory retain complete scope.
  This reduces unrelated pages when repositories have many PRs; no measured
  account-wide savings percentage is claimed.
- Run `bash tests/test-ai-gh.sh`: existing suite completed **280 passed,
  0 failed**, including subprocess admission tests. Final exact-source Ubuntu
  rerun also completed **280 passed, 0 failed** on candidate `f4d1794d`.
- Run `python3 tests/test_review_fixer_state.py`: **55 tests passed**,
  including encoded base-filter and unchanged full-scope tests.
- Run `python3 tests/test-ai-gh-admission.py`: **6 tests passed**, covering
  old waiter versus continuing arrivals, cancellation, hard-kill expiry,
  stale ticket versus held mutex, backward wall time, and escaping symlink.

The subprocess test is part of the existing Bash suite. On Windows the Bash
suite passes its own `cygpath`-resolved Git Bash executable to native Python;
the fixture does not accidentally select Windows' WSL launcher.

## Live qualification and remaining acceptance

A candidate-source read of `repos/popcre/ai-devops/issues/658` returned
`{"number":658,"state":"open"}` through the real shared throttle while runner
traffic continued. It proves a real request traversed the candidate; it does
not prove installed FIFO fairness, because existing runners still use old
unordered copies. A previous source read was invalidated by editing the Bash
script while that process was waiting; its syntax failure is excluded from
qualification. Freeze source before invoking a long-lived Bash process.

A timed useful write through the frozen candidate posted the
[#658 ownership receipt](https://github.com/popcre/ai-devops/issues/658#issuecomment-6551308879)
in **108.05 seconds**, including shared admission wait. This is a real
successful foreground operation, not proof the congestion is resolved or a
matched before/after improvement.

The parent verified immutable candidate `f4d1794d` on Windows host al8960ofc
(4837 route), using Git Bash `bin/bash.exe` and native Python 3.14 in an owned
temporary source archive. All **6 admission tests passed** in 44.439 seconds,
and all **55 fixer lifecycle tests passed**. The admission wrapper supplied its
actual Git Bash executable and signalled recorded MSYS PIDs. No installed
runtime or shared machine setting changed. The existing Windows ai-gh suite
is still pending; do not claim that outcome from the smaller fixture suites.

Still required on #658: full focused Windows ai-gh suite, exact merged candidate install,
all active runner/toolkit copies refreshed by their supported route, and a
timed foreground request amid natural mixed-credential traffic. Measure useful
work latency and probe counts before/after; never infer savings from narrower
source alone. No API requests are generated solely to manufacture savings.
Queue fairness is guaranteed only among upgraded callers; during rollout old
clients still share the same safety mutex and can overtake tickets.
