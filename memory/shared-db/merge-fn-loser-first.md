---
name: merge-fn-loser-first
description: "core.merge_customer/merge_factory take (loser, survivor) — opposite to DB_Data_Admin.md §6 listing; always call by name."
metadata: 
  node_type: memory
  type: reference
  originSessionId: d822d3d2-a17e-4f3e-99dd-e36a260bcd7d
  modified: 2026-07-23T14:30:22.566Z
---

Current signatures (latest def `20260722004500_db_data_admin_merge_fk_coverage.sql`):
`core.merge_customer(p_loser uuid, p_survivor uuid, p_alias_loser_name boolean default true)` and
`core.merge_factory(p_loser uuid, p_survivor uuid, p_alias_loser_name boolean default true)`.

**Loser is the FIRST positional argument.** `DB_Data_Admin.md` §6 lists them as
`core.merge_customer(p_survivor, p_loser)` — WRONG order. Calling positionally per that
listing swaps survivor/loser and deletes the wrong row (the function `delete from core.customer
where id = p_loser`). Always call with **named arguments** (`p_loser =>`, `p_survivor =>`).
Both engines fail closed on extension-row conflicts via `core.reconcile_merge_extension_row`.

Related: `plm.import_master_data()` (latest def `20260625153020`) still CLOBBERS
`core.customer.status` on existing matched rows (maps DesignFlow `customers_status` ACTIVE→active
else inactive) — unlike the Coldlion `plm.import_coldlion_customers` importer, which was made
status-app-owned in `20260716140000`. See [[shared-db-apply-mechanics]].
