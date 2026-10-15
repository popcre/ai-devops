# Step 8 reconcile — both Windows runner maintenance hosts (plan step 8 / #262)

Date: 2026-10-14 (America/New_York)
Operators: MiMo chat `ses_ffe5ec2a5978affe0rPcyOSHaY` (initial audit) and `ses_ffe5ec2a10135ffeHg4O8YjV0C` (correction + final verify) on edge-dev
Scope: `-Verify`, leftover audit, rollback-bundle ACL/size check, and evidence-contract sibling restore on both hosts. No install, update, remove, invoke, or runner-service change.

## Host records reconciled

| Host | Install / proof record | Merged evidence |
|---|---|---|
| `edge-dev-win` (`EDGE-DEV`) | [windows-runner-maintenance-edge-dev-win-2026-10-09](../windows-runner-maintenance-edge-dev-win-2026-10-09/README.md) | PR #1551 `b10a8dd3` |
| `EDGE-RUNN-ENVY` | [windows-runner-maintenance-envy-2026-10-09](../windows-runner-maintenance-envy-2026-10-09/README.md) | PR #1546 `698554f6` |

Source land: PR #560 `bdb44193`. Recovery repair (runtime records + start race): PR #967 `16d348fe`.

## Fresh `-Verify` (2026-10-14, elevated SSH)

Command on each host: `pwsh -NoProfile -File C:\repos\ai-devops\bin\install-windows-runner-maintenance.ps1 -Verify`

| Host | Result | Task state | Runner service |
|---|---|---|---|
| `EDGE-DEV` | `PASS: Windows runner maintenance installation verified` | `\AiDevOps\WindowsRunnerMaintenance` `Ready` | `actions.runner.popcre-ai-devops.edge-dev-win` `Running` / `Automatic` |
| `EDGE-RUNN-ENVY` | `PASS: Windows runner maintenance installation verified` | `\AiDevOps\WindowsRunnerMaintenance` `Ready` | `actions.runner.popcre-ai-devops.EDGE-RUNN-ENVY` `Running` / `Automatic` |

## Leftover / temporary artifact audit (same session)

| Check | `EDGE-DEV` | `EDGE-RUNN-ENVY` |
|---|---|---|
| Temporary / one-use maintenance tasks | none — only `\AiDevOps\WindowsRunnerMaintenance` | none — only `\AiDevOps\WindowsRunnerMaintenance` |
| Live `requests\` | 0 entries | 0 entries |
| Live `temp\` | 0 entries | 0 entries |
| Live `results\` | 1 historical result (intentional runtime record) | 2 historical results (intentional runtime records) |
| `*.tmp` / `*.lock` / `*.lck` leftovers | no lock files. `windows-runner-security.json.tmp` is a **required** evidence-contract sibling (not a leftover): verify (`Test-MaintenanceInstallation`) and the worker's `Test-EvidenceBoundary` both require it. It had been consumed by the atomic refresh rename and was **restored** to the post-refresh contract (0 bytes, `BUILTIN\Administrators`/`SYSTEM` Full, `Everyone` Read) per `windows-runner-maintenance-worker.ps1` lines 362–370. Recheck after restore: verify PASS. | same |
| Stuck `Running` maintenance task (lock) | none (`Ready`) | none (`Ready`) |

Correction (2026-10-14, session `ses_ffe5ec2a10135ffeHg4O8YjV0C`): the initial audit incorrectly treated `windows-runner-security.json.tmp` as a leftover and deleted it. That file is the pinned evidence-write sibling the worker re-creates after every refresh so no pre-creation race starts from a missing sibling. Deleting it makes `-Verify` fail (`Missing required path: ...windows-runner-security.json.tmp`). It was restored with the Evidence ACL contract on both hosts; `-Verify` then returned PASS on each. No other artifact was changed.

## Rollback / recovery bundles — protected and bounded

All bundles under `C:\ProgramData\ai-devops\`. Owner `BUILTIN\Administrators`, non-admin Allow ACEs: **0** on every bundle. Sizes are small and fixed (payload + exported runtime only).

| Host | Bundle | Files | Bytes |
|---|---|---|---|
| `EDGE-DEV` | `reviewed-maintenance-recovery-edge-dev-win` (rollback `-Remove -BackupPath` export) | 22 | 44176 |
| `EDGE-DEV` | `windows-runner-maintenance-recovery-20260928T154305Z` | 16 | 37557 |
| `EDGE-DEV` | `windows-runner-maintenance-recovery-20260928T154629Z` | 16 | 37557 |
| `EDGE-DEV` | `windows-runner-maintenance-recovery-20261009T202252Z` | 14 | 38740 |
| `EDGE-DEV` | `windows-runner-maintenance-recovery-partial-*` (9 dated partial recovery backups, incl. step 6 `20261009T201831Z`) | 2–19 each | 1249–41894 |
| `EDGE-RUNN-ENVY` | `reviewed-maintenance-recovery-ENVY` | 22 | 44085 |
| `EDGE-RUNN-ENVY` | `reviewed-maintenance-recovery-ENVY-second` | 17 | 40478 |
| `EDGE-RUNN-ENVY` | `windows-runner-maintenance-recovery-20261009T161756Z` | 14 | 38491 |
| `EDGE-RUNN-ENVY` | `windows-runner-maintenance-recovery-20261009T161804Z` | 14 | 38491 |

Evidence file `C:\ProgramData\ai-devops\windows-runner-security.json` was not modified by this audit (content never printed). `EDGE-DEV` mtime `2026-10-12T20:50:27Z`; `EDGE-RUNN-ENVY` mtime `2026-10-09T16:19:11Z`.

## Acceptance for step 8

- [x] Both host evidence records compared and consistent with the plan STATUS rows 6–7
- [x] `-Verify` still passes on both hosts (fresh, 2026-10-14, after evidence-sibling restore)
- [x] No temporary tasks / leftover request files / locks remain except the intentional installed task
- [x] Evidence-contract sibling `windows-runner-security.json.tmp` present with Evidence ACL on both hosts (required by verify; not a leftover)
- [x] Rollback and recovery bundles present, Administrators-owned, 0 non-admin Allow ACEs, bounded size
- [x] Runner services unchanged (`Running` / `Automatic`); no service stop/start/reconfigure

Posted by MiMo chat ses_ffe5ec2a5978affe0rPcyOSHaY on this machine
