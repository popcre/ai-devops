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

The cost applies only to explicit host-bound diagnosis and qualification: those
runs require the selected machine to be on and logged in. Required pull-request
and scheduled verification remains hosted.

### Why the reviewer suites have their own lane

For pull requests, `windows-offline-section` runs the Windows-sensitive Bash set
and all PowerShell suites, divided into five declared sections on five
independent hosted machines (issue #210), while `windows-reviewer-safety` requires hosted Codex and
Grok proof. A qualified-pool diagnostic is available only on an explicit full
manual run. The section boundaries live
in `config/ci-suite-manifest.json`, and `tests/test-all.sh` refuses to run a
section unless the declared sections reconstitute the lane exactly. Scheduled
and full manual runs use `windows-offline-complete` on five independent hosted
machines: all discovered Bash suites are sorted and partitioned round-robin,
and section 3 runs all PowerShell suites exactly once. This complete mode does
not use the reduced pull-request manifest. Qualification and no-argument local
entrypoints retain their serial behavior. A single
aggregate job keeps the stable name `windows-offline` and fails closed on any
lane result other than success. The ordinary pull-request
hosted matrix omits Codex and Grok only after assigning both unchanged suites
to `windows-reviewer-fallback` on an independent `windows-2025` host. That job
is the required pull-request and scheduled proof. The qualified self-hosted
lane remains available on an explicit full manual run for host-bound diagnosis,
but it cannot queue or fail a repository-wide verification run. Its 30-minute
execution bound must prove the full process tree stopped before any independent
work is released. This is the host-specific fail-closed contract: a physical
host can fence its own shared runtime, never unrelated hosted capacity.

The prior 30-minute hosted experiment could intermittently go red on healthy
`main` with a recognisable duration signature:

- `test-ai-grok-review.sh` takes 2000s or more against a ~650s green baseline,
  and total `BASH SUITE TIMINGS seconds=` lands near 5700-5800 instead of ~4400.
- The failures are the Grok concurrency and lock-serialization assertions, e.g.
  `different_named_sessions_can_ask_concurrently`,
  `same_next_ask_turn_is_serialized`, `uncertain_ask_blocks_its_exact_retry`.
- `windows-reviewer-safety` passed in the same run, on the same commit.

That duration ceiling is not reused. The complete hosted reviewer proof has a
60-minute bound; exact-head run 34807026089 passed it in about 43 minutes while
the preferred remote host timed out. Assertion failures still fail the stable
`windows-reviewer-safety` aggregate.

That combination is the hosted machine missing the timing window, not a defect.
Confirm it by comparing the two lanes **within one run** before suspecting a
branch — `main` run
[33809598271](https://github.com/popcre/ai-devops/actions/runs/33809598271) is a
clean example on `main` with no pull request involved. Pull requests and merge
groups are now blocked by `verification-closure`, which requires the applicable
Linux, Windows, reviewer, and queued-head evidence without tying that closure
to any one physical runner.

Do not raise a timeout to make these pass; that discards the signal the two-lane
split exists to preserve. The fail-closed removal of this overlap was delivered
in [#260](https://github.com/popcre/ai-devops/issues/260).

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

Two registrations remain available for explicit host-bound diagnostics; they
are not used by required pull-request or scheduled verification. Do not run
both on the same physical machine at once or add a third without a reason — each
competes for the same cores and installed runtime, and oversubscription starves
a runner's heartbeat (see the 2026-08-28 entry in
[`critical-incidents.md`](critical-incidents.md)).

The `edge-dev` label sits alongside the automatic `self-hosted`, `Windows`, and
`X64` labels, which is what `runs-on: [self-hosted, Windows, X64, edge-dev]`
selects.

The required pull-request lanes do not select this label or any persistent
runner: `windows-offline` and `windows-reviewer-safety` use independent hosted
machines. An explicit full manual run may select
`ai-devops-windows-qualified`, the dedicated pool documented in
[`independent-windows-runner-setup.md`](independent-windows-runner-setup.md).
The registrations remain available only for deliberate manual workflows that
ask for `edge-dev`.

Neither is a Windows service — installing one requires an elevated shell. At
most one registration and scheduled task may be active on this physical host.
A deliberate manual diagnostic selects one; the other must remain stopped or
disabled for the whole run because both share the installed runtime and cores.

**Consequence:** only that manual diagnostic depends on the machine. Hosted
repository verification continues independently if the local host is off,
busy, or unavailable.

**Creating an on-demand scheduled task needs an elevated shell.** Do not attach
an at-logon or recurring trigger. From an **Administrator** PowerShell:

```powershell
$action = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument '/c C:\actions-runner-2\run.cmd'
Register-ScheduledTask -TaskName 'GitHubActionsRunner-aidevops-2' -Action $action -User "$env:USERDOMAIN\$env:USERNAME" -RunLevel Limited
Disable-ScheduledTask -TaskName 'GitHubActionsRunner-aidevops-2'
```

## Selecting and checking one registration

Choose one task for the manual diagnostic. Stop and disable its peer before
enabling the selected task; recovery follows the same order and must never
start a selected listener until the peer is proven stopped:

```powershell
$selected = 'GitHubActionsRunner-aidevops'
$peer = 'GitHubActionsRunner-aidevops-2'
$selectedRoot = 'C:\actions-runner'
$peerRoot = 'C:\actions-runner-2'

function Stop-And-ProveRunner([string]$taskName, [string]$runnerRoot) {
    $runnerPrefix = $runnerRoot.TrimEnd('\') + '\'
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
    if ($task.State -eq 'Running') {
        Stop-ScheduledTask -TaskName $taskName -ErrorAction Stop
    }
    Disable-ScheduledTask -TaskName $taskName -ErrorAction Stop
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    do {
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
        $owned = @(Get-CimInstance Win32_Process | Where-Object {
            ($_.ExecutablePath -and $_.ExecutablePath.StartsWith($runnerPrefix, [StringComparison]::OrdinalIgnoreCase)) -or
            ($_.CommandLine -and $_.CommandLine.IndexOf($runnerPrefix, [StringComparison]::OrdinalIgnoreCase) -ge 0)
        })
        if ($task.State -ne 'Running' -and $owned.Count -eq 0) { return }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "$taskName did not stop cleanly; refusing to start another registration on this host."
}

Stop-And-ProveRunner $peer $peerRoot
Enable-ScheduledTask -TaskName $selected
Start-ScheduledTask -TaskName $selected
```

Validate that the selected registration is `online` and its peer is `offline`:

```bash
gh api repos/popcre/ai-devops/actions/runners --jq '.runners[]|{name,status,busy}'
```

If the selected registration reports `offline`, inspect the process before any
recovery. A live listener plus an `offline` status means the selected machine
is saturated; reduce its load and do not re-register or start the peer:

```powershell
Get-Process -Name 'Runner.Listener','Runner.Worker' -ErrorAction SilentlyContinue
```

After the diagnostic, restore the serialized stopped state:

```powershell
Stop-And-ProveRunner $selected $selectedRoot
```

Any command error, timeout, running task, or registration-owned process is a
hard stop. Do not enable the peer or start unrelated work on the shared runtime
until the failed cleanup is diagnosed and the proof succeeds.

## Running a local test series alongside CI

First run `bin/ai-test-local --check-collision`. It matches only runner names
installed on this physical host. A busy independent self-hosted runner does not
block this host, and GitHub-hosted or Blacksmith work remains available. Treat a
shared installed runtime as same-host contention even when the job was launched
elsewhere. Such a runtime must expose one common lock-directory path through
`AI_TEST_SHARED_RUNTIME_LOCK`; the launcher holds it for the complete run.

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

## Required verification versus host diagnostics

Required Windows jobs already use hosted runners. Keep the qualified
self-hosted registrations for explicit manual diagnosis, qualification, and
reproduction on a known physical host. Removing that capability requires a
separate owner decision; it is not part of routine CI routing.
