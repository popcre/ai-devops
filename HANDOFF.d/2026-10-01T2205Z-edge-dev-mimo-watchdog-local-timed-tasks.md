---
issue: null
status: OPEN
owner: mimo/watchdog-local-timed-tasks
---

# HANDOFF — Blacksmith cost cut + watchdog duty pool (session close)

Machine: edge-dev · Agent: mimo · Written: 2026-10-02 (wrap-up)
GitHub signature: `Posted by MiMo chat ses_ffe5f06a5eb68ffeJ09D0qCZjG on edge-dev`

## 0. ⚠️ BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

- **Already decided (do not re-ask):** Stop paying Blacksmith for CI/watchdogs;
  everyday checks use free GitHub-hosted (public repo); abandoned PR pushes must
  not start the expensive matrix (90s settle); routine watchdogs become local
  timed tasks with **watchdog duty pool** rotation on edge-dev / edge-dev3 /
  hetz; free Actions only as backup. Albert 2026-10-01/02 chat.
- **Still his:** nothing required to land PR #1193 or implement the plan.
- **Not Albert's technical call:** conflict resolution on #1193, claim/lease
  design details, Task Scheduler/crontab registration. Never ask him to approve
  technical actions.

## 1. What this application is

`popcre/ai-devops` — public AI workflow recovery toolkit (not a product app).
CI is GitHub Actions. Paid Blacksmith runners had been the default since
2026-09-23. This session cut that cost path and designed alarm timers that do
not need Actions.

## 2. What we set out to do this session, and why

Albert spent ~$1000 on Blacksmith in two weeks, then turned Blacksmith off and
work jammed (labels still named Blacksmith; free runners never picked jobs up).
He asked how to cut runner spend, stop abandoned-push/watchdog cost, then how
watchdogs can be plain timed tasks with automatic rotation when PCs are down.

## 3. Current state — what is true right now

| Outcome | State | Artifact |
|---|---|---|
| Cost diagnosis (Windows Blacksmith bulk; public repo = free hosted) | Done (analysis) | This handoff §5 |
| Free-runner + ENVY + WarpBuild pool, drop Blacksmith | **PR #1193 OPEN** — `verification-closure` was green, then **merge conflicts** with `origin/main` (verify.yml, routing.json, development.md, edge-dev3-rdp doc, test-ci-runner-router.sh, test-workflow-policy.sh, runner-router.cjs) | https://github.com/popcre/ai-devops/pull/1193 branch `mimo/runner-pool-github-envy-warpbuild` worktree `C:\repos\ai-devops-wt-runner-pool` |
| Abandoned-push settle (90s quiet window on PRs) | On PR #1193 (commit `7c6cc86a`); **not on main until #1193 lands** | Same PR; `push-settle` job proved green on that PR run |
| Implementation plan (local timed tasks + failover) | **Landed** | `plan_watchdog-local-timed-tasks.md` → PR #1232 merge `9a5b7bc8` |
| Multi-host rotation in plan | **Landed** | PR #1233 merge `1fd20262` |
| **Watchdog duty pool** runbook (add a machine, claim rules) | **Landed** | `docs/watchdog-duty-pool.md` → PR #1234 merge `0d72a002` |
| AGENTS.md router + deployment.md pointer | **Landed** | same commits |
| Claim/tick tools + installers (plan P0–P5) | **Not started** | Plan STATUS all ⬜ open |

## 4. Everything we tried that did NOT work

- **`bin/ai-gh.cmd` / bare `bash` on this host** — hit WSL (“no installed
  distributions”) or “path not found”. Use Git Bash
  `C:\Program Files\Git\bin\bash.exe` explicitly for toolkit scripts.
- **Turning Blacksmith off without changing `runs-on` labels** — jobs stayed
  queued on `blacksmith-*`; free runners never match those labels. Fix is #1193.
- **Admin-merge PR #1193** — `GraphQL: Pull Request has merge conflicts`. Merge
  aborted cleanly (`git merge --abort`); worktree left clean.
- **First plan draft pinned one host (`run_on_host`)** — rejected after Albert
  said PCs have poor uptime; replaced by claim/lease across three hosts.

## 5. Root causes and key findings

1. Cost is mostly **Windows Blacksmith minutes** (8 sections + reviewer
   fallbacks, often 8–50 min each) plus **cancelled PR re-runs** and
   **windows-queue-watchdog on every verify** (huge run count).
