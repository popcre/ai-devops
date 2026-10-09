# edge-dev-win (EDGE-DEV) — Windows runner maintenance recovery + install proof (plan step 6)

Date: 2026-10-09. Event timestamps are UTC machine times; human-referenced
completion: 4:25 PM EDT, 2026-10-09 (20:25 UTC).
Host: `edge-dev-win` (Windows hostname `EDGE-DEV`; SSH alias `edge-dev`).
Scope: `plan_windows-runner-maintenance-elevation.md` step 6, issue #962 / parent
#262. One host only; `EDGE-RUNN-ENVY` untouched (already proven, PR #1546).
The uncommitted draft in the `edge-dev-runner-qualification` worktree was not
installed. Evidence file content was never printed (metadata/shape only).

## Source and approvals

- Install/recovery source: worktree head
  `b528742e66df6d56629d18bfb705ea5183349c88` (install-inputs doc on top of
  `origin/main` `698554f6`). Payload files are byte-identical to
  `origin/main` at install time (two later docs-only commits on main do not
  touch the payload).
- **Security APPROVE** (read-only, provider `muse`, implementer engine `mimo`,
  run `20261009T200522-1626-8949`, mode `security-review`, head `b528742e…`):
  report
  [review-recovery-approve-b528742e.md](review-recovery-approve-b528742e.md),
  SHA-256 `497ee683a95a29d05503b46d2f53bfd248234a97f7156070b2b68e5553fcdf9a`.
- Deploy gate after declaring `installation` at pre-update HEAD `698554f6` and
  moving to the reviewed head:
  `ai-task-gates check --before deploy --reviewer-approval <report>` →
  `"deploy" allowed by assigned AI reviewer: APPROVE by muse (implementer mimo,
  run 20261009T200522-1626-8949, security-review) for deploy at
  b528742e66df6d56629d18bfb705ea5183349c88 report
  sha256:497ee683a95a29d05503b46d2f53bfd248234a97f7156070b2b68e5553fcdf9a`.
- Task class `installation` declared before any host mutation.

## Payload SHA-256 (source at install head; 4/4 payload files match installed)

- `bin/install-windows-runner-maintenance.ps1` `c2d2719570f05c82a9defbf9556263a167efc2a5d30f559240a3af985d824830`
- `bin/windows-runner-maintenance-worker.ps1` `c763a9aff60f92ecca16be07ae7e1d43fc57bb608490eec0a74b59fa912f10f4`
- `bin/launch-worker.bat` `02cccf7873d2b01b27665434600b89e5aae3fa27d106215e3cc09e2bbac32d92`
- `config/windows-runner-maintenance-policy.json` `255f91de23c6585ce9ac60444685fa1aa1ba777d99bb794a7c9c7d0b727453e7`
  (installed copy is rewritten at install time; manifest pins installed
  `287d72f72282a010a58f7392549f77921c1344586eee870150c2bebd8148d702`)
- `bin/qualify-windows-runner.ps1` `172e1dac1d6de2407acef170b5f63332fb0bfa1e8db73e27b16d6ad2168ccaf7`
- `bin/invoke-windows-runner-maintenance.ps1` `c1ec759e3d9e7ae6c46c3325be41362715eb563a2da833e2c8781b791e6aeff4`

## Operator identity

Local user `EDGE-DEV\ahazan`, SID
`S-1-5-21-3782134917-2737737491-2203520143-1001` (enabled, local account).

## Recovery (issue #962 acceptance — seal/disable, preserve runtime records)

Before recovery the Oct 8 install verified against its own manifest but the
installed policy hash was stale versus current source (`939e8f58…` vs
`255f91de…`). `RecoverPartial` from the reviewed head reported `RECOVERY:
RECOVERED`, then `PASS: Windows runner maintenance installation verified`.

- **Runtime records preserved across recovery** (mtimes unchanged):
  `audit.jsonl` and `processed-requests.jsonl` 2026-10-08; result files
  `cc333b3e…` / `fc4cbbdb…` 2026-09-28 and `a72e1437…` / `c21403a4…` /
  `6892a118…` 2026-10-08. Still present after recovery.
