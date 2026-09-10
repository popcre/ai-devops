# Issue #164 — merge-queue convergence

## What was wrong

Issue #204 took the long Windows jobs off `merge_group` and removed
`windows-offline` from the ruleset's required contexts, because a required check
that never reports on a merge group hangs every entry for the full 120-minute
`check_response_timeout_minutes`. The trade worked, but it left the Windows and
reviewer proof resting on an assumption: that the pull-request run on the exact
queued head commit existed, matched that commit, finished, and passed. Nothing
checked any of it. A change whose Windows verification never ran, ran against an
earlier commit, or ran and failed could still reach the queue and merge on a
green Linux gate alone.

## Measured before changing anything (2026-09-10)

Merge-group `verify` runs, last 100 (window 2026-08-27T23:31Z to
2026-09-10T03:35Z):

| conclusion | n | median | p90 | max |
|---|---:|---:|---:|---:|
| success | 69 | 11.7 min | 123.1 min | 179.5 min |
| failure | 11 | 151.3 min | 170.2 min | 208.3 min |
| cancelled | 18 | 85.0 min | 118.8 min | 212.4 min |

The long tail is entirely pre-#204. Restricted to merge-group successes created
on or after 2026-09-03, when the concurrency fix was live: **n=41, median 10.6
min, p90 12.3 min, max 12.6 min**. The acceptance target for the compatibility
gate is p90 under 15 minutes; it is already met, and the new gate below is
seconds of API reads, not another suite.

Rebuild counts confirm the same boundary. Across the 100-run window the repeat
offenders are all older entries — PR 197 rebuilt 11 times, 129 six, 134 and 135
five each. Of the 25 most recently merged pull requests, only two saw more than
one merge-group run, and none was overtaken indefinitely.

Time in the queue, separated from time spent authoring and reviewing, using each
pull request's `added_to_merge_queue` timeline event:

| statistic | queue time |
|---|---:|
| median | 13.1 min |
| p90 | 13.4 min |
| p95 | 17.0 min |

n = 12 of the 25 most recent merges; the other 13 carry no merge-queue event at
all and merged within seconds of creation, which is the documentation fast path,
not a queue measurement.

Open-to-merged p95 over the same 25 is 404 minutes, and that number does **not**
describe the queue. Splitting it per pull request shows the queue contributing
13 to 21 minutes in every case, with the remainder spent open while a session was
still authoring, verifying and reviewing — 2065 minutes on PR #330, 397 on #353.
The issue's own constraint says faster tests do not by themselves prove this
fixed; the converse holds too, and slower authoring is not a queue defect. The
queue-time p95 of 17.0 minutes is the honest measurement against the 60-minute
target, and it passes.

Ejections: 5 across the 25, on three pull requests (#353 three, #339 one, #330
one). Each was a real failing run, not a starvation rebuild.

## What changed

`bin/ai-merge-group-evidence`, run by a new `merge-group-evidence` job in
`verify.yml`. From inside a merge-queue run it reads the pull-request number out
of the `gh-readonly-queue/main/pr-<N>-<sha>` ref, resolves that pull request's
head commit, and refuses to pass unless:

- one GraphQL snapshot shows both the PR's current head and its live
  merge-group commit, and the latter equals the workflow commit. GitHub rebuilds
  the entry when the PR head changes, so the exact PR head read in that same
  snapshot is the one whose verification must be checked. Squash merge groups
  have one parent and a new tree, so the PR head is not an ancestor;
- a `verify.yml` run on event `pull_request` exists for that exact commit;
- every such run has finished and concluded `success` — an in-progress run is not
  evidence, and an older failing run on the same commit still rejects;
- the named required jobs concluded `success` in it, currently
  `windows-offline` and `windows-reviewer-safety`. `skipped` is rejected, not
  read as success.

Exit 2 is reserved for configuration and usage errors so a broken invocation can
never be mistaken for a pass. The job runs on every event: outside a merge group
it prints that it does not apply and passes in seconds, so the context reports on
both pull requests and merge groups. A context silent on one event reproduces
#204 in one direction or the other.

`config/ci-suite-manifest.json` gains the new suite in the plain `bash` lane; it
is offline and platform-neutral, so it changes no Windows section balance. All
four sections still reconstitute the lane exactly (`--shard i/4 --list` exits 0
for i in 1..4).

## Assertions

`tests/test-ai-merge-group-evidence.sh` — 16 passed, 0 failed. Every branch above
has a case, driven by stub `gh` and `git` commands; nothing contacts GitHub.

`tests/test-workflow-policy.sh` — three new assertions bind the wiring: the job
and script must be present, both Windows lanes must be named as required, and
the job must not be gated to `merge_group` only. Against `origin/main`'s
`verify.yml` all three fail (`grep -c 'merge-group-evidence:'` returns 0), which
is what makes them worth keeping.

## Real merge-group shape and rejected ancestry rule

The exit code was captured directly, without a pipe, against two completed real
merge groups. PR #364 head `162df0ac` versus group `c0c42012` returned ancestry
exit **1**; PR #363 head `bd8e9d3a` versus group `3db8620e` also returned **1**.
Each group had exactly one parent (the then-current `main`), while
`git merge-tree --write-tree <parent> <pr-head>` produced the exact tree stored
by the group commit. The old check therefore rejected valid squash groups.

Run `34437374341` then exercised the first proposed correction against a live group.
It proved the REST commit-to-pulls endpoint is empty while the synthetic commit
is still queued, returning exit 1 rather than a false pass. The final gate uses
one live GraphQL snapshot: `pullRequest.headRefOid` is the PR head and
`mergeQueueEntry.headCommit.oid` is the synthetic group commit. The latter must
equal the workflow's `github.sha`; GitHub then rebuilds the entry if the former
changes. Run `34439264770` proved the intermediate interpretation was also
fail-closed: it correctly returned exit 1 instead of treating the synthetic
group SHA as a PR head. The entry was explicitly dequeued before its non-required
failure could be ignored by the current ruleset.

Run `34440507656` was the genuine injected-failure demonstration on real group
commit `3d42a82b`. A temporary `injected-failure-proof` job requirement made the
evidence job exit 1, and a temporary dependency made `linux-offline` skip. This
proved the live gate and downstream refusal reacted without running another
suite. GitHub nevertheless landed the queued commit because
`merge-group-evidence` is not a required context until #166 and this ruleset
accepted the skipped Linux context. The injected requirement and dependency
were removed immediately in the recovery PR; #166 must make the evidence job
itself required rather than relying on a skipped dependent job.

## What was deliberately not changed

- The `merge_group` concurrency key stays `github.ref`. `base_ref` is always
  `refs/heads/main`, so keying on it makes concurrent entries cancel one another
  and deadlocks the queue at `max_entries_to_build: 5`. The plan forbids changing
  it and the measurements give no reason to.
- Queue batch settings are untouched: `ALLGREEN`, `max_entries_to_build: 5`,
  `max_entries_to_merge: 5`, `min_entries_to_merge: 1`. With p90 queue time at
  12.3 minutes and no indefinite overtaking observed, tuning them would be a
  change without a measured problem.
- Required contexts are untouched here. The ruleset still requires
  `linux-offline` only. Adding `merge-group-evidence` — and restoring
  `windows-offline` — is #166's cutover, which owns the ruleset and its
  no-stale-context gate. Until then this job reports its verdict without
  blocking; #166 should make it required, which is safe precisely because it
  reports on both events.
- PR #115 proposed the earlier form of the concurrency fix for #112. `origin/main`
  already carries the superseding #204 fix, keyed as described above, so #115 is
  obsolete rather than mergeable and is closed with that reason.