2. Public `popcre/ai-devops` → GitHub-hosted runners are **free**; they were
   abandoned for speed (owner 2026-09-23) and re-adopted for cost (2026-10-01).
3. GitHub `schedule:` is unreliable here (`stuck-work-watchdog.yml` header) —
   local timers are the right primary for alarms.
4. Single-host pin goes silent when the PC sleeps; failover needs a shared
   claim (standing GitHub issue marker via `ai-gh`).

## 6. Exact next steps

1. **Land PR #1193** (highest value; unsticks free CI):
   - From worktree `C:\repos\ai-devops-wt-runner-pool` (or a fresh worktree of
     `mimo/runner-pool-github-envy-warpbuild`):
     `git fetch origin main && git merge origin/main`
   - Resolve the seven conflicted files (keep free-runner labels + push-settle;
     drop Blacksmith; keep tests consistent with `tests/test-workflow-policy.sh`
     / `tests/test-ci-runner-router.sh`).
   - Focused tests: `bash tests/test-workflow-policy.sh`,
     `bash tests/test-ci-runner-router.sh` (via Git Bash).
   - Push, wait on `verification-closure`, merge PR #1193, confirm on
     `origin/main`.
2. **Implement plan P0–P5** from `plan_watchdog-local-timed-tasks.md` STATUS
   (P0 harness → P0b claim → watches → backup Actions → install + **two-host
   failover drill**). Keep `docs/watchdog-duty-pool.md` §7 current.
3. **Name an owner issue** for the remaining workstream when claiming it
   (this file’s `issue:` is null — open one at claim time; do not bundle).

**Verify success:** #1193 merged on `main` with no `blacksmith-` labels in
watchdog/verify paths; plan STATUS rows cite real artifacts; failover drill
logs show claim/skip from two hosts.

## 7. Constraints and gotchas in force

- Branch + PR + merge queue; never push `main`; `git var GIT_COMMITTER_IDENT`
  must be Albert’s identity; stage only task-owned files.
- Canonical checkout landing-only; use a worktree.
- All GitHub calls via `bin/ai-gh`; bounded waits only.
- Secrets: 1Password `vibe_coding` only; never argv/logs/commits.
- Never recommend or auto-dispatch Blacksmith for alarms or default CI.
- Independent review if the change set hits reviewer safety / routing rules
  (`ai-task-gates`); redeclare class rather than bypass.
- Times in human output: EST. Public repo — no secrets/private transcripts.

## 8. Access and environment

- Hosts: edge-dev (Windows, this machine), edge-dev3 (`ssh -i ~/.ssh/916-alien
  ahazan@edge-dev3`), hetz (`ssh vps2-direct`, user `ai`).
- Worktrees: `C:\repos\ai-devops-wt-runner-pool` (keep — owns #1193),
  `C:\repos\ai-devops-wt-watchdog-local` (docs landed; safe to retire after
  confirming main).
- `gh`/`ai-gh` as `u2giants` on edge-dev. No new credentials this session.

## 9. Open questions and risks

- #1193 conflicts may also touch PR #1220 (WarpBuild cut-over) — re-read that
  branch’s intent before resolving so the two don’t undo each other.
- windows-reviewer-preferred failed once on #1193 while fallbacks +
  verification-closure passed; confirm policy still accepts that shape after
  conflict resolution.
- hetz install of local-watch may stay crontab-only (production habits) — plan
  §8 OPEN item.

---

## Self-audit (handoff-standard)

1. **Cold start?** Yes — §1–§3 name repo, PRs, paths, and what is on main vs
   only on #1193.
2. **As effective as me?** Yes — §4 failures, §5 causes, §6 exact next commands
   and verify lines.
3. **Failures included?** Yes — §4 (WSL bash, label mismatch, merge conflicts,
   single-host pin).
4. **Concrete next steps + verify?** Yes — §6.
5. **Terms/paths explained?** Yes — duty pool, claim/lease, worktrees, host
   nicknames, PR/merge SHAs.
6. **§0 sweep?** Yes — cost/failover decisions locked; no technical approval
   requested from Albert.

**Synthesis:** A brand-new developer can resolve #1193 and then implement P0–P5
using only this file + `plan_watchdog-local-timed-tasks.md` +
`docs/watchdog-duty-pool.md`. Detail level matches this session’s knowledge.
Evidence: §3 artifacts, §6 verification, links to landed commits `9a5b7bc8`,
`1fd20262`, `0d72a002`.
