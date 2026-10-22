---
issue: 1783
status: BLOCKED
owner: claude/1783-coordinator (chat a0383fe3-ae90-495c-9fa7-9ad7e7cb2fd5, edge-dev3) — released at wrap-up 2026-10-22
---

# Handoff — reviewer recurrence: step 8 open on edge-dev only

Supersedes [2026-10-18T1524Z fleet handoff](https://github.com/popcre/ai-devops/blob/e534a530fad60484e25053a04e318943ae5d3b55/HANDOFF.d/2026-10-18T1524Z-edge-dev3-claude-reviewer-recurrence-fleet.md) (deleted in the same PR under the successor rule; every open item is carried here).

## 0. Business decisions only the owner can make

None. Standing owner constraints: no new CI jobs, Windows CI runs or test suites (2026-10-18); observation week ([#1948](https://github.com/popcre/ai-devops/issues/1948)) forbids reviewer-repair PRs and toolkit installs while its window file is live — log failures with `ai-reviewer-issue` instead.

Already settled — do not re-ask: Windows CI coverage was proposed and rejected (2026-10-18).

## 1. What this application is

[popcre/ai-devops](https://github.com/popcre/ai-devops/blob/main/README.md) is Albert's AI toolkit: independent AI reviewers (Muse, DeepSeek, GLM, StepFun), installers and safety gates used on four review hosts — edge-dev3 and hetz (Ubuntu), edge-dev and 916 (Windows). [popcre/shared-db](https://github.com/popcre/shared-db) records a review only when the reviewer wrote a governed source receipt.

## 2. Goal

Execute [plan_reviewer-recurrence-repair.md](https://github.com/popcre/ai-devops/blob/main/plan_reviewer-recurrence-repair.md) under [#1783](https://github.com/popcre/ai-devops/issues/1783) to the end: step 8 = a real ≥24 h window in which every maintained reviewer on every host produces trustworthy verdicts, plus reconciliation of the 82 step-1 incident IDs.

## 3. Current state (verified 2026-10-22 7:35 AM EDT)

- Steps 1–7 done (plan STATUS). This session (2026-10-18 → 10-22) delivered: 916 protected update + DeepSeek governed receipt proof; prevention children #1834 (PR1839/1845), #1835 (PR1841), #1836 (PR1842/1844/1847/1848); Windows hash fix PR1840; StepFun Windows spawn #1678 (PR1849/1851/1852, PR1807 reverted in PR1848); shared-db incidents 664102/664003 resolved; codex model on hetz restored to `gpt-5.6-sol` (backup kept). Later installs by other sessions: fleet at 21a37359 (Oct 20), PR1899 (Oct 21 ~12:10 AM EDT).
- Step 8 window since the PR1899 install: **edge-dev3, hetz, 916 pass; edge-dev fails** (GLM 7 provider-failed vs 3 verdicts; DeepSeek 7 interrupted + 4 native-execution-failed; StepFun 5 failures). Counts: #1783 comments [6331384073](https://github.com/popcre/ai-devops/issues/1783#issuecomment-6331384073), [6331797848](https://github.com/popcre/ai-devops/issues/1783#issuecomment-6331797848). Plan STATUS updated by PR1971.
- edge-dev incidents open: `20261021T004546Z-edge-dev-glm-2037169`, `20261021T164147Z-edge-dev-multi-reviewer-recording-3487006`, `20261022T031331Z-edge-dev-deepseek-807402` (DeepSeek native stream ends mid-tool after a PowerShell tool call).
- 82 step-1 IDs reconciled: [step8-reconciliation-2026-10-21.md](https://github.com/popcre/ai-devops/blob/main/tests/verification/reviewer-recurrence/step8-reconciliation-2026-10-21.md) (12 fixed, 59 frozen reviewers, 2 Codex, 9 unknown with owners #1405/#1349/#1370/#1783). No incident was resolved from it.
- Nothing uncommitted from this session.

## 4. What did not work

- Reporting EDT clock times by hand: twice wrong (UTC labelled EDT; guessed future times). Compute with `TZ=America/New_York date`.
- 916's `C:\repos\ai-devops` is a stray clone; the live toolkit is **`D:\repos\ai-devops`** (launchers exec there). An install against C: stops with `Installed Windows launcher routing differs`.
- Each guard repair (PR1844 → 1847 → 1848) was REJECTed by DeepSeek for a real data-loss or dead-end case; reviewing the guard only with Muse missed them.
- PR1849's first form (BASH_ENV) still failed: OpenCode 1.18.12 wraps every command in a multi-line `bash -l -c` block the gate refused; fixed in PR1851, then PR1852 kept the gate env off test stubs.
- A wait loop using `pgrep -f 'bin/ai-glm new'` matched itself and never ended.
- Linux `update.sh` retried after a failed stage needs `--stale-manifest-recovery` with an `Approved stale-linux-manifest-recovery.` review, and a leftover `install-authorizations/<sha>.json.ordinary` must be moved aside (backup kept on edge-dev3).

## 5. Findings

- edge-dev is the only failing host; its reviewer repair owner is [#1678](https://github.com/popcre/ai-devops/issues/1678) / [plan_edge-dev-reviewer-repair-no-review.md](https://github.com/popcre/ai-devops/blob/main/plan_edge-dev-reviewer-repair-no-review.md).
- Meta auto-updates Muse Code past pin 1.4.9-R6297.1 (916, earlier hetz); the optional Muse Code install stage then skips.
- Timing-flaky `paces_before_call` in tests/test-ai-stepfun.sh fails CI occasionally; rerun failed jobs only.

## 6. Next steps

1. When observation week (#1948) ends, the #1678 owner repairs edge-dev using the three incidents above. Gate: a governed DeepSeek, GLM and StepFun review on edge-dev each reaches a terminal verdict.
2. Then measure a fresh ≥24 h edge-dev window from lifecycle runs (`~/.local/state/ai-devops/review-lifecycle/runs/**/*.json`, filter `started_at`). Gate: failures are only caller-test refusals or retained-evidence refusals; no provider-failed/native-execution-failed/interrupted clusters.
3. Close step 8 in plan STATUS (prose PR) and close #1783. Then delete this file.
4. Optional cleanup: 916 Muse Code re-pin or restore of the pinned binary.

## 7. Constraints

Branch/PR/merge queue only; never `git pull` an installed checkout (the #1836 guard now refuses and restores); protected installers only; no new CI jobs/suites; sign GitHub posts; times in EDT.

## 8. Access

gh as u2giants. SSH `edge-dev`, `916` (Windows: `"C:\Program Files\Git\bin\bash.exe" -l -s`, script on stdin), `ai@hetz` with key 916-alien. edge-dev3 sudo via 1Password `vibe_coding` item "edge-dev3 ahazan sudo password" through `op_run`.

## 9. Risks

- Observation week may extend; step 8 cannot close before edge-dev is repaired.
- Codex config on hetz was changed outside ai-devops once; recheck if its doctor fails.

## Self-audit

1. Newcomer continues? Yes — §3 state per host, §6 gated steps, §8 access.
2. As well as I could? Yes — §4 every trap hit this session, §5 owners.
3. Every detail? Yes — background §1–2, failures §4, constraints §7, risks §9, evidence links §3.
4. §0 complete? Yes — swept §1–§9: no business decision; repairs are technical and owned by #1678.
