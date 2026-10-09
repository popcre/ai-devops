# EDGE-RUNN-ENVY step 7 — raw command transcripts (2026-10-09)

Verbatim tool outputs backing `README.md`. No addresses, SSH material, or
qualification-evidence contents appear; evidence file contents were never
printed (metadata/shape only). Human times: events are UTC; day 2026-10-09 EDT.

## 1. Gate declaration and deploy gate

```
task class "installation" recorded for popcre/ai-devops (C:/repos/ai-devops)
base: 66c465cd8b505178a512f7d9b6e4ffca0a8258c1
```

(first refusal, fail-closed, before any approval existed:)

```
ai-task-gates: STOP. A same-source toolkit installation needs an assigned AI reviewer APPROVE (--reviewer-approval <report>).
```

(after ff to 63e83b07 and with the exact-head deploy APPROVE:)

```
git pull --ff-only origin main  ->  63e83b0772b5b8e7a071264829b163dd863c39f6
ai-task-gates: "deploy" allowed by assigned AI reviewer: APPROVE by muse (implementer mimo, run 20261009T153928-1591030-1505, security-review) for deploy at 63e83b0772b5b8e7a071264829b163dd863c39f6 report sha256:c6b89b31bad7b84f82eddabe5275ef9e02074f555e86517af02a38d1fe7acfc9
```

## 2. Runner idleness checks (GitHub, via bin/ai-gh; window brackets)

```
15:59Z  EDGE-RUNN-ENVY status=online busy=false     (immediately before install)
16:07Z  EDGE-RUNN-ENVY status=online busy=false     (after proof run)
16:16Z  EDGE-RUNN-ENVY status=online busy=false     (before DoD cycle)
16:29Z  EDGE-RUNN-ENVY status=online busy=false     (after DoD cycle + hostile test)
```

(No `Runner.Worker` process was observed at any probe inside this window; each
in-driver mutation additionally asserted both conditions — see section 6.)

## 3. Install (elevated session; idleness re-checked inside the driver)

```
PREINSTALL_SERVICE=name=actions.runner.popcre-ai-devops.EDGE-RUNN-ENVY|state=Running|startmode=Auto|startname=NT AUTHORITY\NETWORK SERVICE
TASK_PRECONDITION=ABSENT
CLONING
HEAD is now at 63e83b07 docs: hand off Qwen recovery child and runner diagnosis (#1545)
CHECKOUT_HEAD=63e83b0772b5b8e7a071264829b163dd863c39f6
PAYLOAD_HASHES=6/6 MATCH
PASS: Windows runner maintenance installation verified
INSTALL_EXIT=0
TASKPROP TaskName:                             \AiDevOps\WindowsRunnerMaintenance
TASKPROP Status:                               Ready
TASKPROP Logon Mode:                           Interactive/Background
TASKPROP Task To Run:                          C:\Windows\System32\cmd.exe /d /c "C:\Program Files\ai-devops\windows-runner-maintenance\launch-worker.bat"
TASKPROP Run As User:                          ahazan
TASKPROP Schedule Type:                        On demand only
POSTINSTALL_SERVICE=name=actions.runner.popcre-ai-devops.EDGE-RUNN-ENVY|state=Running|startmode=Auto|startname=NT AUTHORITY\NETWORK SERVICE
SERVICE_UNCHANGED=True
```

## 4. Proof run 1 (fresh session; exposed the worker-linger orchestration issue)

