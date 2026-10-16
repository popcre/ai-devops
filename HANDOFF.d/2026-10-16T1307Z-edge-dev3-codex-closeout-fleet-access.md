---
issue: 1779
status: OPEN
owner: codex/01a13fd0-6bf1-7a80-b1cc-818fe11cec0b
---

# Fleet closeout safeguard and remaining Windows access

## 0. Business decisions only the owner can make

None — nothing in this workstream needs the owner. The remaining work is technical review, installation, live verification, or access to an online Windows device. It does not require a business ruling. Do not ask the owner to approve technical work.

Already settled — do not re-ask: on 2026-09-28 the owner ruled that technical actions are gated by assigned AI review, never by human approval. No database writes or licensing source edits are part of this fleet closeout.

## 1. What this application is

`popcre/ai-devops` is POP Creations’ shared toolkit for governed AI development and machine setup. Its closeout checker verifies that a wrapped session has no shared-database reservation or preview, merge, or production-stage lease left behind. The toolkit is distributed from GitHub and installed on Linux and Windows development machines; it has no application server of its own. The public repository is [ai-devops](https://github.com/popcre/ai-devops).

## 2. What this session set out to do, and why

The fleet work began under [issue #1779](https://github.com/popcre/ai-devops/issues/1779), after sessions could leave idle shared-db reservations behind. The source feature merged in [PR #1781](https://github.com/popcre/ai-devops/pull/1781), followed by its protected-install prerequisite in [PR #1789](https://github.com/popcre/ai-devops/pull/1789).

The first full install on Windows host 4837 installed that safeguard, but its live checker failed when Python 3.14 decoded a GitHub JSON response using the legacy Windows code page. A byte in an issue body caused a decode error in a subprocess reader thread, then missing stdout reached JSON parsing. [PR #1802](https://github.com/popcre/ai-devops/pull/1802) fixes this by capturing bytes and strictly decoding UTF-8 on the main thread; invalid bytes now produce structured fail-closed JSON. The PR added regressions for foreign and owned Unicode claims plus invalid UTF-8, and merged at [commit `2e0b9d3`](https://github.com/popcre/ai-devops/commit/2e0b9d354788c6b1c4c08e02296c602afb3c3392).

## 3. Current state — what is true right now

- PRs #1781, #1789, and #1802 are merged. PR #1802’s merged head is [commit `2e0b9d3`](https://github.com/popcre/ai-devops/commit/2e0b9d354788c6b1c4c08e02296c602afb3c3392); source CI and merge queue passed normally, with no force path. The fix and its three tests are in [the closeout checker](https://github.com/popcre/ai-devops/blob/main/bin/ai-shared-db-closeout-check#L68-L85) and [its test file](https://github.com/popcre/ai-devops/blob/main/tests/test-ai-shared-db-closeout-check.py#L371-L398).
- The two Linux hosts remain accepted for the closeout feature at their existing releases. edge-dev3 has installed source/manifest [commit `4ddd46d`](https://github.com/popcre/ai-devops/commit/4ddd46d3676f5783787830b005028d0dc32423b2); hetz has [commit `0277162`](https://github.com/popcre/ai-devops/commit/0277162a402abaadba2c836802ea967085dc9f69). Both were clean, had four matching skills and the previously reviewed helper, and passed the genuine installed checker with no root-owned reservations. The older helper SHA-256 was `e5a27025473eb6566313703d3696e0a9491b788a02417445873c09f560303279`.
- Windows host 4837 completed the full supported installer against the merged fix with exit 0. Its installed source, both launcher receipts, four skills, and helper SHA-256 `63e846eddc9955fb24d23c71c30f46173f320954560984ce6771a397a0e0e744` matched; the genuine installed checker passed with no root-owned reservations.
- edge-dev and 916 each have a native independent APPROVE verdict for the exact merged head, and fresh source checks on both match it. edge-dev’s supported installer exited 0 at 9:09:03 AM EDT; its installed source, helper SHA-256, four skills, both launcher receipts, and genuine installed checker passed on the bounded retry at 9:15:30 AM EDT after the first checker call timed out. 916’s installer exited 0 at 9:11:47 AM EDT and its installed checker passed at 9:13:58 AM EDT. Both live checks returned `ok: true` with 18 claims, 97 open issues, 3 stages, and zero owned reservations. Five of six fleet hosts are accepted (two Linux and Windows hosts 4837, 916, and edge-dev); T16 is the only remaining access blocker. No installation is active.
- A separate read-only Muse check on edge-dev found installed version `1.4.9-R6297.1` with matching vendor release metadata, while `doctor` fails because the configured pin `1.4.7-R6101.1` is absent or not hash-verified; the model catalog and protected key are present. The expected pinned binary was absent before the Muse stage, so the installer invoked Meta’s vendor installer; vendor bytes were written at 9:06:24 AM EDT. Earlier provider health is UNKNOWN. The pin guard remains intact, as shown in [the pinned install guard](https://github.com/popcre/ai-devops/blob/main/bin/windows-muse-code-install.ps1#L41-L63); do not claim it broke a previously working pin. Native preflight reports `installation-unavailable/local-doctor-failed`, `usable=false`. No paid call or security change occurred. Defer supported re-pin/vendor-installer discovery on the same issue #1779, owned by root, under the current wrap freeze; inspect existing pin/config work before implementing any repair in its own worktree, then obtain the assigned exact-head APPROVE before merge or protected installation. No new issue or immediate repair is in scope.
- T16 is online, but SSH is absent; WinRM/RDP, the administrative share, WMI, and remote task execution are unavailable. The existing ScreenConnect account requires MFA, and no OTP seed is available. No install was done there.
- The same issue #1779 remains OPEN and owned by this root session. No successor transfer occurred, no database claim is retained, and no database write or licensing source change was made. The unused linked hetz install candidate remains at its baseline, clean and without authorization or a checkout lock; no Linux update is needed for this Windows-only repair. Root may safely retire that unused candidate after source closure.
- The separate shared-db source at [commit `2da79c5`](https://github.com/popcre/shared-db/commit/2da79c5128926caf4d66cf8003394b53ec7ea3b8) has pre-existing staged material and is intentionally frozen and preserved. This wrap-up made no changes there; do not describe that checkout as globally clean. Its native release/check receipt is already recorded in [shared-db issue #2336](https://github.com/popcre/shared-db/issues/2336#issuecomment-6216198870).
- This handoff and architecture note are delivered together in the PR containing this file.

## 4. Everything tried that did not work

- The original Windows checker used `subprocess.run(text=True)`. On Python 3.14, the Windows reader thread decoded GitHub bytes with the system code page, raised `UnicodeDecodeError`, and left stdout unavailable; the checker then failed during JSON parsing. Explicit encoding alone is not a reliable containment boundary for this Windows reader-thread failure. The byte-capture/main-thread decode in PR #1802 addresses it.
- An earlier 916 installed-loader review lacked the required APP evidence before dispatch. That attempt was not backfilled or reused; fresh native reviews were completed prospectively against the merged target.
- A short-lived SSH subprocess window lost output on a long native task. The durable exec session preserved the running call and its final result. Do not replace long native work with short SSH subprocess timeouts.
- Win32 process listings did not identify MSYS lifecycle owners by PID. Preserve a potentially active native call and join through its native process identity; do not terminate by a mismatched PID. A separate duplicate 916 process group was interrupted by native join and was not counted as valid review or live proof.
- An edge-dev candidate first used the wrong repository ref and was refused; the corrected route used the canonical repository ref. PowerShell 5 policy handling also refused the supported script; the current agent route uses PowerShell 7 without changing global execution policy.
- A stale Linux manifest was first refused by the gate because the live clean checkout and receipt did not agree and there was no fresh authorization. A later legitimate install refreshed the receipt. Do not fabricate elapsed proof or reuse that spent authority.
- Source CI and merge queue passed normally. There was no force merge, manual installed-checkout advance, reviewer backfill, or production/database write.

## 5. Root causes and key findings

- Windows subprocess text mode delegated decoding to reader threads. The permanent boundary is byte capture followed by strict UTF-8 decoding in the caller thread, with `UnicodeDecodeError` converted to a fail-closed `CheckError`: [checker implementation](https://github.com/popcre/ai-devops/blob/main/bin/ai-shared-db-closeout-check#L68-L85). The test suite covers valid Unicode under a legacy locale, preserves owned-claim blocking, and rejects invalid UTF-8 as structured JSON: [regressions](https://github.com/popcre/ai-devops/blob/main/tests/test-ai-shared-db-closeout-check.py#L371-L398).
- The genuine installed checker is a separate acceptance gate from source tests, candidate proof, installer exit status, and source merge. A host is accepted only after its installed source/manifest, managed launchers, helper, four skills, and genuine live checker all match and the checker reports no root-owned reservations.
- Linux hosts already satisfy the feature at their existing reviewed versions; the UTF-8 defect was Windows-specific. Do not create an unrelated Linux upgrade/review lane.
- The protected route requires a fresh installation task at the installed baseline, then the candidate advance, an exact-target independent native APP, one-use authorization, and the full supported installer. See [deployment procedure](https://github.com/popcre/ai-devops/blob/main/docs/deployment.md#L176-L215) and [Linux candidate/install safeguards](https://github.com/popcre/ai-devops/blob/main/docs/deployment.md#L396-L426).
- Private native receipts are retained locally under the opaque root run identifier `01a13fd0-6bf1-7a80-b1cc-818fe11cec0b`; the protected machine atlas resolves them. Do not copy raw native reports, host paths, account names, or credentials into a public issue or handoff.

## 6. Exact next steps

1. Start from the five accepted host results recorded on issue #1779; do not repeat completed installs. No installation remains active. T16 is the only unaccepted host.
2. Keep edge-dev3 and hetz accepted at their existing feature releases; do not update Linux for this Windows-only fix. The previously prepared hetz candidate is idle and has no authority. Success means both still match their recorded clean receipts and no unrelated Linux rollout is started.
3. For the optional Muse discovery on edge-dev, inspect existing pin/config changes and installed state before proposing any repair. The pinned binary was absent before the vendor stage; earlier provider health is UNKNOWN, so do not claim the installer broke a previously working pin. Keep any supported re-pin/vendor-installer repair on issue #1779, owned by root, under the current wrap freeze. Implement a supported repair in its own worktree and obtain the assigned exact-head APPROVE before merge or protected installation. Success means the cause is evidenced without weakening the pin guard or creating another issue.
4. Resolve T16 access only through a legitimate authenticated Windows admin-support route. If the platform cannot provide that route, keep T16 blocked and issue #1779 open; do not reset or guess passwords, bypass MFA, harvest cookies, or retry the known-wrong password. Success means the AI can inspect the canonical repository, managed receipt, and host profile without bypassing access controls.
5. Once T16 has legitimate access, re-read its canonical repository HEAD, managed install receipt, and host profile. Stop before installation if the supported network/install class cannot be established. Create its own clean linked install candidate at installed HEAD and a separate review candidate at the exact merged target; declare the native task classes before advancing the install candidate. Success means both candidates are linked to the canonical Git common directory and the install declaration’s start head equals T16’s fresh installed HEAD.
6. Obtain the allocator-assigned independent native APPROVE verdict for the exact merged target, then use the normal one-use authorization and full [Windows installer](https://github.com/popcre/ai-devops/blob/main/bin/install-ai-devops-windows.ps1) route with the exact `-ExpectedHead`. Never reuse approval or authority from another host. Success means the installer exits 0 and its protected receipt records the exact merged SHA.
7. Verify T16’s installed source/manifest, both launcher receipts, helper hash, four skills, and genuine installed checker. The checker must return structured `ok: true` and report zero root-owned reservations/stages. If any check fails, preserve the host state and repair through the supported route; do not count it accepted.
8. Update the existing issue #1779 with per-host evidence. Close it only when all six hosts are accepted and the same closeout check passes for the root session. Otherwise leave one explicit owner and current blocker on #1779; do not create another issue.

## 7. Constraints and gotchas in force

- Keep issue #1779 as the single card. Root owns coordination, closeout, and any successor handoff. No one transferred the work to a successor.
- For reviewer-safety releases, use a clean install candidate at the installed baseline and a separate reviewer candidate at the exact merged target. Declare before advancing; bind native APPROVE, authorization, and full installation to the same exact target.
- Source merge, candidate tests, native APP, installer exit, installed receipts, and genuine installed live proof are distinct facts. Never substitute one for another or report candidate proof as installed proof.
- Preserve strict UTF-8 failure behavior. Do not restore `text=True`, weaken decoding, change global locale/encoding, or suppress malformed responses.
- No database writes, preview/prod actions, licensing source edits, claim changes, human technical approval, or unsupported install routes belong to this fleet task. No active installation locks or database claims are held by these workstreams.
- The exact target at this handoff is [commit `2e0b9d3`](https://github.com/popcre/ai-devops/commit/2e0b9d354788c6b1c4c08e02296c602afb3c3392); re-read GitHub and each host before any future action. Do not infer that the target remains current.
- No new secrets were encountered. Existing credential references remain in 1Password `vibe_coding`. Preserve the frozen shared-db checkout and all native review/install custody; do not delete, cancel, or rewrite another session’s work.
- Report-only handoff cleanup found five successor-review candidates; none was retired: [2026-09-30 edge-dev Mimo coordinator residuals](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-09-30T1226Z-edge-dev-mimo-coord-del-residuals.md) — owner `mimo/coord-del-parent-1061`; [2026-09-30 edge-dev Mimo residual closeout](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-09-30T1431Z-edge-dev-mimo-coord-del-residuals-closeout.md) — owner `mimo/1061-residuals-hetz-tools`; [2026-10-08 edge-dev3 HTS review RAG](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-08T1754Z-edge-dev3-codex-hts-review-rag.md) — owner `codex/hts-final-closeout`; [2026-10-13 edge-dev Mimo leftover triage](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-13T1126Z-edge-dev-mimo-housekeeping-leftover-triage.md) — owner `mimo/1585-housekeeping-closeout-handoff`; [2026-10-13 edge-dev Mimo review-waste rule](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-13T2120Z-edge-dev-mimo-review-waste-skip-rule.md) — owner `mimo/edge-dev`.

## 8. Access and environment

- The canonical public source is [popcre/ai-devops](https://github.com/popcre/ai-devops); issue and pull-request state is read from GitHub. Linux protected updates use the merged-target candidate route in [deployment.md](https://github.com/popcre/ai-devops/blob/main/docs/deployment.md#L396-L426); Windows protected updates use the full native installer described in [deployment.md](https://github.com/popcre/ai-devops/blob/main/docs/deployment.md#L193-L215).
- Account credentials, where already configured, remain in the 1Password `vibe_coding` vault. Never copy a value or item identifier into this handoff. ScreenConnect currently lacks an available MFA seed, so its stored password alone is insufficient for T16 access.
- T16 is online but has no reachable SSH service; available WinRM/RDP and remote administrative mechanisms are denied. No legitimate remote-write route is currently established there. This is a technical access blocker, not a business decision.
- The opaque run identifier above is only a locator for protected local evidence; use the machine atlas to resolve it. Do not publish local paths or raw reports.

## 9. Open questions and risks

- 2026-10-16: 916’s installer and live check passed at 9:11:47 AM EDT and 9:13:58 AM EDT. edge-dev’s installer passed at 9:09:03 AM EDT; its first live call timed out, and the bounded retry passed at 9:15:30 AM EDT. Both returned 18 claims, 97 open issues, 3 stages, and zero owned reservations; the fleet is 5/6 accepted and no installation remains active. T16 is the only fleet host not accepted. Muse preflight on edge-dev reported `installation-unavailable/local-doctor-failed`, `usable=false`; the expected pin was absent before the vendor stage, new vendor bytes were written at 9:06:24 AM EDT, and earlier provider health is UNKNOWN. Defer further Muse discovery under the current wrap freeze on the same issue #1779.
- 2026-10-16: T16 remains blocked on legitimate MFA/admin access. No account reset, bypass, or credential-guessing path is authorized. Root owns the technical access resolution; if no approved route becomes available, report T16 blocked and keep the fleet issue open.
- This handoff and architecture note are delivered together in the PR containing this file.
- No owner business decision is open. Do not turn the technical access blocker into a request for human approval.

## Per-agent work blocks

### `fleet_windows_census`

Asked to reconcile Windows fleet installation state and provide an optional read-only Muse finding. Root independently verified edge-dev and 916’s final live results; edge-dev’s first checker call timed out and its bounded retry passed at 9:15:30 AM EDT. 916’s checker passed at 9:13:58 AM EDT. Both reported 18 claims, 97 open issues, 3 stages, and zero owned reservations. Five of six fleet hosts are accepted, with no installation active and T16 still blocked. The Muse pin discrepancy and preflight result are described above; no source PR or commit is attributed to this agent. This agent’s work is complete.

### `windows_review_diagnosis`

Asked first to diagnose native Windows review/install activity, then to implement the permanent UTF-8 repair and prepare supported fleet candidates. It reproduced the ASCII-default decoding failure, added strict main-thread decoding and three offline regressions, and the resulting change merged in [PR #1802](https://github.com/popcre/ai-devops/pull/1802). Focused tests passed 27/27 and the fast-close contract passed. It later prepared an idle Hetz candidate at the existing baseline and declared installation before any advance. It deliberately performed no Linux update, paid review, authorization, or install after root narrowed acceptance to the Windows-only fix. The candidate remains clean and root may retire it after source closure.

### `closeout_guard`

Asked for portability checks around the closeout guard. Its focused suite passed 24/24 and test discovery plus CI manifest-loader checks passed 17/17. It reported Windows runtime untested locally and made no commit or push. Do not attribute its uncommitted worktree as a landed release; source behavior is the merged PR #1781 plus the UTF-8 fix in PR #1802.

### `advisory_proof_fix`

Asked to add the exact-name Grok skip and regression coverage. It reported 81 passed, 0 failed, 0 skipped, with required-job rejection covered and `git diff --check` passing. No commit or push was made. This separate test work does not establish fleet installation or live acceptance.

### `current_outcomes`

Asked for a supplemental qualification of current outcomes. It saved a private supplement covering blank-row status, identifier-format counts, catalog matches, and a bounded generator search; the source workbook and prior evidence were unchanged. No product change, PR, or commit was reported, and the output does not establish current application rows or runtime state.

### `duplicate_spec`

Asked for B1/N3 and full-parts checks. It reported 268 passed in the all-parts run and 84 passed in the focused failed-turn run, with syntax and diff checks passing. No commit or review was performed; root retains any commit/review decision. These tests do not replace fleet live proof.

### `elapsed_proofs`

Asked to preserve elapsed-proof findings. It saved a private note with a recorded SHA-256, but made no database or runtime calls; it explicitly did not prove actual row contents or deployed log retention. No commit or PR was reported. Do not promote its note to live application proof.

## Next-session prompt

```text
Resume popcre/ai-devops from https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-16T1307Z-edge-dev3-codex-closeout-fleet-access.md and https://github.com/popcre/ai-devops/issues/1779. Goal: finish the verified fleet rollout and preserve the working safeguards. Use a new current-upstream worktree; do not edit an installed checkout.
Continue issue #1779 from fresh GitHub state. Five of six hosts are accepted; T16 is the only unaccepted host and is blocked on legitimate authenticated Windows-admin access. Pursue only a legitimate route; do not bypass MFA or reset/guess credentials. If access becomes available, inspect its canonical checkout, managed receipt, and host profile; create separate linked install/review candidates, declare the effective classes before advancing, obtain exact-target native APPROVE, run one-use authorization and the full Windows installer, then verify source/helper/skills/launchers and the genuine installed checker. Record evidence on the same issue and close only after all six pass and the root closeout check passes. Optional Muse work on edge-dev is a separate deferred discovery under the same issue and current wrap freeze: inspect existing pin/config state first, implement any supported repair in its own worktree, and obtain assigned exact-head APPROVE before merge or protected installation. Earlier provider health is UNKNOWN; do not claim the vendor stage broke a working pin. Source PRs #1781, #1789, and #1802 are merged; never replay their reviews or installation authority. See [protected install route](https://github.com/popcre/ai-devops/blob/main/docs/deployment.md#L176-L215) and [checker implementation](https://github.com/popcre/ai-devops/blob/main/bin/ai-shared-db-closeout-check#L68-L85).

```

## Self-audit

1. Is the next action concrete, observable, and owned? **Yes.** Root owns issue #1779; the sole fleet blocker is T16’s legitimate access, with objective host/install/live-check criteria. Optional Muse discovery is explicitly deferred under the same issue and wrap freeze.
2. Are approvals, claims, leases, and authority stated without reusing spent authority? **Yes.** The handoff requires fresh candidates, declarations, exact-target assigned APPROVE, and one-use install authorization for T16; no claims or active installation locks remain.
3. Are source, installation, and live acceptance kept separate, with uncertainty preserved? **Yes.** Five accepted hosts have individual merged-source, receipt, and live evidence; T16 remains blocked. Muse pre-stage pin absence is established, while earlier provider health remains UNKNOWN.
4. Are private data, custody, and repository state preserved? **Yes.** No secrets were encountered; private evidence is referenced only by an opaque locator; the staged shared-db checkout, native custody, and report-only cleanup candidates are preserved, with no deletion or unrelated edit.


## Fresh-developer self-audit

1. **Could a developer with no chat context continue without clarification? Yes.** Sections 1–3 identify the repository, purpose, exact released source, five accepted hosts and the sole unaccepted host. Sections 6–8 give the ordered protected route and observable acceptance checks.
2. **Is this as detailed as the session knowledge? Yes.** Sections 3–5 preserve source/installed/live distinctions, exact commits and hashes, native review custody failures, genuine timeout/retry results, and the bounded access findings. Every delegated lane has a result and limitation.
3. **Are execution details and unresolved risks actionable? Yes.** Public implementation and deployment references are linked, private evidence is retained under the session locator, T16 has explicit access/install/live criteria, and Muse has a separate supported repair path without weakening its pin. No paid review or spent install authority is reusable.
4. **Does section 0 contain every owner business decision? Yes.** Reading sections 1–9 and the agent blocks reveals only technical access, review, installation and provider repair work. No business choice is open and no human technical approval is requested.

## Closing record

Documentation: this handoff plus the living architecture note; source changes already merged in PRs #1781, #1789 and #1802. Secrets: no new secret values encountered or committed. Workspace: frozen shared-db staged material and all native review/install custody remain intentionally preserved; no branch or worktree was deleted. Own source-fix and documentation worktrees are retained with their merged source/PR evidence rather than discarding ignored custody. The unused Hetz candidate remains clean, idle and without authority. Housekeeping was report-only: nine live worktrees, 33 merged candidates, 294 unknown worktrees, 57 open handoffs, the five named successor-review candidates above, two unprovable handoffs and zero unowned references. Counts are inventory, not deletion authority. The next-session prompt above carries all unfinished scope; issue #1779 stays open.
