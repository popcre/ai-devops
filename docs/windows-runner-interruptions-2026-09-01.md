# Windows CI runner interruptions — evidence log, 2026-08-29 to 2026-09-01

Written during the Context7 / token-tooling session. This file records only what
was observed and verified through the GitHub API, plus the mechanisms those
observations support. It is an investigation input, not a fix.

## Setup that matters

- `verify.yml` runs three jobs. `linux-offline` runs on GitHub's cloud
  (`ubuntu-24.04`). `windows-offline` and `windows-reviewer-safety` both run on
  `[self-hosted, Windows, X64, edge-dev]`.
- Exactly two self-hosted runners exist: `edge-dev-win` and `edge-dev-win-2`.
  Both are on the `edge-dev` machine, which is also a machine AI sessions work
  on directly.
- `windows-offline` takes about 60-75 minutes (`timeout-minutes: 75`).
  `windows-reviewer-safety` takes about 15-30 minutes (`timeout-minutes: 30`).
  `linux-offline` takes about 10 minutes.
- The workflow sets `cancel-in-progress: true`, keyed on the pull request head
  SHA or, for other events, on `github.sha`.

Two runners, two Windows jobs per run, an hour per long job, and several AI
sessions pushing at once. That is the shape of the problem.

## Observed interruptions

Every row below was read from the Actions API during this session.

| Run | Event | Job killed | Runner | Elapsed before death |
|---|---|---|---|---|
| 33467918585 (pr-197 queue) | merge_group | `windows-offline` cancelled | edge-dev-win-2 | 75 min |
| 33486858691 (pr-197 queue) | merge_group | `windows-offline` **failure, exit -1** | edge-dev-win-2 | 31 min |
| 33486858691 (same run) | merge_group | `windows-reviewer-safety` cancelled | edge-dev-win | 30 min |
| 33345342011 (pr-191 queue) | merge_group | `windows-offline` cancelled | edge-dev-win | 75 min |
| 33343417980 (pr-191 queue) | merge_group | `windows-offline` cancelled | edge-dev-win-2 | 37 min |
| 33448368014 | pull_request | run cancelled | — | — |
| 33325004441, 33316230728, 33284691726, 33237103210 | push main | run cancelled | — | — |

`linux-offline` succeeded in every one of those runs. Not a single cloud job was
ever interrupted. The interruptions are exclusive to the two self-hosted Windows
runners, and they land overwhelmingly on the long job.

## Mechanism 1 — merge-queue regrouping cancels the run in flight (confirmed)

This is the dominant cause, and this session's own history documents it end to
end. PR #197 was queued four separate times:

1. Queue run `pr-197-5dd46b59` started 03:54, cancelled at 05:24 after 75
   minutes. Another session's PR #194 was batched ahead of it; #194 merged,
   #197 did not.
2. Queue run `pr-197-a3c899b9` started 08:24, died 08:55 (see mechanism 3).
3. Queue run `pr-197-23324c75` queued 11:04, superseded within ten minutes when
   PR #202 merged.
4. Queue run `pr-197-90b45b8a` queued 11:14.

Each time any other session merges anything, the queue rebuilds the group on a
new base commit, cancels the in-flight run, and restarts the 60-75 minute
Windows job from zero. Roughly three hours of runner time went into this one
PR without producing a merge. PR #191 shows the same pattern a day earlier: two
cancelled queue runs, 00:03 and 00:42.

The concurrency key makes this worse rather than better. For `merge_group`
events the key falls through to `github.sha`, so two runs for the same group
SHA cancel each other directly.

**This is not a runner fault.** The runner is being told to stop. But the effect
on a busy repository with an hour-long Windows job is that the long job may
never finish, because the gap between two sessions' merges is shorter than the
job itself.

### The documentation-merge trap (confirmed, and self-inflicted in this session)

The repository rule for documentation-only pull requests is: merge immediately,
do not wait for checks, because prose cannot break a build. That rule is about
**not waiting**. It does not mean no build starts, and it does not mean the merge
is free.

Merging *anything at all* — including a prose-only change merged with
`--admin` in under a second — rebuilds the merge queue on a new base commit and
cancels whatever is currently running inside it. The hour-long `windows-offline`
job then restarts from zero.

This session demonstrated it on its own work. Three of PR #197's four queue runs
were killed by documentation merges made from this very session:

- `pr-197-23324c75` — superseded when PR #202 (`AGENTS.md`, prose) merged.
- `pr-197-72e4c327` — superseded when PR #203 (this document, prose) merged.
- `pr-197-90b45b8a` — superseded when PR #205 (a handoff file, prose) merged.

So the two rules interact badly. "Documentation merges are free, ship them
immediately" is true for the person merging and false for the repository: each
one costs whoever is in the queue up to an hour of runner time and can prevent a
code change from ever landing on a busy day.

