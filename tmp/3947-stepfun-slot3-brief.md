# Governed production-risk review — PR #4047 / issue #3947 (slot 3)

You are the allocator-assigned reviewer (slot 3) for popcre/shared-db PR #4047, head `e35c1ecde901b55e7ed3a343da685d5f2c4c7a37`.

## Scope
Forward replacement migration `20261007190954` (`scraped_inventory_warner_fallback_sesame_value_key_dedupe_forward.sql`). It re-applies the same Scraped Properties display-dedupe behavior as the HARD_BLOCKED `20261007020907` (Warner fallback-twin hide, Sesame value_key collapse, Lucasfilm/Disney display dedupe) as a new reserved version on claim #3955. Character and style_guide arms are unchanged. Security posture (SECURITY DEFINER, pinned search_path, licensing-gate-first ordering) and every grant are unchanged. Display-level only: no source-row delete/update.

Read the sealed review packet (MANIFEST + complete diff) and the migration SQL. Assess:

1. Role and permission changes (grants, policies, security boundaries, sibling call paths)
2. Objects and dependencies (exact schemas, names, signatures, callers, dependency stages vs declared scope)
3. Migration immutability (existing migration modifications, version reservations, collision protection)
4. Rollback and recovery (partial-failure recovery; rollback preserves original capability)
5. Probe, indexes and volatility (exact object assertions, useful indexes for every predicate/join, function volatility)
6. Related refusals and tests (prior findings, negative cases, sibling failure classes)

## Verdict
Report all discovered findings together. Preserve independent judgement. End with exactly one final line:

VERDICT: APPROVE e35c1ecde901b55e7ed3a343da685d5f2c4c7a37

or REVISE / REJECT with the same head SHA. Do not emit a production-risk-assessment fence; another slot carries that.
