---
name: op-ref-parens-break-parser
description: 1Password op:// references fail when the item TITLE contains parentheses; use the item ID instead
metadata: 
  node_type: memory
  type: reference
  originSessionId: 1dba598f-7506-49c0-8dce-e9acf4659077
  modified: 2026-07-22T19:09:44.721Z
---

`op://vault/item/field` references (both `op_run` env values AND `op read`) reject any
item whose **title contains `(` `)`** or other non-`[alnum._-]` characters — error:
`invalid character in secret reference: '('`. Neither quoting nor escaping helps; the
op secret-reference parser itself rejects it.

**Fix:** reference the item by its **ID** instead of its title. Look the ID up with the
1Password MCP (`item_lookup` needs a `vaultId` — get it from `vault_list`; vibe_coding =
`b2dsir4jze3wfygdxixoaasdeq`), then use `op://vibe_coding/<ITEM_ID>/<FIELD>`.

Hit this 2026-07-22 on `Supabase Preview Branch Credentials - shared POP database
(shared-db-schema-rehearsal)` (ID `ou6avbeyier7tifwqxup36ih4a`) while linking the preview
Supabase project. Related: [[shared-db-change]] and AGENTS §9 op_run gotchas.
