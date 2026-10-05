# IMPLEMENTATION PLAN — watchdogs as local timed tasks (2026-10-01)

Handoff registration: [HANDOFF.d/2026-10-01T2205Z-edge-dev-mimo-watchdog-local-timed-tasks.md](HANDOFF.d/2026-10-01T2205Z-edge-dev-mimo-watchdog-local-timed-tasks.md)

Operator / agent runbook (name, add-a-machine, claim rules): [`docs/watchdog-duty-pool.md`](docs/watchdog-duty-pool.md) — keep that contract in sync when a STATUS row turns done.

## STATUS — read first

| Step | One independently accepted outcome | State | Evidence when done |
|---|---|---|---|
| P0 | Shared local-watch harness (`schedule` / `tick` / log / lock) reused, not copied | ✅ done | `tools/lib/local-watch.sh`; `tests/test-local-watch-claim.sh` (lock/rotate) |
| P0b | Multi-host claim/lease helper (`ai-local-watch claim`) + `watch_hosts` config | ✅ done | `bin/ai-local-watch`; `config/local-watch.json`; claim tests 14/14 |
| P1 | Runner-pool watch as a local timed task (primary on claim holder) | ✅ done | `bin/ai-runner-pool-watch`; `tests/test-ai-runner-pool-watch.sh` 10/10 |
| P2 | Windows queue-slow watch as a local timed task (replaces Action-on-every-verify) | ✅ done | `bin/ai-windows-queue-watch`; `tests/test-ai-windows-queue-watch.sh` 7/7 |
| P3 | Membership-drift + merge-queue-drift as local timed tasks | ✅ done | `bin/ai-reviewer-membership-drift` tick + `ai-merge-queue-drift tick`; existing suites green |
| P4 | Free GitHub Actions kept only as backup; paid Blacksmith gone from watchdogs | ✅ done | Four workflows `ubuntu-24.04` backup-only; `grep blacksmith` clean on watchdog/drift YML |
| P5 | Installer + docs updated; live proof on **edge-dev, edge-dev3, and hetz** (failover proven) | 🟡 code landed, live proof open | install.ps1 + install.sh schedule `ai-local-watch`; docs updated; **live failover drill still required** |

**Where a fresh session starts:** P0. Do not open P1 until P0’s verification gate is green. Re-read this STATUS table before each phase; the plan is stale the moment a row turns done.

---

## 1. The ultimate goal — what we are actually trying to achieve

Albert pays for CI runners. Watchdogs are small alarm scripts — they should not sit on paid machines, and they should not even need GitHub Actions when computers he already owns can run them on a timer. Those computers do not have perfect uptime, so one pinned host is not enough.

When this is done: every routine watchdog that used to burn a GitHub Actions job (including paid Blacksmith) runs as a plain timed task on **edge-dev, edge-dev3, or hetz**, with automatic failover — whichever machine is alive and holds the claim posts the alarm. GitHub’s **free** hosted runners remain only as a backup alarm if every local host is down or the claim has gone stale. The expensive path is gone, and a single offline PC does not silence the alarms.

If a step below conflicts with this goal, the goal wins — stop and flag it.

## 2. What this application is

`popcre/ai-devops` is Albert’s public recovery toolkit for a multi-model AI workflow (not a product app). GitHub: <https://github.com/popcre/ai-devops>, default branch `main` (protected, merge queue). Local canonical checkout: `C:\repos\ai-devops` (landing only). This plan is executed from a worktree.

Watchdogs today are GitHub Actions workflows under `.github/workflows/`. Their job is to notice stuck queues, a dead Windows runner pool, or a registry/allocator mismatch, and leave a loud alarm (issue comment or failing non-required check). They do not merge code.

This machine is **edge-dev** (Windows). The candidate host set for watchdog duty is **edge-dev** (Windows, Task Scheduler), **edge-dev3** (Ubuntu desktop, user crontab / systemd user timer), and **hetz** (Ubuntu VPS, user crontab — higher uptime). edge-dev already runs Task Scheduler jobs for `ai-blocker-watch tick`, `ai-reviewer-start-watch tick`, and `ai-reap-shared-db-worktrees` — that pattern is the one to copy. Host nicknames and SSH routes live in the protected machine atlas; never put keys in the public repo.

## 3. What triggered this work

