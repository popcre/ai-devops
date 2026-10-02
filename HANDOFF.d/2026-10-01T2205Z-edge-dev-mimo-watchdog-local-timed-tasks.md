---
issue: null
status: OPEN
owner: mimo/watchdog-local-timed-tasks
---

# HANDOFF — plan: watchdogs as local timed tasks

Machine: edge-dev · Agent: mimo · Written: 2026-10-01
GitHub signature this session: `Posted by MiMo chat ses_ffe5f06a5eb68ffeJ09D0qCZjG on edge-dev`

## 0. Decisions only the owner can make

- **Already decided (do not re-ask):** Watchdogs become plain timed tasks on
  edge-dev; GitHub free runners are backup only; never pay for watchdogs again
  (Albert, 2026-10-01 chat).
- **Still his:** nothing required to start implementation.

## 1. What this project is

`popcre/ai-devops` public toolkit. Routine CI watchdogs (queue-slow, runner-pool,
membership drift, merge-queue drift) are GitHub Actions today and have been
burning paid runner time and Actions volume. Albert asked for local timed tasks
with free Actions as backup.

## 2. Goal and reason

Stop paying for alarm scripts. Alarms should run on a machine Albert already
owns, on a timer, and only fall back to free GitHub runners if that machine is
not ticking. Implementation plan (read this first):

[`plan_watchdog-local-timed-tasks.md`](../plan_watchdog-local-timed-tasks.md)

## 3. Current state and proof

Planning only. No implementation started. Related landed/pending work: PR #1193
(free runners for verify + remaining Action watchdogs). This plan moves the
primary cadence off Actions entirely.

## 4. Next concrete step

Start at plan STATUS **P0** (shared local-watch harness), then P1–P5 as in the
plan. Fresh session: open the plan file, read STATUS, claim one row.

## 5. What must not be lost

- GitHub `schedule:` is unreliable on this repo (see
  `stuck-work-watchdog.yml` header) — local timer is primary for that reason,
  not only cost.
- `stuck-work-watchdog` is already the target shape (local tick + free Action
  only as executor/manual). Copy that shape; do not invent a new service.
- Reuse `bin/ai-merge-queue-drift` and `bin/ai-reviewer-membership-drift`.
- Do not put a pool heartbeat on the Windows pool it is measuring.
- Never recommend Blacksmith in leftover copy.
- One unproven outcome per session; live proof checklist on the owner issue.

## 6. Links

- Plan: [`plan_watchdog-local-timed-tasks.md`](../plan_watchdog-local-timed-tasks.md)
- PR #1193 (free-runner cut-over): https://github.com/popcre/ai-devops/pull/1193
- Pattern docs: [`docs/deployment.md`](../docs/deployment.md) schedule stages
- Task router row (to add if missing): routine watchdog / drift alarm
