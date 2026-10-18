---
issue: 1783
status: OPEN
owner: claude/1783-coordinator (chat 05d44eb1-ce4c-474e-885f-5e123d2d28c5, edge-dev3) — released at wrap-up 2026-10-18; next session claims on #1783
---

# Handoff — reviewer recurrence: fixed on three hosts, proof and prevention open

Supersedes this chat's earlier step-8 brief (removed in the same PR; git history keeps it).

## 0. Business decisions only the owner can make

None. Albert's standing constraint (2026-10-18): **no new CI jobs, Windows CI runs or test suites** — prevent breakage at the source.

## 1. What this application is

[popcre/ai-devops](https://github.com/popcre/ai-devops/blob/main/README.md) is Albert's AI toolkit: reviewers (Muse, DeepSeek, GLM, StepFun), installers, safety gates. Consumer: [popcre/shared-db](https://github.com/popcre/shared-db) `scripts/run-governed-review.mjs`, which records a review only when the reviewer wrote a governed source receipt. Hosts: edge-dev3 (Ubuntu), hetz (Ubuntu server), edge-dev (Windows), 916 (Windows).

## 2. Goal and trigger

Albert, 2026-10-16: execute [plan](https://github.com/popcre/ai-devops/blob/main/plan_reviewer-recurrence-repair.md) steps 2–8 under [#1783](https://github.com/popcre/ai-devops/issues/1783). Then: "the reviewers failed again" (shared-db PR4387/4401), "check edge-dev", "make a parent issue + child issues … run the plan by Muse".

## 3. Current state (verified 2026-10-18 ~11:40 AM EDT)

- **Merged this chat:** PR1810 housekeeping trap; PR1811 hook-test isolation; PR1812 StepFun single-decision prompt; PR1820/1824 docs; **PR1826** governed receipt for every core door + no pass reuse for governed calls (root cause of 2026-10-16 DeepSeek/StepFun/GLM shared-db failures); PR1830 Windows path fix for PR1811's test.
- **Installed (protected route, verified):** edge-dev3 at aebe9048; hetz at aebe9048 (via `stale-linux-manifest-recovery`; GLM APPROVE); edge-dev at 280f426e (DeepSeek APPROVE; `install-ai-devops-windows.ps1 -ExpectedHead`).
- **Live governed-receipt checks (planted-defect fixture, receipt env set):** edge-dev3 all four REJECT + receipt (2026-10-18); hetz DeepSeek + StepFun REJECT + receipt; edge-dev DeepSeek REJECT + receipt, **StepFun failed** (`review snapshot changed during the review`).
- **Not checked/updated:** 916 runs 5dc158e8 (2026-10-12) — older than both PR1799's bug and PR1826's fix; needs protected Windows update.
- **Prevention plan:** parent [#1833](https://github.com/popcre/ai-devops/issues/1833), children [#1834](https://github.com/popcre/ai-devops/issues/1834) (one code path for all reviewers), [#1835](https://github.com/popcre/ai-devops/issues/1835) (no raw path comparison), [#1836](https://github.com/popcre/ai-devops/issues/1836) (installed checkout refuses plain pull via managed `reference-transaction` hook). Muse plan review: REJECT then APPROVE after revision; notes on each child. **No code started.**
- **Step-8 window:** restarted 2026-10-16 6:28 PM EDT; zero organic reviews ran on edge-dev3 through 2026-10-18 morning, so it proves nothing alone. No new reviewer incident logged since.
- Evidence comments on #1783: 6224746526 (cause), 6225893096 (PR1826 install), 6249832426/6249932338 (hetz), 6250066358/6251288627 (edge-dev); #1678 has the edge-dev copies.

## 4. Failed attempts and dead ends

- I wrongly reported DeepSeek shared-db acceptance on 2026-10-16 (the 4:07 PM REJECT was GLM); corrected in comment 6224746526.
- Switching branches in a shared worktree mid-review → correct `source-head-mismatch`. Use one worktree per review.
- First PR1826 review: GLM REJECT (stale base; pool reuse sibling) → fixed, then APPROVE.
- hetz first install failed Muse Code stage: only Meta's auto-updated muse-bin-1.4.10 present; pin is 1.4.9-R6297.1 (PR1814). Restored by copying edge-dev3's binary after SHA-256 matched the pin (a2280100…abe05).
- Proposed extra Windows CI coverage — **rejected by Albert**; do not re-propose.

## 5. Findings

- PR1799 gated receipt publication on `provider = muse` → DeepSeek/StepFun governed reviews unrecordable. PR1826 generalized it.
- Front door/pool returned another reviewer's earlier pass to a governed call → GLM never ran.
- Plain `git pull` of installed checkouts by other sessions: hetz 2026-10-18 07:50 EDT by Claude chat f169b5d3 (PopDAM worktree); edge-dev 2026-10-16 21:29Z. Hosts then ran code no install verified.
- Windows CI ran PR1811's changed test only on Linux; a Windows-only failure surfaced at install time.

## 6. Exact next steps (each with its gate)

1. Claim coordinator on #1783 (signed comment).
2. **916:** read-only check via `ssh 916` (Tailscale name `916`), then the same protected Windows route used for edge-dev: review candidate at current main, DeepSeek or Muse final-check base=installed launcher source-sha, install candidate at installed HEAD, `ai-task-gates authorize-install`, target `bin/install-ai-devops-windows.ps1 -RepoPath <checkout> -ExpectedHead <sha>`. Gate: launcher `source-sha` = target; DeepSeek receipt check on fixture.
3. **Shared-db acceptance:** when the allocator next assigns DeepSeek and StepFun on edge-dev3 or hetz, confirm a `refs/db-review-verdicts/…` with that reviewer. Never take another session's slot. Then resolve incidents 20261016T204930Z-edge-dev3-deepseek-664102 and -stepfun-664003 with `ai-reviewer-issue`.
4. **Prevention children** #1834 → #1835 → #1836, each independently: branch, PR, independent exact-head review, merge queue, protected install; apply Muse's notes on each issue.
5. **Step 8 close:** once a ≥24 h window contains real reviews on the installed release, count per provider (lifecycle runs + `reviewer-events/events.jsonl`), reconcile the 82 step-1 IDs, update plan STATUS.

## 7. Constraints

Task class reviewer-safety. Branch/PR/merge queue only; never `git pull` an installed checkout; protected installers only. No new CI jobs/suites/Windows runs. Never delete evidence or replay paid turns. Times in EDT; sign GitHub posts.

## 8. Access

gh as u2giants. SSH: `edge-dev` (Windows; use `"C:\Program Files\Git\bin\bash.exe" -l -s` with a script on stdin, or PowerShell via `[Console]::In.ReadToEnd()`), `916`, `ai@hetz` with the SSH key named 916-alien (passwordless sudo). edge-dev3 sudo: 1Password item "edge-dev3 ahazan sudo password" via `op_run` into a pipe-only sudo shim; detached installs export XDG_RUNTIME_DIR, DBUS_SESSION_BUS_ADDRESS, AI_MUSE_ENGINE=opencode.

## 9. Risks and ownership

- **Blocked:** StepFun on Windows — owned by [edge-dev no-review plan](https://github.com/popcre/ai-devops/blob/main/plan_edge-dev-reviewer-repair-no-review.md) / #1678 and open PR1807 (touches the same StepFun door as PR1812; check Linux before it merges).
- **Blocked:** stale StepFun slot 6672 on merged shared-db PR4406 (`refs/db-review-active-v2/stepfun-step-5-preview/…-slot3`) — a shared-db owner must release it.
- Chat f169b5d3 on hetz may pull again until #1836 lands.

## Self-audit

1. Newcomer can continue? Yes — §3 exact versions per host, §6 numbered steps with gates, §8 access.
2. As well as I could? Yes — §4 every trap and the corrected false claim; §5 causes.
3. Every detail? Yes — background §1–2, state §3, failures §4, decisions §0/§4, constraints §7, risks §9, verification gates §6. Gap on first pass: missing 916 SSH name and Windows command form — added §6/§8.
