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

### An already-registered runner started by a scheduled task

A host whose runner was installed as a logon scheduled task rather than a
service cannot qualify, and that is deliberate: a service with automatic start
is the only thing that proves the host comes back on its own after a reboot with
nobody signed in. A logon task also flashes console windows at whoever is using
the machine. `edge-dev` was in exactly this state on 2026-09-02.

Convert it in place - the runner keeps its registration, name and labels:

```powershell
pwsh -File bin\promote-windows-runner-to-service.ps1
```

Run it from Administrator PowerShell, in a session where `gh` is already signed
in. A runner that was never configured with `--runasservice` has no service
installer at all, so the script unconfigures it and configures it again in
service mode under the same name, labels and work folder. It reads the labels
back from GitHub first, removes the runner scheduled tasks, registers and starts
the service, forces automatic start, and then warns about any required tool that
resolves only inside a user profile. The removal and registration tokens are
requested from GitHub as the script runs and are passed to the runner on
standard input, so they never reach a command line, a log or the repository.

It is safe to run twice, and it also repairs a runner that a previous attempt
left wrecked - a registered service that is stopped with the runner identity
files deleted, which is where `edge-dev` was left on 2026-09-02. In that state
the local credentials are gone, so it deletes the stale registration from GitHub
and the leftover service before registering the host again.

A tool installed under `C:\Users\...` is invisible to the service account, so
install it for all users before qualifying; on `edge-dev` that applies to
Python:

```powershell
winget install --id Python.Python.3.13 --scope machine
```

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
- Do not use `$env:USERNAME` or `%USERNAME%` to secure runner-created files.
  Under the GitHub service it can be the computer identity, such as
  `EDGE-RUNN-ENVY$`, which is not the service's security principal. Resolve
  `[Security.Principal.WindowsIdentity]::GetCurrent().User.Value` and grant the
  resulting SID instead. Tests may use the matching `.Name` only when reading
  and verifying the ACL that was already granted by SID.
- Do not compare a Git Bash `/tmp/...` string directly with a path saved by a
  native Windows child process. Under Network Service they can name the same
  directory as `/tmp/...` and
  `/c/Windows/ServiceProfiles/NetworkService/AppData/Local/Temp/...`. Immediately
  normalize a new fixture root with `TMP="$(cd "$TMP" && pwd -P)"` before
  exporting state, sandbox or progress paths. This fixed false concurrency
  stalls without increasing timeouts or weakening reviewer lock assertions.
- The service does not have permission to read TPM state directly. The
  Administrator preflight records a narrow, non-secret attestation instead.
- Incorrect system time made fresh evidence look stale. Enabling Windows Time,
  forcing resynchronization and recreating the attestation fixed it.
- Adding the legacy `edge-dev` label before full qualification allowed required
  jobs to start and fail during setup. Candidate and qualified routing must stay
  separate.

## Reaching a runner host over SSH

`EDGE-ALIEN` and `EDGE-RUNN-ENVY` accept SSH **only over the private Tailscale
network**, using the operator's dedicated runner key. There is no LAN or public
route to either host, so a runner is unreachable whenever Tailscale is down on
either end, and password authentication is not the intended path. Concrete
addresses, account names, key file and host aliases live in the protected
machine atlas, not in this public repository:

```bash
ai-private-config path machine_atlas
```

The account name differs between the operator workstation and the runner hosts,
and that mismatch is the usual cause of a surprise password prompt. Use the
configured host alias, which already carries the correct account and key,
instead of typing a host and key path by hand.

Two traps that make a working key look broken:

- A shell running under a second local Windows profile reads a different `.ssh`
  directory that holds no key, so SSH silently falls back to a password.
  Confirm the profile with `echo "$env:USERNAME | $env:USERPROFILE"` before
  concluding the key or the server is at fault.
- A wrong key path is not a connect-time error. SSH only warns `Identity file
  ... not accessible` and then asks for a password, which reads as a rejected
  key.

Prove key authentication rather than assuming it:

```bash
ssh -o BatchMode=yes <runner-alias> "whoami"
```

`BatchMode=yes` disables the password fallback, so this succeeds only when the
key is actually accepted. The two hosts do not share a default remote shell -
one answers PowerShell and the other `cmd.exe` - so quote remote commands for
the shell that host actually runs.

Both hosts were verified reachable this way on 2026-09-02.

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

## First-host evidence as of 2026-09-02

