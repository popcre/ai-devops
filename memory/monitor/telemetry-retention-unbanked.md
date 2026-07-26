---
name: telemetry-retention-unbanked
description: "2026-07-16 — monitor's telemetry retention (migration 00042) is committed but installed nowhere; live DB still ~32GB with no retention. Owner decisions pending before install."
metadata: 
  node_type: memory
  type: project
  originSessionId: b8cfcfdf-16a9-476e-91c4-abc8c4c163eb
---

**UPDATE 2026-07-16: now installed on live and partially run.** `00042` + both retention indexes are on `aaxtrlfpnoutziwhshlt`; 61k rows deleted in staged batches; **56.4M expired `process_snapshots` rows remain** (97% of a 16GB table); hourly cron deliberately **unscheduled** pending owner sign-off. Owner decisions were taken: `disk_io_stats` → 35d (protects the metrics page's 30d range), and the 4 partman tables left to partman.

Original cause: a 2026-06-22 session installed it and purged ~27.8M rows on the **old Ohio project**, later deleted — taking purge, functions and cron with it. See [[supabase-migration-virginia]].

**Why this is in memory and not just the repo:** detail is in `docs/telemetry-retention.md` / AGENTS §15-16. What's worth carrying:

- The DB is **42GB and growing**; the single biggest win is draining `process_snapshots` (measured 50k/532ms, zero blocking, ~10 min total). It is queued behind an owner decision, not a technical problem.
- **The partman decision in `00042` is conditional**: those 4 tables were left to partman, and partman is dead — see [[partman-cron-dead]]. Until that's fixed they have *no* retention at all.
- Deletes are final: **no rollback project exists** (the old one was deleted).

**How to apply:** don't re-plan from scratch — read `docs/telemetry-retention.md`, then either re-enable the cron (SQL is in the doc) or drain in one pass. DB password: 1Password → "Supabase DB Password - synology-monitor"; use `op_run`; direct host is IPv6-only.
