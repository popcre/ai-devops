# GitHub admission congestion repair — October 31, 2026 EDT

Owner: current Codex coordinator under existing programme issue #658. The
incident occurred on edge-dev3 Ubuntu; shared Bash code also runs in Git Bash
on Windows. The first-stage repair and bounded-admission follow-up are
installed on edge-dev3 and Windows al8960ofc (4837 route). Linux observed real
terminal state after the follow-up; Windows then exposed a native cached-path
failure. The cache-preserving correction is now merged and installed on both
hosts; both final-source installed cached waiters observed the real merged
PR. This scoped repair is complete. Full fleet refresh, lower account-wide
demand and comparable-workload acceptance remain separate and are not claimed.

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
runtime or shared machine setting changed during those tests. The existing
Windows ai-gh suite subsequently finished at the same `f4d1794d` candidate:
**280 passed, 0 failed**, including an admission-suite rerun of **6 passed**
in 44.718 seconds. This supersedes the earlier PENDING broad-suite state.

## Merged installation and installed-command proof

The repair landed through [PR #2219](https://github.com/popcre/ai-devops/pull/2219)
at [edfb85ae52fd2be5c8cb499249e846e6e12ea271](https://github.com/popcre/ai-devops/commit/edfb85ae52fd2be5c8cb499249e846e6e12ea271).
Both following installations used that exact merged source. Later unrelated
main commits do not change the source these receipts prove.

**Ubuntu edge-dev3:** the normal installation transaction completed all
required stages and final `install-verify`. The first update encountered
authentication/session-environment prerequisites; the coordinator recovered
through the existing protected credential and user-session routes and resumed
the full installer successfully. No required stage was skipped and no
protection was bypassed. The installed `/usr/local/bin/ai-gh` source hash
matched the merged source. An actual installed-command read of issue #2220
succeeded amid natural caller traffic. Its public-safe receipt is preserved
here so it does not depend on a temporary machine-local file:

```json
{
  "source": "edfb85ae52fd2be5c8cb499249e846e6e12ea271",
  "elapsed_seconds": 119.21,
  "exit_code": 0,
  "stdout": "{\"number\":2220,\"state\":\"OPEN\",\"url\":\"https://github.com/popcre/ai-devops/issues/2220\"}",
  "stderr": ""
}
```

**Windows al8960ofc / 4837:** the full
`install-ai-devops-windows.ps1` transaction completed with exit 0 at the same
merged source. The canonical checkout was clean and pinned to that source.
The real installed `~/.local/bin/ai-gh issue view 2220` returned the issue JSON
with exit 0. Windows elapsed time was not captured and remains **unknown**.
These are first-stage installed-command results, distinct from the
temporary-source tests above and the follow-up waiter proof below.

The useful work originally obstructed by congestion also reached GitHub:
[TokenEconomizer issue #2220](https://github.com/popcre/ai-devops/issues/2220)
exists, and its planning change [PR #2221](https://github.com/popcre/ai-devops/pull/2221)
is merged. That delivers the plan, not TokenEconomizer installation.

## Bounded-waiter gap and follow-up

Ordinary installed reads succeeding did not restore every caller capability.
The normal bounded waiter for PR #2219 still failed reads at elapsed times of
approximately **11, 323 and 635 seconds**, although the PR had already merged.
It used `AI_GH_NO_WAIT=1` with a 10-second lock-admission limit, discarded its
ticket, then rejoined five minutes later. The first-stage fairness repair
could not give a permanently waiting position to a caller that abandoned it.

[PR #2225](https://github.com/popcre/ai-devops/pull/2225) contains the follow-up
at exact tested head
[7ce3954da213a989246306bb9691006d07773eb8](https://github.com/popcre/ai-devops/commit/7ce3954da213a989246306bb9691006d07773eb8).
Its runtime source is unchanged from tested candidate `1446be28`; the later
commit adds the final stream-preservation regression only. It subsequently
merged at
[190dd4e4100a7eceeab59a4f3d79f21ba25ee384](https://github.com/popcre/ai-devops/commit/190dd4e4100a7eceeab59a4f3d79f21ba25ee384).
The normal protected Linux update and full Windows installer both completed
at that exact source with exit 0; required Linux stages passed.

The follow-up keeps default admission for up to **300 seconds**, preserving
explicit shorter or zero admission overrides and immediate recorded-backoff
handling. Actual network calls have their own post-admission timeout through
the existing owned-process-tree supervisor. Genuine backend exits, including
137, remain genuine exits; an owned timeout returns 124 even when the backend
ignores termination. The generic waiter also uses the existing supervisor to
bound admission and execution by the whole remaining deadline. Neither waiter
adds a registry or polls faster than the five-minute floor. No quota, pacing
or secondary-backoff protection is removed.

Qualification results for the unchanged follow-up runtime:

- Ubuntu: `bash tests/test-ai-gh.sh` **280 passed, 0 failed**, including the
  then-current **15 focused cases**; `bash tests/test-ai-pr-wait.sh`
  **101 passed, 0 failed**. The added stdout/stderr/backend-exit-7 case also
  passed separately, giving **15+1 focused cases**.
- Windows al8960ofc / 4837: native Git Bash plus Python 3.14 passed all
  **15 focused cases** at `1446be28` in **109.307 seconds**, exit 0. The added
  `test_timed_backend_output_and_error_exit_are_preserved` case at `7ce3954d`
  passed separately in **6.129 seconds**, exit 0: **15+1 focused cases**.
- The focused cases cover waiting beyond the old 10-second abandonment limit
  for both production defaults, separate post-admission network timing,
  ordinary and GraphQL timeout/cancellation paths, ignored termination,
  natural error exits and streams, explicit zero/invalid settings, and no API
  call starting after the generic waiter's deadline fixture. They also retain
  the original admission, continuing-arrival and stale-ticket cases.

Reproduction: on each OS run `python tests/test-ai-gh-admission.py` from the
candidate. On Windows supply the actual Git Bash executable using
`AI_TEST_BASH="$(cygpath -w "$(command -v bash)")"`; do not select the WSL
launcher. The source is frozen while each run executes. These qualification
results do **not** replace merged installation and a real installed waiter
observing terminal state.

## Installed bounded-waiter result and Windows cache failure

After the #2225 installation, the actual installed Linux
`/usr/local/bin/ai-pr-wait 2225` observed **MERGED** at source
`190dd4e4100a7eceeab59a4f3d79f21ba25ee384` in **94.01 seconds**, exit 0.
All three changed installed runtime scripts were byte-matched to that source
at the start of the proof. This restores a useful Linux completion
observation; it is not a paired speed comparison or final-fix source proof.

The real installed Windows cached waiter failed its first read with
**WinError 193**, rather than observing the already merged PR. This failure is
retained and **excluded from acceptance**. A separate native Python 3.14
probe reproduced the same error when `subprocess.run` was given the selected
Python Bash shim as argv0. Bash could invoke that shim, but native Windows
could not execute it as a Win32 program. The uncached fixtures had not entered
this native cached-spawn branch.

The coordinator cleaned up only the failed proof's own waiter and SSH
transport. No shared cache, held lock or foreign process was removed or
changed, and caching was not disabled to make the error disappear.

## Native cached-interpreter fix

[PR #2229](https://github.com/popcre/ai-devops/pull/2229), exact qualified head
[09287c4fe4c506aa94f6219d5c61bb1ea6e2caf6](https://github.com/popcre/ai-devops/commit/09287c4fe4c506aa94f6219d5c61bb1ea6e2caf6),
resolves the selected compatible interpreter through its own `sys.executable`
before building command arrays. Only `bin/ai-pr-wait` interpreter selection
and its focused regression change. The normal cache, single-flight
coalescing, admission bounds and whole deadline are preserved. The fix merged
at [d36de907ab91414aa54446f1c91aedc8d3292e5c](https://github.com/popcre/ai-devops/commit/d36de907ab91414aa54446f1c91aedc8d3292e5c).
The full protected Linux update completed with exit 0, all required stages
passed and final installation verification completed. The full Windows
installer also completed with exit 0 at that same exact merged source.

The regression supplies a synthetic status context and a Python shell shim,
starts two concurrent waiters, and requires both to observe MERGED from **one
upstream read**. It also verifies that the native cached subprocess uses the
actual interpreter rather than the shell shim. The Linux regression failed
before the fix and passed afterward in **2.638 seconds**. Existing Linux
`bash tests/test-ai-pr-wait.sh` finished **101 passed, 0 failed**. Native
Windows Git Bash/Python 3.14 passed the new cached-coalescing regression in
**11.624 seconds**, exit 0. No unchanged broad suite was repeated for this
two-file fix.

Reproduce from that exact candidate with
`python tests/test-ai-gh-admission.py AdmissionTests.test_python_shell_shim_preserves_cached_status_coalescing`,
supplying the actual Git Bash executable on Windows as described above.
Synthetic-context qualification does not replace the final installed normal
cached-status proof on each host.

## Final-source installed proof

The final installed Linux source was byte-matched to `d36de907` for all three
changed runtime scripts before invoking the actual installed
`/usr/local/bin/ai-pr-wait 2229`. The proof succeeded through normal shared
admission. Its public-safe receipt is retained here:

```json
{
  "source": "d36de907ab91414aa54446f1c91aedc8d3292e5c",
  "elapsed_seconds": 69.87,
  "exit_code": 0,
  "stdout": "PR #2229 MERGED  merge commit d36de907ab91414aa54446f1c91aedc8d3292e5c",
  "stderr": ""
}
```

The actual installed Windows canonical `ai-pr-wait.cmd 2229` ran at that same
exact source, with its runtime SHA-256 asserted against the committed source
before invocation. It returned the actual merged state through the normal
cached-status path:

```json
{
  "source": "d36de907ab91414aa54446f1c91aedc8d3292e5c",
  "elapsed_seconds": 18.43,
  "exit_code": 0,
  "stdout": "PR #2229 MERGED merge commit d36de907ab91414aa54446f1c91aedc8d3292e5c",
  "cache_files_written_since_call_start": 2
}
```

The two file writes were observed in the real production status-cache root,
not a fake context or a replacement cache. This is evidence the normal cached
path worked; it is not a cache-hit rate or upstream-request count. Caching was
not disabled. Together with the successful full installers and Linux proof,
this completes the scoped repair's installed capability acceptance on both
proved operating systems.

## Remaining long-term mitigation and acceptance

A historical source-path snapshot after the first-stage installation found
paths for **8 active callers** matching file hash prefix `4e15c1cd4459` and
paths for **3 active callers** matching the old prefix `65d5203b04b6`. This
inventory read source files associated with process paths; it did **not**
prove the Bash source bytes each already-running process had loaded. The
snapshot was not refreshed for later follow-ups and is not a current fleet
inventory or a promise that all future calls use the final source.
Existing old jobs were retained; their running checkout was not overwritten.
Both generations share the original safety mutex, but only upgraded callers
honor ticket order.

The durable changes are FIFO admission against continuing arrivals,
branch-filtered cleanup scans against unnecessary unrelated PR pages, retained
bounded-waiter admission with separately supervised network calls, and native
interpreter selection that preserves cached coalescing on Windows. Do not
undo quotas, split shared-principal budgets, disable automated fixing or add
an unapproved global coordinator to remove the symptom. Continue the existing
source-reduction programme under #658 and its linked
[remaining-traffic plan](../../../plan_cut-unneeded-github-traffic.md).

The current #658 coordinator still owns these acceptance items:

1. Let old active jobs finish normally and verify subsequent runner/toolkit
   checkouts through their supported refresh route; do not edit a Bash source
   file while a process is executing it. Inventory other applicable installed
   hosts before claiming full fleet adoption.
2. Measure useful-work wait time and quota/probe demand during comparable
   natural mixed-credential workloads after adoption. The installed Linux
   results of 119.21, 94.01 and 69.87 seconds, the Windows final result of
   18.43 seconds, and the earlier candidate write of 108.05 seconds involve
   different operations, source versions, hosts and workloads. They are **not
   a paired comparison**, show no proved latency improvement, and do not
   establish that congestion is cleared or whole-account traffic has fallen.

Keep the remaining programme `live proof` checklist on the same #658 issue.
Do not close the broader #658 programme from this repair. No API requests are
generated solely to manufacture savings or a favorable latency comparison.
