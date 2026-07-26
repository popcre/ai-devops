---
name: feedback-1password-ids-unstable
description: Never cache 1Password vault/item IDs — look them up by title each session; op:// refs with spaces/parens in the title fail to parse
metadata: 
  node_type: memory
  type: feedback
  originSessionId: ae9e5c93-d34e-41d4-82c1-068fe5840c43
  modified: 2026-07-26T23:06:47.301Z
---

**1Password vault and item IDs are NOT stable across MCP reconnects.** Mid-session on
2026-07-24 the `vibe_coding` vault ID changed from `b2dsir4jze3wfygdxixoaasdeq` to
`pimcaogmxxzoafh7lsluj6uxkq`, and every cached item ID went stale — `op_run` failed with
`itemNotFound` / "Vault ... is not in the allowed vault list", which LOOKS like a broken
tool or a permissions problem but is neither.

**How to apply:**
1. Resolve by title at point of use each session: `vault_list` → `item_lookup(query, vaultId)`
   → use the returned item ID immediately. Do not hardcode or reuse IDs from notes/memory.
2. In `op://` references, prefer `op://vibe_coding/<ITEM_ID>/<FIELD>` — the **vault NAME**
   works even when the ID rotated, but a **title containing spaces or parentheses does not**:
   `op://vibe_coding/Supabase Preview Branch Credentials - shared POP database (shared-db-schema-rehearsal)/password`
   fails with "secret references must only contain alphanumeric, _, . or - characters".
   So: vault by name + item by ID.
3. Field names differ per item — the preview-branch item uses `DB_PASSWORD` (not `password`),
   while `Supabase DB Password - shared POP database` uses `password`. Read the item's field
   list rather than guessing.

**Why:** cost ~15 minutes of false debugging (suspecting revoked access / a broken MCP)
during the [[project_sample_tracking]] schema work. Related: [[feedback_bff_oidc]].
