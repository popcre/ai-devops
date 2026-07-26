---
name: leaked-secrets-pending-rotation
description: Live secrets were committed to the public repo and redacted on 2026-05-29; they still need rotating
metadata: 
  node_type: memory
  type: project
  originSessionId: 1d41f339-3928-435c-80ce-4fb67ca9ee35
---

On 2026-05-29 we found live production secrets committed in plaintext to the
public GitHub repo `u2giants/synology-monitor` and redacted them in-repo. Leaked locations found (all redacted):
`apps/relay/RECOVERY_PROMPT.md`, `apps/relay/.env.runtime` (now gitignored),
`scripts/backfill-synobackup.mjs` (hardcoded Supabase service-role key), and —
found during the 2026-05-29 docs pass, missed by the first audit because the
`*.env` grep glob didn't match `*.env.example` — `apps/web/.env.example` and
`deploy/synology/nas-{1,2}.env.example` (real NAS API secrets + signing keys).

**Why:** Redacting the working files does NOT un-leak them — the real values are
still in git history on GitHub and must be treated as compromised.

**How to apply:** The following still need ROTATION by the owner (I cannot do this
from the repo side): NAS_EDGE1/2_API_SECRET, NAS_EDGE1/2_API_SIGNING_KEY (rotate in
each NAS `.env` + matching Coolify `NAS_EDGE*` vars), RELAY_BEARER_TOKEN +
RELAY_ADMIN_SECRET (Coolify), the Supabase service-role key (Supabase dashboard →
also update everywhere it's used), and the NAS SSH password for user `popdam`.
Until rotated, anyone with repo history has full NAS + Supabase access.
