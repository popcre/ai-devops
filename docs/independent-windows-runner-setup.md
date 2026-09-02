# Independent Windows runner setup

**Owner:** issue [#209](https://github.com/popcre/ai-devops/issues/209) under parent
[#159](https://github.com/popcre/ai-devops/issues/159).

Use this runbook to add one dedicated physical Windows computer to the
`popcre/ai-devops` GitHub Actions pool. Registration is not qualification: a new
host receives only the candidate label `ai-devops-windows` until every gate below
passes. Ordinary required CI must not route to it before then.

## Capacity and security decisions

- Install **one runner service per physical computer**. One service executes one
  GitHub job at a time. Do not add a second logical runner to "use all the cores":
  the Windows suites share process names, locks, disk and timing assumptions.
  Two services on one host recreate the contention and misleading failures #209
  exists to remove.
- Scale with physical hosts. Three qualified computers provide three concurrent
  Windows jobs. Issue #210 owns later bounded parallel test sections; it must not
  be simulated by competing services on one computer.
- This repository is public. Before registration, this must report
  `all_external_contributors`:

  ```powershell
  gh api repos/popcre/ai-devops/actions/permissions/fork-pr-contributor-approval
  ```

  That policy requires approval before any external contributor's fork code can
  execute on a self-hosted machine. Never put unrelated credentials or private
  files on a runner host.
- Keep a new runner off ordinary CI until the dedicated qualification workflow
  is green. The candidate label is `ai-devops-windows`; the permanent qualified
  pool label is `ai-devops-windows-qualified`. The legacy `edge-dev` label is a
  temporary compatibility route only and must never be added before qualification.

## 1. Qualify the computer itself

Use a dedicated Windows 11 Pro computer with current Windows Updates, TPM 2.0,
Secure Boot, at least 16 GB RAM and ample free disk. Keep it powered on, awake and
connected to the internet while jobs run. The LAN itself is not required; the
runner makes outbound HTTPS connections to GitHub.

Do not trust `Get-ComputerInfo` to name Windows 11 correctly. Windows 11 can still
return `Windows 10 Pro` and `WindowsVersion 2009` for compatibility. Build 22000+
is authoritative. Check without publishing Device ID, Product ID or serial number:

```powershell
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' |
  Select-Object ProductName,DisplayVersion,CurrentBuildNumber
Get-Tpm | Select-Object TpmPresent,TpmReady
Confirm-SecureBootUEFI
Get-Volume -DriveLetter C | Select-Object Size,SizeRemaining
```

Required results are Windows build 22000 or newer, `TpmPresent=True`,
`TpmReady=True`, and Secure Boot `True`.

## 2. Install service-visible dependencies

Run these from **Administrator PowerShell**. Git, GitHub CLI and jq must be
machine-wide; a user-only Store app or WinGet link can work interactively while
remaining invisible to the background runner service.

```powershell
winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
winget install --id GitHub.cli -e --source winget --accept-package-agreements --accept-source-agreements
winget install --id Microsoft.PowerShell -e --source winget --installer-type wix --force --accept-package-agreements --accept-source-agreements
winget install --id jqlang.jq -e --scope machine --source winget --force --accept-package-agreements --accept-source-agreements
winget install --id OpenJS.NodeJS.LTS -e --version 24.17.0 --scope machine --source winget --accept-package-agreements --accept-source-agreements
winget install --id Python.Python.3.13 -e --version 3.13.14 --scope machine --source winget --override "/quiet InstallAllUsers=1 PrependPath=1 Include_test=0" --accept-package-agreements --accept-source-agreements
```

PowerShell 7.6+ defaults to a Store-style MSIX through WinGet. The explicit
`--installer-type wix` is required so the runner service can execute
`C:\Program Files\PowerShell\7\pwsh.exe`. For jq, `--scope machine` must create
`C:\Program Files\WinGet\Links\jq.exe`; a path only under the interactive user's
profile is insufficient. Verify the background service can execute the link,
not merely that an Administrator can find it. If the qualification log says
`Program Files/WinGet/Links/jq: Permission denied`, grant the runner service
read-and-execute access to the exact WinGet package binary and restart it:

```powershell
$jqTarget = (Get-Item 'C:\Program Files\WinGet\Links\jq.exe').Target
icacls.exe $jqTarget /grant '*S-1-5-20:(RX)'
Get-Service | Where-Object Name -Like 'actions.runner.*' | Restart-Service
```

Close and reopen PowerShell, then verify:

```powershell
git --version
gh --version
jq --version
node --version
python --version
& 'C:\Program Files\PowerShell\7\pwsh.exe' --version
Test-Path 'C:\Program Files\Git\bin\bash.exe'
where.exe jq
where.exe python
```

Do **not** substitute `winget install python3`. That alias currently selects
Python 3.14 and can leave the `python` command pointing only at the Microsoft
Store execution alias. The repository pins Python 3.13.14, and the explicit
installer override above both installs it for all users and prepends its
machine-wide path. `where.exe python` must list
`C:\Program Files\Python313\python.exe` first, and `python --version` must report
`Python 3.13.14`.

Likewise, use the exact pinned Node command above rather than omitting
`--version`. A different current LTS may work, but it is not dependency parity
with the reviewed recovery catalog.

After installing or correcting any dependency, restart the runner service so it
inherits the new machine PATH:

```powershell
Get-Service | Where-Object Name -Like 'actions.runner.*' | Restart-Service
```

## 3. Register exactly one service

Open the repository's **Settings -> Actions -> Runners -> New self-hosted
runner**, select Windows x64, and run GitHub's current download and configuration
commands from Administrator PowerShell. Registration tokens expire after one
hour and must never be pasted into chat, logs or the repository.

Use:

- directory: `C:\actions-runner`;
- runner name: the Windows device name;
- additional label: `ai-devops-windows` only;
- work folder: `_work`;
- run as a service: Yes;
- service account: GitHub's default.

Do not register a second service on the same physical computer. Confirm:

```powershell
Get-Service | Where-Object Name -Like 'actions.runner.*' |
  Select-Object Name,Status,StartType
```

Exactly one service must be `Running` and automatic. GitHub should show the host
online and idle with `self-hosted`, `Windows`, `X64`, and
`ai-devops-windows`—not `edge-dev`.

## 4. Synchronize time and create Administrator evidence

Correct system time is required for TLS, GitHub authentication, logs and test
timing. Run:

```powershell
Set-Service w32time -StartupType Automatic
Start-Service w32time
w32tm /resync /force
```

From a current `popcre/ai-devops` checkout, run the idempotent Administrator
preflight:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\bin\qualify-windows-runner.ps1
```

It proves Windows 11, TPM, Secure Boot, one running automatic runner service,
machine-wide PowerShell and Git Bash, then atomically writes non-secret evidence
to `C:\ProgramData\ai-devops\windows-runner-security.json`. It contains no device
name, hardware identifier or credential. The CI qualification accepts only the
same Windows build and evidence within a bounded 24-hour clock window.

The runner service cannot reliably query TPM itself under its restricted
account. That is why the Administrator preflight exists; weakening or deleting
the TPM/Secure Boot gate is not the fix.

Restart the service after any machine-wide package or PATH change:

```powershell
Get-Service | Where-Object Name -Like 'actions.runner.*' | Restart-Service
```

## 5. Run canonical qualification

Run **qualify Windows runner** from the repository's Actions page. A pull request
that changes the qualification workflow triggers it automatically. The job uses
only `[self-hosted, Windows, X64, ai-devops-windows]`, so it cannot consume or
approve ordinary CI while still a candidate.

Acceptance requires one uninterrupted green job proving:

1. checkout cleanup succeeds;
2. fresh Administrator security evidence matches the current Windows build;
3. `git`, `gh`, `jq`, `pwsh` and Git Bash are visible to the service account;
4. exactly one runner service is running and automatic;
5. the complete `tests/test-all.ps1` Windows and Bash matrix passes;
6. the workspace remains clean and reusable afterward.

The complete matrix has historically taken 60–75 minutes. A queued job has not
failed; an in-progress job must be left alone. Do not restart, sleep or use the
computer during qualification.

## 6. Admit the host to ordinary CI

Only after the exact qualification job is green:

1. add `ai-devops-windows-qualified`;
2. keep `ai-devops-windows` for future requalification;
3. route normal Windows jobs to the qualified pool through the governed #209
   workflow change;
4. prove a representative job names this physical runner;
5. take one qualified runner offline and prove the other physical hosts keep
   Windows CI operational;
6. prove restart, automatic runner update, workspace cleanup and visible
   offline/capacity reporting.

Do not add `edge-dev` merely to drain the backlog before qualification. Required
green checks are approval evidence, so faster unqualified checks are not useful.

## Failures found during the first setup

The first host, `EDGE-RUNN-ENVY`, exposed these reusable traps:

- `Get-ComputerInfo` called Windows 11 25H2 build 26200 "Windows 10 Pro 2009";
  the build and Windows Settings page were correct.
- The Microsoft Store PowerShell 7.6.5 lived under `WindowsApps`. It worked for
  the interactive Administrator but the runner service could not resolve
  `pwsh`. The machine-wide WiX/MSI installation fixed it.
- The first jq installation created only a user WinGet link. Reinstalling with
  `--scope machine` created the service-visible Program Files link.
- A machine-wide jq link can still point to a package binary that Network
  Service cannot execute. This produces hundreds of misleading downstream
  failures. Grant `S-1-5-20` read-and-execute access to that exact binary,
  restart the service, and rerun qualification.
- Node.js and Python were omitted from the first manual setup, so the complete
  suite spent 35 minutes before exposing cascading provider-test failures. Both
  are pinned machine-wide prerequisites and are now checked before the suite.
- Using `winget install python3 --scope machine` installed Python 3.14.7 but
  `python` still resolved to the Microsoft Store alias. Installing the exact
  `Python.Python.3.13` version with `InstallAllUsers=1 PrependPath=1`, reopening
  PowerShell and restarting the runner service produced the required
  `C:\Program Files\Python313\python.exe` first in PATH.
- Installing Node without the pinned version selected 24.19.0 rather than the
  catalog's 24.17.0. The first host could execute it, but future setup must use
  the catalog version so runner rebuilds are reproducible.
- A private-file ACL test used the interactive username. Under Network Service,
  Windows exposed the computer identity and `icacls` could not resolve it. The
  fixture now grants the current security SID directly, which is valid for both
  interactive users and runner services without weakening the ACL assertion.
- The service does not have permission to read TPM state directly. The
  Administrator preflight records a narrow, non-secret attestation instead.
- Incorrect system time made fresh evidence look stale. Enabling Windows Time,
  forcing resynchronization and recreating the attestation fixed it.
- Adding the legacy `edge-dev` label before full qualification allowed required
  jobs to start and fail during setup. Candidate and qualified routing must stay
  separate.

## Status and troubleshooting

Repository runner status:

```powershell
gh api repos/popcre/ai-devops/actions/runners --jq '.runners[]|{name,status,busy,labels:[.labels[].name]}'
```

`online, busy=false` means idle. `online, busy=true` means one job is assigned.
`queued` means GitHub has not assigned a matching runner; it is not proof of a
dead service. If the GitHub page and runner status disagree, inspect the exact
job's `runner_name` before restarting or re-registering anything.

If a dependency was installed after service creation, restart the service so it
inherits the new machine PATH. If a job fails, open the exact failed step; never
treat cancellation, timeout, missing dependency or exit `-1` as a code-test
failure without its logs.

## First-host evidence as of 2026-09-01

- Host: `EDGE-RUNN-ENVY`, Windows 11 Pro 25H2 build 26200, i7-10700, 16 GB RAM.
- TPM ready and Secure Boot enabled; Windows Time synchronized.
- One automatic runner service; runner version 2.336.0.
- Candidate labels only: `self-hosted`, `Windows`, `X64`,
  `ai-devops-windows`.
- Administrator preflight passed.
- Service-visible dependency gate passed.
- Complete offline matrix is currently in progress in Actions run
  [33544988495](https://github.com/popcre/ai-devops/actions/runs/33544988495),
  job `99985106789`.
- Ordinary CI admission, second/third physical hosts, failover proof and EDGE-DEV
  retirement remain open under #209.
