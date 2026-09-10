# Blacksmith Windows runner findings

**Recorded:** 2026-09-09 during PR
[#355](https://github.com/popcre/ai-devops/pull/355).
**Status:** qualification is still in progress; this is evidence and design
guidance, not proof that PR #355 is ready to merge.

**Implementation plan:**
[`../plan_blacksmith-windows-throughput.md`](../plan_blacksmith-windows-throughput.md)
owns the approved throughput design: six measured shards, split 3+3 across
GitHub and Blacksmith, with a separately cancellable Blacksmith workflow and
visible exact-shard GitHub recovery when Blacksmith cannot start.

## Owner intent

Blacksmith is additional Windows capacity. It must not replace the existing
GitHub-hosted Windows lane or the qualified local reviewer-safety lane. GitHub
Actions selects one runner class for each job, so providers cannot be expressed
as interchangeable labels on one job. Additive capacity requires separate jobs
or an explicit matrix that assigns each shard to a provider.

## What the migration wizard did

The Blacksmith migration wizard opened PR #355 and replaced every compatible
`runs-on` label, including Ubuntu and GitHub-hosted Windows. This was normal
wizard behavior, but it did not match the additive intent. The branch was
changed to restore GitHub-hosted Ubuntu and Windows and retain the qualified
self-hosted reviewer lane, while adding a separate
`blacksmith-4vcpu-windows-2025` job.

Blacksmith's current documentation says its runners have no provider-imposed
concurrency limit and explicitly encourages sharding. GitHub account, billing,
or repository concurrency rules can still constrain a real run, so verify the
queue live. Windows is described as public beta and its image intentionally
omits some components from GitHub's complete image. Source:
<https://docs.blacksmith.sh/blacksmith-runners/overview>.

## Qualification findings

The first Blacksmith Windows attempt, run
[`34406469534`](https://github.com/popcre/ai-devops/actions/runs/34406469534),
showed that the image did not provide the Python command expected by the test
harness and that Windows ACL output may identify the same user by SID instead
of display name. PR #355 therefore installs pinned Python 3.13 in only the
Blacksmith job and makes the ACL assertion accept either the nonempty current
account name or its nonempty exact SID. Both paths remain fail-closed.

Run [`34414264824`](https://github.com/popcre/ai-devops/actions/runs/34414264824)
proved Python was repaired but exposed another image difference: `grep` could
include filenames in a single-file fallback search. Commit `92ba1e9a` adds
`grep -h`, making the command's output shape explicit. The focused fact-search
suite then passed 14/14 locally.

The qualified local reviewer lane also produced two known Grok timing failures
on an earlier exact-head run while 223 other checks passed. The previous commit
had passed on the same host. This is the documented timing signature; do not
raise timeouts or weaken assertions to hide it. The final exact-head run
[`34418585172`](https://github.com/popcre/ai-devops/actions/runs/34418585172)
had Linux and reviewer-safety green while both full Windows jobs were still
running when this record was written.

## What should be permanent

Duplicating the complete Windows pack on GitHub and Blacksmith for every pull
request is useful for initial qualification but is not the recommended steady
state. The repository currently has 69 Bash suites and 18 PowerShell suites;
ordinary pull requests select the 23 Windows-sensitive Bash suites plus all 18
PowerShell suites, while scheduled and manual runs retain the complete pack.

Earlier recommendation, superseded by Albert's throughput decision on
2026-09-10:

1. Split the Windows-sensitive pull-request pack into several unique Blacksmith
   shards. Each suite must be assigned exactly once, and injected omissions and
   duplicates must fail policy tests.
2. Keep a smaller independent GitHub-hosted Windows sentinel instead of
   duplicating the entire Blacksmith pack on every pull request.
3. Keep Codex and Grok reviewer-safety tests on the qualified local physical
   runner because its stable timing is the evidence that lane exists to provide.
4. Keep the complete Windows pack as the scheduled/manual backstop.

Do not call this design implemented. PR #355 currently adds one complete
Blacksmith lane; it does not yet implement the sharded steady state above.

Albert subsequently decided that a small Blacksmith sentinel is insufficient.
The current locked target is the 3+3 design in
[`plan_blacksmith-windows-throughput.md`](../plan_blacksmith-windows-throughput.md).
Keep the earlier recommendation as decision history; do not implement it.

## Cost and operational consequence

Blacksmith's documentation says Windows usage consumes free-tier units at twice
the x64 2-vCPU rate, with higher-vCPU runners scaling proportionally. A
4-vCPU Windows job running for 60 minutes therefore consumes the equivalent of
240 x64 2-vCPU minutes. Duplicating an hour-long full pack on every code pull
request can exhaust the 3,000-minute free allowance quickly. Confirm current
pricing and account limits in Blacksmith before treating these figures as a
budget.

Sharding reduces wall-clock time but not automatically total billed compute. It
is safe on Blacksmith because every shard receives an isolated ephemeral VM. Do
not copy that concurrency model onto multiple runners sharing one physical
Windows computer; CPU contention destroys the timing evidence and can starve
runner heartbeats.

## Acceptance gate

Before merging a permanent design:

- rebase PR #355 onto current `origin/main` and resolve its current conflict;
- verify the exact final commit, not an earlier branch head;
- require the focused workflow-policy tests and every assigned suite to pass;
- obtain a new read-only exact-head review after the final push;
- prove GitHub-hosted Windows, Blacksmith Windows, and qualified local reviewer
  capacity remain visible and that no suite silently disappeared;
- merge through the repository queue and confirm the landed commit on
  `origin/main`.
