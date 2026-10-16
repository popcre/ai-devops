---
issue: 1783
status: OPEN
owner: claude/1783-coordinator (chat 05d44eb1-ce4c-474e-885f-5e123d2d28c5, edge-dev3)
---

# Handoff — reviewer recurrence, steps 2–7 done, step 8 observing

## 0. Business decisions only the owner can make

None. StepFun credit was recharged by Albert on October 16, 2026; nothing else is owed by him.

## 1. What this application is

[popcre/ai-devops](../README.md) is Albert's AI toolkit (reviewers, installers, safety gates). edge-dev3 is the affected Linux host; its installed checkout is `/home/ahazan/repos/ai-devops` (landing/install only — never pull it). Consumer: popcre/shared-db `scripts/run-governed-review.mjs`.

## 2. Goal and trigger

Albert (October 16, 2026): "execute plan steps 2–8: repairs, Muse re-pin, housekeeping fix, protected install, live per-provider proof and 24-hour observation." Spec: [plan](../plan_reviewer-recurrence-repair.md) — read its STATUS table first. Predecessor brief: [step-2 handoff](2026-10-16T1400Z-edge-dev3-claude-reviewer-recurrence-step2.md) (another session's file; do not edit).

## 3. Current state (verified October 16, 2026, ~1:45 PM EDT)

- Merged: PR1810 (housekeeping EXIT-trap `tmp: unbound variable`), PR1811 (preflight test no longer writes synthetic `hooktest/clone` records into the live `~/.local/state/ai-devops/task-gates/unprotected-advances.log`), PR1812 (StepFun prompt states consumer's single-decision rule; door prints `report-extra-decision-line` without rewriting bytes), PR1820 (plan STATUS).
- Installed on edge-dev3: **1aefa959dec223f88e93c8923f2d4f185df03134** from 4ddd46d3 via candidate `update.sh --expected-head`; every stage PASS incl. Muse Code (Linux) and Housekeeping schedule; `Linux install verified`. Authority: Muse final-check APPROVE run 20261016T162830-3080875-21619 with local tests.
- Live matrix (issue comment 6221299618): all four providers REJECT a planted defect and APPROVE its fix; Muse/GLM/DeepSeek via same-conversation follow-up; StepFun via two fresh reviews (no follow-up command exists). Release review APPROVE from Muse ×3, DeepSeek, GLM, StepFun.
- Step 8 window opened **October 16, 2026, 1:00 PM EDT** (comment 6220423435).
- Issue comments this session: claim 6218912628, progress 6219505789, install 6220101569, window 6220423435, StepFun 6220845071, matrix 6221299618.

## 4. Failed attempts and dead ends

- Switching branches in one worktree while a review ran → correct `source-head-mismatch` refusal (GLM). Use one worktree per concurrent review.
- First install authorization refused: needs a separate installation-candidate worktree (`start --class installation`) and a review carrying `--tests` evidence. See docs/deployment.md.
- StepFun held `out-of-credit`; after recharge, `ai-review-preflight check stepfun <repo> --live` probes and clears the hold itself. Never clear manually.
- DeepSeek: my prompt asked for `VERDICT: X sha` while the wrapper requires `## Verdict` → model mixed both → correct `invalid-terminal-verdict`. Do not add your own format line. `reply` must repeat `--review --repo-tools` or it runs as a plain, non-authorizing chat.
- First housekeeping test version ran real `schtasks` on Windows CI; now skipped where `schtasks.exe` exists.

## 5. Findings

- Step 2 receipt conflict: caused by the runner's preparatory `verify` publishing the receipt early; fixed by PR1799 (0277162a). Orphan sweep is `|| true` — noise (~32 lines/run), not a blocker.
- Muse: `bin/ai-muse` runs hash-verified `~/.local/bin/muse-bin-1.4.7-R6101.1`; PATH `muse` 1.4.9 is Meta's self-updater and unused. No re-pin needed.
- Muse `tool-calls` incomplete-completion work remains owned by #674 and the final-receipt design lane (01a14247…).
- The live unprotected-advances log still holds 276 old synthetic entries; they settle at the next protected install acknowledgement. Do not delete.

## 6. Exact next steps

1. Not before **October 17, 2026, 1:00 PM EDT**: count every review on edge-dev3 since the window opened (`ai-reviewer-issue list`, lifecycle runs under `~/.local/state/ai-devops/review-lifecycle/runs`), per provider: usable decisions, refusals, failures. Gate: real timestamps; honest denominators.
2. Reconcile all 82 step-1 IDs (private manifest `~/.local/state/ai-devops/1783-step1-inventory-20261016/manifest.tsv`) to fixed / expected refusal / duplicate / frozen-provider limitation / carried forward, appending resolutions via `ai-reviewer-issue`. Never reclassify to hide a defect.
3. Shared-db consumer acceptance for Muse, DeepSeek, StepFun when the allocator assigns them real governed reviews; never take another session's slot.
4. Update plan STATUS, check #1783 boxes, delete this file when everything is discharged.

## 7. Constraints

Task class reviewer-safety. Branch/PR/queue only; never pull the installed checkout; never delete evidence or replay paid turns. Times in EDT. Sign GitHub posts.

## 8. Access

gh as u2giants. Sudo for `update.sh` via 1Password item "edge-dev3 ahazan sudo password" injected through `op_run` into a pipe-only sudo shim; for detached installs export XDG_RUNTIME_DIR, DBUS_SESSION_BUS_ADDRESS, AI_MUSE_ENGINE=opencode.

## 9. Risks and ownership

Coordinator: this chat until step 8 closes. A reviewer-code regression during the window requires a repair plus a new 24-hour window. A provider outage is an availability limit, not a code failure.

## Self-audit (completeness gate)

1. Could a brand-new developer continue? Yes — §3 gives exact SHAs/PRs/comments, §6 exact commands and gates, §1/§8 paths and access.
2. As well as I could? Yes — §4 records every trap hit this session and its correct handling; §5 the root causes.
3. Every relevant detail? Yes — background §1–2, state §3, failures §4, decisions §5, constraints §7, risks §9, next actions with gates §6. Gap found on first read: missing install-access detail — added §8.