On 2026-10-01 Albert reported about **$1000 of Blacksmith spend in two weeks**. He then turned Blacksmith off; jobs whose labels still named Blacksmith sat queued and agents waited. A follow-up question was why a watchdog needs a paid runner at all. Answer: it does not. He asked for a plan to make those small scripts **plain timed tasks on this machine**, with **GitHub’s free machines as a backup**. The same day he added: **“my computers don't always have the best uptime”** and asked for **automatic rotation across edge-dev, edge-dev3, or hetz**. Single-host pin is therefore not sufficient; failover is in scope.

Related live work (do not re-derive): [PR #1193](https://github.com/popcre/ai-devops/pull/1193) already switches verify + remaining Action watchdogs from Blacksmith to free GitHub-hosted / ENVY / WarpBuild. This plan **complements** that PR: after #1193, watchdog Actions are free but still burn Actions minutes and still depend on GitHub’s schedule reliability (GitHub has dropped scheduled runs on this repo — see `stuck-work-watchdog.yml` header).

## 4. Scope — in and out

**In scope**
- The four Action-based watchdog workflows listed in §5.
- A small shared local-watch harness (or reuse of an existing one) so each watchdog gets `schedule` / `tick` / log / lock like `ai-blocker-watch`.
- **Multi-host claim/lease failover** across edge-dev, edge-dev3, and hetz (automatic rotation when the current duty host is down).
- Schedule registration on each candidate host (Task Scheduler on Windows, crontab/systemd on Linux) via the existing installer paths.
- Free GitHub-hosted Actions kept as **backup only** (when the shared claim is stale).
- Tests for the new/changed `bin/` tools, claim helper, and schedule registration.

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
| Host pinning example | `config/reviewer-start-watch.json` `run_on_host`; `config/blocker-watch.json` `propagate_on_host` (edge-dev) / `fixer_on_host` (edge-dev3) / `stuck_watchdog_*`. **Pin without failover** — if that host is offline, the duty is silent. | those config files |
| Candidate hosts | edge-dev (Windows Task Scheduler), edge-dev3 (Ubuntu, `ssh -i ~/.ssh/916-alien ahazan@edge-dev3`), hetz (Ubuntu VPS, `ssh vps2-direct`, user `ai` on `/worksp/ai-devops`). Installs: `install.ps1` / `install.sh`. | `docs/restore-from-zero.md`, handoff fleet-adopt notes |

## 6. Key findings and root cause

1. **Watchdogs do not need compute scale.** They poll APIs and write a comment. A 4-vCPU Blacksmith (or even a free Actions) job is wasted capacity. The cost driver is *volume* (queue watch on every verify) and *label* (Blacksmith).
2. **GitHub `schedule:` is unreliable on this repo.** `stuck-work-watchdog.yml:16–21` records hourly crons firing every 4–7 hours and the first four 15-minute slots after merge never running. A local timer is strictly more reliable than Actions cron for the primary alarm.
3. **Event-driven watch ≠ must stay in Actions.** `windows-queue-watchdog` looks like it must be a `workflow_run` hook, but its real job is: “for each in-progress PR verify, if Windows sections are still queued after ~3 minutes, comment once.” A local 1–2 minute tick can do the same list+comment via `ai-gh`, and can cancel/ignore non-PR runs without creating an Actions run at all.
4. **Same-machine pattern is already proven.** `ai-reviewer-start-watch` every 2 minutes and `ai-blocker-watch tick` every 10 minutes run unattended on edge-dev with Task Scheduler, a tick lock, and `tick.log` (`docs/task-router.md` reviewer-start-watch row; `tests/verification/github-requests/s1-edge-dev-2026-09-27.md`).
5. **Local primary + Actions backup matches `stuck-work-watchdog`.** That workflow is only a manual/backup execution surface; the cadence lives on the machine.
6. **Single-host pin dies with the host.** Albert (2026-10-01): his computers “don’t always have the best uptime.” `propagate_on_host` / `run_on_host` are single points of silence. Failover needs a **shared claim** any host can see (hosts cannot see each other’s disks). GitHub via `ai-gh` is the only shared store every candidate already has; a short lease (renewed each successful duty tick) is enough.

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
| Keep a single `run_on_host` pin (first draft of this plan) | Silences alarms when that host is offline — the exact failure Albert named. Replaced by claim/lease failover (2026-10-01). |
| All hosts always run every tick and always post | Triple API reads (conflicts with GitHub request reduction #658) and triple comments. Claim/lease keeps one poster. |
| Lease on a Synology share or a shared-db table | Synology is not mounted on every host; shared-db structure is a governed cross-repo change for a watchdog detail. Rejected for v1. |

## 8. Design decisions already made (dated)

| Decision | Status | Reason |
|---|---|---|
| Primary runtime = **local timed tasks** on edge-dev / edge-dev3 / hetz (2026-10-01, Albert: “plain timed tasks on this machine”; then automatic rotation across the three) | **LOCKED** | Owner request; matches existing machine pattern; uptime failover. |
| **Automatic rotation** = short claim/lease (default TTL 3× the tool’s tick interval, min 15 min), stored as a marker on one standing GitHub issue via `ai-gh`; duty host renews while healthy; any listed host may claim when stale (2026-10-01) | **LOCKED** | Shared store every host already has; no new service; one poster. |
| Backup runtime = **GitHub free hosted** (`ubuntu-24.04` / `ubuntu-latest`), never Blacksmith (2026-10-01) | **LOCKED** | Owner cost rule; public repo free tier. |
| Reuse `bin/ai-merge-queue-drift` and `bin/ai-reviewer-membership-drift` rather than reimplement (2026-10-01) | **LOCKED** | Repository reuse rule. |
| One shared local-watch harness (schedule/tick/lock/log) instead of five copy-pasted Task Scheduler scripts (2026-10-01) | **LOCKED** | Harness consolidation (#167 class); copy #9 trap in reviewer-wrapper audits. |
| `windows-queue-watchdog` messaging must stop recommending Blacksmith (2026-10-01) | **LOCKED** | Blacksmith is out of the pool (PR #1193 / owner cost direction). |
| Host name strings in `watch_hosts[]` (`edge-dev` vs `COMPUTERNAME`, `edge-dev3` vs hostname) | **OPEN** | Match `blocker-watch.json` `propagate_on_host` / `fixer_on_host` nicknames already in use; document aliases in the config `_comment`. |
| Claim marker home: dedicated issue number vs `alarm_digest` style standing issue | **OPEN** | Prefer one long-lived issue titled `local-watch-leader` (or reuse an existing ops issue); document the issue number in `config/local-watch.json`. |
| hetz participation: full duty vs backup-only (production-read-only habits) | **OPEN** | Read-only tick + claim is fine; **no** package installs on hetz outside Ansible / approved install path. If that blocks `install.sh` on hetz, leave the crontab entry as a manual one-liner in the handoff and mark the row partial. |
| Backup Actions cadence (daily vs weekly vs heartbeat-stale-only) | **OPEN** | Prefer claim-stale-only + weekly smoke; justify in the PR if different. |
| Whether queue-slow tick rides `ai-blocker-watch tick` or its own 2-minute task | **OPEN** | Criteria: if both can share one lock/log without cross-failures, piggyback is fine; else own task. |

## 9. The plan — numbered, ordered steps

### Phase A — harness (P0)

**A1. Add or extend a shared local-watch helper** — target `tools/lib/local-watch.sh` (new) **or** extract the common `schedule`/`tick`/lock/log tail already duplicated in `bin/ai-blocker-watch` / `bin/ai-reviewer-start-watch`. Behavior when done: one place defines (a) Task Scheduler registration name `\ai-devops\<tool>`, (b) per-tick lock (see `docs/locks.md` tick lock style), (c) append-only `~/.ai-devops/<tool>/tick.log`, (d) non-zero tick exits that are *alarms* vs *skips*.  
**Depends on:** nothing.  
**Gate:** `tests/test-local-watch.sh` green (new); `bash tests/test-ai-blocker-watch.sh` and `tests/test-ai-reviewer-start-watch.sh` still green if those tools switch to the helper.

**A2. Define multi-host config** — `config/local-watch.json` with:
- `watch_hosts`: ordered preference `["edge-dev","edge-dev3","hetz"]` (names per §8 OPEN).
- `claim_issue`: number of the standing `local-watch-leader` issue (or create one in P5).
- `lease_ttl_minutes`: default `max(15, 3 × tool_tick_minutes)`.
- per-tool tick minutes (queue-watch 2, pool 60, membership 360, merge-queue 1440).  
**Depends on:** A1.  
**Gate:** unit test that config schema validates and that a host **not** in `watch_hosts` does not claim (install may still schedule a *local-only* wake if desired — default **skip**).

**A2b. `bin/ai-local-watch claim|release|status`** (or commands on the A1 helper) — each duty tick:
1. Read the claim marker on the standing issue (`ai-gh`).
2. If renewer is me and lease not expired → renew, exit 0 (I hold duty).
3. If lease expired or missing → claim (hostname + ISO timestamp), exit 0.
4. If another host holds a fresh lease → exit 3 (*skip: leader=…*).  
Non-leader ticks must not post public alarms.  
**Gate:** `tests/test-local-watch-claim.sh` fixtures: fresh other lease → skip; expired → claim; own lease → renew; API error → do not claim, exit alarm code.

### Phase B — move the cheap periodic watches (P1, P3)

**B1. `bin/ai-runner-pool-watch`** (new thin wrapper; body = the bash in `runner-pool-watchdog.yml:40–75`): commands `tick`, `schedule`, `check`. Uses `ai-gh` (never raw `gh`) and the same Administration:Read token resolution as today (1Password / env — never log the token). Hourly on the 25th minute. Failures append to tick.log **and** open/update one standing issue (same alarm surface as the Action).  
**Gate:** `tests/test-ai-runner-pool-watch.sh` (offline fixture roster: 0 online → alarm; 1 online → warning; 2+ → ok). Live: `ai-runner-pool-watch tick` on the current claim holder returns 0 and the log line names the online count.

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

**D2. Installer wiring on every `watch_hosts` member** —
- **edge-dev / Windows:** `bin/install-ai-devops-windows.ps1` after the existing schedule blocks (`:1207–1271`), same Git Bash + test-mode rules. Four new tasks under `\ai-devops\`.
- **edge-dev3 / hetz / Linux:** extend the existing `install.sh` / crontab or systemd-user pattern **only if sibling tools already schedule there** (blocker-watch / worktree reap). Prefer one marked crontab block `# ai-devops local-watch` invoking `bin/ai-local-watch tick-all`. hetz: if package/install policy blocks `install.sh`, a documented user-crontab one-liner in the handoff is acceptable for P5 partial.  
**Gate:** test mode never touches tasks; each host that is in scope shows its four timers (or documented partial). Claim is exercised at least once per OS (Windows Task Scheduler + Linux crontab).

**D3. Docs** — `docs/deployment.md` schedule list, `docs/task-router.md` a row for “routine watchdog / drift alarm”, AGENTS.md router row if a task type is missing. Strike Blacksmith wording from watchdog comments.  
**Gate:** `bin/ai-doc-reachability` (or the repo’s doc test) passes; no stale “route to Blacksmith” string in watchdog sources.

**D4. Live proof including failover (required before any row is marked done)** —
1. One successful manual tick per tool on the duty host (log lines + timer LastRun).
2. **Failover drill:** stop/sleep the duty host (or freeze its claim), wait past `lease_ttl_minutes`, confirm a second host claims and posts once.
3. Restore the first host; confirm it does **not** double-post (skip path, leader=… in its log).  
Leave `- [ ] live proof` on the owner issue if a step is code-landed-but-unproved.  
**Gate:** log excerpts for claim/renew/skip from at least two hosts; one single public alarm during the drill.

### Adversarial cases (trust boundary: GitHub API, tokens, comments)

| External input | Hostile case | Test that proves it |
|---|---|---|
| Runner roster JSON | 403 / missing token / empty runners / runner names with spaces | `tests/test-ai-runner-pool-watch.sh` fixtures |
| Workflow run list | Fork PRs, merge_group runs, cancelled runs, missing `pull_requests[]` | `tests/test-ai-windows-queue-watch.sh` fixtures (mirror `windows-queue-watchdog.yml:45–47`) |
| PR comments API | Existing marker comment, race two ticks, comment turned off on repo | unit: second tick does not create a second comment |
| `RUNNER_POOL_READ_TOKEN` | Token present but under-scoped; token in argv or log line | assert token never printed; `ai-gh` / env-only |
| Task Scheduler | Task already exists from old script; laptop sleeps mid-tick; two ticks overlap | lock file test; `schtasks /F` re-point test |
| Clock skew | tick uses UTC vs local; “3 minutes” uses wrong unit | fixture freezes time in unit tests |
| Claim marker / lease | Two hosts claim the same second; host crashes after claim before renew; forged hostname in marker | claim tests: second claim loses or wins deterministically (issue edit is the lock); expired lease can be stolen; marker parsed strictly (host allowlist `watch_hosts`) |
| Claim API outage | `ai-gh` fails mid-tick | do not treat as leadership; exit alarm; never post from a host that cannot read the lease |

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
- [ ] P0–P5 STATUS rows each have artifact evidence (path, commit SHA, or `schtasks`/`crontab` listing).
- [ ] No watchdog/drift workflow on `main` uses Blacksmith labels.
- [ ] Four tools have green unit tests + one live tick each; **claim failover proven on at least two hosts** (edge-dev + one of edge-dev3/hetz).
- [ ] Backup Actions are free-only and rare; primary cadence is local; duty is single-poster via claim.
- [ ] PR merged through the queue; `origin/main` contains the commit.
- [ ] `docs/deployment.md` + task-router updated; no “route to Blacksmith” in watchdog sources.
- [ ] Owner issue checklist item `live proof` ticked or explicitly left with one named owner.

**Rollback:** delete/disable the new timed tasks on each host (Task Scheduler / crontab block), re-enable the Action triggers (revert the workflow commit). Clear or delete the claim issue marker. No data migration.

**Risks (updated)**
- Claim race at the same second → last successful issue edit wins; the loser logs skip. Acceptable (idempotent alarms).
- hetz install path constrained by production/Ansible habits → document a crontab one-liner rather than force `install.sh`.
- Clock skew between Windows and Ubuntu → lease checks use UTC ISO in the marker only.
- Landing this while PR #1193 is open → workflow YAML conflicts; rebase first and re-run workflow policy tests.

**Risks**
- edge-dev offline → primary alarm silent → backup Actions cover (by design). Document how to see “local heartbeat stale”.
- Token scope wrong → roster watch false-alarms; keep the existing 403 message text.
- Landing this while PR #1193 is open → workflow YAML conflicts; implementer should rebase on whichever merges first and re-run workflow policy tests.
- Over-commenting on PRs from the queue watch → keep the single marker + update-in-place behavior.

**Open questions (criteria in §8):** host-pin string, backup cadence, own task vs blocker-watch piggyback for queue watch.

---

## Self-audit (implementation-plan-writer Mode A)

1. **Could a brand-new AI session execute this without asking anything?** Yes — §2 names the app, three hosts, and install paths; §5–§6 give file anchors, why Actions cron is untrustworthy, and why single-host pin fails; §9 steps name `tools/lib/local-watch.sh`, `bin/ai-local-watch claim`, `bin/ai-runner-pool-watch`, `bin/ai-windows-queue-watch`, Windows installer lines `install-ai-devops-windows.ps1:1207–1271`, Linux crontab rules, and gates including the failover drill. Gaps fixed in draft: (a) queue-watch is event-shaped — C1/C2 convert it to a tick and retire `workflow_run`; (b) first draft pinned one host — §6.6 / A2 / A2b add claim/lease rotation across edge-dev, edge-dev3, hetz.
2. **Does it carry background, nuance, and rejected approaches?** Yes — §3 links the $1000/Blacksmith incident, PR #1193, and the uptime/rotation request; §7 rejects free-Actions-only, self-hosted pool heartbeats, deleting watches, mega-BlockerWatch, bare multi-poster, and Synology/shared-db leases; §8 locks owner decisions and labels open ones (name strings, claim issue home, hetz install depth).
3. **Is the ultimate goal clear for judgment calls?** Yes — §1 is business English (no paid runners; alarms must survive one offline PC; free Actions only if every host is down) and ends with goal-wins. Open items carry criteria so implementers correct toward the goal instead of redesigning.

**Checklist:** 13 sections present; goal first; fresh-session executable; rejected approaches present; steps have files + gates; adversarial table includes claim/lease races; locked vs open labeled; out-of-scope explicit; tests named; terms defined; secrets by location; DoD includes commit/CI and two-host failover proof; handoff linked both ways.