The practical consequence for any session: **before merging a documentation-only
change, check whether anything is sitting in the merge queue.** If something is,
either wait for it or accept — knowingly — that you are restarting its build.

```bash
gh run list --repo popcre/ai-devops --limit 10 --json status,headBranch
```

Anything whose branch starts with `gh-readonly-queue/` and is not `completed` is
a build you are about to kill.

## Mechanism 2 — only two runners for two Windows jobs (confirmed)

In run 33467918585, `windows-reviewer-safety` occupied `edge-dev-win-2` from
03:54:53 to 04:09:05. `windows-offline` did not start until 04:09:06 — on that
same runner. It waited fifteen minutes for a slot, then still had to run its
full hour, finishing well inside a window where a competing merge could kill it.

Two runners cannot absorb concurrent PR runs, push-to-main runs, and merge-queue
runs from several sessions. Queueing stretches wall-clock time, and longer
wall-clock time means a larger chance of being cancelled by mechanism 1.

## Mechanism 3 — abrupt process death, exit code -1 (unexplained)

Run 33486858691 is the one that does not fit the cancellation pattern cleanly.
`windows-offline` did not report `cancelled`; it reported **`failure`** with
`Process completed with exit code -1` at 08:55:51, mid-suite, after individual
tests had been passing normally. `-1` is a killed process, not a test assertion.
At virtually the same moment, 08:54:39, `windows-reviewer-safety` on the *other*
runner was cancelled.

Two jobs on two different runners dying within ninety seconds of each other
points at something machine-wide rather than per-job: a queue cancel arriving
while the shell was mid-run, resource exhaustion, or an unrelated process on
`edge-dev` killing the test processes.

This matters because it is **indistinguishable from a real test failure in the
UI**. A cancelled job is obvious; a `-1` failure looks like broken code and
sends someone chasing a bug that does not exist. It did exactly that in this
session before the job steps were inspected.

## Mechanism 4 — local test runs on edge-dev (contributing, previously known)

`edge-dev` hosts the runners *and* is worked on directly by AI sessions. A local
full test sweep started on that machine kills the running CI job. This was
already recorded in earlier sessions' notes as "local run cancels live CI", and
it reports as `cancelled`, not as a failure.

Earlier in this session two full local test sweeps were run on `edge-dev` while
measuring token tooling — one raw sweep of about twelve minutes, and one wrapped
sweep that hung for about seventy minutes before being abandoned. Both ran on
the machine hosting the runners. Which specific CI runs they collided with
cannot be proven from the API, and they are not being claimed as the cause of
the 2026-09-01 queue cancellations, which have a separate documented cause. But
it is the same failure mode and should be ruled in or out.

A guard rule was added to `AGENTS.md` in PR #202: do not start a local full
sweep on `edge-dev` while a GitHub run is active.

## Mechanism 5 — throughput: the repository asks for more runner time than it has (confirmed)

This was not in the first version of this log and it may be the most important
number in it.

Measured at 2026-09-01 11:30Z: **16 runs were pending at once** — 6 `merge_group`,
5 `pull_request`, 5 `push`. Every one of those runs needs **two** Windows jobs,
and both self-hosted runners were `busy=true`.

Do the arithmetic:

- `windows-offline` takes about 60–75 minutes. `windows-reviewer-safety` takes
  about 15–30 minutes. That is roughly **1.5 hours of Windows runner time per
  run**.
- 16 pending runs is therefore about **24 hours of serial Windows work**, spread
  over two runners — most of a day of backlog, with more arriving.
- A runner executes one job at a time. There is no parallelism beyond the two
  machines.

**And a single merge creates three runs, not one.** Merging one pull request fires
a `pull_request` run, a `push` run on `main`, and a `merge_group` run. Each of the
three drags two Windows jobs behind it. Six Windows jobs, roughly four and a half
hours of runner time, for one merge of one file.

That is the underlying condition. Mechanisms 1 through 4 are what happens *to* a
job; this is why there are always so many jobs in flight for something to happen
to. A queue that is saturated also means every job sits waiting longer before it
starts, which widens the window in which a regroup can cancel it. The
cancellations and the backlog feed each other.

## Mechanism 6 — both runners live on one machine (structural risk, not yet a measured failure)

`edge-dev-win` and `edge-dev-win-2` are two runner services on the **same physical
machine**, `edge-dev`. This has three consequences the log should state plainly:

1. **No redundancy.** If that machine sleeps, reboots, loses its network, or has
   its runner service stopped, the repository has *zero* Windows CI. There is no
   second host to fall back to. The cloud `linux-offline` job would keep passing,
   which makes the outage look partial rather than total.