- **Seal + disable before unregister** is the landed `RecoverPartial` path
  (`Set-MaintenanceTaskTeardownAcl` drops the operator ACE, `Disable-ScheduledTask`,
  identity re-check, then unregister). Covered by tests
  `RecoverPartial_SealsThenDisablesBeforeUnregister`,
  `RecoverPartial_PreservesRuntimeRecords`,
  `RecoverPartial_TeardownAclDropsOperatorEntirely` (maintenance suite 127/127).
- Recovery backup bundle:
  `C:\ProgramData\ai-devops\windows-runner-maintenance-recovery-partial-20261009T201831Z`.

## Acceptance matrix (plan §10 / ENVY §10 host adaptation)

| Case | Result |
|---|---|
| Elevated `-Verify` after recovery+install | `PASS: Windows runner maintenance installation verified` |
| Non-elevated invoke `refresh-qualification` | Task ran; bounded result `OPERATION_FAILED` (see host preconditions); result schema fields exactly `schema_version,request_id,operation,host,started_at_utc,ended_at_utc,result,exit_code,message`; no evidence content, no stack/stdout/stderr |
| Audit record | `requester_sid` = operator SID, host, operation, start/end, result; ledger recorded the new request id |
| Live wrong-owner | Audit shows `REQUEST_REJECTED` with `requester_sid=S-1-5-32-544` (Administrators) — admin-owned raw write refused |
| Unknown operation | Client `ValidateSet` refuses (`N2 UNKNOWN_OP=REFUSED`) |
| Operator redefine/delete task | `Access is denied` for `Set-ScheduledTask` and `Unregister-ScheduledTask` from non-elevated token |
| Concurrency | Two invokes: one `OPERATION_FAILED`, duplicate `CONCURRENT_EXECUTION` |
| Runner service throughout | `actions.runner.popcre-ai-devops.edge-dev-win` Stopped / Auto / `NT AUTHORITY\NETWORK SERVICE` — unchanged |
| Rollback | `-Remove -RequireManifestMatch -BackupPath C:\ProgramData\ai-devops\reviewed-maintenance-recovery-edge-dev-win` → `REMOVED`; task absent; evidence `windows-runner-security.json` untouched (mtime 2026-09-03); runtime records exported into the protected bundle (`runtime/audit.jsonl`, `processed-requests.jsonl`, `results/`) |
| Reinstall after rollback | `PASS: Windows runner maintenance installation verified` |
| Second install (idempotent) | `PASS` |
| `-Verify` after all mutations | `PASS` |

## Host preconditions for refresh SUCCESS (reported as-is, never faked)

- `Confirm-SecureBootUEFI` = **False** (firmware; not changeable remotely).
  Qualify script throws `Secure Boot must be enabled.` — evidence mtime stays
  `2026-09-03`.
- Runner service **Stopped** / GitHub runner `edge-dev-win` **offline**.
  Qualify requires exactly one *running* automatic runner service. The service
  was **not** started, stopped, or reconfigured by this work.
- TPM present and ready.

Consequence: the maintenance boundary is proven (recovery, install, verify,
invoke envelope, negatives, concurrency, rollback, idempotency). The one
bounded **refresh-qualification SUCCESS with fresh evidence** waits on Secure
Boot being re-enabled in firmware and the runner service being returned to
Running by its normal operator — both outside this maintenance install.

## Runner qualification

GitHub runner `edge-dev-win` labels remain
`self-hosted,Windows,X64,edge-dev,ai-devops-windows` — **not**
`ai-devops-windows-qualified`. The runner stays unqualified until its own full
GitHub qualification passes.

## Host-level mutation note

SSH sessions on this host yield a full elevated administrator token (same
deviation as EDGE-RUNN-ENVY, tracked in #1547). Elevated SSH was used only for
install / `-RecoverPartial` / `-Verify` / `-Remove` / `-Install`. Invoke and
every privilege negative ran from the non-elevated local operator token
(`admin=False`).