```
VERIFY_RC=0 OUT=PASS: Windows runner maintenance installation verified
SERVICE_UNCHANGED=True
EVIDENCE_MTIME_PRE_INVOKE=2026-09-04T03:28:26.9402474Z
LIMITED_CHILD_RC=0 DETAIL=spawn-ok pid=8362024
PROOF CTX elevated=False user=edge-runn-envy\ahazan
PROOF NET_SESSION_RC=2
PROOF QUERY_RC=0
PROOF CHANGE_DISABLE_RC=1 MSG=ERROR: Access is denied.
PROOF DELETE_RC=1 MSG=ERROR: Access is denied.
PROOF TASK_PRESENT_AFTER_ATTEMPTS_RC=0
PROOF UNKNOWN_OP_RC=1 MSG=invoke-windows-runner-maintenance.ps1: Cannot validate argument on parameter 'Operation'. The argument "not-a-real-op" does not belong to the set "refresh-qualification" specified by the ValidateSet a
PROOF UNKNOWN_ARG_RC=1 MSG=invoke-windows-runner-maintenance.ps1: A parameter cannot be found that matches parameter name 'Frobnicate'.
PROOF RUN_C_RC=0
PROOF UNKNOWN_FIELD_RESULT=REQUEST_REJECTED KEYS=ended_at_utc,exit_code,host,message,operation,request_id,result,schema_version,started_at_utc
PROOF INVOKE_RC=12 OUT={ "schema_version": 1, "request_id": "57243b9b-bf75-4ecf-b88c-6d50409af673", "operation": "refresh-qualification", "host": "EDGE-RUNN-ENVY", "started_at_utc": "2026-10-09T15:58:41.9034793Z", "ended_at_utc": "2026-10-09T15:58:41.9225638Z", "result": "CONCURRENT_EXECUTION", "exit_code": 1, "message": "Another maintenance request is already running." }
PROOF EVIDENCE_ADVANCED=False        (no execution happened in this run)
PROOF CONC_A_RESULT=CONCURRENT_EXECUTION CONC_B_RESULT=CONCURRENT_EXECUTION
PROOF RESULT_FILES=4 SCHEMA_VIOLATIONS=0
GROUPS BUILTIN\Administrators ... Group used for deny only
GROUPS Mandatory Label\Medium Mandatory Level ... S-1-16-8192
```

Interpretation recorded in README: every request during one worker instance's
life is answered `CONCURRENT_EXECUTION` (client rc 12 — bounded, not a hang,
not a drop; all four requests produced result files). Fixed by waiting for
task `Ready` between phases.

## 5. Proof run 2 (fresh session; full matrix pass)

