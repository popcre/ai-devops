# Pending work

Index of active plan pointers, moved from [`AGENTS.md`](../AGENTS.md) (#1881 phase 4). Read the linked plan STATUS first.

## Issue implementation plans

These plans record issue-specific assessments; read each verdict or STATUS before
acting. Some call only for live proof or closure, rather than implementation.

### Installation and local tooling

- [#1836: installed-checkout protection and remaining live proof](../plan_issue-1836.md)
- [#1860: ZCode headless failures after auto-update](../plan_issue-1860.md)
- [#1941: slow Windows GitHub authentication checks](../plan_issue-1941.md)
- [#1962: closeout of Claude sleep-permission failures](../plan_issue-1962.md)
- [#2235: installer globals and isolated regression coverage](../plan_issue-2235.md)
- [#2255: same-inode owner-repair regression coverage](../plan_issue-2255.md)
- [#2280: updater dirty-checkout guards](../plan_issue-2280.md)
- [#2284: closeout of the obsolete Windows event finding](../plan_issue-2284.md)
- [#2326: safe command-shim installation](../plan_issue-2326.md)

### Reviews, verification, and documentation

- [#988: scheduled full-verification failures](../plan_issue-988.md)
- [#2095: advisory-failure follow-ups in PR waiting](../plan_issue-2095.md)
- [#2236: stale reviewer freeze and approval wording](../plan_issue-2236.md)
- [#2307: closeout-checker architecture documentation](../plan_issue-2307.md)
- [#2332: reviewer maintenance test and deletion coverage](../plan_issue-2332.md)
- [#2336: changed-file documentation safety checks](../plan_issue-2336.md)
- [#2340: runner guidance and manual Windows verification timeout](../plan_issue-2340.md)
- [#2346: heartbeat GitHub call throttling](../plan_issue-2346.md)

### Shared database, transcripts, and trial closeout

- [#1779: idle shared-db reservations and remaining fleet proof](../plan_issue-1779.md)
- [#1998: live transcript re-audit](../plan_issue-1998.md)
- [#2017: retire the verified DesignFlow HTS handoff](../plan_issue-2017.md)
- [#2101–#2103: transcript-store review repairs](../plan_issue-2101-2102-2103.md)
- [#2248: closeout of the Entire Gates finding](../plan_issue-2248.md)
- [#2261: shared-db worktree reaper working directory](../plan_issue-2261.md)
- [#2314: vendored Supabase skills and shared-db rules](../plan_issue-2314.md)

### Programmes, watchers, and this plan set

- [#1288: standing watchdog claim issue, never close](../plan_issue-1288.md)
- [#1881: ruleset trim closeout, hook gap and re-audit](../plan_issue-1881.md)
- [#2172: lean required checks, finish shared-db stage C](../plan_issue-2172.md)
- [#2338: blocker-watch digest, own the blockers and auto-close old digests](../plan_issue-2338.md)
- [#2350: reachability of these plans, land PR #2349](../plan_issue-2350.md)
- [#2354: finish retiring the Entire trial from routing docs](../plan_issue-2354.md)

Registration handoff: [2026-11-04T2142Z-al8960ofc-claude-open-issue-plans-batch2.md](../HANDOFF.d/2026-11-04T2142Z-al8960ofc-claude-open-issue-plans-batch2.md).

## Programme pointers

CI process repair (every recurring CI problem from the transcript review): read the [CI repair plan](../plan_ci-process-repair.md) STATUS first ([#2367](https://github.com/popcre/ai-devops/issues/2367)).

Reversible Entire trial alongside GitHub: read the [trial plan](../plan_entire-reversible-trial.md)
STATUS first ([#2022](https://github.com/popcre/ai-devops/issues/2022)); planning only,
execution not started. Includes continuous memory, Trails, sessions/search and optional CI.

Ruleset trim and enforcement: read the [ruleset plan](../plan_ruleset-trim-and-enforce.md) STATUS first ([#1881](https://github.com/popcre/ai-devops/issues/1881)); evidence is private and stays out of Git.

Reviewer observation week (fast-fail, per-session skip, non-blocking reviews, 7-day repair freeze): read the [observation week plan](../plan_reviewer-observation-week.md) STATUS first; sibling repair programmes (#1783, #1822, #1678) pause for the week.

Current reviewer recurrence repairs: read the [edge-dev3 repair plan](../plan_reviewer-recurrence-repair.md) STATUS first; reuse existing owners and completed programmes. Current brief: [2026-10-22T1149Z-edge-dev3-claude-reviewer-recurrence-step8.md](../HANDOFF.d/2026-10-22T1149Z-edge-dev3-claude-reviewer-recurrence-step8.md).

Class-level reviewer stability (≥24h green): read the [reviewer stability plan](../plan_reviewer-stability-24h.md) STATUS first ([#1822](https://github.com/popcre/ai-devops/issues/1822)); do not re-derive the sibling host programmes; no bulk raw-transcript third-party extract without a token budget.

Review output contract rebuild (one validator, format repair turn, roster cut): read the [review output contract plan](../plan_review-output-contract.md) STATUS first ([#1783](https://github.com/popcre/ai-devops/issues/1783)).
Release live review check (real review on Ubuntu + Windows 4837 before a shared-review-code release installs): read the [release live check plan](../plan_release-live-review-check.md) STATUS first ([#1783](https://github.com/popcre/ai-devops/issues/1783)).

Edge-dev reviewer repair without AI-reviewer gates: read the [edge-dev no-review plan](../plan_edge-dev-reviewer-repair-no-review.md) STATUS first (owner bootstrap: implementation must not need reviewers).

For GLM access to its own truncated output, read
[`plan_glm_own_output_recovery.md`](../plan_glm_own_output_recovery.md) STATUS first
([#1791](https://github.com/popcre/ai-devops/issues/1791)); preserve the shared
service and repository instructions while qualifying the isolated formal profile.

Live sources (always prefer these over this table when they disagree):

| Status | Item | Owner / next action |
|---|---|---|
| live | Active plans and STATUS | Root `plan_*.md` — read STATUS first |
| live | Open session workstreams | `HANDOFF.d/` OPEN files, newest first |
| live | Known defects | [`bugs.md`](../bugs.md) |
| live | Specialized task queue | [`docs/task-router.md`](task-router.md) matching rows |

Do not treat completed `plan_*.md` files as a backlog; they remain decision
records. When adding rows here, mark them `done` or remove them as soon as they
stale.

Active scoped release repair: [exact sandbox source-release plan](../plan_exact-designflow-sandbox-source-releases.md) — owner codex/exact-sandbox-release; retire pointer at issue1796 closure; read STATUS first; design approval precedes implementation.
