# EDGE-RUNN-ENVY — Windows runner maintenance install proof (plan step 7)

Date: 2026-10-09. Event timestamps are UTC machine times; human-referenced
completion: 12:35 PM EDT, 2026-10-09 (16:35 UTC).
Host: `EDGE-RUNN-ENVY` (alias per plan §12; no addresses recorded anywhere in
this directory). Scope: `plan_windows-runner-maintenance-elevation.md` step 7,
issue #262. One host only; `edge-dev-win` untouched (child issue #962 owns it).
Raw command outputs for every claim below: [`transcripts.md`](transcripts.md).

## Source and approvals (all artifacts committed here; nothing self-attested)

- Installed checkout head (exact reviewed SHA, full):
  `63e83b0772b5b8e7a071264829b163dd863c39f6` (= origin/main at install; contains
  plan landing squash `bdb44193343b46e511c1405e8f19040cba7dc70d`, 2026-09-18).
- **Install-inputs security APPROVE** (read-only, provider `muse`, implementer
  engine `mimo`, lifecycle run `20261009T150435-1526462-9371`, mode
  `security-review`, head `66c465cd8b505178a512f7d9b6e4ffca0a8258c1`):
  full report committed as
  [`review-install-approve-66c465cd.md`](review-install-approve-66c465cd.md),
  SHA-256 `9d09cbdf40a5f8dd052d3a8c1074a47ba934bc05de97b53433da847c56064f0b`
  (= lifecycle `report_sha256`). That report authorizes installing on this
  host/task/payload/commands with binding preconditions.