```
VERIFY_RC=0 OUT=PASS: Windows runner maintenance installation verified
SERVICE_UNCHANGED=True
EVIDENCE_MTIME_PRE_INVOKE=2026-09-04T03:28:26.9402474Z
LIMITED_CHILD_RC=0 DETAIL=spawn-ok pid=8369712
PROOF CTX elevated=False user=edge-runn-envy\ahazan
PROOF NET_SESSION_RC=2
PROOF QUERY_RC=0
PROOF CHANGE_DISABLE_RC=1 MSG=ERROR: Access is denied.
PROOF DELETE_RC=1 MSG=ERROR: Access is denied.
PROOF TASK_PRESENT_AFTER_ATTEMPTS_RC=0
PROOF UNKNOWN_OP_RC=1 MSG=invoke-windows-runner-maintenance.ps1: Cannot validate argument on parameter 'Operation'. ...
PROOF UNKNOWN_ARG_RC=1 MSG=invoke-windows-runner-maintenance.ps1: A parameter cannot be found that matches parameter name 'Frobnicate'.
PROOF RUN_C_RC=0
PROOF UNKNOWN_FIELD_RESULT=REQUEST_REJECTED KEYS=ended_at_utc,exit_code,host,message,operation,request_id,result,schema_version,started_at_utc
PROOF WORKER_READY_AFTER_C=True
PROOF WORKER_READY_BEFORE_INVOKE=True
PROOF INVOKE_RC=0 OUT={ "schema_version": 1, "request_id": "f9389433-e0c3-4e7b-ba25-4dd219bdbe08", "operation": "refresh-qualification", "host": "EDGE-RUNN-ENVY", "started_at_utc": "2026-10-09T16:01:37.7110349Z", "ended_at_utc": "2026-10-09T16:01:41.1605734Z", "result": "SUCCESS", "exit_code": 0, "message": "Windows runner qualification evidence was refreshed." }
PROOF EVIDENCE_MTIME_BEFORE=2026-09-04T03:28:26.9402474Z
PROOF EVIDENCE_MTIME_AFTER=2026-10-09T16:01:41.0529609Z
PROOF EVIDENCE_ADVANCED=True
PROOF WORKER_READY_BEFORE_AB=True
PROOF RUN_AB_RC=0
PROOF CONC_A_RESULT=CONCURRENT_EXECUTION CONC_B_RESULT=SUCCESS
PROOF AUDIT result=SUCCESS op=refresh-qualification host=EDGE-RUNN-ENVY sid=S-1-5-21-***-1001 dur=3.4s
PROOF AUDIT result=SUCCESS op=refresh-qualification host=EDGE-RUNN-ENVY sid=S-1-5-21-***-1001 dur=1.7s
PROOF AUDIT result=REQUEST_REJECTED op=refresh-qualification host=EDGE-RUNN-ENVY sid=S-1-5-21-***-1001 dur=0s
PROOF AUDIT result=CONCURRENT_EXECUTION op=refresh-qualification host=EDGE-RUNN-ENVY sid=S-1-5-21-***-1001 dur=0s
PROOF RESULT_FILES=8 SCHEMA_VIOLATIONS=0
GROUPS NT AUTHORITY\Local account and member of Administrators group ... S-1-5-114 Group used for deny only
GROUPS BUILTIN\Administrators ... S-1-5-32-544 Group used for deny only
GROUPS Mandatory Label\Medium Mandatory Level ... S-1-16-8192
EVIDENCE_MTIME_POST_INVOKE=2026-10-09T16:01:47.8467255Z
EVIDENCE_ADVANCED=True
TASK_STILL_PRESENT_RC=0
SERVICE_FINAL_UNCHANGED=True
```

Full audit SIDs equal
`S-1-5-21-4110623484-3775389421-3704134857-1001` (recorded full in README;
masked here only because the original transcript masked them).

## 6. Rollback phase

```
EVIDENCE_MTIME_START=2026-10-09T16:01:47.8467255Z
R1_REMOVE_BADPATH_RC=1 MSG=Exception: ... Recovery backup path must be under an administrator-managed root (ProgramD...
R1_TASK_STILL_PRESENT_RC=0
R2_REMOVE_RC=0 MSG=REMOVED
R2_TASK_ABSENT_RC=1
R2_PAYLOAD_ROOT_PRESENT=False
R2_RUNTIME_LEFT=
EVIDENCE_MTIME_AFTER_REMOVE=2026-10-09T16:01:47.8467255Z UNCHANGED=True
R2_BACKUP_ENTRIES=payload,runtime,recovery.json,task.xml
R2_BACKUP_NONADMIN_ACES=0
R2_SERVICE=Running|Auto|NT AUTHORITY\NETWORK SERVICE
R3_REINSTALL_RC=0 MSG=PASS: Windows runner maintenance installation verified
R4_REVERIFY_RC=0 MSG=PASS: Windows runner maintenance installation verified
FINAL_TASK_PRESENT_RC=0
FINAL_SERVICE=Running|Auto|NT AUTHORITY\NETWORK SERVICE
FINAL_EVIDENCE_MTIME=2026-10-09T16:01:47.8467255Z PRESERVED=True
TEMP_TASKS_REMAINING=0
```

## 7. DoD cycle (idleness asserted before every mutation)

