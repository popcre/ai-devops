---
name: project_db_backfill_batching
description: Big single-statement backfills on popdam-prod time out at the MCP gateway and can crash the compute into WAL recovery — batch them
metadata: 
  node_type: memory
  type: project
  originSessionId: 8fa604ba-5565-4550-915b-ccedbedc3cf6
---

On popdam-prod (`ryltkzzernhwnojzouyb`), the `assets` table is ~100k+ rows. A single `UPDATE ... FROM (SELECT infer_path_attrs(...) FROM assets)` over the whole table:
- exceeds the Supabase MCP `execute_sql`/`apply_migration` gateway wall-clock limit (~2 min) → "Connection terminated unexpectedly", and
- a too-heavy batch (~55k rows in one statement) crashed the compute instance into crash recovery ("redo in progress", `57P03 the database system is not accepting connections`) for several minutes (2026-06-08, during the stage/customer/program backfill).

**How to apply:** Keep DDL in the `apply_migration` migration; run large data backfills separately via `execute_sql`, scoped into batches of ~20k rows (e.g. partition by a `LIKE` prefix or `id`-range / `LIMIT`). A statement that loses its client connection may still commit server-side — re-check row counts before re-running. See [[project_cicd]].
