# muse security-review — 20261009T150435-1526462-9371

| field | value |
|---|---|
| provider | `muse` |
| repository | `/c/repos/ai-devops` |
| reviewed commit | `66c465cd8b505178a512f7d9b6e4ffca0a8258c1` |
| source digest | `145d88a8fa514c083198814234824a5421dda536ce22d017c8cfbe0dd5e7ae9f` |
| run | `20261009T150435-1526462-9371` |
| caller | `zcode` |
| elapsed seconds | `837` |
| runner | `ai-review-engine` (review-lifecycle-core/1) |
| tools | door muse |
| packet | `77d6ad270cecae77efea4d74e7ca5d5256511b1eecad4bb07f6edb5c51cc9c56` |

## Result

# Muse review — runner door

| field | value |
|---|---|
| model | `muse-spark-1.3-contributor` |
| engine | `muse-code` |
| reviewed commit | `66c465cd8b505178a512f7d9b6e4ffca0a8258c1` |

---

### Findings and reasoning

**Provisional verdict: APPROVE (conditional)** — the payload is strongly hardened and I found no injectable secret, injection, or boundary-escape vector; final judgment below is contingent on the live preconditions stated.

# Security review — reviewed head `66c465cd8b505178a512f7d9b6e4ffca0a8258c1`

Scope: security only (authorization, data leakage, injection, secrets, file boundaries, permissions) across the 84-file change, with emphasis on the live-install payload for `EDGE-RUNN-ENVY`.

## Findings — High severity (binding preconditions for the live install)

1. **Install authorized on `EDGE-RUNN-ENVY` ONLY if all preconditions hold at mutation time.** The probe showed GitHub `busy=true` at dispatch, so the install must wait for `busy=false` + no local `Runner.Worker` process + a fresh pre-install service snapshot (`actions.runner.popcre-ai-devops.EDGE-RUNN-ENVY`, Running/Automatic/`NT AUTHORITY\NETWORK SERVICE`). The exact commands under review are `INSTALL`/`VERIFY` via `bin/install-windows-runner-maintenance.ps1` (`-Install`/`-Verify -OperatorUser "$env:COMPUTERNAME\ahazan"`), `INVOKE` via `bin/invoke-windows-runner-maintenance.ps1 -Operation refresh-qualification` from a fresh non-elevated session, and `ROLLBACK` via `-Remove -RequireManifestMatch -BackupPath C:\ProgramData\ai-devops\reviewed-maintenance-recovery-ENVY`. Payload hashes pinned: installer `c2d27195…d824830`, worker `c763a9af…912f10f4`, launcher `02cccf78…ac32d92`, policy `255f91de…727453e7`, qualify `172e1dac…d2168ccaf7`, invoke `c1ec759e…791e6aeff4`; policy `payload_hashes` pins worker/launcher/qualify (`config/windows-runner-maintenance-policy.json:16`). If any hash, hostname (`EDGE-RUNN-ENVY`), task path (`\AiDevOps\WindowsRunnerMaintenance`), or operator SID differs — refuse.

2. **Ruling on the elevated-SSH-token deviation: ACCEPTABLE for the elevated steps, NOT acceptable as the non-elevated context.** Fresh SSH sessions yield a full elevated administrator token (High, `net session OK`) with `EnableLUA=1`, no `LocalAccountTokenFilterPolicy`, and sudo not enabled. Nothing was changed to obtain it, and the installer's own gates do not depend on arriving through a UAC consent prompt: `Assert-Administrator` (`bin/install-windows-runner-maintenance.ps1:37`), local-SID pinning with machine-name match + `S-1-5-21-` prefix + positive `UserPrincipal` confirmation that rejects group SIDs (`bin/install-windows-runner-maintenance.ps1:53`), per-user COM-override refusal (`bin/install-windows-runner-maintenance.ps1:243`), reparse/foreign-ownership/backup-chain checks (`bin/install-windows-runner-maintenance.ps1:71`), and hash-pinned payload adoption (`bin/install-windows-runner-maintenance.ps1:120`) all re-verify inside the elevated session. SSH-admin already equals host-admin, so no new privilege is created by this route. However, the operator negative tests (cannot redefine/delete/replace the task, unknown operation/field/argument rejected, `CONCURRENT_EXECUTION`, no raw-exception leaks) REQUIRE a proven non-elevated caller context — running them from the elevated SSH session proves nothing and is refused as evidence. A genuinely non-elevated execution context (e.g., operator logon at Limited, `RunAs`) must be demonstrated for the negatives, otherwise refuse that acceptance item.

## Findings — Medium severity (residual risks, all mitigated in-code)

