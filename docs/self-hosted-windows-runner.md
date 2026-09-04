# The self-hosted Windows runners

**Added:** 2026-08-27, with PR
[#142](https://github.com/popcre/ai-devops/pull/142).
**Applies to:** `windows-offline` and `windows-reviewer-safety` in
[`.github/workflows/verify.yml`](../.github/workflows/verify.yml).
`linux-offline` is unchanged and still runs on GitHub's `ubuntu-24.04`.

## Why this exists

The reviewer suites assert on real wrapper processes taking real locks, so their
correctness depends on timing. GitHub-hosted Windows runners gave a different
machine, at a different load, on every run. Over two days of attempts against
issue [#89](https://github.com/popcre/ai-devops/issues/89) that produced 65-75
minute jobs and no evidence anyone could attribute: a failure could not be
reproduced, and a pass could not be trusted. See
[`tests/verification/reviewer-flake-89/`](../tests/verification/reviewer-flake-89/).

Self-hosting fixes two separate things:

1. **The machine is known and constant**, so a run is comparable with the run
   before it and a series means something.
2. **Capacity is controlled**, so the machine is never oversubscribed the way a
   pool of unrelated hosted runners can be. Contention is the documented cause of
   the baseline inflation these suites suffer from — see the header of
   [`tests/lib-test-timing.sh`](../tests/lib-test-timing.sh).

The cost is real and accepted: verification only happens while that machine is on
and logged in.

### The hosted lane still runs these suites, and still goes red at random

`windows-offline` runs on GitHub-hosted `windows-2025` and executes the full Bash
suite, so it re-runs the reviewer suites that `windows-reviewer-safety` already
proves on the qualified pool. On the hosted image that is intermittently red on
`main` itself, with a recognisable signature:

- `test-ai-grok-review.sh` takes 2000s or more against a ~650s green baseline,
  and total `BASH SUITE TIMINGS seconds=` lands near 5700-5800 instead of ~4400.
- The failures are the Grok concurrency and lock-serialization assertions, e.g.
  `different_named_sessions_can_ask_concurrently`,
  `same_next_ask_turn_is_serialized`, `uncertain_ask_blocks_its_exact_retry`.
- `windows-reviewer-safety` passes in the same run, on the same commit.

That combination is the hosted machine missing the timing window, not a defect.
Confirm it by comparing the two lanes **within one run** before suspecting a
branch — `main` run
[33809598271](https://github.com/popcre/ai-devops/actions/runs/33809598271) is a
clean example on `main` with no pull request involved. Only `linux-offline` is a
required check, so this does not block a merge.

Do not raise a timeout to make these pass; that discards the signal the two-lane
split exists to preserve. Removing the reviewer suites from the hosted lane is
tracked in [#260](https://github.com/popcre/ai-devops/issues/260).

## Security — read this before adding another runner

**This repository is public.** A self-hosted runner executes whatever code a
pull request contains, on the machine it runs on. The protection is the
repository's Actions fork-PR approval policy, which is set to
`all_external_contributors`:

```bash
gh api repos/popcre/ai-devops/actions/permissions/fork-pr-contributor-approval
```

That must report `all_external_contributors`. If it ever reports
`first_time_contributors` or `first_time_contributors_new_to_github`, a fork's
pull request can run on the machine without approval. Restore it with:

```bash
gh api --method PUT repos/popcre/ai-devops/actions/permissions/fork-pr-contributor-approval -f approval_policy=all_external_contributors
```

Do not register a self-hosted runner for this repository on a machine holding
credentials you would not hand to a pull request author.

## What is installed

**Two runners**, both labelled `edge-dev`, living outside every repository
checkout:

| Runner | Directory | Scheduled task |
|---|---|---|
| `edge-dev-win` | `C:\actions-runner` | `GitHubActionsRunner-aidevops` |
| `edge-dev-win-2` | `C:\actions-runner-2` | `GitHubActionsRunner-aidevops-2` |

Two exist so `windows-offline` and `windows-reviewer-safety` run **in parallel**
rather than one queueing behind the other; with a single runner a full pass took
roughly twice as long in wall clock. Do not add a third without a reason — each
one competes for the same cores, and oversubscribing this machine is what starves
a runner's heartbeat (see the 2026-08-28 entry in
[`critical-incidents.md`](critical-incidents.md)).

The `edge-dev` label sits alongside the automatic `self-hosted`, `Windows`, and
`X64` labels, which is what `runs-on: [self-hosted, Windows, X64, edge-dev]`
selects.

Since 2026-09-02 the two heavy `verify` Windows jobs no longer select this
label: `windows-offline` and `windows-reviewer-safety` run on
`ai-devops-windows-qualified`, a pool of dedicated hosts documented in
[`independent-windows-runner-setup.md`](independent-windows-runner-setup.md).
These two runners still serve every other workflow that asks for `edge-dev`.

Neither is a Windows service — installing one requires an elevated shell. Both
run from scheduled tasks triggered at logon for the interactive user.

**Consequence:** verification runs only while that machine is powered on and that
user is logged in. A queued job simply waits. Nothing fails; nothing finishes
either.

**Creating the scheduled task needs an elevated shell.** A non-elevated session
can start a runner directly (so it works immediately) but cannot make it survive
a reboot. From an **Administrator** PowerShell:

```powershell
schtasks /create /tn "GitHubActionsRunner-aidevops-2" /tr "C:\actions-runner-2\run.cmd" /sc onlogon /rl LIMITED /f
```

## Checking it

```bash
gh api repos/popcre/ai-devops/actions/runners --jq '.runners[]|{name,status,busy}'
```

Every runner must report `online`. If one reports `offline`, check whether its
process is actually alive before re-registering anything:

```powershell
Get-Process -Name 'Runner.Listener','Runner.Worker' -ErrorAction SilentlyContinue
```

**A live process plus an `offline` status means the machine is saturated, not
that the runner is broken** — the heartbeat is being starved. Reduce the load; do
not re-register. If the process is genuinely gone:

```powershell
Start-ScheduledTask -TaskName 'GitHubActionsRunner-aidevops-2'
```

## Running a local test series alongside CI

**Bound the concurrency, and scope your cleanup.** The reviewer suites and the CI
jobs that run them are the same script with the same process name, on the same
machine. Two rules follow, both learned the hard way on 2026-08-28:

- **Cap concurrent local suites at about four.** Eight starved the runners'
  heartbeat. Four leaves headroom — confirm with the runner check above while the
  series runs.
- **Never clean up with a bare process-name match.** It will match the CI job's
  own processes and cancel a live check. Record the process IDs your script
  starts and kill only those.

## Re-registering after a token or repository change

Registration tokens expire in one hour, so fetch one at the moment you use it
(change the directory and `--name` for the second runner):

```powershell
$t = gh api --method POST repos/popcre/ai-devops/actions/runners/registration-token --jq '.token'; Set-Location C:\actions-runner; .\config.cmd --unattended --url https://github.com/popcre/ai-devops --token $t --name edge-dev-win --labels edge-dev --work _work --replace
```

## Going back to hosted runners

Change both Windows jobs in `.github/workflows/verify.yml` back to
`runs-on: windows-2025`. Nothing else in the repository depends on the runners,
and the required check names do not change either way — which is deliberate, so
ruleset `21564317` needs no edit to move in either direction.
