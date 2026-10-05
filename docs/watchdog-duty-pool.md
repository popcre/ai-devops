# Watchdog duty pool — runbook (how alarms stay alive)

**Name:** watchdog duty pool (config key: `watch_hosts`).  
**What it is:** the set of Albert’s machines that take turns running the small
CI *watchdog* timers (queue-slow, runner-pool, membership drift, merge-queue
drift). One machine is on duty at a time (claim/lease). If that machine is
offline, another pool member takes over. GitHub’s **free** runners are backup
only.

**Read first if you are an AI agent:** implementation plan
[`plan_watchdog-local-timed-tasks.md`](../plan_watchdog-local-timed-tasks.md)
(STATUS table), then this runbook, then the owner handoff
[`HANDOFF.d/2026-10-01T2205Z-edge-dev-mimo-watchdog-local-timed-tasks.md`](../HANDOFF.d/2026-10-01T2205Z-edge-dev-mimo-watchdog-local-timed-tasks.md).
Do not invent another name (not “runner pool”, not “failover cluster”).

## 1. Why this exists

- Paid runners (Blacksmith) were too expensive for alarm scripts ($1000 / 2
  weeks class spend, 2026-10-01). Alarm work is now local timers only.
- A single pinned host (`run_on_host` / `propagate_on_host`) goes silent when
  that PC sleeps or dies. Albert’s machines do not have perfect uptime.
- GitHub `schedule:` on this repo is unreliable (see
  `stuck-work-watchdog.yml` header). Local timers are primary.

## 2. Pool members (edit in `config/local-watch.json`)

| Nickname | OS | Timer | Notes |
|---|---|---|---|
| `edge-dev` | Windows | Task Scheduler `\ai-devops\…` | This desktop; installer `install.ps1` |
| `edge-dev3` | Ubuntu | user crontab / systemd user timer | `ssh -i ~/.ssh/916-alien ahazan@edge-dev3` |
| `hetz` | Ubuntu VPS | user crontab | `ssh vps2-direct`, user `ai`, checkout `/worksp/ai-devops` |

Add or remove machines **only** by changing `watch_hosts` in that config (a
normal branch + PR). Nicknames must match what BlockerWatch already uses
(`config/blocker-watch.json` `propagate_on_host` / `fixer_on_host`).

## 3. How duty works (claim / lease)

1. Each pool member runs the same timed ticks (see intervals in the plan).
2. Before **posting** a public alarm, the tick must hold the **claim**:
   a marker on one standing GitHub issue (number in `config/local-watch.json`
   `claim_issue`), body like `leader=edge-dev3` + UTC timestamp.
3. Lease TTL is in config (`lease_ttl_minutes`, default `max(15, 3× tick)`).
   The leader **renews** on a successful duty tick.
4. If the lease is stale or missing, any pool member may **claim** (prefer
   `watch_hosts` order). The loser logs `skip: leader=…` and does not post.
5. If **no** local claim is fresh, the free GitHub Action backup may run.
6. Never recommend paid Blacksmith from these tools.

Exit codes agents must understand:

| Code | Meaning | Agent action |
|---|---|---|
| 0 | Duty tick OK (leader or local-only check) | Nothing |
| 3 | Not leader this tick | Nothing; do not “fix” |
| 1 / other | Alarm or tool failure | Read `tick.log`; open/refresh the standing alarm issue |

## 4. Add a new computer to the duty pool

Do these as **one** scoped session (branch + PR + live proof). Never ask Albert
to click through them.

1. **Prereqs on the new host:** Git, Git Bash or bash, Node + jq as required by
   the tools, `bin/ai-gh` auth (`u2giants` / documented identity), repo
   checkout (worktree or clone), no secret in the repo.
2. **Name:** add the host’s short nickname to `watch_hosts` in
   `config/local-watch.json` (ordered preference). Record any alias in the
   `_comment` (same style as `blocker-watch.json`).
3. **Install timers:** run the repo installer (`install.ps1` on Windows,
   `install.sh` on Linux) **or** the marked crontab block documented in the
   plan’s D2 if the host is production-constrained (hetz). Test mode
   (`AI_DEVOPS_INSTALL_TEST_MODE=1`) must not touch tasks — use it first.
4. **Verify claim path:** `bin/ai-local-watch status` (or the plan’s named
   helper) prints leader + lease age; `claim` when stale is allowed; `skip`
   when another host is fresh.
5. **One live tick** per watchdog tool on the new host; log line in
   `~/.ai-devops/<tool>/tick.log`.
6. **Failover drill** (required once per new host): freeze the current leader’s
   renewal (stop its timers or wait past TTL), confirm **this** host claims and
   posts **once**; restore the old leader and confirm it does not double-post.
7. **Proof:** attach log excerpts (claim/renew/skip + one alarm) to the owner
   issue checklist `- [ ] live proof`. Update the pool table in this file if
   the host is permanent.

## 5. Remove a machine

1. Shorten `watch_hosts` in `config/local-watch.json` (PR).
2. Disable/remove its timers (`schtasks /Change /TN \ai-devops\… /DISABLE` or
   delete the crontab block).
3. If it was leader, let the lease expire (or `release`) so the next host
   claims. Confirm no gap longer than one TTL in `tick.log` on the successor.

## 6. What an agent must never do

- Put this duty on paid Blacksmith or invent a second pool name/config.
- Post alarms without a fresh claim (double comments / fight Club).
- Store tokens in the public repo, argv, or logs (1Password vault
  `vibe_coding` only).
- Mutate hetz packages outside Ansible / approved install; a crontab line is
  enough for duty.
- Declare the move “done” without a two-host failover drill and live proof.

## 7. Current state (2026-10-05)

| Piece | State |
|---|---|
| Plan + this runbook | Landed in `popcre/ai-devops` |
| Shared harness | `tools/lib/local-watch.sh` (schedule / lock / log) |
| Claim/lease + tick-all | `bin/ai-local-watch` + `config/local-watch.json` (`watch_hosts`, claim issue) |
| Duty tools | `ai-windows-queue-watch`, `ai-runner-pool-watch`, `ai-reviewer-membership-drift tick`, `ai-merge-queue-drift tick` |
| Installers | `install-ai-devops-windows.ps1` and `install.sh` schedule `ai-local-watch` on pool members |
| Free Actions backup | Watchdog/drift workflows are `ubuntu-24.04` weekly smoke + dispatch; no paid runners |
| Live failover drill | **Proven on edge-dev ↔ edge-dev3** (2026-10-05): expired lease → edge-dev3 claim → edge-dev `skip: leader=edge-dev3` → release → edge-dev reclaim. Claim issue #1288. runner-pool live tick + edge-dev3/hetz timer install still open (owner issue #1287). |

Fresh session: finish the live proof (D4 in the plan). Keep this runbook as the
**contract** the tools and docs must match. When a row of the plan’s STATUS turns
done, update §7 here in the same PR.
