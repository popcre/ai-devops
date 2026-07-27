---
name: project-service-role-key-mismatch
description: "PopDAM edge functions use the NEW sb_secret_ key, but 1Password holds the LEGACY service_role JWT — service-role probes fail and look like an auth regression"
metadata: 
  node_type: memory
  type: project
  originSessionId: 7f75d1b6-370e-40a4-b10e-fe9af344cbca
  modified: 2026-07-27T02:19:02.035Z
---

For Supabase project `qsllyeztdwjgirsysgai` (PopDAM/PopSG, Virginia), the
**deployed edge-function secret `SUPABASE_SERVICE_ROLE_KEY` is the project's
new-format `default secret` key (`sb_secret_…`)**, NOT the legacy `service_role`
JWT stored in 1Password item "Supabase Runtime Keys - shared POP database
(production)". Same story for `SUPABASE_ANON_KEY` (deployed = new *publishable*
key; vault = legacy anon JWT). Verified 2026-07-26.

**Why:** the legacy JWT still authenticates fine against **PostgREST**
(`/rest/v1/...` returns 200), so it looks correct — but any edge function that
compares the bearer token to its own `SUPABASE_SERVICE_ROLE_KEY` env var rejects
it with 401. Probing the service-role bypass with the vault key therefore looks
exactly like an auth regression you just introduced, and sends you debugging
code that is fine.

**How to apply:**
- `supabase secrets list --project-ref <ref>` prints a DIGEST column that is a
  **plain sha256 of the secret value** — hash a candidate key and compare to
  identify which key is actually deployed.
- Reveal the real keys with the Management API using the vault's "Supabase CLI
  Personal Access Token":
  `GET https://api.supabase.com/v1/projects/qsllyeztdwjgirsysgai/api-keys?reveal=true`
  (returns `legacy anon`, `legacy service_role`, `default publishable`,
  `default secret`).
- The 1Password entry has not been reconciled — treat it as stale for
  edge-function work until it is.

Related: [[project_secret_access_paths]], [[project_supabase_virginia_cutover]]
