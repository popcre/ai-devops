issue: https://github.com/popcre/ai-devops/issues/2705
status: OPEN
owner: SchemaGraph trial coordinator

# SchemaGraph trial

0. Owner decisions. None required.
1. Application. POP applications share PostgreSQL definitions in popcre/shared-db.
2. Goal. Determine whether an AI finds affected objects more reliably or faster using SchemaGraph.
3. State. The [plan](../plan_schemagraph-evaluation.md) records verified source pins and the full protocol. No trial has started.
4. Failed approaches. No execution attempt. Upstream benchmarks and synthetic examples cannot establish our business result.
5. Findings. Read plan sections 5–6 for source evidence, partial parsing and the difference between a migration and the current schema.
6. Next. Follow the seven gates in section 9. Dispatch setup and key research concurrently. Keep answers isolated until scoring.
7. Constraints. Local schema only. Raw evidence belongs with shared-db. The CodeGraph trial is independent.
8. Access. Planning verified repository reads. Runtime prerequisites are in section 12.
9. Risks. Database reconstruction, hidden objects and unresolved dynamic names can invalidate results. Apply section 13 and start using the plan's final prompt.
