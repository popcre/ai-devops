# Pending work

Index of active plan pointers, moved from [`AGENTS.md`](../AGENTS.md) (#1881 phase 4). Read the linked plan STATUS first.

Reversible Entire trial alongside GitHub: read the [trial plan](../plan_entire-reversible-trial.md)
STATUS first ([#2022](https://github.com/popcre/ai-devops/issues/2022)); planning only,
execution not started. Includes continuous memory, Trails, sessions/search and optional CI.

Ruleset trim and enforcement: read the [ruleset plan](../plan_ruleset-trim-and-enforce.md) STATUS first ([#1881](https://github.com/popcre/ai-devops/issues/1881)); evidence is private and stays out of Git.

Reviewer observation week (fast-fail, per-session skip, non-blocking reviews, 7-day repair freeze): read the [observation week plan](../plan_reviewer-observation-week.md) STATUS first; sibling repair programmes (#1783, #1822, #1678) pause for the week.

Current reviewer recurrence repairs: read the [edge-dev3 repair plan](../plan_reviewer-recurrence-repair.md) STATUS first; reuse existing owners and completed programmes. Current brief: [2026-10-22T1149Z-edge-dev3-claude-reviewer-recurrence-step8.md](../HANDOFF.d/2026-10-22T1149Z-edge-dev3-claude-reviewer-recurrence-step8.md).

Class-level reviewer stability (≥24h green): read the [reviewer stability plan](../plan_reviewer-stability-24h.md) STATUS first ([#1822](https://github.com/popcre/ai-devops/issues/1822)); do not re-derive the sibling host programmes; no bulk raw-transcript third-party extract without a token budget.

Review output contract rebuild (one validator, format repair turn, roster cut): read the [review output contract plan](../plan_review-output-contract.md) STATUS first ([#1783](https://github.com/popcre/ai-devops/issues/1783)).

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