- **Deploy-gate security APPROVE** at the installed head (run
  `20261009T153928-1591030-1505`, head
  `63e83b0772b5b8e7a071264829b163dd863c39f6`): full report committed as
  [`review-deploy-approve-63e83b07.md`](review-deploy-approve-63e83b07.md),
  SHA-256 `c6b89b31bad7b84f82eddabe5275ef9e02074f555e86517af02a38d1fe7acfc9`
  (= lifecycle `report_sha256` = the gate's binding hash below). The reviewer
  read all six payload files in full and re-verified the six hashes.
- Head-equivalence proof between the two approvals (install approval is at
  `66c465cd…`, installed head at `63e83b07…`):
  `git diff --name-only 66c465cd8b505178a512f7d9b6e4ffca0a8258c1 63e83b0772b5b8e7a071264829b163dd863c39f6`
  → exactly one prose file
  `HANDOFF.d/2026-10-09T1421Z-edge-dev3-codex-qwen-runner-closeout.md`; no
  payload file differs, and all six payload SHA-256 values were re-verified
  identically at both heads (transcripts). The deploy-gate APPROVE covers the
  installed head directly regardless.
- Gate transcript (committed): `ai-task-gates check --before deploy
  --reviewer-approval …` → `allowed by assigned AI reviewer: APPROVE by muse
  (implementer mimo, run 20261009T153928-1591030-1505, security-review) for
  deploy at 63e83b0772b5b8e7a071264829b163dd863c39f6 report
  sha256:c6b89b31bad7b84f82eddabe5275ef9e02074f555e86517af02a38d1fe7acfc9`.
- An earlier APPROVE at `66c465cd…` (run `20261009T145719-1504033-13300`)
  explicitly scoped the live-install axis out of its review and was **not**
  used as install authorization.
- Task class `installation` declared before any host mutation.

## Payload SHA-256 (verified on the host before install, 6/6 match; same bytes at both approved heads)

- `bin/install-windows-runner-maintenance.ps1` `c2d2719570f05c82a9defbf9556263a167efc2a5d30f559240a3af985d824830`
- `bin/windows-runner-maintenance-worker.ps1` `c763a9aff60f92ecca16be07ae7e1d43fc57bb608490eec0a74b59fa912f10f4`
- `bin/launch-worker.bat` `02cccf7873d2b01b27665434600b89e5aae3fa27d106215e3cc09e2bbac32d92`
- `config/windows-runner-maintenance-policy.json` `255f91de23c6585ce9ac60444685fa1aa1ba777d99bb794a7c9c7d0b727453e7`
- `bin/qualify-windows-runner.ps1` `172e1dac1d6de2407acef170b5f63332fb0bfa1e8db73e27b16d6ad2168ccaf7`
- `bin/invoke-windows-runner-maintenance.ps1` `c1ec759e3d9e7ae6c46c3325be41362715eb563a2da833e2c8781b791e6aeff4`

## Operator identity (full, re-pinnable per plan §11)

- Local user `EDGE-RUNN-ENVY\ahazan`, **SID `S-1-5-21-4110623484-3775389421-3704134857-1001`**,
  enabled, domain `WORKGROUP` (local account, not domain/ambiguous). Resolved
  with `Get-LocalUser` + machine-context confirmation before install; the same
  SID is the task principal, the request-owner allowlist, and the audit identity
  (audit SIDs observed equal to it; shown full in transcripts' masked form and
  here in full).

## Pre-install live state (read-only probes, 2026-10-09)

- Windows build `10.0.26200`; machine-wide pwsh at
  `C:\Program Files\PowerShell\7\pwsh.exe`; maintenance task absent.
- UAC `EnableLUA=1`; `LocalAccountTokenFilterPolicy` value absent; Windows sudo
  feature not enabled (config key present, no `Enabled` value); OpenSSH
  `9.5p2 for Windows`, service `LocalSystem`, stock config.
- Runner service baseline: `actions.runner.popcre-ai-devops.EDGE-RUNN-ENVY`,
  Running / Auto / `NT AUTHORITY\NETWORK SERVICE`, `Runner.Listener` only.
- Runner idleness at the install boundary: GitHub runner
  `online, busy=false` (checked immediately before the install run), no local
  `Runner.Worker` process inside the install driver, and a fresh service
  snapshot captured in the same run before the mutation.

## Elevation posture (plan §3 deviation — investigated, tracked, not a shrug)

Fresh SSH sessions on this host yield a full elevated administrator token
(High Mandatory Level, `net session` OK). Investigation results, all read-only:

- `GetTokenInformation(TokenLinkedToken)` on the session token fails with
  `ERROR_NO_SUCH_LOGON_SESSION` (1312): the logon never produced a UAC split
  token, so no filtered counterpart exists to fall back to.
- Every documented weakening mechanism verified **absent**: `EnableLUA=1`,
  no `LocalAccountTokenFilterPolicy`, sudo feature disabled, sshd config stock.
- S4U tasks at `RunLevel Limited` for the same account also yield elevated
  tokens (probed and deleted: task absent afterwards).
- No configuration was changed by this session to obtain or keep this state.

Root cause (Win32-OpenSSH logon path vs build 26200 behavior) is not yet
attributed; it is tracked in **[#1547](https://github.com/popcre/ai-devops/issues/1547)**
with these facts, and plan §3/§10 now record the observation and the
reviewer-approved host adaptation. Consequence for this proof: install,
`-Verify`, and rollback ran from the elevated session (named in the
install-inputs APPROVE); the positive invoke and every negative privilege test
ran from a proven non-elevated operator context (below).

## Non-elevated operator context (harness committed; bounded; deleted from host)

Because no filtered SSH token and no linked limited token exist on this host,
the proof context was the operator's own UAC-limited token from the active
interactive session: a bounded harness opened the interactive `explorer`
process token (same operator SID, Medium Mandatory Level `S-1-16-8192`,
Administrators deny-only), duplicated it to a fresh primary token (the raw
token is “already in use as a primary token”, Win32 1375), and spawned the
proof child with `CreateProcessWithTokenW` (window hidden). No password, no
sudo, no `LocalAccountTokenFilterPolicy`, no stored credential, no new
account, no lasting scheduled task.

Committed harness sources (exact bytes executed on the host):

| File | SHA-256 |
|---|---|
| [`harness/limited-context-harness.ps1`](harness/limited-context-harness.ps1) | `025e9dd1afc1f4924485aed6fc9ce7ce6d5962002383d237ba1e8295df71128a` |
| [`harness/negproof-suite.ps1`](harness/negproof-suite.ps1) | `77e397587988a643b5f77bff3db042e10bec6407c1e9cbe11efd00f7077111df` |
| [`harness/hostile-duplicate.ps1`](harness/hostile-duplicate.ps1) | `0ce7636f848bfb12648ea4c09cdf7f4fcc915f3a21b27719a422131abe35a11d` |
| [`harness/install-driver.ps1`](harness/install-driver.ps1) | `0505212af1ee107c5b806613930877731e7f799e4c56e39443c41df67eb072e3` |
| [`harness/rollback-driver.ps1`](harness/rollback-driver.ps1) | `e96e8a257dd9fe02ebd6994307da6542d0810643848dffd27b2c162c28c9c60b` |
| [`harness/final-cycle-driver.ps1`](harness/final-cycle-driver.ps1) | `b5d9a4df79305e141b2652d6f9b9a3920bf82730c9e239b0530479243f334c43` |

All harness/transcript files were deleted from the host after the proof
(deletion transcript in `transcripts.md`); they remain here as the reviewable
source of the proof mechanism. Context properties observed inside the child
before any test ran: `elevated=False`, user `edge-runn-envy\ahazan`,
`BUILTIN\Administrators` = “Group used for deny only”, Mandatory Label =
Medium (`S-1-16-8192`), `net session` rc 2.

## Positive proof

| Check | Result (raw output in transcripts.md) |
|---|---|
| `-Verify` from fresh session (post-install) | `PASS: Windows runner maintenance installation verified`, rc 0 |
| `-Verify` after update, after final reinstall | `PASS`, rc 0 (both) |
| `refresh-qualification` via `bin/invoke-windows-runner-maintenance.ps1` **from the non-elevated operator context** | rc 0, `result=SUCCESS`, `exit_code=0`, bounded 9-field JSON, 2026-10-09T16:01:37Z–16:01:41Z |
| Second invoke (post-update, idempotency) | rc 0, `result=SUCCESS`, 2026-10-09T16:18:10Z–16:18:12Z |
| Evidence freshness — timestamp only, content never printed | mtime `2026-09-04T03:28:26.9402474Z` → `2026-10-09T16:01:47.8467255Z` → `2026-10-09T16:18:12.3195965Z` (advanced on each SUCCESS) |
| Evidence content **shape** (structure only, values not printed) | parse ok; exactly the 9 schema fields, 0 missing, 0 extra; `schema_version=1`; `windows_build` matches the known host build 26200 |
| Audit presence | `audit.jsonl` records for every request: masked-in-transcript/full-SID requester, host, operation, start/end, result (`SUCCESS` dur 3.4s and 1.7s, `REQUEST_REJECTED`, `CONCURRENT_EXECUTION`) |

## Negative proof (privilege tests from the non-elevated operator context)

| Check | Result |
|---|---|
| Redefine task (`schtasks /change /disable`) | `ERROR: Access is denied.` rc 1 |
| Delete task (`schtasks /delete /f`) | `ERROR: Access is denied.` rc 1; task still present |
| Task read (GRGX) | `/query` rc 0 |
| Unknown operation | client `ValidateSet` rejection, rc 1, bounded message |
| Unknown argument | client parameter rejection, rc 1, bounded message |
| Unknown request field (owner = operator SID) | `result=REQUEST_REJECTED`, exactly the 9 safe result fields |
| Wrong-owner request (owner = `BUILTIN\Administrators`, written from an elevated context) | `result=REQUEST_REJECTED` for both requests — live proof of `Request_RejectsWrongOwner` (bonus finding during the DoD cycle; matches the worker contract and #1312) |
| Concurrency duplicate (same first scan) | one `SUCCESS` + one `CONCURRENT_EXECUTION` |
| **Hostile timing duplicate (request injected while task `Running`, observed at 460 ms)** | A `SUCCESS` + B `CONCURRENT_EXECUTION` — the mid-execution case, no request lost (every request got a result file; a client answered `CONCURRENT_EXECUTION` exits rc 12 with the bounded enum, never a hang or a silent drop) |
| No raw leaks | all result files carry exactly the 9 safe fields; `SCHEMA_VIOLATIONS=0` across 8 files, re-confirmed after the DoD cycle |
| Recoverable failure | unknown-field `REQUEST_REJECTED` → worker returned to Ready → subsequent invoke `SUCCESS`; consumed request files removed by the worker (`requests\` empty — stale-request cleanup) |

Worker semantics note: one execution per task instance; requests arriving
during a live instance (its quiet-linger window) are answered
`CONCURRENT_EXECUTION` without execution. Proven by sequencing (task `Ready`
between phases) and, for the hostile case, by injecting mid-run (above). Not a
product defect; first orchestration attempt that ignored this produced only
`CONCURRENT_EXECUTION` results (client rc 12) and is preserved in
`transcripts.md` as the recoverable-failure evidence.

## DoD idempotency matrix (§13) with an idleness re-check before every mutation

Each mutation below was preceded by an in-driver assertion: no
`Runner.Worker` process and service Running/Auto/NETWORK SERVICE
(`IDLE_OK <step>` lines in transcripts), and GitHub runner `online,
busy=false` was confirmed by bracketing checks across the whole mutation
window (15:59Z before install, 16:07Z after proofs, 16:16Z before the DoD
cycle, 16:29Z after it — all `busy=false`; no `Runner.Worker` observed at any
probe in the window).

| Matrix step (§13) | Result |
|---|---|
| install | rc 0, `PASS: … installation verified` |
| second install | rc 0 `PASS` (idempotent) |
| update (identical payload, backup to protected root) | rc 0 `PASS` |
| verify | rc 0 `PASS` (after install, after update, after final reinstall) |
| invoke | rc 0 `SUCCESS` × 2 (first from the non-elevated context) |
| failure recovery | unknown-field `REQUEST_REJECTED` → Ready → `SUCCESS` |
| remove | rc 0 `REMOVED` |
| second remove (fresh cycle) | rc 0 `REMOVED`, task absent |
| remove of absent installation | rc 0 `ABSENT` (idempotent no-op, no mutation) |
| reinstall | rc 0 `PASS` + final `-Verify` rc 0 `PASS`, task present |

## Rollback proof

- **Refused-safe:** `-Remove -RequireManifestMatch -BackupPath
  <user-profile path>` → rc 1, refused (`Recovery backup path must be under an
  administrator-managed root…`), task still present — no mutation.
- **Full rollback:** `-Remove -RequireManifestMatch -BackupPath
  C:\ProgramData\ai-devops\reviewed-maintenance-recovery-ENVY` → `REMOVED`
  rc 0; task absent; payload root absent; runtime emptied into the backup;
  evidence mtime unchanged; bundle entries `payload, runtime, recovery.json,
  task.xml` with **0** non-administrator ACEs; service unchanged.
- A second protected backup exists for the later cycle
  (`…-recovery-ENVY-second`), and the update path wrote
  `…-recovery-ENVY-update` before replacing identical payload.
- Final end state: task installed, `Ready`, `-Verify` `PASS`.

## ACL / boundary summary (installer `-Verify` assertions + live negatives above)

- Task DACL: operator `S-1-5-21-4110623484-3775389421-3704134857-1001`
  GRGX only; Administrators/SYSTEM full; live change/delete attempts denied.
- Payload root administrator-owned, hash-verified manifest before every
  dispatch (6/6 on the host).
- Runtime: operator write confined to `requests\`; results/audit/ledger
  administrator-written, operator read; request owner must equal the operator
  SID (proven both ways above).
- Evidence contract: Administrators/SYSTEM full + Everyone read, no operator
  grant (installer refuses otherwise).
- Rollback bundle: Administrators/SYSTEM only (0 non-admin ACEs measured).

## Runner service (never stopped, restarted, relabeled, or reconfigured)

Every snapshot — pre-install, post-install, post-proof, post-rollback,
final — identical:
`actions.runner.popcre-ai-devops.EDGE-RUNN-ENVY` = Running / Auto /
`NT AUTHORITY\NETWORK SERVICE`.

## Temporary artifacts

Temporary proof tasks remaining: **0** (`Get-ScheduledTask` filter
`*limproof*`/`__*` → 0). Host harness/transcript files deleted (transcripts).
