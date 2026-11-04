---
issue: popcre/ai-devops#2350 # the plans PR itself; each plan carries its own issue
status: OPEN
owner: claude/open-issue-plans
---

# Implementation plans for every open ai-devops issue — registration (2026-11-04)

## 0. ⚠️ BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

None. Every plan below states its own locked and open decisions; the open ones
are implementer judgment calls with a default, not owner questions.

## 1. What this is

Albert asked (2026-11-04) for a detailed implementation plan for every open
issue in `popcre/ai-devops`, written to the `implementation-plan-writer`
standard. PR [#2349](https://github.com/popcre/ai-devops/pull/2349) (branch
`claude/open-issue-plans`) carries them. The first batch (24 plans, commit
`7b3de5d0`) was written by an earlier session on 2026-11-04; the automatic
fixer added the `docs/pending-work.md` index (`33fae053`, PR #2351). This
session (al8960ofc, Claude) merged that fix into the branch and added the six
plans for the issues the first batch missed, plus this registration.

Every plan is indexed under "Issue implementation plans" in
[`docs/pending-work.md`](../docs/pending-work.md). Read a plan's verdict and
STATUS table first; several conclude that only live proof or closure remains.

## 2. The plans

Batch 2 (this session):

- [plan_issue-1288.md](../plan_issue-1288.md) — standing watchdog claim issue; never close
- [plan_issue-1881.md](../plan_issue-1881.md) — ruleset trim closeout: hook gap + re-audit
- [plan_issue-2172.md](../plan_issue-2172.md) — lean required checks: finish shared-db stage C
- [plan_issue-2338.md](../plan_issue-2338.md) — blocker-watch digest: own the blockers, auto-close old digests
- [plan_issue-2350.md](../plan_issue-2350.md) — reachability of these plans; land #2349
- [plan_issue-2354.md](../plan_issue-2354.md) — finish retiring the Entire trial from routing docs

Batch 1 (earlier session, same branch):

- [plan_issue-988.md](../plan_issue-988.md), [plan_issue-1779.md](../plan_issue-1779.md),
  [plan_issue-1836.md](../plan_issue-1836.md), [plan_issue-1860.md](../plan_issue-1860.md),
  [plan_issue-1941.md](../plan_issue-1941.md), [plan_issue-1962.md](../plan_issue-1962.md),
  [plan_issue-1998.md](../plan_issue-1998.md), [plan_issue-2017.md](../plan_issue-2017.md),
  [plan_issue-2095.md](../plan_issue-2095.md), [plan_issue-2101-2102-2103.md](../plan_issue-2101-2102-2103.md),
  [plan_issue-2235.md](../plan_issue-2235.md), [plan_issue-2236.md](../plan_issue-2236.md),
  [plan_issue-2248.md](../plan_issue-2248.md) (issue since closed; kept as record),
  [plan_issue-2255.md](../plan_issue-2255.md), [plan_issue-2261.md](../plan_issue-2261.md),
  [plan_issue-2280.md](../plan_issue-2280.md), [plan_issue-2284.md](../plan_issue-2284.md),
  [plan_issue-2307.md](../plan_issue-2307.md), [plan_issue-2314.md](../plan_issue-2314.md),
  [plan_issue-2326.md](../plan_issue-2326.md), [plan_issue-2332.md](../plan_issue-2332.md),
  [plan_issue-2336.md](../plan_issue-2336.md), [plan_issue-2340.md](../plan_issue-2340.md),
  [plan_issue-2346.md](../plan_issue-2346.md).

The batch-1 plans each say the implementer must create a handoff file; this
file is that registration for all of them. They were written read-only and
say the plan "lives in a scratchpad" — that note is stale; the files are in
the repository.

## 3. State at hand-off

- Branch `claude/open-issue-plans`, PR #2349 open against `main`. CI on the
  previous head failed only `doc-safety` (unreachable Markdown), fixed by the
  index. `verification-closure` (the one required check) passed.
- Nothing posted to the issues; the PR is the card.
- Next: CI green on the new head, merge #2349, close #2350 and #2351. Then
  each issue is picked up from its plan independently.

## 4. Dead ends

- Writing a second, duplicate set of plans from `main` instead of building on
  PR #2349: avoided. The earlier branch was found by listing open PRs before
  starting.
- Excluding root `plan_*.md` from `.doc-reachability.json` to silence
  `doc-safety`: rejected (see plan_issue-2350 §7).
