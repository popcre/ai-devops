---
name: op-account-migration-2026-07
description: "2026-07-22 the 1Password service account moved to a NEW account (popcreations.1password.com); all old-account item UUIDs are dead; the final SA is READ-WRITE (item_edit verified 2026-07-26)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 4838ebb3-d531-4f47-8660-f0a495d23914
  modified: 2026-07-26T18:05:27.061Z
---

On **2026-07-22** Albert rotated the 1Password service-account token AND the new
token belongs to a **different 1Password account**:
`popcreations.1password.com` (old was `my.1password.com`). The new token is set
as the OS env var `OP_SERVICE_ACCOUNT_TOKEN` (User scope) on al8960ofc — that env
var, not the vault, is the live source of truth for the token.

**Why:** every `op://vibe_coding/<UUID>/...` reference pinned to an OLD-account
item UUID is now stale — the new vault (`vibe_coding`, new vault id
`pimcaogmxxzoafh7lsluj6uxkq`) contains the same items under NEW UUIDs.

**How to apply:**
- The raw token was swapped in the 3 live configs that embed it literally:
  `~/.claude/settings.json`, `~/.codex/config.toml`,
  `~/AppData/Roaming/Claude/claude_desktop_config.json` (the `1password` MCP
  `OP_SERVICE_ACCOUNT_TOKEN` env). MCP processes only pick it up after a restart.
- Stale UUID `op://` refs were re-pointed to **name-based** refs where the title
  has no parentheses (robust to future migrations), UUID only where it doesn't:
  - Supabase: `op://vibe_coding/Supabase CLI Personal Access Token/SUPABASE_ACCESS_TOKEN`
  - Recall: `op://vibe_coding/recall-ai MCP/password`
  - GitHub: `op://vibe_coding/GitHub PAT - u2giants repo push access/token`
  - Trigger (title has `()` → name refs are rejected with "invalid character '('",
    so it MUST stay UUID): new id `ylzcsfbhmjyzjy65mnu6uxw67e`, field `credential`
  - GLM: field is now `api key`, NOT `credential` (`credential` resolves to 0 bytes
    — the silent-empty trap). `op://vibe_coding/GLM z.ai API/api key`
  - Fixed in repo `config/mcp.env.example`, `bin/setup-machine.ps1`,
    `bin/setup-secrets.sh`, `docs/model-setup.md`, and the live
    `~/.config/ai-devops/mcp.env`. Verified all resolve non-empty via `op run`.
- **SA identity churn during setup (resolved):** the first replacement token
  belonged to a read-only SA (Integration ID `Q7Y622J275BGZFWYDX4QCYG7OI`), which
  Albert then deleted. The FINAL working token is a read-write SA, Integration ID
  **`OEO2NT4575H6XPSVHZE7AQXPZM`** — verified with `op item create`+`delete`
  (exit 0). Gotcha seen along the way: `op whoami` decodes the token LOCALLY, so
  it kept showing the deleted SA's ID while every real server call returned
  `(403) Service Account Deleted`. Always prove write with a real create/delete,
  not `whoami`. The vault token backup fields (`op_service_account_token` AND
  `credential` on `vibe_coding-service-account`) were refreshed to the new
  866-char token once write access was live.

See [[op-service-account-token-field]] and [[onepassword-vault-vibe-coding]].
