---
name: supabase-anon-execute-trap
description: "On Supabase, GRANT does not restrict — anon gets EXECUTE on new public functions by default, and PostgREST publishes them. Found monitor's exec_sql callable by anon (arbitrary SQL) on 2026-07-16."
metadata: 
  node_type: memory
  type: reference
  originSessionId: b8cfcfdf-16a9-476e-91c4-abc8c4c163eb
---

**On Supabase, `GRANT EXECUTE … TO service_role` restricts NOTHING.** Three things combine:
1. Postgres grants `EXECUTE` on new functions to `PUBLIC` by default.
2. Supabase projects have `ALTER DEFAULT PRIVILEGES` granting `EXECUTE` on new functions in `public` to **`anon` and `authenticated`**.
3. PostgREST publishes every function in `public` as an RPC endpoint.

So a `SECURITY DEFINER` function in `public` is **callable by anyone holding the anon key** — which is public (baked into the browser bundle). Only an explicit **`REVOKE`** restricts:
```sql
REVOKE ALL ON FUNCTION <sig> FROM PUBLIC, anon, authenticated;  -- THEN grant
```

**Found live in monitor 2026-07-16** (fixed, migration `00043`): `anon` could `POST /rest/v1/rpc/exec_sql {"sql":…}` → HTTP 204, **arbitrary SQL as postgres**, and `smon_get_openai_key` → HTTP 200 **returning the live `sk-or-v1-…` key**. 7 functions exposed. The `00010` migration's `grant … to service_role` looked protective and wasn't.

**Why:** this is a silent, repo-wide default. It applies to **every Supabase project** here (popdam/popcrm/poppim/dflow/shared-db), not just monitor — worth auditing them.

**How to apply:** after any `CREATE FUNCTION` on Supabase, always `REVOKE` then `GRANT`. Audit any project with:
```sql
SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.prosecdef AND has_function_privilege('anon',p.oid,'EXECUTE');
```
Related: [[telemetry-retention-unbanked]], [[leaked-secrets-pending-rotation]] (the OpenRouter key needs rotating).
