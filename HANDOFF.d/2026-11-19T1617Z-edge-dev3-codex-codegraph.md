issue: https://github.com/popcre/ai-devops/issues/2699
status: OPEN
owner: Codex CodeGraph evaluation lead

# CodeGraph comparison

0. Owner decisions. None required to run the scoped trial.
1. Applications. DesignFlow manages products, PopDAM manages assets, and shared-db owns their database definitions. Use local source snapshots.
2. Purpose. Measure whether a session locates relevant code faster without missing important dependencies.
3. State. The [implementation plan](../plan_codegraph-evaluation.md) carries the pinned inputs, case anchors and status. Planning inspected the source trees. Execution starts at step 1.
4. Failed attempts. No trial runs were attempted. Upstream measurements do not answer these application-specific questions.
5. Findings. See plan section 6 for upstream language coverage and reproducible source counts. SQL and application code need separate treatment.
6. Next steps. Freeze nine verified keys, validate three isolated indexes, collect 18 independent answers and publish three decisions. The executable gates are in section 9.
7. Constraints. Local copies only. Keep private answer keys and source evidence with their owners. No application or database changes.
8. Access. Existing Git access worked for the planning snapshots. No production login is necessary.
9. Risks. Unknown SQL coverage and dynamic links could produce plausible but incomplete answers. Apply the frozen correctness and time thresholds. Use the plan's final launch prompt to begin.