2. **The two runners compete for one machine's CPU, disk and memory.** When both
   run simultaneously — the normal case, since every run needs both — the test
   suites are sharing one box. This repository's test suites are known to be
   timing-sensitive; earlier sessions recorded flakes caused by machine slowness
   and by environment conditions rather than by code. A job slowed by contention
   is a job closer to its timeout.
3. **The machine is also a daily working machine** (mechanism 4). Its spare
   capacity is whatever the humans and AI sessions on it are not using at that
   moment.

## Timeout headroom is thin (confirmed from the workflow)

`windows-offline` is capped at `timeout-minutes: 75`. The workflow's own comment
records the suite measuring about 62 minutes. The successful PR #197 run took
**1h 3m 51s**. That is roughly 15% of headroom.

Under contention — two jobs on one machine, plus local work — a suite that
normally finishes in 63 minutes does not need to slow down much to hit 75. A
timeout is reported as a **failure**, not as a capacity problem, so it will look
like broken code. Nothing currently distinguishes the two in the interface.

## There is no retry, and no alert

- A cancelled or killed run is **not** retried automatically. Someone — a human or
  an AI session — has to notice and re-queue it. PR #197 was re-queued by hand
  four times; had nobody been watching, it would simply have sat OPEN forever.
- Nothing alerts on repeated cancellations. The pattern in this document was found
  only because a session was actively babysitting one pull request.
- A merge-queue ejection **leaves the pull request OPEN**, so any automation that
  waits on pull request state alone waits forever. This was already known from
  earlier sessions and it bit this one again.
- Polling the API aggressively to watch runs (`gh run watch`, tight loops) can trip
  a secondary rate limit that returns 403 on every Actions call *while the quota
  endpoint still reports a full allowance*. Poll on the order of a minute, not
  seconds.

## Failure states are not distinguishable from each other

This is the reporting problem that ties the whole document together. All four of
these appear differently in the interface than what they actually are:

| What really happened | How it is reported |
|---|---|
| Queue regrouped and cancelled the run | `cancelled` — clear, and correct |
| Process killed mid-suite (run 33486858691) | **`failure`** — looks like broken code |
| Suite exceeded 75 minutes under contention | **`failure`** — looks like broken code |
| Local sweep on `edge-dev` killed the job | `cancelled` — clear, but the cause is invisible |

Two of the four masquerade as test failures. Until that is fixed, every red
Windows job in this repository has to be opened and inspected step-by-step before
anyone can say whether the code is actually broken — which is exactly the wasted
investigation this session performed.

## What this adds up to

The runners are probably not "dying" in the hardware sense. What is happening:

1. Merge-queue regrouping repeatedly cancels hour-long Windows jobs, so on a
   busy day a PR can burn hours of runner time and still not merge.
2. Two runners cannot serve the concurrent load, which stretches every job and
   widens the window for (1).
3. At least one death was an abrupt kill reported as a test failure, which is
   actively misleading.
4. Local work on the runner host can kill live CI, and that host is in daily use.
5. The repository asks for more Windows runner time than two runners on one
   machine can supply, so everything queues and stays exposed for longer.
6. Two of the four ways a job dies are reported as test failures, so red is not
   evidence of broken code here.

## Open questions for the investigation

- Why exit `-1` in run 33486858691, and why did a job on the *other* runner die
  within ninety seconds? Runner service logs on `edge-dev` for 2026-09-01
  08:54-08:56 would settle this; the API cannot.
- Should `merge_group` be excluded from `cancel-in-progress`, so a queue run
  that has already spent forty minutes is not thrown away?
- Should documentation-only merges be held while the queue is busy, or should
  the queue simply not run the hour-long suite so prose merges stop costing an
  hour of somebody else's build?
- Should the hour-long `windows-offline` suite run in the merge queue at all, or
  only on the pull request, given the queue re-runs it on every regroup?
- Can the Windows suite be split or parallelised so no single job runs for an
  hour? An hour is longer than the typical gap between two sessions' merges,
  which is the structural reason this keeps repeating.
- Can a killed or timed-out job be made visually distinct from a real test
  failure, so nobody investigates a phantom bug again?
- Should cancelled queue runs be retried automatically, and should repeated
  cancellation of the same pull request raise an alert?
- Does a second Windows host exist or can one be added? Today a single machine
  sleeping takes all Windows CI down with it.
- Do the two runners belong on a machine that is not also a daily working
  machine?

## How to reproduce the evidence

List recent runs and their conclusions:

```bash
gh run list --repo popcre/ai-devops --limit 40 --json databaseId,status,conclusion,headBranch,createdAt,event
```

Then inspect the jobs of any run id, including which runner served each job:

```bash
gh api repos/popcre/ai-devops/actions/runs/33486858691/jobs
```
