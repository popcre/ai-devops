# Memory index

- [Supabase migrated Ohio→Virginia](supabase-migration-virginia.md) — 2026-06-21: backend moved qnjimovrsaacneqkggsn→aaxtrlfpnoutziwhshlt. New project ref, cutover surface (GH bake/Coolify/NAS), and gotchas (disk-full crash, process_snapshots index-thrash, service_role timeout). **Old project now DELETED — no rollback exists.**
- [Telemetry retention](telemetry-retention-unbanked.md) — 00042 now installed on live; 56.4M expired process_snapshots rows still to drain, hourly cron unscheduled pending sign-off. Deletes are final (no rollback project).
- [pg_partman cron dead](partman-cron-dead.md) — 25/25 failures (SELECT on a procedure) since the June migration; ~8.4GB stranded in DEFAULT partitions. Diagnosed, NOT fixed. "Scheduled ≠ working."
- [Archive feature Phases 1 & 2 shipped](archive-inventory-phase1.md) — 2026-06-07: read-only inventory + staged reversible archive-move both on main (CI green). Gotchas: NAS_API_NAME≠NAS_NAME; moves write via :rw /btrfs/volume1; btrfs snapshot path needs live validation.
- [Supabase anon-EXECUTE trap](supabase-anon-execute-trap.md) — **GRANT does not restrict on Supabase**; anon gets EXECUTE on new public functions + PostgREST publishes them. Monitor's exec_sql was anon-callable (arbitrary SQL) until 2026-07-16. Applies to ALL our Supabase projects — worth auditing.
- [Leaked secrets pending rotation](leaked-secrets-pending-rotation.md) — live NAS/Supabase/relay secrets were in public git history; redacted 2026-05-29 but still must be rotated by the owner. **+ the OpenRouter `sk-or-v1-…` key (anon-readable until 2026-07-16) now also needs rotation.**
- [DB partman & ingestion state](db-partman-and-ingestion-state.md) — 2026-05-29: ingestion stall fixed + pg_partman fully repaired (+3.34GB reclaimed); both RESOLVED.
- [AI rebuild plan](ai-rebuild-plan.md) — issue-agent 3-stage rebuild is designed in PLAN.md (repo root); code it in a fresh session from there.
- [AI stage improvements 2026-05-31](ai-stage-improvements-2026-05-31.md) — inflight I/O metric, Drive client log fix, Stage 2 run_command tool, Stage 3 evidence bug fix, PLAN.md §3 spec rewrite.
- [DB schema reference](db-schema-reference.md) — all 52 tables: who writes, who reads, status. Check here before dropping anything.
- [Call-limit folklore](call-limit-folklore.md) — the "~10–15-call degradation limit" is a myth; validator grep-blocks are stateless & intentional, not session decay.
- [Sandbox env quirks](sandbox-env-quirks.md) — a root process keeps breaking .git ownership (fix: sudo chown -R ai:ai .git); Go isn't preinstalled.
- [NAS MCP usage](nas-mcp-usage.md) — how to call the MCP server directly via curl (bearer token, required headers, tool pattern). TODO: add MCP `instructions` field to server.
- [NAS migration plan](nas-migration-plan.md) — two-pass clean DSM rebuild: wipe edge2→copy from edge1→switch users→wipe edge1→copy back. rsync -aXH, no Drive DB.
- [ShareSync queue fix](sharesync-queue-fix.md) — only fix that works: move file to parent, rename, wait for sync, move back, rename back. Restarting does nothing.
