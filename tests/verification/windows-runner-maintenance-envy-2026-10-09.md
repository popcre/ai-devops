# EDGE-RUNN-ENVY — Windows runner maintenance install proof (plan step 7)

Date: 2026-10-09 (event timestamps below are UTC machine times; human-referenced
completion time: 12:05 PM EST, 2026-10-09).
Host: `EDGE-RUNN-ENVY` (alias per plan §12; no addresses recorded here).
Scope: plan_windows-runner-maintenance-elevation.md step 7, issue #262.
One host only; `edge-dev-win` untouched (child issue #962 owns it).

## Source and approvals

- Installed checkout head (exact reviewed SHA): `63e83b0772b5b8e7a071264829b163dd863c39f6`
  (= origin/main at install; contains plan landing squash `bdb44193`, 2026-09-18).
- Payload SHA-256 verified on the host before install, 6/6 identical to this record:
  - `bin/install-windows-runner-maintenance.ps1` `c2d2719570f05c82a9defbf9556263a167efc2a5d30f559240a3af985d824830`
  - `bin/windows-runner-maintenance-worker.ps1` `c763a9aff60f92ecca16be07ae7e1d43fc57bb608490eec0a74b59fa912f10f4`
  - `bin/launch-worker.bat` `02cccf7873d2b01b27665434600b89e5aae3fa27d106215e3cc09e2bbac32d92`
  - `config/windows-runner-maintenance-policy.json` `255f91de23c6585ce9ac60444685fa1aa1ba777d99bb794a7c9c7d0b727453e7`
  - `bin/qualify-windows-runner.ps1` `172e1dac1d6de2407acef170b5f63332fb0bfa1e8db73e27b16d6ad2168ccaf7`
  - `bin/invoke-windows-runner-maintenance.ps1` `c1ec759e3d9e7ae6c46c3325be41362715eb563a2da833e2c8781b791e6aeff4`
- Independent security approvals (read-only, engine `muse` ≠ implementer `mimo`,
  lifecycle-recorded security-review APPROVE):
  - Exact-inputs install approval at head `66c465cd…`: run
    `20261009T150435-1526462-9371`, report
    `.ai/reviews/muse-security-review-20261009T150435-1526462-9371.md` — authorizes
    the install on this host/task/payload/commands with binding preconditions
    (runner idleness re-check + fresh service snapshot before mutation;
    operator negatives from a proven non-elevated context; full acceptance matrix).
    An earlier APPROVE at the same head
    (`20261009T145719-1504033-13300`) explicitly scoped the live-install axis out
    and was NOT used as install authorization.
  - Deploy-gate approval at head `63e83b07…`: run
    `20261009T153928-1591030-1505`, report
    `.ai/reviews/muse-security-review-20261009T153928-1591030-1505.md`
    (reviewer read all six payload files in full; verified the six hashes).
- Gates: task class `installation` declared; `ai-task-gates check --before deploy`
  passed with `--reviewer-approval` bound to the exact head above
  (`APPROVE by muse (implementer mimo, security-review) … report sha256:c6b89b31…`).

## Pre-install live state (read-only probes, 2026-10-09)

- Windows build `10.0.26200`; machine-wide pwsh present at
  `C:\Program Files\PowerShell\7\pwsh.exe`.
- Maintenance task `\AiDevOps\WindowsRunnerMaintenance` absent.
- Operator: local `EDGE-RUNN-ENVY\ahazan`, SID `S-1-5-21-*-1001`, enabled, domain
  WORKGROUP (local, not domain/ambiguous).
- UAC `EnableLUA=1`; `LocalAccountTokenFilterPolicy` absent; Windows sudo feature
  not enabled (config key carries no `Enabled` value).
- Runner service baseline: `actions.runner.popcre-ai-devops.EDGE-RUNN-ENVY`,
  Running / Auto / `NT AUTHORITY\NETWORK SERVICE`, `Runner.Listener` only
  (no `Runner.Worker`); GitHub runner `online, busy=false` immediately before the
  install mutation; service snapshot captured in the same run before install.
- Token elevation state: fresh SSH sessions on this host yield a full elevated
  administrator token (High Mandatory Level, `net session` OK) with UAC intact —
  a material deviation from plan §3's historical filtered-token observation,
  accepted explicitly by the security reviewer for install/verify/rollback only.
  Nothing was enabled or changed to obtain it.
- Non-elevated proof context: the UAC-limited (Medium IL, Administrators
  deny-only) token of the same operator SID, obtained by duplicating the
  interactive session's explorer token via documented token APIs; no password,
  no sudo, no `LocalAccountTokenFilterPolicy`, no stored credential. Bounded
  harness scripts were deleted from the host after the proof.

## Install (elevated session, after all gates)

`pwsh -NoProfile -File .\bin\install-windows-runner-maintenance.ps1 -Install -OperatorUser "$env:COMPUTERNAME\ahazan"`
from `C:\repos\ai-devops` checked out at `63e83b07…` on the host:
exit 0, built-in `PASS: Windows runner maintenance installation verified`.
Post-install task: Status Ready; action
`C:\Windows\System32\cmd.exe /d /c "C:\Program Files\ai-devops\windows-runner-maintenance\launch-worker.bat"`;
Run As User `ahazan`; Schedule `On demand only` (triggerless); principal S4U
Highest per installer defaults; `IgnoreNew`.

## ACL / boundary summary (asserted by installer `-Verify`, elevated)

- Task DACL: operator `S-1-5-21-*-1001` read/execute (GRGX) only; Administrators
  and SYSTEM full control; operator cannot change/delete/replace the task —
  proven live below, not just asserted.
- Payload root `C:\Program Files\ai-devops\windows-runner-maintenance`:
  administrator-owned, hash-verified manifest before every dispatch (6/6 hashes
  matched on the host).
- Runtime root `C:\ProgramData\ai-devops\windows-runner-maintenance`: operator
  write limited to `requests\`; results/audit/ledger administrator-written,
  operator read; consumed request files removed by the worker.
- Evidence contract: `windows-runner-security.json` and its tmp sibling pinned to
  Administrators/SYSTEM full + Everyone read, no operator grant.

## Positive proof (fresh session; negatives inside the proven non-elevated context)

| Check | Result |
|---|---|
| `-Verify` from fresh session (install) | `PASS: Windows runner maintenance installation verified`, rc 0 |
| `-Verify` after reinstall (rollback end) | `PASS`, rc 0 |
| Non-elevated context | `elevated=False`, user `edge-runn-envy\ahazan`, Administrators **deny-only**, Medium Mandatory Level; `net session` denied (rc 2) |
| `refresh-qualification` invoke (client, non-elevated) | rc 0, `result=SUCCESS`, `exit_code=0`, bounded 9-field JSON, message `Windows runner qualification evidence was refreshed.` (2026-10-09T16:01:37Z–16:01:41Z) |
| Evidence freshness (metadata only; content never printed) | mtime `2026-09-04T03:28:26.9402474Z` → `2026-10-09T16:01:47.8467255Z` (advanced) |
| Audit presence | `audit.jsonl` entries with request SID (masked here), host, operation, start/end, result: `SUCCESS` dur 3.4s and 1.7s, `REQUEST_REJECTED`, `CONCURRENT_EXECUTION` |

## Negative proof (all from the non-elevated operator context)

| Check | Result |
|---|---|
| Operator redefines task (`schtasks /change /disable`) | `ERROR: Access is denied.` rc 1 |
| Operator deletes task (`schtasks /delete /f`) | `ERROR: Access is denied.` rc 1; task still present afterwards |
| Task readable (GRGX) | `/query` rc 0 |
| Unknown operation | client `ValidateSet` rejection, rc 1, bounded message |
| Unknown argument | client parameter rejection, rc 1, bounded message |
| Unknown request field | `result=REQUEST_REJECTED`, exactly the 9 safe result fields |
| Concurrency duplicate | two requests, one start: one `SUCCESS` + one `CONCURRENT_EXECUTION` |
| No raw leaks | all 8 result files carry exactly the 9 safe fields, `SCHEMA_VIOLATIONS=0` |
| Recoverable failure | unknown-field `REQUEST_REJECTED` followed by successful invoke; consumed request files cleaned (empty `requests\`) |

Note: the worker executes one request per task instance; requests arriving during
a live instance (its quiet linger window) are answered `CONCURRENT_EXECUTION`
with no execution — observed, then proven correct by sequencing fresh instances
(task Ready) between phases; not a product defect.

## Runner service unchanged (never stopped, restarted, relabeled, or reconfigured)

Baseline, post-install, post-proof, and final snapshots all identical:
`actions.runner.popcre-ai-devops.EDGE-RUNN-ENVY` = Running / Auto /
`NT AUTHORITY\NETWORK SERVICE`. No `Runner.Worker` at every mutation boundary.

## Rollback proof

- Refused-safe: `-Remove -RequireManifestMatch -BackupPath <user-profile path>`
  → rc 1, refused (`Recovery backup path must be under an administrator-managed
  root…`), task still present — no mutation.
- Full rollback: `-Remove -RequireManifestMatch -BackupPath
  C:\ProgramData\ai-devops\reviewed-maintenance-recovery-ENVY` → `REMOVED`,
  rc 0; task absent; payload root absent; runtime emptied into the backup;
  evidence file mtime unchanged; bundle entries `payload, runtime, recovery.json,
  task.xml` with **0** non-administrator ACEs; service unchanged.
- Reinstall + re-verify: `-Install` rc 0 `PASS`; `-Verify` rc 0 `PASS`.
- Temporary proof tasks remaining: 0; host harness files deleted.

## Environment deviations recorded

- Fresh SSH sessions on this host are elevated (see pre-install state); the
  reviewer accepted this for install/verify/rollback and required — and this
  record proves — negatives and the positive invoke from the non-elevated
  operator context instead.
