# Windows runner interruptions — 2026-09-01

**Scope:** issue #160 closeout on `EDGE-DEV`, from the inherited PR #193
failure through the clean final local proof on 2026-09-01. Times are UTC.

## Executive summary

No single event explains the delays. Four different conditions occurred:

1. Smart App Control prevented the official GitHub runner executable from
   loading. This was a real runner-start failure, repaired by setting the
   explicitly authorized machine policy to Off after making a recoverable
   backup. Source automation for that permanent setup remains issue #200.
2. Many pull-request, merge-queue, and post-merge `main` runs competed for two
   runner registrations on one physical computer. Queued jobs were waiting for
   capacity; the runner had not died.
3. Local reviewer suites and GitHub jobs use the same process names and machine
   resources. One inherited local diagnostic overlapped CI and was therefore
   invalid as evidence. A later local attempt started five seconds before a new
   merge-queue run appeared; both sides became untrustworthy and the local
   process tree was deliberately stopped and scoped cleanup was verified.
4. GitHub's merge queue repeatedly generated replacement merge-group runs when
   the queue changed. A replacement run is new work competing for `EDGE-DEV`;
   it does not prove that a runner died or that another AI session explicitly
   killed the older job.

The valid final local proof ran from `2026-09-01T09:26:12Z` through
`2026-09-01T10:29:45Z`, while GitHub's Windows runners were idle. It passed all
61 Bash suites and all 17 PowerShell suites, including Grok 199/199 and Kimi
207/207. The next GitHub Windows job began at `10:37:41Z`, after the proof had
finished, so there was no overlap.

## What `EDGE-DEV` and “released” mean

`edge-dev-win` and `edge-dev-win-2` are two GitHub runner registrations, but
both execute on the same physical Windows computer. They were added so
`windows-offline` and `windows-reviewer-safety` could run in parallel. They do
not provide physical isolation from one another or from a local terminal.

In this session, “wait for another session to release EDGE-DEV” meant: wait
until every GitHub Windows job from other pull requests, merge groups, and
`main` pushes was terminal and no local test series was using the shared
machine. No person or AI session holds an explicit lease, and nobody needs to
click a release button. The earlier wording “the other session” was too vague:
there were several independent branches and GitHub-generated runs.

## Timeline and evidence

### 1. PR #193 exposed a real fixture lifetime defect

PR #193 run `33419491770` tested remote head `3ca8ad7`. `linux-offline` and
`windows-reviewer-safety` passed. `windows-offline` ran from
`2026-08-31T20:50:22Z` to `22:04:59Z` and failed
`uncertain_ask_blocks_its_exact_retry` rather than reaching a generic workflow
timeout.

The log showed the fixture owner lived 243 seconds: packet preparation plus the
intentional 150-second silent interval exceeded its 240-second test lease. The
wrapper correctly treated the expired owner as invalid. Commit `1b4e5dd`
changed only the held test owner's lease to 480 seconds. It did not change the
challenger bound, production timeout, silent interval, or assertion.

An earlier PR #193 Windows attempt had been cancelled around its 75-minute job
ceiling. That cancelled attempt is not acceptance evidence and was not treated
as a product failure.

### 2. Smart App Control made both runner registrations unable to start work

Code Integrity events 3077 and 3033 attributed the block to the signed
`VerifiedAndReputableDesktop` Smart App Control base policy. An unsigned narrow
supplemental allow policy was rejected with `IsAuthorized:false`; it was
removed, and no supplemental policy was left active.

The Code Integrity registry state and active policy files were backed up under
`C:\ProgramData\ai-devops\backups\smart-app-control-<timestamp>`. Albert had
explicitly authorized Smart App Control Off for this runner machine, so
`VerifiedAndReputablePolicyState` was set to `0`. Afterward,
`Runner.Listener.exe --version` succeeded at 2.337.0 and both registrations
reported online.

This was a real load/start failure, not queue congestion. Smart App Control has
no supported arbitrary local path/hash whitelist, and it cannot be turned back
on without Windows reset/reinstall. Issue #200 owns the permanent, backed-up,
idempotent Windows setup and verification work; it remains separate from #160.

### 3. The inherited durable Bash diagnostic overlapped GitHub CI

The inherited diagnostic wrote `.ai/issue-160-bash-rerun.log`. It began at
approximately `2026-08-31T23:45Z`. During the early resumption, the log appeared
to stop in `test-ai-grok-review.sh` and no terminal summary was yet visible.
Later file evidence showed the process had continued and eventually printed
`OFFLINE BASH SUMMARY tests=61 failures=0` at approximately
`2026-09-01T01:19Z`.

GitHub Windows jobs were active during that interval, including runs
`33449336803`, `33449373129`, `33450901116`, and `33450914863`. Therefore the
61/61 result is diagnostic only. It cannot prove #160 because local and CI
reviewer suites shared the same process names, locks, CPU, disk, and runner
host. The initial statement that this process was already dead was corrected by
the completed durable log; the safe conclusion is that it was still running but
could not be trusted because it overlapped CI.

### 4. Backlog from other branches and GitHub-generated events

The session waited while Windows work arrived from several independent sources:

