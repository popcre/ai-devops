# edge-dev-win step 6 — raw command transcripts (2026-10-09)

Verbatim decisive outputs. No addresses, SSH material, or qualification-evidence
contents appear; evidence file contents were never printed (metadata/shape only).
Human times: EDT.

## 1. Gates and security APPROVE

```
task class "installation" recorded for popcre/ai-devops (C:/tmp/wt-edge-dev-win-step6)
base: 698554f6013a
ai-task-gates: "deploy" allowed by assigned AI reviewer: APPROVE by muse (implementer mimo, run 20261009T200522-1626-8949, security-review) for deploy at b528742e66df6d56629d18bfb705ea5183349c88 report sha256:497ee683a95a29d05503b46d2f53bfd248234a97f7156070b2b68e5553fcdf9a
```

## 2. Offline tests (pre-mutation)

```
RESULT: 127 passed, 0 failed, 0 skipped   # tests/test-windows-runner-maintenance.ps1
PASS: Administrator Windows runner preflight is complete and atomic
53 passed, 0 failed                       # tests/test-windows-scripts.sh
```

## 3. Live state before recovery (2026-10-09)

```
HOST=EDGE-DEV
BOOT=2026-10-09T14:57:47.5000000-04:00
SECUREBOOT=False
ADMIN=True
SVC actions.runner.popcre-ai-devops.edge-dev-win status=Stopped start=Auto account=NT AUTHORITY\NETWORK SERVICE
TASK state=Ready user=ahazan logon=S4U run=Highest
TASK exec=C:\Windows\System32\cmd.exe args=/d /c "C:\Program Files\ai-devops\windows-runner-maintenance\launch-worker.bat"
EVIDENCE len=338 mtime=2026-09-03T23:09:52.6642491-04:00
# runtime records present: audit.jsonl + processed-requests.jsonl + 5 results (2026-09-28 and 2026-10-08)
OPERATOR sid=S-1-5-21-3782134917-2737737491-2203520143-1001
TPM present=True ready=True
```

## 4. Recovery + install (elevated SSH)

```
RECOVERY: RECOVERED
PASS: Windows runner maintenance installation verified
```

Runtime records after recovery (mtimes unchanged from pre-recovery):
```
FILE \audit.jsonl len=1509 mtime=2026-10-08T11:34:49.7650350-04:00
FILE \processed-requests.jsonl len=275 mtime=2026-10-08T11:34:49.7660198-04:00
FILE \results\6892a118-… mtime=2026-10-08T11:34:49.7296639-04:00
FILE \results\a72e1437-… mtime=2026-10-08T09:39:32.4453689-04:00
FILE \results\c21403a4-… mtime=2026-10-08T09:39:32.4733717-04:00
FILE \results\cc333b3e-… mtime=2026-09-28T11:40:28.5002734-04:00
FILE \results\fc4cbbdb-… mtime=2026-09-28T11:40:28.5367711-04:00
BACKUP windows-runner-maintenance-recovery-partial-20261009T201831Z
```

## 5. Verify + non-elevated invoke

```
PASS: Windows runner maintenance installation verified   # elevated -Verify
CONTEXT admin=False
{ "result": "OPERATION_FAILED", "exit_code": 1,
  "message": "Qualification did not complete successfully." }
RC=14
RESULT fields=ended_at_utc,exit_code,host,message,operation,request_id,result,schema_version,started_at_utc
AUDIT … result=OPERATION_FAILED sid=S-1-5-21-3782134917-2737737491-2203520143-1001
AUDIT … result=REQUEST_REJECTED sid=S-1-5-32-544
EVIDENCE mtime=2026-09-03T23:09:52.6642491-04:00   # unchanged; content never printed
```

## 6. Negatives and concurrency (non-elevated)

```
N1 REDEFINE=REFUSED (Access is denied)
N1 UNREGISTER=REFUSED (Access is denied)
N2 UNKNOWN_OP=REFUSED
N4 job1 result=OPERATION_FAILED
N4 job2 result=CONCURRENT_EXECUTION
SVC actions.runner.popcre-ai-devops.edge-dev-win status=Stopped start=Auto account=NT AUTHORITY\NETWORK SERVICE
```

## 7. Rollback + reinstall + idempotency

```
REMOVED
# task absent; windows-runner-security.json mtime 2026-09-03 untouched
# runtime exported to C:\ProgramData\ai-devops\reviewed-maintenance-recovery-edge-dev-win\runtime\
PASS: Windows runner maintenance installation verified   # reinstall
PASS: Windows runner maintenance installation verified   # second install
PASS: Windows runner maintenance installation verified   # final -Verify
```

## 8. GitHub runner labels (unqualified)

```
{"busy":false,"labels":["self-hosted","Windows","X64","edge-dev","ai-devops-windows"],"name":"edge-dev-win","status":"offline"}
```
