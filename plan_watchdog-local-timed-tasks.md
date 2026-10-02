# IMPLEMENTATION PLAN — watchdogs as local timed tasks (2026-10-01)

Handoff registration: [HANDOFF.d/2026-10-01T2205Z-edge-dev-mimo-watchdog-local-timed-tasks.md](HANDOFF.d/2026-10-01T2205Z-edge-dev-mimo-watchdog-local-timed-tasks.md)

## STATUS — read first

| Step | One independently accepted outcome | State | Evidence when done |
|---|---|---|---|
| P0 | Shared local-watch harness (`schedule` / `tick` / log / lock) reused, not copied | ⬜ open | |
| P1 | Runner-pool watch as a local timed task on edge-dev | ⬜ open | |
| P2 | Windows queue-slow watch as a local timed task (replaces Action-on-every-verify) | ⬜ open | |
| P3 | Membership-drift + merge-queue-drift as local timed tasks | ⬜ open | |
| P4 | Free GitHub Actions kept only as backup; paid Blacksmith gone from watchdogs | ⬜ open | |
| P5 | Installer + docs updated; live proof on edge-dev | ⬜ open | |

**Where a fresh session starts:** P0. Do not open P1 until P0’s verification gate is green. Re-read this STATUS table before each phase; the plan is stale the moment a row turns done.

---

## 1. The ultimate goal — what we are actually trying to achieve

Albert pays for CI runners. Watchdogs are small alarm scripts — they should not sit on paid machines, and they should not even need GitHub Actions when a computer he already owns can run them on a timer.

When this is done: every routine watchdog that used to burn a GitHub Actions job (including paid Blacksmith) runs as a plain timed task on **edge-dev** (this machine). GitHub’s **free** hosted runners remain only as a backup alarm if edge-dev is asleep, offline, or the local tick stops reporting. The expensive path is gone.

If a step below conflicts with this goal, the goal wins — stop and flag it.

## 2. What this application is

`popcre/ai-devops` is Albert’s public recovery toolkit for a multi-model AI workflow (not a product app). GitHub: <https://github.com/popcre/ai-devops>, default branch `main` (protected, merge queue). Local canonical checkout: `C:\repos\ai-devops` (landing only). This plan is executed from a worktree.

Watchdogs today are GitHub Actions workflows under `.github/workflows/`. Their job is to notice stuck queues, a dead Windows runner pool, or a registry/allocator mismatch, and leave a loud alarm (issue comment or failing non-required check). They do not merge code.

This machine is **edge-dev** (Windows). It already runs Task Scheduler jobs for `ai-blocker-watch tick`, `ai-reviewer-start-watch tick`, and `ai-reap-shared-db-worktrees` — that pattern is the one to copy.

## 3. What triggered this work

On 2026-10-01 Albert reported about **$1000 of Blacksmith spend in two weeks**. He then turned Blacksmith off; jobs whose labels still named Blacksmith sat queued and agents waited. A follow-up question was why a watchdog needs a paid runner at all. Answer: it does not. He asked for a plan to make those small scripts **plain timed tasks on this machine**, with **GitHub’s free machines as a backup**.

