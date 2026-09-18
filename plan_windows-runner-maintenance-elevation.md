# Windows runner maintenance elevation plan

Issue: [#262](https://github.com/popcre/ai-devops/issues/262)
Companion handoff: [`HANDOFF.d/2026-09-17T1804Z-edge-dev-codex-windows-runner-maintenance-elevation.md`](HANDOFF.d/2026-09-17T1804Z-edge-dev-codex-windows-runner-maintenance-elevation.md)

## STATUS

| Step | State | Date | Evidence / restart point |
|---|---|---|---|
| 1. Freeze the contract and threat model | ✅ complete | 2026-09-17 | Locked schemas and hostile case names are executable in `tests/test-windows-runner-maintenance.ps1`. |
| 2. Build the protected installer and payload | ✅ complete | 2026-09-17 | Installer, worker and policy exist; rerun the focused maintenance test for the protected-copy, task and lifecycle contract. |
| 3. Build the unprivileged request client | ✅ complete | 2026-09-17 | Client exposes only `refresh-qualification`; rerun the focused maintenance test for schema, result and timeout coverage. |
| 4. Add hostile offline tests and operating documentation | ✅ complete | 2026-09-17 | Focused maintenance 54/54 (43 original plus 11 review-driven hardening cases), qualification guard, Windows scripts 48/48, workflow policy, reachability and context audit pass on the repaired branch. The permitted full local matrix hit host resource exhaustion in `test-ai-codex-review.sh`: `CreateFileMapping ... Win32 error 1455`; PR #560's required checks on the exact reviewed head are the complete clean-host result. |
| 5. Obtain exact-head independent security approval and land | 🟨 in progress | 2026-09-17 | Implementation PR #560, rebased onto current `origin/main`. Reviews 1-4 (`b0a5a7a1`, `8a72a9fc`, `b1b6007e`, `2305f6a2`) each REJECTed with findings repaired on the same branch. Review 5 (`9a30ad19`) REJECT: the launcher's `FOR /F` child cmd ran without `/d` (HKCU AutoRun), the worker's evidence check was narrower than the installer's, and three lows — repaired: the launcher refuses any cmd AutoRun override (full-path reg.exe, verified by local execution) before any `FOR /F`; the worker verifies the evidence tmp sibling and parent and the runtime `temp` directory with the full contract; reserved DOS device names are rejected as request ids; the recovery backup path is restricted to administrator-managed roots. A sixth exact-head review of the repaired head is required before any merge; protected gate unchanged. |
| 6. Install and prove `edge-dev-win` | ⬜ open | 2026-09-17 | Protected live-host gate; not authorized by this planning PR. |
| 7. Install and prove `EDGE-RUNN-ENVY` | ⬜ open | 2026-09-17 | Protected live-host gate; not authorized by this planning PR. |
| 8. Reconcile evidence, rollback readiness, and issue closure | ⬜ open | 2026-09-17 | Close only after both independent host proofs pass. |

Fresh-session starting point: **Step 5 landing**. Five exact-head reviews (`b0a5a7a1`, `8a72a9fc`, `b1b6007e`, `2305f6a2`, `9a30ad19`) each REJECTed and all their findings are repaired on the branch; the full clean-host matrix resolves through PR #560's required checks on the exact reviewed head. Obtain the next exact-head independent security APPROVE of the repaired head, merge through the queue, and verify the merge commit on `origin/main`; do not install on either host in that session.

## 1. The ultimate goal

POP Creations must be able to refresh the security qualification evidence on either Windows CI host through its existing private Tailscale SSH route without giving that SSH session general administrator power. The operator gets one named operation, an observable bounded result, and a durable audit record; Windows keeps User Account Control (UAC) and remote-token filtering enabled.

When finished, an ordinary remote session on `edge-dev-win` or `EDGE-RUNN-ENVY` can request only `refresh-qualification`. A protected, administrator-installed task runs a fixed, hash-verified payload, writes `C:\ProgramData\ai-devops\windows-runner-security.json`, and cannot be repurposed to run a caller-supplied command, argument, or path.

**If a step conflicts with this goal, the goal wins — stop and flag it.** Do not trade the narrow privilege boundary for convenience.

## 2. What this application is

`popcre/ai-devops` is the public recovery and governance toolkit for POP Creations' multi-model AI and CI workflow. GitHub `main` is authoritative; work lands through a feature branch, pull request, required checks, and the merge queue.

This work concerns two dedicated Windows 11 runner hosts reached over the private Tailscale network:

- `edge-dev-win`
- `EDGE-RUNN-ENVY`

Each host runs one automatic GitHub Actions runner service and uses the candidate/qualified labels documented in [`docs/independent-windows-runner-setup.md`](docs/independent-windows-runner-setup.md). The current administrator preflight is [`bin/qualify-windows-runner.ps1`](bin/qualify-windows-runner.ps1); it checks Windows build 22000+, TPM, Secure Boot, exactly one running automatic runner service, machine-wide PowerShell, and Git Bash, then atomically writes non-secret evidence.

For this repository, deployment means installation onto a host, not a cloud release. [`docs/deployment.md`](docs/deployment.md) governs that boundary. Concrete addresses and credentials remain in the private machine atlas resolved at runtime; they must not enter this public repository.

## 3. What triggered this work

Issue #262 records the incident from #246. SSH authenticated as local administrator `ahazan`, but Windows remote-token filtering supplied a non-elevated token. Built-in Windows `sudo` was disabled, and UAC approval is unsuitable for unattended SSH. That prevented the Administrator-only qualification script from refreshing `C:\ProgramData\ai-devops\windows-runner-security.json` on `EDGE-RUNN-ENVY`.

A one-use highest-privilege S4U scheduled task successfully ran the qualification script and was removed. That proved the Windows mechanism, but a one-off task has no durable allowlist, audit, result contract, lifecycle, concurrency guard, or recovery procedure. Reproduction is: connect through Tailscale SSH, confirm the token is filtered, then run the current qualification script; `#Requires -RunAsAdministrator` refuses before writing evidence.

Live state re-derived 2026-09-17 from issue #262, `origin/main` `26bb4a2efdd9cd243df6d4fb7c0d901ba3fb2868`, the open PR list, and registered worktrees: #262 is open; no open PR, branch, or other worktree owns this implementation. This planning branch is the only `262`/elevation worktree.

## 4. Scope — in and out

### In this plan

- One fixed operation ID: `refresh-qualification`.
- One on-demand task, `\AiDevOps\WindowsRunnerMaintenance`, installed by an elevated local administrator and run at highest privilege with S4U.
- One administrator-owned immutable payload under `C:\Program Files\ai-devops\windows-runner-maintenance`.
- One request/result/audit boundary under `C:\ProgramData\ai-devops\windows-runner-maintenance`.
- Read/execute permission for the resolved local `ahazan` SID; no right to redefine or delete the task or protected payload.
- Bounded request, execution, result, audit, timeout, recovery, install, update, verify, and removal behavior.
- Offline hostile tests plus live negative and positive proof on both named hosts.

### NOT in this plan

- No arbitrary command, script, argument, environment variable, working directory, evidence path, or repository path from the requester.
- No operation besides `refresh-qualification`.
- No runner-service stop, restart, reconfiguration, task replacement, label change, or GitHub runner mutation.
- No UAC change, `LocalAccountTokenFilterPolicy=1`, Windows `sudo`, unrestricted `sudo`, interactive UAC automation, service account password, stored credential, or secret.
- No general-purpose elevation broker, remote shell, API server, long-running Windows service, WinRM change, Tailscale change, or firewall change.
- No installation or mutation of either live host in the implementation session. Installation and live proof are separate protected outcomes after the code lands.
- No closure of #262 until both hosts pass the exact live acceptance matrix.

## 5. Current state of the code

The following is true on `origin/main` `26bb4a2e` as of 2026-09-17:

- [`bin/qualify-windows-runner.ps1:1`](bin/qualify-windows-runner.ps1) requires Administrator. Its only parameter is `EvidencePath`, defaulting to `C:\ProgramData\ai-devops\windows-runner-security.json`.
- [`bin/qualify-windows-runner.ps1:8`](bin/qualify-windows-runner.ps1) through line 25 performs the machine checks. Lines 27–42 create the parent, write a temporary JSON file, and atomically replace the evidence file.
- [`tests/test-qualify-windows-runner.ps1:1`](tests/test-qualify-windows-runner.ps1) is a static guard for the Administrator requirement, security checks, exact machine-wide tool paths, service checks, timestamp, and atomic move.
- [`docs/independent-windows-runner-setup.md:197`](docs/independent-windows-runner-setup.md) documents the manual elevated preflight; lines 204–210 define the evidence contract and why the runner service cannot perform TPM checks.
- [`bin/setup-opencode-glm.ps1:387`](bin/setup-opencode-glm.ps1) through line 429 is an existing scheduled-task and `Schedule.Service.SetSecurityDescriptor` example. It is not a privilege-boundary implementation: its ordinary user receives Full Access, which is forbidden here.
- [`docs/glm-opencode.md:488`](docs/glm-opencode.md) through line 500 records two reusable Task Scheduler facts: an elevated owner can block later redefinition, and `SetSecurityDescriptor($sddl, 0)` requires flag `0`, not `4`.
- [`docs/deployment.md:23`](docs/deployment.md) through line 30 says a new command needs `config/machine-tools.tsv`; this design deliberately uses explicit `.ps1` entrypoints, so no global command is added initially.
- No maintenance installer, worker, request client, policy, audit schema, hostile test, or operational runbook exists. Nothing from this plan is committed, deployed, or installed.

## 6. Key findings and root cause

1. The failure is Windows privilege-token behavior, not a missing SSH identity. A local administrator can authenticate remotely yet receive a filtered token. UAC and filtering are protections to preserve.
2. The existing qualification script genuinely needs elevation because TPM, Secure Boot, service configuration, and the ProgramData evidence path are privileged checks/writes. Removing `#Requires -RunAsAdministrator` would create a false or partial qualification.
3. A highest-privilege S4U scheduled task is already proven viable by the #246 incident. S4U avoids an interactive UAC prompt and does not store the user's password.
4. Executing a script from a writable repository at highest privilege would turn any repository edit into elevation. The task must execute only an administrator-owned copy in `Program Files`; the installer copies and hashes the qualification operation into that protected payload.
5. Task permission and filesystem permission are separate controls. The operator needs task read/execute (`GRGX`) but not Full Access, task change, or delete. Administrators and SYSTEM retain full control. The installed task action, principal, settings, DACL, payload hashes, and filesystem ACLs must all be verified.
6. Task Scheduler `MultipleInstances IgnoreNew` is necessary but insufficient evidence of duplicate rejection. The worker must also take a nonblocking machine-wide lock and issue a specific bounded `CONCURRENT_EXECUTION` result for every extra request it observes.
7. A task cannot reliably identify who invoked `Start-ScheduledTask`. The request file's owner SID, resolved against the install-time allowlisted operator SID, is the audit identity. The requester's claimed display name is never trusted.
8. Results and audit must be useful without leaking host inventory or command output. Return an enum, timestamps, request ID, operation, host name, and safe summary; never stdout/stderr, stack traces, environment, tokens, paths supplied by a caller, or evidence contents.

## 7. Approaches considered and rejected

- **Enable Windows `sudo` or unrestricted `sudo`: rejected.** It grants a general elevation mechanism rather than one governed maintenance operation.
- **Prompt for UAC over SSH: rejected.** Consent UI is interactive, session-bound, and not a reliable unattended transport.
- **Set `LocalAccountTokenFilterPolicy=1`: rejected.** It weakens remote-admin protections for every remote administrator action.
- **Run the repository checkout directly from the privileged task: rejected.** The remote operator can change checkout contents and obtain arbitrary elevated execution.
- **Pass a command, script path, arguments, evidence path, or working directory in JSON: rejected.** An allowlist around a general command runner is still a general-purpose broker with parser and quoting escape paths.
- **Create a broad Windows service or HTTP/named-pipe daemon: rejected.** It adds a persistent attack surface, service lifecycle, and protocol that one infrequent operation does not need.
- **Create and delete one-off highest tasks per request: rejected.** It requires privileged task mutation, is not idempotently governed, and reproduces the ungoverned #246 workaround.
- **Grant the operator Full Access on the scheduled task: rejected.** Full Access permits task replacement, converting read/run access into arbitrary elevation.
- **Use the GitHub runner service to do the Administrator checks: rejected.** The documented restricted service account cannot reliably query TPM, and maintenance must not mutate or couple itself to runner-service state.
- **Disable or stop the runner service during proof: rejected.** The operation only reads service state; stopping or reconfiguring it would violate issue #262 and could cancel CI.

## 8. Design decisions already made

### Locked on 2026-09-17 — do not relitigate

- UAC and remote-token filtering remain enabled.
- The initial and only allowlist entry is `refresh-qualification`.
- Task name: `\AiDevOps\WindowsRunnerMaintenance`.
- Principal: resolved local `HOST\ahazan`, `LogonType S4U`, `RunLevel Highest`; no password is stored. If S4U cannot be installed and run on a host, stop rather than substitute SYSTEM or a stored credential.
- Task action: machine-wide `C:\Program Files\PowerShell\7\pwsh.exe -NoProfile -NonInteractive -ExecutionPolicy AllSigned -File <protected worker>`. If repository scripts are not signed at implementation time, use `RemoteSigned` only for the administrator-owned local payload and verify SHA-256 before every dispatch; never use caller-controlled content. The independent security reviewer must approve the final execution-policy choice.
- Review-driven tightening of the task action (exact-head reviews at `8a72a9fc` and `b1b6007e`, 2026-09-17): the action launches through `C:\Windows\System32\cmd.exe /d` running the hash-pinned `launch-worker.cmd` from the protected payload. The launcher clears the ENTIRE inherited S4U environment and rebuilds a fixed allowlist of well-known literals before the same machine-wide `pwsh.exe` command runs — a denylist was judged insufficient because the CoreCLR profiler channel and its siblings load operator code before any script statement. This tightens the locked action without broadening the operation or the privilege boundary.
- Review-driven tightening of the evidence contract (same reviews): the operator holds NO grant on the qualification evidence or its tmp sibling. The elevated worker and qualification child write through their Administrators membership; any operator ACE on those files is ACL drift.
- Protected payload root: `C:\Program Files\ai-devops\windows-runner-maintenance`; runtime root: `C:\ProgramData\ai-devops\windows-runner-maintenance`.
- Request schema contains only `schema_version`, UUID `request_id`, literal `operation`, and UTC `requested_at`. All unknown fields and malformed/oversized inputs fail closed.
- Worker derives requester SID from the request file owner and compares it to the install-time SID. It never trusts a claimed user.
- Result schema is bounded to 8 KiB and contains only schema, request ID, operation, host, start/end UTC, result enum, exit code, and a curated safe message.
- Audit is administrator/SYSTEM append-only JSON Lines with request SID, host, operation, start/end UTC, and result. Operator has read access only.
- A global nonblocking lock plus Task Scheduler `IgnoreNew` prevents concurrent execution. Duplicates receive `CONCURRENT_EXECUTION`; no request silently disappears.
- The protected qualification copy always uses the fixed evidence destination. The caller cannot override it.
- Install/update/verify/remove are idempotent and refuse drift. Removal verifies task/action/principal/manifest ownership, exports recoverable metadata, removes only owned artifacts, and never touches the runner service or qualification evidence.

### Open only to the independent security reviewer

- The exact minimal Task Scheduler SDDL mask must be demonstrated on a disposable local task and both target hosts. The proposed operator ACE is `GRGX`; anything broader than read/run is a review failure.
- Choose `AllSigned` only if the project introduces a governed signing path without secrets in the repository; otherwise approve the hash-verified administrator-owned `RemoteSigned` payload. This is a technical security ruling, not permission to broaden the feature.

No owner decision is currently required. A request for another operation, another operator, SYSTEM execution, a stored credential, or a broader ACL changes the business risk and must return to Albert before implementation continues.

## 9. The plan

### Phase A — implement offline (one session; natural cut after Step 4)

1. **Freeze the contract and threat model.** Re-read issue #262, this plan, [`AGENTS.md`](AGENTS.md), [`docs/task-router.md`](docs/task-router.md), [`docs/deployment.md`](docs/deployment.md), and the Windows runner runbook. Start `ai-task-gates` with the strongest class selected from the actual intended files before editing. Confirm live that no PR/worktree now owns #262. Record the final request/result/audit schemas as constants in the tests before implementation. **You'll know it worked when** the test names and fixture schemas below exist and reject all fields outside the locked contract.

2. **Build the protected installer and payload.** Add:
   - `bin/install-windows-runner-maintenance.ps1` with `Assert-Administrator`, `Resolve-OperatorSid`, `Get-DesiredPayloadManifest`, `Set-ProtectedFilesystemAcl`, `Register-MaintenanceTask`, `Set-MaintenanceTaskAcl`, `Test-MaintenanceInstallation`, `Backup-MaintenanceInstallation`, and `Remove-MaintenanceInstallation`.
   - `bin/windows-runner-maintenance-worker.ps1` with `Read-ValidatedRequest`, `Enter-MaintenanceLock`, `Invoke-RefreshQualification`, `Write-SafeResult`, and `Write-AuditEvent`.
   - `config/windows-runner-maintenance-policy.json` containing schema version, the single literal operation, fixed task/payload/runtime names, size/time limits, and expected source payload hashes. The installer copies this into the protected root; the worker never reads policy from the repository.
   - Extend `tests/test-qualify-windows-runner.ps1` only if a stable callable function is extracted. Preserve every existing guard and the standalone Administrator behavior.

   The installer must copy the worker and `qualify-windows-runner.ps1` into a staging directory, hash and ACL it, atomically replace the owned installation, register the S4U task with no trigger and `MultipleInstances IgnoreNew`, stamp the task DACL through `Schedule.Service.SetSecurityDescriptor($sddl, 0)`, then verify exact action, principal, settings, DACL, manifest, hashes, and filesystem ACL. Update must back up the prior owned task XML/SDDL and payload before replacement. `-Verify` is read-only. `-Remove` refuses foreign/drifted objects, exports a timestamped recovery bundle, unregisters only the exact owned task, removes only manifest-owned runtime files, and leaves `windows-runner-security.json` untouched. **You'll know it worked when** the installer can run install → install → verify → remove → remove in an isolated fixture with identical second-run state and no access outside fixture roots.

3. **Build the unprivileged request client.** Add `bin/invoke-windows-runner-maintenance.ps1` with `New-MaintenanceRequest`, `Start-MaintenanceTask`, `Wait-MaintenanceResult`, and `Read-BoundedMaintenanceResult`. Its only operation parameter uses `ValidateSet('refresh-qualification')`; it accepts no command/path/argument parameter. It writes a UTF-8 no-BOM request with a fresh UUID using create-new semantics, starts the fixed task, waits with a default 180-second and hard 300-second ceiling, prints only the safe result fields, and returns nonzero for every non-success enum. It must diagnose `MISSING_TASK`, `STALE_INSTALLATION`, `CONCURRENT_EXECUTION`, `REQUEST_REJECTED`, `OPERATION_FAILED`, `RESULT_INVALID`, and `TIMEOUT`. **You'll know it worked when** the offline client fixtures map every enum to the documented message/exit code and no raw worker output is emitted.

4. **Add hostile tests and documentation.** Add `tests/test-windows-runner-maintenance.ps1` covering the exact cases in section 10. Update `config/ci-suite-manifest.json`, `tests/test-all.ps1`, and the applicable Windows test inventory so the suite is mandatory. Update [`docs/independent-windows-runner-setup.md`](docs/independent-windows-runner-setup.md) with install/update/verify/invoke/remove/recovery commands, fixed locations, result enums, and the rule that this does not replace full GitHub qualification. Update [`docs/deployment.md`](docs/deployment.md) with the narrow privileged installer exception and no generic command-catalog entry. Update [`docs/task-router.md`](docs/task-router.md) to route future maintenance elevation work back to this plan and runbook. **You'll know it worked when** focused PowerShell tests, the existing qualification test, Windows script tests, document reachability, context audit, and the complete Windows offline suite all pass with zero skipped maintenance tests.

### Phase B — review and land (fresh session; re-read Phases B and C first)

5. **Obtain exact-head independent security approval and land.** Commit only the planned files on a current-upstream feature branch. Run `ai-task-gates check --before review`; dispatch one read-only security reviewer with the exact head/base SHAs, full diff, locked threat model, task ACL, filesystem ACL, request race/concurrency model, rollback, and hostile-test evidence. Any response other than explicit `APPROVE` stops and is repaired on the same branch. Then open a PR linked to #262, use `bin/ai-pr-wait`, merge through the queue, and verify the merge commit is on `origin/main`. **You'll know it worked when** the reviewer verdict names the exact head SHA, all required checks pass for the queued landing commit, and `origin/main` contains it.

### Phase C — one live host per fresh session

6. **Install and prove `edge-dev-win`.** This is a protected host mutation. Resolve live runner status and prove it is idle without changing its service. Run `ai-task-gates check --before deploy`; provide the exact host, task name, install/update action, payload hashes, rollback command, and merged SHA to an independent read-only security reviewer. Only explicit approval authorizes an elevated local Administrator to run:

   `pwsh -NoProfile -File .\bin\install-windows-runner-maintenance.ps1 -Install -OperatorUser "$env:COMPUTERNAME\ahazan"`

   From a fresh non-elevated Tailscale SSH session run `-Verify`, invoke `refresh-qualification`, verify the evidence timestamp/build without printing the file, inspect the bounded result and audit, run all negative ACL/argument/concurrency tests, and prove the GitHub runner service name/start mode/status did not change. Exercise a recoverable failure, stale-result cleanup, and re-verify. **You'll know it worked when** one host-specific evidence record captures the merged SHA, installed hashes, exact token elevation state, task/payload ACLs, positive result, negative tests, audit fields, evidence freshness, unchanged runner service, and tested rollback command.

7. **Install and prove `EDGE-RUNN-ENVY`.** Use a new session and repeat Step 6 independently; do not treat the first host as portability evidence. Re-resolve host identity, Windows build, operator SID, task absence/state, and runner idleness. **You'll know it worked when** the second host has its own complete evidence record with the same acceptance matrix and no fact copied from `edge-dev-win` as proof.

8. **Reconcile and close.** From current `origin/main`, compare both host records, verify `-Verify` still passes on each, prove no temporary tasks/backups/request files/locks remain except the intentional installed task, and confirm rollback bundles are protected and bounded. Update this STATUS table and the handoff, move the plan to the completed table in `docs/implementation-plan-index.md`, retire the handoff under the successor rule, and close #262 only after every required outcome is evidenced. **You'll know it worked when** #262 is closed with direct links to the merged commit, exact-head review, two live-host records, unchanged runner services, and rollback proof.

## 10. Tests required

`tests/test-windows-runner-maintenance.ps1` must include named cases for:

- `Install_IsIdempotent`, `Update_IsAtomicAndBackedUp`, `Verify_IsReadOnly`, `Remove_IsIdempotent`, and `Remove_RefusesForeignOrDriftedTask`.
- `Task_UsesS4UHighestFixedProtectedAction`, `Task_HasNoTrigger`, `Task_IgnoresParallelInstance`, `Operator_CanReadAndRunOnly`, and `Operator_CannotChangeDeleteOrReplaceTask`.
- `Payload_IsAdministratorOwnedAndHashVerified`, `RepositoryMutation_CannotChangeInstalledPayload`, `ReparsePoint_IsRejected`, and `AclDrift_FailsClosed`.
- `Request_AllowsOnlyRefreshQualification`, `Request_RejectsUnknownFields`, `Request_RejectsArgumentsPathsAndEnvironment`, `Request_RejectsWrongOwner`, `Request_RejectsMalformedJson`, `Request_RejectsOversize`, `Request_RejectsStaleTimestamp`, and `Request_RejectsReusedUuid`.
- `Concurrency_OneRunsAndDuplicateGetsExplicitResult`, `StaleLock_IsDiagnosedNotSilentlyRemoved`, and `TaskIgnoredStart_DoesNotLoseRequest`.
- `Result_IsAtMost8KiB`, `Result_ContainsOnlySafeSchema`, `Result_RejectsMismatchedUuid`, `Result_RejectsReparsePoint`, `Timeout_IsBounded`, and `Failure_DoesNotExposeExceptionStdoutStderrEnvironmentOrEvidence`.
- `Audit_RecordsRequesterSidHostOperationStartEndResult`, `Audit_IsAppendOnlyForOperator`, and `Audit_RecordsRejectedAndFailedRequests`.
- `RefreshQualification_UsesFixedEvidencePath`, `RefreshQualification_PreservesAllExistingGuards`, and `RunnerService_IsReadOnly`.
- `Recovery_MissingTask`, `Recovery_StaleInstall`, `Recovery_RunningTask`, `Recovery_FailedCleanup`, and `Rollback_RestoresExactPriorOwnedState`.

Required commands before the implementation PR:

- `pwsh -NoProfile -File tests/test-windows-runner-maintenance.ps1`
- `pwsh -NoProfile -File tests/test-qualify-windows-runner.ps1`
- `"C:\Program Files\Git\bin\bash.exe" tests/test-windows-scripts.sh`
- `python3 bin/ai-doc-reachability --repo . --base origin/main`
- `pwsh -NoProfile -File tests/test-context-audit.ps1`
- `pwsh -NoProfile -File tests/test-all.ps1` after `bin/ai-test-local --check-collision` permits the local run

Live tests run from a filtered, non-elevated SSH token on each host and must prove success plus every negative privilege test. Never simulate live acceptance with an elevated console.

## 11. Constraints, standing rules, and gotchas

- Use a unique current-upstream worktree; stage only owned files; never push to `main`.
- Declare the real task class and recheck before review, shipment, installation, or live proof. A refusal stops work; it is not bypassed.
- Installation/live proof is one host and one unproven outcome per session.
- Every GitHub call goes through `bin/ai-gh`; CI waits use `bin/ai-pr-wait` with a bound.
- Independent read-only exact-head security approval is mandatory before merge and again before each protected live-host installation.
- Check runner idleness immediately before every host mutation. Do not stop, restart, replace, relabel, or reconfigure the runner service.
- A successful task result is not full runner qualification. GitHub's canonical qualification remains separate.
- Never expose the private machine atlas, SSH material, tokens, raw environment, result internals, or Windows security evidence content in the public repo, PR, issue, audit, or logs.
- The local `ahazan` name is not an authority boundary; resolve and pin its SID separately on each host. Refuse a missing, domain, ambiguous, or changed SID.
- Do not trust a green CI runner as proof that Tailscale administration works, or one host as proof of the other.
- PowerShell 5.1 and PowerShell 7 differ in encoding. Requests/results must specify UTF-8 behavior and parse bytes with a hard bound.
- Task Scheduler's security-descriptor method uses flag `0`; `4` is not a security-information flag and fails.
- Task and filesystem ownership/ACL checks must inspect resolved SIDs, not localized account display names.
- No cleanup may delete an unknown file, foreign task, qualification evidence, runner task/service, or unverified backup.

## 12. Access and environment

- Repository: `popcre/ai-devops`; target branch `main`; feature-branch PR with merge queue.
- GitHub access: authenticated `bin/ai-gh` as the repository owner identity; never call `gh` directly.
- Windows access: existing Tailscale SSH aliases `edge-dev-win` and `EDGE-RUNN-ENVY`, local identity `ahazan`. Resolve addresses from the private machine atlas at runtime; do not copy them here.
- Elevated installation: an interactive local Administrator or an independently approved existing recovery route on the named host. A filtered SSH token cannot bootstrap its own elevation boundary.
- Required host tools: machine-wide PowerShell 7 at `C:\Program Files\PowerShell\7\pwsh.exe`, Git Bash at `C:\Program Files\Git\bin\bash.exe`, Task Scheduler, TPM, Secure Boot, and one running automatic runner service.
- Secrets: none are required by the maintenance task. GitHub/SSH authentication remains outside the task. If a credential unexpectedly becomes necessary, stop; do not add it to this design. Governed secrets would live only in 1Password vault `vibe_coding`, referenced by item title and never value.
- Local offline development uses fixture roots and mocked Task Scheduler adapters; it must not register a real privileged task on the development PC.

## 13. Definition of done, risks, rollback, and open questions

### Definition of done

- All planned source/config/test/doc files exist, are reviewed, and every test in section 10 passes.
- The exact implementation head receives explicit independent read-only security `APPROVE`.
- The PR passes its required checks, merges through the queue, and the intended commit is verified on `origin/main`.
- `edge-dev-win` and `EDGE-RUNN-ENVY` each pass separate filtered-token positive, hostile negative, audit, recovery, and unchanged-runner-service proof against the merged SHA.
- Install, second install, update, verify, invoke, failure recovery, remove, second remove, and reinstall are each proven idempotent/recoverable as applicable.
- UAC and remote-token filtering remain enabled; no `sudo`, `LocalAccountTokenFilterPolicy`, runner-service, Tailscale, credential, or secret change occurs.
- This STATUS table and handoff are current; the plan index moves this record to completed; #262 closes with direct evidence.

### Risks and mitigations

- **ACL too broad:** a read/run ACE may map unexpectedly. Prove the resolved SDDL and negative redefine/delete tests; any broader effective right stops.
- **Mutable elevated payload:** repository or runtime ACL drift could redirect execution. Use protected copies, exact hashes, no reparse points, fixed executable/action, and fail-closed verification.
- **Request race or loss:** task `IgnoreNew` alone can strand a request. Use worker lock, bounded queue scan, per-request results, UUID replay ledger, and hostile concurrent tests.
- **Unsafe diagnostics:** PowerShell exceptions can include paths or values. Map internal failures to curated codes; keep detailed audit bounded and secret-safe.
- **S4U difference between hosts:** validate independently. If either host cannot run the fixed task as designed, stop; do not silently switch to SYSTEM or store a password.
- **Rollback damage:** removal could target foreign state. Require manifest/hash/action/principal/DACL ownership proof and a verified recovery bundle before deletion.
- **Repository tampering:** the policy-hash check in `Get-DesiredPayloadManifest` detects accidental drift, not a compromised checkout — the policy file lives in the same repository an operator could edit. Tamper resistance comes from the elevated install being run deliberately from a trusted checkout and from the administrator-owned protected copy installed on the host, never from the repository itself.

### Exact rollback

Before every install/update, export the existing owned task XML, task SDDL, payload manifest/hashes, and ACLs into a timestamped Administrator-only recovery bundle. If live acceptance fails, run:

`pwsh -NoProfile -File .\bin\install-windows-runner-maintenance.ps1 -Remove -RequireManifestMatch -BackupPath <reviewed-protected-backup>`

Then verify the task is absent, owned payload/runtime request/result files are absent, the pre-existing `windows-runner-security.json` remains, and the GitHub runner service has the exact pre-install name, startup mode, account, and status. If the task/payload drifted and safe removal refuses, use the exported exact task XML/SDDL and manifest in an elevated recovery session; never force-delete by broad path.

### Open questions

Only two technical validations remain, both assigned to the independent security reviewer rather than Albert: prove the minimal Task Scheduler read/run mask on the actual Windows builds, and approve `AllSigned` versus hash-verified protected `RemoteSigned`. Either may tighten the implementation; neither may broaden the operation or privilege boundary.

## Mandatory plan self-audit

1. **Could a brand-new session execute this perfectly without asking anything? Yes.** Sections 2–6 define the system, trigger, exact current files, root cause, and scope; sections 8–12 name the locked schemas, files, functions, commands, hosts, phases, and gates; section 13 defines completion and rollback.
2. **Does the plan preserve every relevant nuance and rejected path? Yes.** Sections 6–8 carry the token-filtering cause, protected-copy requirement, audit identity, concurrency/result model, all rejected elevation shortcuts, and the two bounded security-review judgments.
3. **Is the goal clear enough for an unexpected judgment call? Yes.** Section 1 states the business result and the goal-wins rule; sections 4, 8, and 11 define what may never be traded away.

Checklist result: all 13 required sections are present; a fresh session has no chat dependency; scope and rejected approaches are explicit; every step names concrete files/functions and a verification gate; locked/open decisions are labeled; tests are named; identifiers and hosts are defined; secrets are location-only; landing, installation, live SHA proof, rollback, and issue closure are included; and plan/handoff links are reciprocal.