- Host: `EDGE-RUNN-ENVY`, Windows 11 Pro 25H2 build 26200, i7-10700, 16 GB RAM.
- TPM ready and Secure Boot enabled; Windows Time synchronized.
- One automatic runner service; runner version 2.336.0.
- Labels at qualification time: `self-hosted`, `Windows`, `X64`,
  `ai-devops-windows`.
- Administrator preflight passed.
- Service-visible dependency gate passed.
- Run
  [33559660147](https://github.com/popcre/ai-devops/actions/runs/33559660147)
  proved security, service-visible dependencies and reusable cleanup, then
  exposed the username/SID and Git Bash/native temp-path defects above.
- Both focused repairs passed locally (`ai-gemini`: 62/62; `ai-grok-review`:
  199/199) and received independent exact-head approval on commit `fa46a1f`.
- Complete offline matrix passed in qualification run
  [33571202823](https://github.com/popcre/ai-devops/actions/runs/33571202823)
  on 2026-09-01, job `qualify`, 1h00m14s. Within it
  `tests/test-ai-grok-review.sh` passed 199 of 199 checks in 538s - the same
  suite that exceeded its 30 minute ceiling twice while sharing the edge-dev
  desktop (runs 33571202865 and 33624326508).
- Promoted on 2026-09-02: label `ai-devops-windows-qualified` added, candidate
  label `ai-devops-windows` kept for requalification. The `edge-dev` label was
  not added.
- Windows CI runs in two lanes at once, on purpose. `windows-offline`, the long
  matrix, takes GitHub's hosted `windows-2025` image, where concurrency is
  unmetered on a public repository and a run never waits for a machine.
  `windows-reviewer-safety` takes the qualified self-hosted pool, where a timing
  flake can be reproduced on a known physical machine. The self-hosted pool is
  **extra** Windows capacity, never a replacement for GitHub's runners; routing
  both jobs to a one-host pool on 2026-09-02 serialised the whole repository and
  left six verify runs queued behind one desktop.
- `edge-dev` is being onboarded into the qualified pool rather than retired, so
  the pool holds more than one machine and a single failure cannot stop the
  self-hosted lane. It is a candidate until a green `qualify Windows runner` job
  runs on it, exactly like any other host. One blocker is specific to it: its
  runner is installed as an interactive scheduled task, and both the
  Administrator preflight and the qualification job require a real Windows
  service with automatic start. Converting it also removes the console windows
  that the scheduled task produced. That conversion needs one elevated command
  on the machine.
- `EDGE-ALIEN` is registered and online with the candidate label only. Its
  Administrator preflight and service-visible dependency gates passed in run
  [33625657591](https://github.com/popcre/ai-devops/actions/runs/33625657591)
  on 2026-09-02, but the complete offline matrix was cancelled at the 90 minute
  ceiling there and again in run
  [33639477174](https://github.com/popcre/ai-devops/actions/runs/33639477174),
  so the host is not qualified and takes no ordinary CI.
- That is host slowness, not a hang, and the second run's log proves it: the
  suite logged a passing check at 15:32:53Z and the cancellation arrived at
  15:32:54Z. Nothing was stuck. Measured against `EDGE-RUNN-ENVY` on the same
  commit and the same matrix, `EDGE-ALIEN` is roughly three times slower on
  every suite - `test-ai-claude-review.sh` 17m against 4m26s,
  `test-ai-codex-review.sh` 14m against 3m52s, `test-ai-glm.sh` 18m against
  6m00s, and `test-ai-grok-review.sh` still running past 20m against 9m02s. The
  slowdown is uniform per operation rather than one long wait: the gap between
  consecutive checks clusters at 5-12s on `EDGE-RUNN-ENVY` and never exceeds
  19s, while on `EDGE-ALIEN` gaps of 20-64s recur throughout. A 62 minute
  matrix at that rate needs about three hours.
- Part of the gap is hardware and part is endpoint scanning; only the second
  part is recoverable. `EDGE-ALIEN` is an i7-6700 (4 cores, 8 threads, 2015)
  against `EDGE-RUNN-ENVY`'s i7-10700 (8 cores, 16 threads). Checked on the host
  on 2026-09-02 and ruled out as causes: Defender real-time protection is
  already off, the runner work folder is already on the NVMe volume rather than
  the SATA disk, and the CPU runs at its full 3401 MHz with the processor
  throttle at 100 percent. The power plan was Balanced and was set to High
  performance, which measured about five percent.
- The suspect is SentinelOne, agent 25.2.442, which is installed on
  `EDGE-ALIEN` and not on the other Windows hosts here. Two identical
  arithmetic loops separate it from raw speed. An `awk` loop, which spawns
  nothing and runs no script engine, is 2.2x slower on `EDGE-ALIEN` than on the
  i7-12700 desktop - ordinary generational difference. The same loop written in
  Windows PowerShell is **9.3x** slower on the same pair. Process spawning sits
  with the `awk` figure at 2.1x. The suites lean heavily on PowerShell and on
  file writes, which is where script and file scanning lands, and the real
  matrix runs at 3x. So most of the penalty sits in the part an exclusion can
  address, not in the core count.
- **Onboarding of `EDGE-ALIEN` is paused pending SentinelOne exclusions.** The
  owner has asked the IT contractor to exclude the runner's
  directories on that host. Requested paths, confirmed present on the machine:

  | Path | Why |
  | --- | --- |
  | `C:\actions-runner\` | The runner, its `_work` checkout and `_work\_tool` cache: every file CI writes and re-reads |
  | `C:\Program Files\Git\` | `git.exe` and the Git Bash toolchain, re-scanned on every one of thousands of spawns |
  | `C:\Program Files\PowerShell\7\` | The other shell the suites spawn |
  | `C:\Program Files\nodejs\` | `node.exe`, spawned per reviewer check |
  | `C:\Windows\ServiceProfiles\NetworkService\AppData\Local\Temp\` | The runner service account's temp directory |

  Ask specifically whether the policy's **script or AMSI scanning** can be
  excluded for these paths as well as on-access file scanning. The PowerShell
  measurement above points at the script engine, so a file-only exclusion may
  recover far less.
- The security trade is real and worth stating: excluding the runner tree means
  code that CI checks out and executes is no longer inspected on that host. This
  repository is public, which is only acceptable because fork pull-request
  approval is pinned to `all_external_contributors`, so no outside contributor's
  code runs without a maintainer releasing it. If that setting ever changes,
  these exclusions must be revisited.
- **Even a complete win may not be enough, and the gate does not move.** Removing
  the scanning penalty leaves the hardware ratio of about 1.6x, which puts the
  62 minute matrix near 100 minutes on `EDGE-ALIEN`. That is inside the 90
  minute qualification ceiling only if the recovery is better than estimated,
  and it is still above `windows-offline`'s 75 minute ceiling in `verify.yml`.
  Admission is fitness for the 75 minute job, not a green qualification run, so
  a qualification that merely finishes does not admit the host.
- To re-measure after the exclusions land, repeat the same three numbers on an
  **idle** host and compare against this baseline, taken on 2026-09-02 with the
  High performance plan already applied and SentinelOne unmodified:
  `awk` loop 395 ms, 100 process spawns 6499 ms, 30 `git --version` spawns
  2722 ms. Then re-run the PowerShell loop, which is the one expected to move
  most. Only after that is it worth spending a qualification run. Nothing on
  that host may be measured while a CI job is live on it: a local run and a CI
  job on the same four cores corrupt each other, which happened on 2026-09-02
  and cost two measurements.
- Second qualified host, failover proof and EDGE-DEV retirement remain open
  under #209.

## If the qualified pool goes down

`ai-devops-windows-qualified` resolves to one host until `edge-dev` qualifies, so
losing it stops `windows-reviewer-safety` from ever starting - a dead host leaves
that job *queued*, not failed, so it never reports. `windows-offline` is
unaffected: it runs in GitHub's hosted lane, which is exactly why that lane was
kept. This does not
freeze merging: rulesets `21183703` and `21564317` require `linux-offline` only,
and both Windows jobs are skipped on `merge_group`. The damage is silent loss of
reviewer-suite proof, which is the gap recorded in
[`ai-devops-required-checks-gap.md`](ai-devops-required-checks-gap.md).

Check the pool with:

```bash
gh api repos/popcre/ai-devops/actions/runners --jq '.runners[]|"\(.name) \(.status) \(.labels|map(.name)|join(","))"'
```

If no `ai-devops-windows-qualified` runner is `online`, repair that host first.
Only if it stays down long enough to matter may the owner deliberately apply the
`ai-devops-windows-qualified` label to the `edge-dev` runners and accept
serialized, slower CI on the interactive desktop:

```bash
gh api --method POST repos/popcre/ai-devops/actions/runners/<id>/labels -f "labels[]=ai-devops-windows-qualified"
```

That is a deliberate, owner-authorized fallback, not a default. Remove the label
again once the dedicated host returns. Never add `edge-dev` to the `runs-on`
list in `verify.yml` as a fallback: `runs-on` entries are ANDed, so a shared
fallback label lets the desktop win the race again and reintroduces the
double-cancellation this pool exists to remove.