Related live work (do not re-derive): [PR #1193](https://github.com/popcre/ai-devops/pull/1193) already switches verify + remaining Action watchdogs from Blacksmith to free GitHub-hosted / ENVY / WarpBuild. This plan **complements** that PR: after #1193, watchdog Actions are free but still burn Actions minutes and still depend on GitHub’s schedule reliability (GitHub has dropped scheduled runs on this repo — see `stuck-work-watchdog.yml` header).

## 4. Scope — in and out

**In scope**
- The four Action-based watchdog workflows listed in §5.
- A small shared local-watch harness (or reuse of an existing one) so each watchdog gets `schedule` / `tick` / log / lock like `ai-blocker-watch`.
- Task Scheduler registration on edge-dev via the existing installer path.
- Free GitHub-hosted Actions kept as **backup only** (lower frequency and/or heartbeat-stale trigger).
- Tests for the new/changed `bin/` tools and schedule registration.

**NOT in this plan**
- Changing `verify.yml` required CI, merge-queue rules, or runner pool for the main test matrix (owned by PR #1193 / WarpBuild #961).
- Removing self-hosted Windows capacity or WarpBuild BYOC.
- BlockerWatch itself (`ai-blocker-watch`) except as a pattern to copy and, if needed, a tick to piggyback on.
- shared-db schema or allocator behavior.
- Replacing `stuck-work-watchdog`’s business logic (already free + already driven from local tick).
- Any new paid runner, vendor, or cloud resource.

## 5. Current state of the code

| Component | State | Anchor |
|---|---|---|
| `windows-queue-watchdog.yml` | Runs as Action on **every** `verify` `workflow_run` `in_progress`. Job `if:` keeps it to pull_request; merge_group runs are created then skipped. Historically ~87% of all Action run count. Suggests routing to **Blacksmith** (stale after #1193). `runs-on: blacksmith-4vcpu-ubuntu-2404` on current `main`. | `.github/workflows/windows-queue-watchdog.yml:12–35, 87–88` |
| `runner-pool-watchdog.yml` | Hourly cron `25 * * * *`. Fails if zero online `ai-devops-windows-qualified` runners. Needs `RUNNER_POOL_READ_TOKEN` (Administration: Read-only) because `GITHUB_TOKEN` cannot list runners. | `.github/workflows/runner-pool-watchdog.yml:19–74` |
| `reviewer-membership-drift.yml` | Cron `17 */6 * * *` + PR paths. Runs `tests/test-ai-reviewer-membership-drift.sh` then `node bin/ai-reviewer-membership-drift`. | `.github/workflows/reviewer-membership-drift.yml:7–31` |
| `merge-queue-drift.yml` | Cron `23 7 * * *` + PR paths. Runs `tests/test-ai-merge-queue-drift.sh` and `bin/ai-merge-queue-drift --offline`. Live ruleset job dormant unless `MERGE_QUEUE_DRIFT_LIVE=enabled`. | `.github/workflows/merge-queue-drift.yml:14–49` |
| `stuck-work-watchdog.yml` | **Already free** (`ubuntu-latest`) and **already scheduled from local** `ai-blocker-watch tick` on `fixer_on_host` — GitHub cron is deliberately unused because GitHub dropped scheduled runs. This is the target architecture. | `.github/workflows/stuck-work-watchdog.yml:15–21, 41` |
| Local schedule pattern | Each tool has `schedule` / `tick`, Task Scheduler via `schtasks /F`, log under `~/.ai-devops/<tool>/`, host selected by config JSON. Installer wires them. | `bin/ai-blocker-watch`, `bin/ai-reviewer-start-watch`, `bin/ai-reap-shared-db-worktrees`; `install-ai-devops-windows.ps1:1207–1271`; `docs/deployment.md:87–105` |
| Drift CLIs already exist | `bin/ai-merge-queue-drift`, `bin/ai-reviewer-membership-drift` — **reuse**, do not fork. | `bin/ai-merge-queue-drift`, `bin/ai-reviewer-membership-drift` |
| Host pinning example | `config/reviewer-start-watch.json` `run_on_host`; `config/blocker-watch.json` `propagate_on_host` / `stuck_watchdog_*`. | those config files |

## 6. Key findings and root cause

1. **Watchdogs do not need compute scale.** They poll APIs and write a comment. A 4-vCPU Blacksmith (or even a free Actions) job is wasted capacity. The cost driver is *volume* (queue watch on every verify) and *label* (Blacksmith).
2. **GitHub `schedule:` is unreliable on this repo.** `stuck-work-watchdog.yml:16–21` records hourly crons firing every 4–7 hours and the first four 15-minute slots after merge never running. A local timer is strictly more reliable than Actions cron for the primary alarm.
3. **Event-driven watch ≠ must stay in Actions.** `windows-queue-watchdog` looks like it must be a `workflow_run` hook, but its real job is: “for each in-progress PR verify, if Windows sections are still queued after ~3 minutes, comment once.” A local 1–2 minute tick can do the same list+comment via `ai-gh`, and can cancel/ignore non-PR runs without creating an Actions run at all.
4. **Same-machine pattern is already proven.** `ai-reviewer-start-watch` every 2 minutes and `ai-blocker-watch tick` every 10 minutes run unattended on edge-dev with Task Scheduler, a tick lock, and `tick.log` (`docs/task-router.md` reviewer-start-watch row; `tests/verification/github-requests/s1-edge-dev-2026-09-27.md`).
5. **Local primary + Actions backup matches `stuck-work-watchdog`.** That workflow is only a manual/backup execution surface; the cadence lives on the machine.

## 7. Approaches considered and REJECTED, and why

| Approach | Why rejected |
|---|---|
| Keep watchdogs on Actions but only `ubuntu-latest` / free | Solves **money**, not **reliability** or Actions-minute noise. Still dies when GitHub drops scheduled runs. Acceptable as *backup* only (that is P4), not as primary. |
| One mega-watchdog Action with path filters | Still paid/volume problem; path filters do not help a `workflow_run` on every verify. |
| Put watchdog jobs on the self-hosted Windows runner | The pool watchdog would queue on the pool it is testing (`runner-pool-watchdog.yml:4–12` already explains this). Also serializes with real CI. |
| Rewrite watchdog logic in a new language/service (Node daemon, etc.) | Violates reuse; the CLIs and tick pattern already exist. |
| Fold every watch into one `ai-blocker-watch tick` without a shared harness | BlockerWatch is a different ownership/safety surface; bolting five unrelated alarms on it makes failures impossible to attribute. Prefer **one shared local-watch helper** + thin per-tool ticks (P0). |
| Delete the watchdogs | They close real blind spots (dead Windows pool silently drops coverage; merge-queue drift ejects PRs for hours). Goal is *move*, not *remove*. |
| Ask Albert to keep a PC on / RDP in to click things | Standing rule: AI runs the manual steps. Task Scheduler + login-as-user (S4U where appropriate) is the supported path already used on this machine. |

## 8. Design decisions already made (dated)

| Decision | Status | Reason |
|---|---|---|
| Primary runtime = **Task Scheduler on edge-dev** (2026-10-01, Albert: “plain timed tasks on this machine”) | **LOCKED** | Owner request; matches existing machine pattern. |
| Backup runtime = **GitHub free hosted** (`ubuntu-24.04` / `ubuntu-latest`), never Blacksmith (2026-10-01) | **LOCKED** | Owner cost rule; public repo free tier. |
| Reuse `bin/ai-merge-queue-drift` and `bin/ai-reviewer-membership-drift` rather than reimplement (2026-10-01) | **LOCKED** | Repository reuse rule. |
| One shared local-watch harness (schedule/tick/lock/log) instead of five copy-pasted Task Scheduler scripts (2026-10-01) | **LOCKED** | Harness consolidation (#167 class); copy #9 trap in reviewer-wrapper audits. |
| `windows-queue-watchdog` messaging must stop recommending Blacksmith (2026-10-01) | **LOCKED** | Blacksmith is out of the pool (PR #1193 / owner cost direction). |
| Which exact host name string goes in the new host-pin config (`edge-dev` vs `COMPUTERNAME` value) | **OPEN** | Implementer records the live `COMPUTERNAME` / existing config convention (`reviewer-start-watch.json` `run_on_host`) and matches it. |
| Backup Actions cadence (daily vs weekly vs heartbeat-stale-only) | **OPEN** | Prefer heartbeat-stale-only + weekly smoke; justify in the PR if different. |
| Whether queue-slow tick rides `ai-blocker-watch tick` or its own 2-minute task | **OPEN** | Criteria: if both can share one lock/log without cross-failures, piggyback is fine; else own task. |

## 9. The plan — numbered, ordered steps

### Phase A — harness (P0)

**A1. Add or extend a shared local-watch helper** — target `tools/lib/local-watch.sh` (new) **or** extract the common `schedule`/`tick`/lock/log tail already duplicated in `bin/ai-blocker-watch` / `bin/ai-reviewer-start-watch`. Behavior when done: one place defines (a) Task Scheduler registration name `\ai-devops\<tool>`, (b) per-tick lock (see `docs/locks.md` tick lock style), (c) append-only `~/.ai-devops/<tool>/tick.log`, (d) non-zero tick exits that are *alarms* vs *skips*.  
**Depends on:** nothing.  
**Gate:** `tests/test-local-watch.sh` green (new); `bash tests/test-ai-blocker-watch.sh` and `tests/test-ai-reviewer-start-watch.sh` still green if those tools switch to the helper.

**A2. Define host-pin config** — `config/local-watch.json` with `run_on_host` (same idea as `config/reviewer-start-watch.json`). Only that host registers the tasks in the installer; other machines skip with a note.  
**Gate:** unit test asserts a non-host machine’s install test-mode output contains “skipped”.

### Phase B — move the cheap periodic watches (P1, P3)

**B1. `bin/ai-runner-pool-watch`** (new thin wrapper; body = the bash in `runner-pool-watchdog.yml:40–75`): commands `tick`, `schedule`, `check`. Uses `ai-gh` (never raw `gh`) and the same Administration:Read token resolution as today (1Password / env — never log the token). Hourly on the 25th minute. Failures append to tick.log **and** open/update one standing issue (same alarm surface as the Action).  
**Gate:** `tests/test-ai-runner-pool-watch.sh` (offline fixture roster: 0 online → alarm; 1 online → warning; 2+ → ok). Live: `ai-runner-pool-watch tick` on edge-dev returns 0 and the log line names the online count.

**B2. `bin/ai-reviewer-membership-drift schedule|tick`** — wrap the existing Node tool; tick runs the offline suite then the compare. Every 6 hours at minute 17 (keep the old minute to avoid colliding with other tasks).  
**Gate:** `schtasks /Query /TN \ai-devops\reviewer-membership-drift` shows the task; one manual tick matches the Action’s two steps.

**B3. `bin/ai-merge-queue-drift schedule|tick`** — wrap existing tool; daily at 07:23 machine-local (or 07:23 UTC with the EST label in the log — pick one and document it; prefer **America/New_York** for human-facing logs per standing rules).  
**Gate:** manual `tick` runs `tests/test-ai-merge-queue-drift.sh` + `ai-merge-queue-drift --offline` and logs pass/fail.

### Phase C — move the event-driven queue watch (P2)

**C1. `bin/ai-windows-queue-watch tick`** — every 2 minutes: list recent `verify` workflow runs for open PRs (`ai-gh api`), for each in-progress PR run list jobs, if `windows-offline-section*` still queued after 3 minutes and not already commented (`<!-- windows-queue-watchdog -->` marker), update/create that comment. **Never** suggest Blacksmith; suggest waiting on the free lane or telling an agent to investigate. Bounded: max N PRs per tick, no unbounded polls.  
**Gate:** `tests/test-ai-windows-queue-watch.sh` with fixture job JSON (all picked up → no comment; one queued >3m → one comment; second tick → no duplicate comment). Live: one tick on edge-dev against the real API, log only.

**C2. Stop the Action from firing on every verify.** After C1 is live and proven, change `.github/workflows/windows-queue-watchdog.yml` to **backup-only**: remove `workflow_run` trigger (or keep it but `if: false` behind a repo variable), leave `workflow_dispatch` + a weekly free-runner smoke that just re-runs the same `bin/ai-windows-queue-watch tick` logic. Update the header comment to say primary is the edge-dev timed task.  
**Gate:** no `windows-queue-watchdog` workflow_run runs for 24h after merge; one manual dispatch still green on `ubuntu-24.04`.

### Phase D — backup Actions + install (P4, P5)

**D1. Convert the other three workflows to backup-only on free runners** (`ubuntu-24.04`, never Blacksmith): keep `workflow_dispatch` + a **weekly** schedule that runs the same `bin/… tick` entry points. If `config/local-watch.json` heartbeat (`~/.ai-devops/<tool>/tick.log` mtime) is stale, the backup may run sooner — optional, OPEN.  
**Gate:** `grep blacksmith` under `.github/workflows/*watchdog*.yml` and `*drift*.yml` returns nothing; `tests/test-workflow-policy.sh` still green if it asserts runner labels (coordinate with PR #1193 if both land).

**D2. Installer wiring** — in `bin/install-ai-devops-windows.ps1` after the existing schedule blocks (`:1207–1271`), register each new tool’s `schedule` the same way (Git Bash path resolution included; test mode must not touch Task Scheduler). Optionally the Unix installer / `bin/setup-machine.ps1` if this repo still installs crontab there — **only if those files already schedule sibling tools**; do not invent a second pattern.  
**Gate:** `AI_DEVOPS_INSTALL_TEST_MODE=1` prints “not touching this computer's scheduled tasks” for each; a real install on edge-dev shows four new tasks under `\ai-devops\`.

**D3. Docs** — `docs/deployment.md` schedule list, `docs/task-router.md` a row for “routine watchdog / drift alarm”, AGENTS.md router row if a task type is missing. Strike Blacksmith wording from watchdog comments.  
**Gate:** `bin/ai-doc-reachability` (or the repo’s doc test) passes; no stale “route to Blacksmith” string in watchdog sources.

**D4. Live proof on edge-dev (required before any row is marked done)** — one successful manual tick per tool, Task Scheduler LastRunTime/LastTaskResult, tick.log lines, and (for B1) one synthetic alarm in a test-only mode or a dry-run issue comment path. Leave `- [ ] live proof` on the owner issue if a step is code-landed-but-unproved.  
**Gate:** screenshot or log excerpts attached to the owner issue; `schtasks /Query` for each name.

### Adversarial cases (trust boundary: GitHub API, tokens, comments)

| External input | Hostile case | Test that proves it |
|---|---|---|
| Runner roster JSON | 403 / missing token / empty runners / runner names with spaces | `tests/test-ai-runner-pool-watch.sh` fixtures |
| Workflow run list | Fork PRs, merge_group runs, cancelled runs, missing `pull_requests[]` | `tests/test-ai-windows-queue-watch.sh` fixtures (mirror `windows-queue-watchdog.yml:45–47`) |
| PR comments API | Existing marker comment, race two ticks, comment turned off on repo | unit: second tick does not create a second comment |
| `RUNNER_POOL_READ_TOKEN` | Token present but under-scoped; token in argv or log line | assert token never printed; `ai-gh` / env-only |
| Task Scheduler | Task already exists from old script; laptop sleeps mid-tick; two ticks overlap | lock file test; `schtasks /F` re-point test |
| Clock skew | tick uses UTC vs local; “3 minutes” uses wrong unit | fixture freezes time in unit tests |

## 10. Tests required

**New**
- `tests/test-local-watch.sh` — schedule/tick/lock/log helper.
- `tests/test-ai-runner-pool-watch.sh` — roster fixtures (0/1/2+ online).
- `tests/test-ai-windows-queue-watch.sh` — pickup delay, marker dedupe, non-PR skip.
- `tests/test-ai-reviewer-membership-drift-schedule.sh` (or extend existing `tests/test-ai-reviewer-membership-drift.sh`) — `schedule` idempotence + test-mode.
- `tests/test-ai-merge-queue-drift-schedule.sh` (or extend existing) — same.

**Must stay green**
- `bash tests/test-ai-merge-queue-drift.sh`
- `bash tests/test-ai-reviewer-membership-drift.sh`
- `bash tests/test-ai-blocker-watch.sh`
- `bash tests/test-ai-reviewer-start-watch.sh`
- `pwsh -NoProfile -File tests/test-install-ai-devops-windows.ps1` (test mode must still not touch tasks)
- `bash tests/test-workflow-policy.sh` if workflow files change (coordinate with PR #1193)

Run focused suites first, then the repository’s required local/CI suites per `docs/development.md`.

## 11. Constraints, standing rules, and gotchas in force

- Work on a branch + PR; never push to `main`. Merge queue decides. `git var GIT_COMMITTER_IDENT` must be Albert’s identity before commit.
- Canonical checkout is landing-only; implement from a worktree.
- Every GitHub call goes through `bin/ai-gh` (lock, spacing, budget). No bare `gh` in new tools.
- Bounded waits only; no open-ended `until gh …` loops.
- Secrets: 1Password vault `vibe_coding` via `op run` / env; never argv, logs, or commits. `RUNNER_POOL_READ_TOKEN` already exists as a repo secret for the Action — local use should come from the machine’s existing credential path (1Password item title only in docs).
- **Do not recommend or auto-dispatch Blacksmith** in any remaining copy.
- Task Scheduler: copy `install-ai-devops-windows.ps1` patterns (Git Bash preferred over WSL bash; test mode; `schtasks /F`). Do not replace OS binaries.
- Independent review is required before merge if this touches reviewer wrappers, evidence tools, safety tests, or installed routing rules (AGENTS.md). `ai-task-gates start --class` accordingly (`code` or escalate).
- One unproven outcome per session: if live proof is not finished, leave a checklist item on the **same** owner issue.
- Label times in human output as EST.

## 12. Access and environment

- Machine: **edge-dev** (Windows). Task Scheduler already hosts `\ai-devops\reviewer-start-watch` and blocker-watch / debris tasks.
- Repo: `popcre/ai-devops`, branch from `origin/main`, worktree e.g. `C:\repos\ai-devops-wt-watchdog-local`.
- CLIs: Git Bash at `C:\Program Files\Git\bin\bash.exe`, `pwsh` 7, `node`, `jq`, `bin/ai-gh`, `bin/ai-task-gates`.
- Auth: `gh`/`ai-gh` as `u2giants` on this machine (see existing keyring auth evidence in `tests/verification/github-requests/s1-edge-dev-2026-09-27.md`). Token for runner administration: 1Password vault `vibe_coding` (item for GitHub runner-admin read — **title only, never the value**). Repo secret name remains `RUNNER_POOL_READ_TOKEN` for the backup workflow.
- How to run: `bash tests/test-…sh` from the worktree; `AI_DEVOPS_INSTALL_TEST_MODE=1` for installer tests; `schtasks /Run /TN \ai-devops\<tool>` for one live tick; logs in `~/.ai-devops/<tool>/tick.log`.

## 13. Definition of done + risks and open questions

**Done when**
- [ ] P0–P5 STATUS rows each have artifact evidence (path, commit SHA, or `schtasks /Query` output).
- [ ] No watchdog/drift workflow on `main` uses Blacksmith labels.
- [ ] Four local tasks registered on edge-dev; four tools have green unit tests + one live tick each.
- [ ] Backup Actions are free-only and rare; primary cadence is local.
- [ ] PR merged through the queue; `origin/main` contains the commit.
- [ ] `docs/deployment.md` + task-router updated; no “route to Blacksmith” in watchdog sources.
- [ ] Owner issue checklist item `live proof` ticked or explicitly left with one named owner.

**Rollback:** delete/disable the new Task Scheduler tasks (`schtasks /Change /TN … /DISABLE` or installer remove), re-enable the Action triggers (revert the workflow commit). No data migration.

**Risks**
- edge-dev offline → primary alarm silent → backup Actions cover (by design). Document how to see “local heartbeat stale”.
- Token scope wrong → roster watch false-alarms; keep the existing 403 message text.
- Landing this while PR #1193 is open → workflow YAML conflicts; implementer should rebase on whichever merges first and re-run workflow policy tests.
- Over-commenting on PRs from the queue watch → keep the single marker + update-in-place behavior.

**Open questions (criteria in §8):** host-pin string, backup cadence, own task vs blocker-watch piggyback for queue watch.

---

## Self-audit (implementation-plan-writer Mode A)

1. **Could a brand-new AI session execute this without asking anything?** Yes — §2 names the app and machine; §5–§6 give file anchors and why Actions cron is untrustworthy; §9 steps name `tools/lib/local-watch.sh`, `bin/ai-runner-pool-watch`, `bin/ai-windows-queue-watch`, installer lines `install-ai-devops-windows.ps1:1207–1271`, and verification gates; §10–§12 give tests and auth locations. Gap found and fixed during draft: queue-watch is event-shaped — §6.3 and step C1/C2 convert it to a tick and then retire the `workflow_run` trigger so implementers do not leave both firing.
2. **Does it carry background, nuance, and rejected approaches?** Yes — §3 links the $1000/Blacksmith incident and PR #1193; §7 rejects free-Actions-only, self-hosted pool heartbeats, deleting watches, and mega-BlockerWatch; §8 locks owner decisions and labels open ones.
3. **Is the ultimate goal clear for judgment calls?** Yes — §1 is business English (“should not sit on paid machines”; free backup only) and ends with goal-wins. Backup cadence and host-pin remain open with criteria so a wrong step can be corrected toward the goal.

**Checklist:** 13 sections present; goal first; fresh-session executable; rejected approaches present; steps have files + gates; adversarial table for API/token/comment inputs; locked vs open labeled; out-of-scope explicit; tests named; terms defined; secrets by location; DoD includes commit/CI; handoff linked both ways.
