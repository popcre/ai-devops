---
name: project_admin_config_secret_exposure
description: PopDAM admin_config leaked 8 plaintext secrets to any authenticated user (fixed 2026-07-24); rotation still pending; Vault/env plan
metadata: 
  node_type: memory
  type: project
  originSessionId: 063717bf-f645-4909-89b1-a4d1886d8d7d
  modified: 2026-07-26T18:10:13.050Z
---

On 2026-07-24 found `public.admin_config` (shared prod `qsllyeztdwjgirsysgai`) had RLS
policy `Authenticated read admin_config` = `USING (true)` for role `authenticated`, so
ANY logged-in user of ANY POP app could `SELECT` all 755 rows — including 8 plaintext
credentials: ANTHROPIC/OPENAI/OPENROUTER/GOOGLE_AI API keys, DO_SPACES_KEY/SECRET, and
both `WINDOWS_AGENT*_NAS_PASS`. Writes were already admin-gated; only reads leaked.
`anon` also had a TRUNCATE grant (not RLS-gated).

FIXED + LIVE in prod (shared-db PR #204, merged+auto-deployed via
shared-supabase-migrations.yml): split read policy — non-admins get
`key !~* '(pass|secret|token|key|cred|pwd)'`, admins get all; revoked anon
insert/update/delete/truncate. Verified: non-admin secret visibility 8→0, admin still 8.
Pattern matches exactly those 8 of 755 keys, 0 false positives.

STILL PENDING (owner action, NOT done): **rotate all 8 credentials** — assume compromised
(readable during the exposure window). Pre-rotation values backed up per-service in
1Password vibe_coding: `ai-provider-api-keys` (fields `*_popdam_shared_supabase`),
`DigitalOcean Spaces - popdam bucket (nyc3)`, `Synology edgesynology2 - styleguides SMB
share`, `Synology 192.168.3.101 - mac SMB share`. NAS passwords are AD domain accounts on
IML.isaacmorris.com (popdam, ahazan) — rotating = AD change. See fix_admin_config_secret_rotation.md.

LONGER-TERM PLAN (pending owner decision): move secrets out of admin_config.
Recommended split — env vars (hosting panels) for the 6 API/storage keys (server-only,
set-once); Supabase Vault for the 2 NAS passwords (operator edits them in PopSG/PopDAM
Settings UI). 1Password stays the human master of record. Explicitly NOT adopting
"reference-at-deploy" (apps fetching from 1Password via a machine token) — reintroduces
the single-token fragility that broke us. Secret-placement rule and per-secret table
worked out in the 2026-07-24 session. Ties to [[project_popdam_shared_env]] and the NAS
unification plan (one AD account → one Vault secret).
