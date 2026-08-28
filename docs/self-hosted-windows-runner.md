# The self-hosted Windows runner

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

A single self-hosted runner fixes two separate things:

1. **The machine is known and constant**, so a run is comparable with the run
   before it and a series means something.
2. **There is exactly one of it**, so the two Windows jobs queue behind each
   other instead of contending for the same cores. Contention is the documented
   cause of the baseline inflation these suites suffer from — see the header of
   [`tests/lib-test-timing.sh`](../tests/lib-test-timing.sh).

The cost is real and accepted: verification only happens while that machine is
on and logged in, and the two Windows jobs no longer overlap, so a full pass
takes longer in wall clock than it did on two hosted runners.

## Security — read this before adding a second runner

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

The runner lives outside every repository checkout, at `C:\actions-runner`, and
works in `C:\actions-runner\_work`. It is registered to the repository with the
label `edge-dev` alongside the automatic `self-hosted`, `Windows`, and `X64`
labels, which is what `runs-on: [self-hosted, Windows, X64, edge-dev]` selects.

It is **not** a Windows service. Installing one requires an elevated shell, so
it runs from a scheduled task, `GitHubActionsRunner-aidevops`, triggered at
logon for the interactive user and set to restart if it exits.

**Consequence:** verification runs only while that machine is powered on and
that user is logged in. A queued job simply waits. Nothing fails; nothing
finishes either.

## Checking it

```bash
gh api repos/popcre/ai-devops/actions/runners --jq '.runners[]|{name,status,busy}'
```

`status` must be `online`. If it is `offline`, on the machine itself:

```powershell
Start-ScheduledTask -TaskName 'GitHubActionsRunner-aidevops'
```

## Re-registering after a token or repository change

Registration tokens expire in one hour, so fetch one at the moment you use it:

```powershell
$t = gh api --method POST repos/popcre/ai-devops/actions/runners/registration-token --jq '.token'; Set-Location C:\actions-runner; .\config.cmd --unattended --url https://github.com/popcre/ai-devops --token $t --name edge-dev-win --labels edge-dev --work _work --replace
```

## Going back to hosted runners

Change both Windows jobs in `.github/workflows/verify.yml` back to
`runs-on: windows-2025`. Nothing else in the repository depends on the runner,
and the required check names do not change either way — which is deliberate, so
ruleset `21564317` needs no edit to move in either direction.
