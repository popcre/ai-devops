---
name: partman-cron-dead
description: "2026-07-16 — monitor's pg_partman cron has failed 25/25 (SELECT on a procedure); ~8.4GB stranded in DEFAULT partitions. Diagnosed, NOT fixed."
metadata: 
  node_type: memory
  type: project
  originSessionId: b8cfcfdf-16a9-476e-91c4-abc8c4c163eb
---

Monitor's pg_cron job `smon-partition-maintenance` runs `select public.run_maintenance_proc()`. In pg_partman 5.x that's a **procedure**, so Postgres rejects it every run: *"To call a procedure, use CALL."* **25/25 failures**, daily, since the jobs were hand-recreated after the 2026-06-21 migration. `cron.job.active = true` the whole time.

Result: no bounded partition past 2026-06-13, so `metrics`/`nas_logs`/`container_status`/`storage_snapshots` all write to the **DEFAULT** partition — which partman retention *never* drops. ~8.4GB/27M rows immortal and growing; DB is 42GB. **Diagnosed 2026-07-16, NOT fixed.**

**Why this is in memory:** the repo records it ([[telemetry-retention-unbanked]], `docs/telemetry-retention.md`, AGENTS §15). What's worth carrying: the two generalizable lessons.

1. **A scheduled job is not a working job.** `active = true` only means scheduled. Always check `cron.job_run_details` (status + return_message) after creating/recreating any pg_cron job, and for partman that `part_config.maintenance_last_run` advances. This bug survived a month of "healthy" dashboards.
2. **`ignore_default_data = true` is a trap** for draining a default partition — Postgres validates DEFAULT on `ATTACH`, so it makes partition creation *fail*, not skip work. Leave it false and let partman move data per-week.

**How to apply:** don't re-diagnose — read `docs/telemetry-retention.md` § pg_partman. Run `CALL run_maintenance_proc()` manually/watched before repointing the cron (48d backlog, ~27M rows, 1GB Micro).
