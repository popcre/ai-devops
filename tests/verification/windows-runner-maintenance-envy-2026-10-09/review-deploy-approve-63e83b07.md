# muse security-review — 20261009T153928-1591030-1505

| field | value |
|---|---|
| provider | `muse` |
| repository | `/c/repos/ai-devops` |
| reviewed commit | `63e83b0772b5b8e7a071264829b163dd863c39f6` |
| source digest | `6fa3c31b736f1643b9fa0ddcfb6c200353472695a0e3578356d88e72b6fb57a6` |
| run | `20261009T153928-1591030-1505` |
| caller | `zcode` |
| elapsed seconds | `647` |
| runner | `ai-review-engine` (review-lifecycle-core/1) |
| tools | door muse |
| packet | `f64be7348ceeccecef3e966a545dfcecf62108331a2ff7cd814b3a023b22afd3` |

## Result

# Muse review — runner door

| field | value |
|---|---|
| model | `muse-spark-1.3-contributor` |
| engine | `muse-code` |
| reviewed commit | `63e83b0772b5b8e7a071264829b163dd863c39f6` |

---

### Findings and reasoning

**Provisional verdict: APPROVE** (conditional on the gating checks below) — payload hashes verified, no blocking security flaw found in the install payload; the elevated-SSH-token deviation is acceptable with constraints.

# Security review — Windows runner maintenance live install

Reviewed head SHA: `63e83b0772b5b8e7a071264829b163dd863c39f6`

Scope: the exact live install on host `EDGE-RUNN-ENVY` as specified in RUN FACTS (task `\AiDevOps\WindowsRunnerMaintenance`, operator `EDGE-RUNN-ENVY\ahazan`), i.e. the six-file payload at this head. I read `bin/install-windows-runner-maintenance.ps1` (755 lines), `bin/windows-runner-maintenance-worker.ps1` (420 lines), `bin/launch-worker.bat`, `config/windows-runner-maintenance-policy.json`, `bin/qualify-windows-runner.ps1`, `bin/invoke-windows-runner-maintenance.ps1` in full, plus the hostile-test assertions in `tests/test-windows-runner-maintenance.ps1`. I verified the payload hashes in this disposable copy match RUN FACTS exactly (all six `sha256sum` values identical) and confirmed HEAD via `git rev-parse`. No files edited, nothing committed. Broader 85-file diff reviewed only as it bears on this install (no additional install-relevant secrets or boundaries found).

## Findings — Critical / High

None. The payload enforces, with file-and-line evidence:

- **Authorization**: operator must be one unambiguous local user — `bin/install-windows-runner-maintenance.ps1:53-69` (machine-name match, `S-1-5-21-` local-SID prefix, positive `UserPrincipal` check rejecting local groups). Task DACL grants the operator GRGX (start) only — `:287`, `:406`; teardown drops the operator ACE entirely — `:294-307`. Install/Remove require Administrator — `:37-41`, `:733`, `:738`, `:740`.
- **Privilege boundary is bounded**: S4U + Highest task runs only the hash-pinned worker via `/d`-launched `launch-worker.bat` (`:229-241`); worker re-verifies payload hashes, runtime/task/evidence boundaries and capacity before executing (`bin/windows-runner-maintenance-worker.ps1:352-356`), single operation `refresh-qualification` only (`:43`, `:313`), 6-minute task limit / 300 s hard timeout.
- **Injection**: launcher pins COMSPEC, refuses per-user and system AutoRun, strips env to an allowlist (`bin/launch-worker.bat:18-40`); installer and worker pin `PSModulePath` and refuse hostile code-loading variables (`install…:21-24`, `worker…:12`); requests strictly validated — 4 exact fields, GUID canonicalization, round-trip timestamp, age window, owner-SID match, replay ledger (`worker…:28-59`, `:344-350`); result/audit/ledger writes field-allowlisted and size-bounded (`:273-304`); errors mapped to enums, no raw leak (`:373-380`; invoke `:67-80` maps unknowns to `RESULT_INVALID`).
- **File boundaries**: reparse-point checks at every adoption/copy/delete site, foreign-ownership refusal on ProgramData state, per-entry (never recursive) elevated copies/deletes, `/L` link-targeted icacls, pre-delete re-verification (`install…:71-118`, `:411-424`, `:426-472`, `:582-594`, `:675-726`).
- **Secrets**: none in payload — grep for password/secret/token/apikey/PAT/connection-string hits only the words "token" in comments about Windows tokens. Evidence file holds posture facts (build, TPM, Secure Boot, service state), not credentials.
- **Permissions**: payload admin-full/operator-RX, requests operator-Modify by design, results/audit operator-R, ledger/temp/evidence no-operator-grant, evidence world-R-only (runner service account `NETWORK SERVICE` must read the CI gate) with write/delete refused to non-admins (`install…:172-227`, `:342-380`; `worker…:150-188`).
- **Rollback**: `-Remove -RequireManifestMatch` verifies ownership + internal consistency unconditionally and additionally requires byte-identity with the reviewed checkout; backup pinned under admin roots with safe-chain checks; refuses while task Running (`install…:550-594`).

## Findings — Medium

None that block. One explicit ruling below covers the reported deviation.

## Findings — Low / Informational

1. `bin/qualify-windows-runner.ps1:24` — service name interpolated into a WMI `-Filter` string (`"Name='$($runnerService[0].Name)'"`). Source is system-enumerated service names, not operator input; service-name charset makes breakout impractical. No change required.
2. `bin/windows-runner-maintenance-worker.ps1:266` — child arguments built as one pre-quoted string (deliberate, documented `Start-Process` quoting reason); both interpolated paths are pinned literals. Safe as-is.
3. Evidence file is world-readable by design (`S-1-1-0:R`, `install…:186`, `worker…:184-185`). Contents are non-sensitive posture facts consumed by CI. Acceptable.
4. Install staging parent (`C:\Program Files\...`) gets reparse-check but no ownership assertion (`install…:500-504`). Parent is admin-owned by platform default and not operator-writable; acceptable.

## Ruling on the MATERIAL DEVIATION (elevated SSH token)

The probe reports fresh SSH sessions yield a full elevated administrator token despite `EnableLUA=1`, absent `LocalAccountTokenFilterPolicy`, and no sudo enablement — and that nothing was changed to obtain it. I **accept this exact route** for the elevated install step, because:

- The installer requires elevation anyway; the token satisfies `Assert-Administrator` without weakening any check (no FilterPolicy/sudo/service change was made to get it, per probe).
- The install does not create or widen this posture: the operator already holds remote admin via SSH, and the new task grants strictly less (GRGX start-only on a hash-pinned, triggerless, time-bounded refresh operation).

With mandatory conditions (these are gates, not payload defects):

1. **Negatives must run from a proven non-elevated context** (fresh limited-token logon, `whoami /priv` showing filtered token) — never from the elevated SSH session: operator cannot redefine/delete/replace the task, unknown operation/field/argument rejected, duplicate gets `CONCURRENT_EXECUTION`, no raw exception/stdout/stderr leak.
2. **Re-check idleness immediately before the install mutation** (GitHub online + `busy=false` + no local `Runner.Worker`) and capture the pre-install runner-service snapshot (name/start-mode/status/account) then; abort on any drift or busyness.
3. `-Verify` from a fresh session; `refresh-qualification` returns a bounded enum + audit record; evidence timestamp advance verified **without printing file contents**; exercise one recoverable failure, stale-result cleanup, re-verify; rollback command documented and refused-safe (manifest-match + admin-root backup path).


---

## Verdict
APPROVE
