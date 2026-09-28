# HANDOFF — cut unneeded GitHub traffic plan (2026-09-25T17:15Z, edge-dev/mimo)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

**BLOCKING** — none. The plan can be executed without Albert.

**RECOVERABLE** — none. Implementation judgment calls are labeled OPEN in the
plan §8 with criteria; a wrong guess is a normal code fix.

**NOT PART OF THIS WORK, AND NOBODY IS ON IT**
- Parent plan STATUS was stale on #809 (alarm cache). This session recorded the
  fix commit but the *programme* acceptance for P5 is still open — if Albert
  wants a single "are we done with rate limits?" answer, that is still P8, not
  this plan. Recommendation: leave P8 with the programme owner.
- Many stale worktrees sit under `.claude/worktrees` and `C:/repos/ai-devops-*`.
  Recommendation: a later `cleanup-worktree` session; **do not** delete
  `p5-rest-savings-mimo` (it holds uncommitted S1 code).

**Already settled — do NOT re-ask**
- 2026-09-25: Albert asked for a plan to fix the unneeded GitHub traffic; write
  the plan (this session). He did **not** authorize implementing S1–S4 here.
- Parent programme (#658) remains the owner of measurement and acceptance.

## 1. What this application is

`popcre/ai-devops` is Albert's public multi-model AI recovery toolkit (scripts,
installers, skills, CI). Not an app or database. Deployment = installation onto
machines. GitHub is source of truth. BlockerWatch is a 10-minute scheduled
watcher (wakes / propagate / unowned-blocker alarm / dependency links).
`bin/ai-gh` is the paced GitHub CLI gate. Hosts: edge-dev (propagation owner),
ALBT16, 916, hetz.

## 2. What we set out to do this session, and why

Albert: still hitting GitHub rate limits; what do we send that is not needed?
Then: write a plan to fix all of that. Goal of the plan: remove unneeded
GitHub demand (BlockerWatch per-item REST on top of the snapshot, duplicate PR
waiters, direct `gh` bypasses) without losing any safety, wake, alarm, link,
or merge behavior.

Parent: [`plan_github-request-reduction.md`](../plan_github-request-reduction.md)
(#658). This session's deliverable is the execution plan, not the fixes.

## 3. Current state — what is true right now

**Works / done**
- P1 telemetry live on edge-dev (PR #663).
- BlockerWatch #806 (shared open-issue read), #812 (PR `depends_on` skip),
  #809/#853 (file-based alarm cache + node budget) are on `origin/main`.
- Measurement: BlockerWatch ≈ 95% of managed traffic (parent STATUS 2026-09-24).

**Half-done (do not lose)**
- Worktree `C:/repos/ai-devops/.claude/worktrees/p5-rest-savings-mimo`, branch
  `mimo/p5-rest-savings-snapshot`, **uncommitted** changes to
  `bin/ai-blocker-watch` (+~207/−28) and new
  `tests/test-ai-blocker-watch-replay.sh`. Implements snapshot index
  (`SNAPIDX`/`SNAPBB`), `snapshot_dependents_of`, `snapshot_open_hit`,
  REST fallbacks in `propagate`/`wake`/`link`. That is Phase S1 of the plan.

**Not started**
- S2 waiter sharing (P4), S3 direct-caller routing (P3), S4 after-sample +
  parent STATUS de-stale.

**This session's artifacts (branch `mimo/cut-unneeded-github-traffic-plan`)**
- [`plan_cut-unneeded-github-traffic.md`](../plan_cut-unneeded-github-traffic.md)
- This handoff
- Parent plan STATUS row for P5 marked for de-stale in S4 (note only)
- AGENTS.md task-router line pointing at the execution plan

Committed/pushed as a documentation PR against `origin/main` when this handoff
was written. Update the SHA after merge.

## 4. Everything we tried that did NOT work

- `bash -lc` (WSL) is not installed on edge-dev — Git Bash must be
  `C:\Program Files\Git\bin\bash.exe`.
- PowerShell `date -u` is not valid (`-u` is ambiguous) — use
  `Get-Date -Format ... -AsUTC` or Git Bash `date -u`.
- `bin/ai-task-gates` and `bin/ai-gh` `.cmd` shims sometimes print
  "The system cannot find the path specified" when invoked without going
  through their installed `C:\Users\ahazan\.local\bin\*.cmd` or Git Bash.
  Retry via the absolute `.cmd` path or `bash.exe -lc`.
- Parallel tool calls get cancelled if one fails; sequence shell probes.

## 5. Root causes and key findings

- Remaining waste is **per-item REST on top of data the open-issue snapshot
  already has**: `propagate` `dependencies/blocking` per closed issue
  (`bin/ai-blocker-watch:386`), `wake` issue probe every 10 minutes
  (`:445`), `link` id + existing-link REST (`:149–151`).
- Alarm `ISSUE_Q` per unowned candidate is **needed** (fresh state before a
  comment). Only *repeats* are waste (#809 cache).
- `j="$(issue_json …)"` is a subshell — shell-variable caches die there.
  Keep file-based `$ALARM_TICK` cache (#853).
- Snapshot miss ≠ closed (PRs, out-of-set repos, pagination). Always REST
  fallback.
- #812: a PR named in `depends_on` used to fail the whole links scan every 10
  minutes for days. Never fail the scan on one bad fence.
- Parent STATUS still said "#809 remaining" after #853 landed — plans rot
  unless the landing session updates them.

## 6. Exact next steps

1. Fresh session: read `plan_cut-unneeded-github-traffic.md` **entirely**,
   especially STATUS and §5 WIP. Claim **one** row.
2. S1 first: fresh worktree from `origin/main`, re-apply or continue the
   `p5-rest-savings-mimo` hunks (do not `reset` that worktree). Gate: replay +
   tick tests, live edge-dev tick call-count evidence.
3. Then S2 (waiter single-flight), then S3 (route direct `gh` through
   `ai-gh` or document an allowlist exception), then S4 (after-sample +
   de-stale parent STATUS; cite `5f8cf19b` for #809).
4. One unproven live outcome per session; leftover-proof issue if needed.
5. Update plan STATUS when a step lands.

**You'll know the plan is consumed when** the first implementation session can
start S1 with no questions.

## 7. Constraints and gotchas in force

See plan §11. Summarized: worktree-only edits; branch+PR+queue; `ai-gh` for
every GitHub call; no open-ended `gh` loops; one live outcome per session;
never rewrite root `HANDOFF.md`; sign GitHub posts
`Posted by MiMo chat <id> on <machine>`; secrets only in 1Password
`vibe_coding`; times in EST; serialize with other BlockerWatch editors.

## 8. Access and environment

- Machine: `edge-dev`. Native shell PowerShell 7; Git Bash at
  `C:\Program Files\Git\bin\bash.exe`.
- `gh` authenticated as Albert. Prefer `bin/ai-gh`.
- 1Password vault `vibe_coding` (names only).
- Safe dry-run: `bin/ai-blocker-watch tick --dry-run`.
- WIP worktree path in §3 — read-only inspect first.

## 9. Open questions and risks

- S1 must reconcile the WIP with current `origin/main` (it is ~29 commits
  behind). If hunks conflict, reimplement the same symbols/fallback rules.
- S3 may keep dispatch/privacy unwrapped **if documented** (parent P1 said
  they were unwrapped by design). Decide in S3; do not silently wrap.
- Until S4's after-sample exists, any "we fixed the rate limits" claim is
  premature. Parent P8 acceptance is out of scope here.
