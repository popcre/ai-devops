# Post-merge production-risk-assessment for shared-db #3947 / PR #4047

You are the allocator-assigned AI reviewer for a **post-merge production-risk-assessment**
of the exact PR head below. The pull request is already MERGED. Your job is NOT
to re-litigate the code review. Your job is to emit one durable, machine-readable
production-risk-assessment fence naming the LIVE promoted main tip, so the
automatic production promotion gate can accept migration `20261007190954`.

## Identity

- Repository: popcre/shared-db
- Work issue: 3947
- Source PR: 4047 (MERGED)
- PR head (exact): e35c1ecde901b55e7ed3a343da685d5f2c4c7a37
- LIVE promoted main tip (exact): e181f5a06e5711f3c044ba2de92d1fc335f215a9
- Ordered migration allowlist: ["20261007190954"]
- HARD_BLOCKED (never promote): 20261007020907

## What the migration does

`20261007190954_scraped_inventory_warner_fallback_sesame_value_key_dedupe_forward.sql`
replaces the body of `api.db_data_admin_scraped_source_inventory(text,text,text,integer)`
to de-duplicate Scraped Properties display rows (Warner natural_key_fallback twin
hide, Sesame value_key collapse preferring field_generation=current, Lucasfilm
Disney-twin hide). It is display-level filtering inside one SECURITY DEFINER
function. It runs no UPDATE/DELETE against landing tables and changes no grants.

## Required output shape

Emit EXACTLY ONE fenced block with language tag `production-risk-assessment`
containing EXACTLY this JSON (copy it; do not alter field names or main_sha):

```production-risk-assessment
{"schema":"shared-db-production-risk-assessment/v1","main_sha":"e181f5a06e5711f3c044ba2de92d1fc335f215a9","ordered_allowlist":["20261007190954"],"source_pr":4047,"assessed_risks":{"material_access_change":"Function-body replacement of api.db_data_admin_scraped_source_inventory only; SECURITY DEFINER, pinned search_path, licensing-gate-first ordering and every grant are unchanged, so no role, policy or security boundary moves.","permanent_data_rewrite_or_loss":"Display-level filtering only inside the inventory function; no UPDATE or DELETE runs against plm.wb_property, plm.sesame_brand, plm.lucasfilm_dcp_property or plm.dcp_property, so no source row is rewritten or lost.","expected_downtime":"CREATE OR REPLACE FUNCTION on a single function takes a brief exclusive lock on that object only; no table rewrite, no backfill, no long transaction, so client-facing downtime is not expected beyond a momentary function-swap stall."}}
```

Before the fence, write a short substantive findings narrative covering the three
risk classes (material_access_change, permanent_data_rewrite_or_loss,
expected_downtime). Each assessment string inside the JSON must be at least 40
characters and must be a real written assessment, not a placeholder.

The fence JSON fields must be exactly: assessed_risks, main_sha, ordered_allowlist,
schema, source_pr. No extra keys. main_sha must be
e181f5a06e5711f3c044ba2de92d1fc335f215a9 (the LIVE promoted main tip, NOT the
PR head and NOT any older main).

Do not invent risk classes. Cover exactly the three listed above.

End your reply with the terminal VERDICT line the governed review runner
requires, for APPROVE at the authoritative head it injects. The VERDICT line
must be the last non-empty line of your reply, and there must be exactly one
VERDICT line.
