---
issue: 961
status: OPEN
owner: mimo/warpbuild-required-ci-migration
---

# HANDOFF — WarpBuild canary green; required cut-over NOT landed; Blacksmith stays

Machine: edge-dev · Agent: mimo · Written: 2026-10-01 (updated at wrap-up)
GitHub signature this session: `Posted by MiMo chat ses_ffe5f0d4e5291ffey2COx392lA on edge-dev`

## 0. Decisions only the owner can make

- **Already decided (do not re-ask):** WarpBuild Azure BYOC on the dedicated
  `warpbuild ci runners` subscription; cheapest on-demand Windows that works;
  canary before cut-over; **Blacksmith stays in the pool until WarpBuild is
  fully up** (Albert, 2026-10-01 chat). Use Blacksmith for runs that would
  otherwise get stuck. **Do not turn Blacksmith off.** Do not stop WarpBuild
  bring-up.
- **Still his:** whether cost target requires a smaller/larger VM after the
  first real invoices. Not needed to continue the technical work.
- **Not Albert's technical call:** cut-over diffs, Azure topology, and runner
  config take independent AI review (explicit APPROVE). Never ask Albert to
  approve technical actions.

## 1. What this project is

`popcre/ai-devops` is POP Creations' public AI workflow toolkit. Windows CI
today is Blacksmith. WarpBuild Azure BYOC is the cheaper Windows rental (one
ephemeral Azure VM per job). Issue
[#961](https://github.com/popcre/ai-devops/issues/961). Operational doc:
[`docs/warpbuild-azure-byoc.md`](../docs/warpbuild-azure-byoc.md).

## 2. Goal and reason

Cut Windows CI cost by moving the **full required** test suite from Blacksmith
to WarpBuild, while Blacksmith remains available until WarpBuild is proven
fully up. Albert chose WarpBuild after Blacksmith billing looked high.

## 3. Current state and proof

### Proven
- **Canary green 2026-09-30 15:06Z:**
  [36731941680 job 109943590499](https://github.com/popcre/ai-devops/actions/runs/36731941680/job/109943590499)
  on `warp-custom-warpbuild-win2022-canary`. Win NT 10.0.20348, X64,
  git 2.55.0.windows.5; VM + disk cleaned up after job.
- Root cause of earlier stuck queues: org **Default** runner group had
  `allows_public_repositories=false` on this public repo. Fixed live; also
  created runner group **WarpBuild BYOC** (id 6). See
  [`docs/warpbuild-azure-byoc.md`](../docs/warpbuild-azure-byoc.md).
- Stack `popcre-ci-use1` active. Runner set `wts3yujcycg8o15x`, labels
  `warp-custom-warpbuild-win2022-canary` and `warp-custom-win2022-canary`.
  Storage stuck at 150 GB (vendor floor 256 GB; tooling canary still fit).

### NOT done (this is the open work)
- **Required CI is still on Blacksmith.** Cut-over is NOT merged.
- Branch `mimo/warpbuild-required-cutover`
  (worktree `C:/repos/ai-devops/.ai/worktrees/warpbuild-required-cutover`) has
  commits re-pointing required Windows to the WarpBuild label.
- PR [#1220](https://github.com/popcre/ai-devops/pull/1220) ("Cut required
  Windows CI from Blacksmith to WarpBuild Azure BYOC") is **not merged** and
  has been closed/reopened several times (Albert once closed to reset a stuck
  concurrency group). Latest checks on that branch **failed broadly**:
  `doc-safety`; `linux-offline-shard` (2) and (4); **all**
  `windows-offline-section` (1–8); `windows-reviewer-fallback-codex/grok`;
  `verification-closure`. Diagnose before any merge.
- Open PR [#1193](https://github.com/popcre/ai-devops/pull/1193)
  (`mimo/runner-pool-github-envy-warpbuild`) prefers GitHub+ENVY then
  WarpBuild. Do **not** let it violate Albert's two rules (WarpBuild is the
  target cost lane; Blacksmith stays until WarpBuild is fully up).
- Background workers `general-1` (cancelled repeatedly) and `general-2` were
  dispatched for this cut-over. If a worker is still running, it may continue
  only the cut-over; wrap-up freeze forbids new scope.

## 4. Failed or incomplete attempts

- Multi-hour queued canary runs: WarpBuild cycled `wb-*` VMs (cloud-init OK,
  "Connected to GitHub" / "Listening for Jobs") but jobs stayed queued until
  Default runner group allowed public repos.
- PATCH runner storage to 256 GB returned 200 but stayed 150 GB.
- `az vm run-command` captures can be preempted; use a tiny log-tail script
  immediately (VMs die in ~40s after failed pickup).
- Cut-over PR CI failed (list in §3). Not diagnosed to root cause before
  wrap-up.
- Subagent `general-1` was cancelled/failed multiple times (process restarts).
  Work resumed via `general-2`. Do not assume either finished.

## 5. Findings that affect the implementation

- **Public-repo runner group flag is mandatory** for BYOC runners here.
- Full required suite on Server 2022 / 4-vCPU / 150 GB is **unproven**. Only
  the tooling canary has passed on WarpBuild.
- Azure `standardDASv4Family` quota is ~10 vCPU (2–3 concurrent VMs). Parallel
  Windows sections will queue; timeouts start at job start.
- Check **names** must stay stable (matrix keeps lane id `blacksmith` even when
  `runs_on` changes) or required gates break.
- Manual escape hatch: `windows-offline-blacksmith.yml` must remain usable.
- Oracle subscription (Teams bot) stays frozen. Dedicated CI subscription only.

## 6. Exact next steps and gates

1. Read this file and `docs/warpbuild-azure-byoc.md`. Do not re-derive the
   canary or the public runner-group fix.
2. Diagnose the failed checks on `mimo/warpbuild-required-cutover` (especially
   all `windows-offline-section` 1–8 and `linux-offline-shard` 2/4). Get the
   real log reason — do not guess OS vs quota vs labels.
3. Adjust the cut-over so required Windows **prefers WarpBuild** when available
   and **keeps Blacksmith as a live fallback** (owner rule). Fail closed if
   neither can run tests. Never skip coverage.
4. Fix `doc-safety` on that PR.
5. Focused offline tests (`tests/test-workflow-policy.sh`, runner-router tests).
6. Independent exact-head APPROVE. Reopen #1220 or open a clean PR on the same
   branch. `bin/ai-pr-wait`. Merge via queue. You merge; Albert does not.
7. After merge, one real required Windows verify must go green (WarpBuild
   preferred; Blacksmith fallback OK while WarpBuild is not fully up). Comment
   the green job URL on #961 (non-orchestrator). Signature above.
8. Only when WarpBuild carries the full suite reliably may Blacksmith be
   considered for reduction — and **only with a fresh owner decision**. Default
   is leave Blacksmith on.

## 7. Constraints and safety

- Public repo: no secrets, subscription GUIDs, API keys, signed vendor URLs.
- Canonical checkout is landing-only. Branch + PR + queue; `bin/ai-gh`.
- Independent review before merging the cut-over. Infrastructure beyond the
  already-approved stack/runner needs review.
- One unproven live outcome per session for required-CI proof.
- **Do not turn Blacksmith off** (owner, 2026-10-01).

## 8. Access and environment

- Origin: <https://github.com/popcre/ai-devops>; machine edge-dev (Windows).
- Worktree for cut-over: `C:/repos/ai-devops/.ai/worktrees/warpbuild-required-cutover`
  branch `mimo/warpbuild-required-cutover`. KEEP until merged or explicitly
  abandoned — it holds unmerged work.
- Azure CLI on this machine was authenticated as the dedicated CI subscription
  owner; recheck `az account show` live.
- WarpBuild API key: 1Password `vibe_coding` /
  `7xlkdojgsymtifrqwgnntjaqk4` / `credential`. `op run` only.
- Git Bash: `"C:\Program Files\Git\bin\bash.exe" -lc "..."`.
- Docs: [`docs/warpbuild-azure-byoc.md`](../docs/warpbuild-azure-byoc.md),
  [`docs/development.md`](../docs/development.md),
  [`docs/task-router.md`](../docs/task-router.md), `AGENTS.md` router row.
- Older handoff `HANDOFF.d/2026-09-28T1125Z-edge-dev3-codex-warpbuild-azure-byoc.md`
  is historical. Do not edit it.

## 9. Open questions and risks

- Why did **all** Windows sections fail on the cut-over branch in ~7–8 minutes?
  Unresolved. Could be WarpBuild pickup, win-2022 tests, 150 GB disk, quota, or
  labels — **verify from logs**.
- Is 150 GB enough for the full suite? Unproven.
- PR #1193 vs #1220 routing conflict — must be reconciled to Albert's rules.
- Cost savings not measured on invoices yet.

## 10. STALE sibling handoffs (issue already CLOSED — do not edit; list only)

Checked 2026-09-30 via `bin/ai-gh issue view`. Owner is the agent field in each
filename. Count is not a warning.

| Issue | Handoff |
|---|---|
| 131 | `2026-08-27T1939Z-edge-dev-codex-ai-devops-work-claims-plan.md` |
| 159 | `2026-08-28T1858Z-edge-dev-codex-repo-throughput-restructure.md` |
| 159 | `2026-09-10T1242Z-edge-dev-codex-repo-throughput-159.md` |
| 159 | `2026-09-11T0441Z-edge-dev-codex-reviewer-hierarchy-159.md` |
| 159 | `2026-09-11T1152Z-edge-dev-codex-throughput-reviewer-closeout.md` |
| 159 | `2026-09-14T1452Z-edge-dev-codex-reviewer-programme-after-397.md` |
| 159 | `2026-09-14T1502Z-edge-dev-codex-post-closeout-addendum.md` |
| 159 | `2026-09-14T1653Z-edge-dev-codex-reviewer-sequence-blockers.md` |
| 159 | `2026-09-14T2133Z-edge-dev-codex-reviewer-acceptance-continuation.md` |
| 159 | `2026-09-15T1137Z-edge-dev-codex-reviewer-programme-continuation.md` |
| 337 | `2026-09-08T1957Z-edge-dev-codex-reviewer-reliability-plan.md` |
| 608 | `2026-09-18T1606Z-edge-dev-kimi-review-packet-race-plan.md` |
| 634 | `2026-09-23T0106Z-edge-dev-codex-issue-634-stale-session.md` |
| 707 | `2026-09-23T1803Z-edge-dev-claude-tool-skill-scoping-plan.md` |
| 711 | `2026-09-25T1720Z-edge-dev-zcode-agent-self-cleanup-phase4.md` |
| 758 | `2026-09-23T1856Z-edge-dev-mimo-client-integration.md` |
| 816 | `2026-09-25T0312Z-edge-dev-zcode-pr666-reconciliation-handoff.md` |
| 816 | `2026-09-25T1715Z-edge-dev-mimo-cut-unneeded-github-traffic.md` |
| 852 | `2026-09-25T1728Z-edge-dev3-claude-deepseek-windows-live-proof.md` |
| 903 | `2026-09-28T0250Z-edge-dev3-codex-agent-evidence-jj-plan.md` |
| 903 | `2026-09-28T1136Z-edge-dev3-codex-agent-evidence-903-wrapup.md` |
| 1061 | `2026-09-30T1226Z-edge-dev-mimo-coord-del-residuals.md` |
| 1061 | `2026-09-30T1431Z-edge-dev-mimo-coord-del-residuals-closeout.md` |

## Self-audit

1. **Brand-new developer, no session context?** Yes — §§1–3 give product, owner
   rules, what is proven (canary URL) and what is not (cut-over). §6 is ordered
   with gates. §8 has paths and worktree. Evidence: every step has a named
   artifact (PR, branch, job URL, doc path).
2. **As effective as this session?** Yes — §4 records stuck-queue diagnosis,
   disk PATCH failure, run-command races, failed cut-over checks, and cancelled
   workers so the successor does not rediscover them. §5 records public
   runner-group trap, quota, stable check names, and the Blacksmith rule.
3. **Every material detail?** Yes — background (§1–2), outcome (§3), failures
   (§4), constraints (§7), risks (§9), exact next actions (§6), verification
   evidence (canary URL in §3). No silent pending work outside §3/§6/§9.