```
IDLE_OK second-install service=Running/Auto/NT AUTHORITY\NETWORK SERVICE
SECOND_INSTALL_RC=0 MSG=PASS: Windows runner maintenance installation verified
IDLE_OK update service=Running/Auto/NT AUTHORITY\NETWORK SERVICE
UPDATE_RC=0 MSG=PASS: Windows runner maintenance installation verified
IDLE_OK verify-after-update service=Running/Auto/NT AUTHORITY\NETWORK SERVICE
VERIFY_AFTER_UPDATE_RC=0 MSG=PASS: Windows runner maintenance installation verified
IDLE_OK invoke-2 service=Running/Auto/NT AUTHORITY\NETWORK SERVICE
INVOKE2_RC=0 OUT={ ... "result": "SUCCESS", "exit_code": 0, ... "started_at_utc": "2026-10-09T16:18:10.7715576Z", "ended_at_utc": "2026-10-09T16:18:12.4014614Z" ... }
IDLE_OK hostile-duplicate service=Running/Auto/NT AUTHORITY\NETWORK SERVICE
MIDRUN_TASK_RUNNING_OBSERVED=True delay_ms=668
HOSTILE_DUP_A=REQUEST_REJECTED B=REQUEST_REJECTED    <- elevated raw writes are Administrators-owned; worker rejected both (live wrong-owner proof); rerun below with caller re-own
EVIDENCE_SHAPE parse=ok fields=9 missing=0 extra=0 build_matches_known=True schema_v1=True
IDLE_OK second-remove service=Running/Auto/NT AUTHORITY\NETWORK SERVICE
SECOND_REMOVE_RC=0 MSG=REMOVED
TASK_ABSENT_AFTER_SECOND_REMOVE_RC=1
REMOVE_AGAIN_RC=0 MSG=ABSENT
IDLE_OK final-reinstall service=Running/Auto/NT AUTHORITY\NETWORK SERVICE
FINAL_REINSTALL_RC=0 MSG=PASS: Windows runner maintenance installation verified
FINAL_VERIFY_RC=0 MSG=PASS: Windows runner maintenance installation verified
FINAL_TASK_PRESENT_RC=0
FINAL_SERVICE=Running|Auto|NT AUTHORITY\NETWORK SERVICE
FINAL_RUNNER_WORKER=False
FINAL_EVIDENCE_MTIME=2026-10-09T16:18:12.3195965Z
```

## 8. Hostile mid-run duplicate, rerun with caller-SID re-own

```
WROTE 06987790-d394-4a17-912b-02544b3dc37b owner_is_caller=True
WROTE 7582753b-27a6-4cc3-adf1-d0d1e4f8986d owner_is_caller=True
MIDRUN_TASK_RUNNING_OBSERVED=True delay_ms=460
HOSTILE_DUP_A=SUCCESS B=CONCURRENT_EXECUTION
SERVICE=Running|Auto|NT AUTHORITY\NETWORK SERVICE
```

## 9. Final host snapshot and harness cleanup

```
TASK Status: Ready
TASK Task To Run: C:\Windows\System32\cmd.exe /d /c "C:\Program Files\ai-devops\windows-runner-maintenance\launch-worker.bat"
TASK Run As User: ahazan
TASK Schedule Type: On demand only
EVIDENCE mtime=2026-10-09T16:01:47.8467255Z len=338        (metadata only; content never read)
RUNTIME: requests, results, temp, audit.jsonl, processed-requests.jsonl
SERVICE Running|Auto|NT AUTHORITY\NETWORK SERVICE
RUNNER_WORKER_PROC=False
DELETED limtok-probe.ps1 / limproof-child.ps1 / limproof-child.cmd /
        limproof-driver.ps1 / limproof-driver2.ps1 / limproof-driver3.ps1 /
        limproof-driver4.ps1 / topen.ps1 / envy-install-driver.ps1 /
        proof-driver.ps1 / negproof.ps1 / rollback-driver.ps1 /
        envy-negproof.txt / envy-negproof-groups.txt
```

(Final-cycle and hostile drivers were deleted in a later cleanup pass; their
exact bytes are committed under `harness/`.)
