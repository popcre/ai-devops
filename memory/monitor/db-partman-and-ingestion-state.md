---
name: db-partman-and-ingestion-state
description: 2026-05-29 — ingestion fixed (still RESOLVED) and pg_partman repaired (BROKEN AGAIN 2026-07-16 — see partman-cron-dead). Contains the how-to for draining default partitions.
metadata: 
  node_type: memory
  type: project
  originSessionId: 1d41f339-3928-435c-80ce-4fb67ca9ee35
---

Supabase project `qnjimovrsaacneqkggsn` (the OLD Ohio project — since deleted; see [[supabase-migration-virginia]]). Both issues below were RESOLVED on 2026-05-29 **on that project**.

> **⚠️ 2026-07-16: partman is BROKEN AGAIN on the live Virginia project** — different cause (cron `select`s a procedure), same symptom (defaults filling, ~8.4GB). See [[partman-cron-dead]]. **The repair playbook below is the most valuable thing in this file — reuse it**, especially: `ignore_default_data=false`, the live-write race on the current week, and the `p_lock_wait` corruption.

**Ingestion stall — FIXED.** Brittle source-whitelist CHECK constraints
(`smon_logs_source_check`, `smon_alerts_source_check`) rejected ~13 log sources +
ShareSync alert sources; PostgREST batch-inserts meant one bad row failed the whole
batch → after 5 retries all dropped → nas_logs froze ~19h, alerts ~23d while metrics
flowed. Fix (committed + deployed): migration 00035 drops both whitelists; agent stops
emitting `"filter"` severity; sender now isolates a bad row instead of failing the
whole batch (apps/agent sender.go postRows). Verified: blocked sources now flow fresh.

**pg_partman — FULLY REPAIRED.** The 00031 table rename had left part_config pointing
at old `smon_*` names, so partitioning died ~Apr 18 and all data piled into the default
partitions (metrics_default hit 12.85M/3.3GB). Fixed: corrected part_config.parent_table
to the renamed parents; set ignore_default_data=false; drained the 3 small tables with
partition_data_proc; for metrics, the current actively-written week couldn't be drained
by partman (live-write race) so used a manual atomic detach→create current+future
partitions→backfill. run_maintenance now creates premake partitions + applies retention
(84d metrics/storage, 180d logs/container). Dropped the 3.34GB metrics_olddefault backup
after verifying conservation. Default empty; new writes route to weekly partitions.

**Quirks hit (for next time):** pg_partman 5.3.1 lives in `public` schema (not `partman`);
maintenance = `public.run_maintenance_proc()`, cron job 'smon-partition-maintenance' daily.
partition_data_proc's lock-wait branch is corrupted (`format()` too-few-args) — do NOT pass
p_lock_wait. A 120s statement_timeout kills big batches — set `PGOPTIONS='-c statement_timeout=0'`.
Cosmetic leftover: 3 oldest partitions still named smon_metrics_p2026040x; retention auto-drops
them ~Jun 27. The 2 functions smon_create_alert/smon_get_openai_key intentionally still smon_-named.