- `claude/headroom-prompt-cache-2be961`, run `33449336803`;
- `claude/context7-mcp-da99de`, run `33449373129`;
- `codex/reviewer-problem-solving-plan-198`, run `33450901116`;
- the resulting `main` push, run `33450914863`;
- PR #197 merge-group runs `33467918585`, `33486858691`, and `33498373084`;
- PR #194 merge-group runs `33471361468` and `33473504993`;
- another post-merge `main` push, run `33479765150`;
- later reviewer-plan correction and queue runs `33500542035`, `33500550342`,
  and `33500571669`.

Some entries were ordinary pull-request work created by another AI session.
Others were created automatically by GitHub after a merge or when the merge
queue rebuilt its speculative head. All consume the same two registrations.
A queued job means capacity is unavailable; it does not mean its runner is dead.

### 5. First final local attempt collided with a new merge-group run

The first final local attempt wrote
`.ai/issue-160-final-full-2be4a7b.log` and began at
`2026-09-01T08:24:18Z` after a live check found no Windows job active. GitHub
created PR #197 merge-group run `33486858691` five seconds later, at
`08:24:23Z`; both Windows jobs started at `08:24:26Z`.

At `08:54Z` the overlap was discovered while the local run was in the Grok
suite. The local run was interrupted deliberately. The first interrupt did not
immediately remove every descendant, so the remaining pre-`08:55Z` local test
tree was identified by exact PID, parent relationship, start time, and test
identity, then stopped. Processes that began with the GitHub job were not
touched.

Run `33486858691` subsequently recorded:

- `linux-offline`: success;
- `windows-reviewer-safety`: cancelled at `08:54:39Z`;
- `windows-offline`: failure at `08:55:54Z`;
- overall merge-group run: cancelled.

The timing and shared process boundary make local/CI collision the leading
explanation, but the available evidence does not prove which local process
caused each CI terminal state. The conservative treatment is stricter: count
neither the partial local run nor either Windows job as #160 evidence. A
`cancelled` conclusion means the job did not complete; it is not a pass and is
not automatically a product defect.

### 6. Second final attempt completed in an uncontended window

After every live Windows job became terminal, the second attempt wrote
`.ai/issue-160-final-full-2be4a7b-attempt2.log` and ran exact commit
`2be4a7bf844cb1b038a170d04b7538f1a3c58f35` from
`2026-09-01T09:26:12Z` through `10:29:45Z`.

It completed with:

- Bash: 61 suites, zero failures, 3,773 seconds;
- PowerShell: 17 suites, zero failures;
- Grok: 199 passed, zero failed;
- Kimi: 207 passed, zero failed;
- overall exit: zero.

PR #197 merge-group run `33498373084` did not start its Windows jobs until
`10:37:41Z`, eight minutes after the local proof ended. This is the first final
run in this session that satisfies both completeness and isolation.

## How to interpret runner states

- **Queued:** waiting for a matching runner. The runner may be busy or unavailable;
  the job itself has not started.
- **In progress:** GitHub assigned a runner and the job has started. Local
  reviewer suites must not run on `EDGE-DEV` at this time.
- **Cancelled:** the job did not finish. It may have been superseded, stopped by
  GitHub/queue policy, or had its process terminated externally. It is never a
  pass and is not enough by itself to identify a code defect.
- **Failure:** the job reached a failing step. Read that step and its timing; do
  not assume the runner died. PR #193's 243-second fixture result was a real,
  diagnosable failure.
- **Runner offline with `Runner.Listener` still alive:** often heartbeat
  starvation from machine saturation. Reduce load before re-registering.
- **Runner process absent or blocked by Code Integrity:** a real runner-start or
  process-lifetime problem. Smart App Control caused this condition here.
- **Merge-group replacement:** a new speculative commit and new workflow run
  because the queue changed. The older result may become irrelevant even when
  no runner malfunction occurred.

## Operating rules established by this session

1. Before any local reviewer or full-suite run, inspect every nonterminal
   `windows-*` job, not merely PR #193.
2. A one-time idle observation is not a reservation. Recheck periodically during
   long local runs and stop only the local PID tree if GitHub work appears.
3. Never terminate by process name. Local and CI tests deliberately use the same
   executables and names.
4. Preserve durable logs, but count a result only when it has a terminal summary,
   exit zero, exact source identity, and no runner overlap.
5. Do not raise timeouts, delete assertions, allow failures, or retry until green.
   Diagnose the exact readiness, lease, or process-lifetime boundary.
6. Treat two registrations on one host as one shared failure domain. Issue #161
   must serialize every EDGE-DEV Windows job through a shared job-level
   concurrency group with cancellation disabled.
7. Required checks need an always-reporting fast classifier. Top-level
   `paths-ignore` can leave a required context waiting forever.
8. Merge-group, scheduled, and manual events must retain complete coverage; a
   manifest must account for all 61 Bash and 17 PowerShell suites exactly once
   before later phases narrow platform or local selection.
9. Do not restore Smart App Control or the rejected unsigned supplemental policy.
   Complete issue #200 independently with backup, idempotence, listener-load
   proof, disposable Windows proof, and the irreversible-until-reset warning.

## Related records

- PR #193 and issue #160;
- issue #200 for durable Smart App Control setup;
- [`self-hosted-windows-runner.md`](self-hosted-windows-runner.md);
- [`critical-incidents.md`](critical-incidents.md), 2026-08-28 local-series
  cancellation incident;
- [`../tests/verification/reviewer-reliability/issue-160-determinism.md`](../tests/verification/reviewer-reliability/issue-160-determinism.md).