3. **S4U Highest task lets any Start-holder trigger an elevated worker — bounded to one fixed operation.** Task action is pinned to `cmd.exe /d /c launch-worker.bat`, principal pinned to the operator SID, `S4U`/`Highest`, triggerless, `IgnoreNew` (`bin/install-windows-runner-maintenance.ps1:229`); task DACL grants only `GRGX` to the operator (`bin/install-windows-runner-maintenance.ps1:281`), and recovery seals to admins/SYSTEM-only before teardown (`bin/install-windows-runner-maintenance.ps1:294`). The worker re-verifies payload manifest, runtime/task/evidence boundaries, and audit capacity before every operation (`bin/windows-runner-maintenance-worker.ps1:352`), accepts only `refresh-qualification` with a 4-field request schema, owner-equals-operator-SID, fresh timestamp, and replay-ledger non-reuse (`bin/windows-runner-maintenance-worker.ps1:28`), and maps every failure to a bounded result enum with no raw exception passthrough (`bin/windows-runner-maintenance-worker.ps1:373`). Residual persistence risk is accepted: this is exactly the reviewed, triggerless, 6-minute-bounded shape.

4. **Evidence file is world-readable by design — no secret content.** Evidence and tmp sibling carry admins/SYSTEM full + `S-1-1-0:R` with write/delete refused to non-admins (`bin/install-windows-runner-maintenance.ps1:358`); worker enforces the same contract (`bin/windows-runner-maintenance-worker.ps1:171`). Content is machine posture only (build, TPM, Secure Boot, runner-service state, tool paths — `bin/qualify-windows-runner.ps1:27`); the pre-existing evidence file's content was never printed, per protocol. No leakage finding.

5. **Pre-existing evidence/parent adoption is fail-closed.** `Protect-EvidenceFile` refuses foreign-owned parent/evidence/tmp paths (`bin/install-windows-runner-maintenance.ps1:474`); if the `2026-09-04` evidence file is not Administrators/SYSTEM-owned, install stops with `STALE_INSTALLATION` rather than laundering it. Correct behavior — record as expected refusal, not a failure.

## Findings — Low / informational (checked, no action)

6. **No secrets, tokens, or private keys in the reviewed surface.** Pattern scan over installer, worker, invoke, qualify, launcher, `install-ai-devops-windows.ps1`, `telemetry.sh`, `reviewer_credit_stream.py`, `reviewer_admission.py`, and `mcp-session-guard.mjs` returned zero hits for password/secret/token/private-key/GitHub-PAT shapes.

7. **No shell-injection or elevation-bypass primitives in the broader diff.** Scan for `Invoke-Expression`/`DownloadString`/`Bypass`/unauthenticated-allow returned zero hits in the sandbox/packet/preflight/lifecycle/installer/session-guard sources. New `instrumented-gh` Windows channel code validates the inherited handle (rejects std handles, requires pipe type + client end, clears inheritability, enforces a lifetime bound) (`tools/github-requests/instrumented-gh/channel_windows.go:14`), and the counter source set is closure-pinned against additions/omissions (`tools/github-requests/instrumented-gh/source_binding.py:1`). `telemetry.sh` handles only operation/caller labels, never request/response text (`tools/github-requests/telemetry.sh:1`).

8. **Minor: CIM filter interpolates an admin-controlled service name** (`bin/qualify-windows-runner.ps1:24`). Service names are registry/admin-controlled, not operator input, and the script requires `#Requires -RunAsAdministrator`; not exploitable through this boundary. No change requested.

9. **Launcher environment scrub is allowlist-based and AutoRun-fail-closed** (`bin/launch-worker.bat:18`). `COMSPEC` pinned, `FOR /F` shielded by full-path `reg.exe` AutoRun refusal first, cleared names restricted to an injection-proof class, and worker launched via absolute `pwsh.exe` path. Invoke-side request creation uses `CreateNew` (no clobber) plus owner-only re-own (`bin/invoke-windows-runner-maintenance.ps1:13`), and errors collapse to the bounded exit-code map (`bin/invoke-windows-runner-maintenance.ps1:67`). No findings.

## Live-install authorization (exact)

I authorize installing on `EDGE-RUNN-ENVY` exactly as specified — host `EDGE-RUNN-ENVY`, task `\AiDevOps\WindowsRunnerMaintenance`, operator `EDGE-RUNN-ENVY\ahazan` with locally resolved+pinned SID (refuse missing/domain/ambiguous), payload hashes as listed in finding 1, and the four commands as listed — **subject to**: (a) runner-idleness re-check plus fresh service snapshot immediately before the install mutation; (b) operator negatives executed from a proven non-elevated context; (c) `Verify` passing from a fresh session, bounded `SUCCESS` enum + audit record on invoke, timestamp-only evidence check, runner service untouched, one recoverable failure + stale-result cleanup + re-verify, and rollback proven documented and refused-safe. The elevated-SSH-token deviation is accepted for the elevated install/verify/rollback steps per finding 2 and is explicitly **not** accepted as the negative-test context.


---

## Verdict
APPROVE
