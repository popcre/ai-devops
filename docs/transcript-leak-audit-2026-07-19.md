# Transcript leak audit — 2026-07-19

## Executive verdict

The original six Synology Monitor values are rotated, but the wider incident is
not closed. The private transcript archive contains many additional credentials
that were current when the archive was publicly reachable. A vault-wide exact
comparison found **61 current concealed 1Password fields** represented in the
archive. Some are public values or non-secret text stored in concealed fields,
but many are active production credentials.

No credential was rotated during this audit. Every further rotation requires
Albert's approval for its atomic rotation group.

## Safety and method

- Scanned 1,281 files in the private `u2giants/ai-devops-transcripts` archive.
- Initial format-based scan found 836 distinct candidates; this deliberately
  over-counted generic assignments and examples.
- Compared 89 concealed fields across 47 items in the scoped 1Password vault
  `vibe_coding` against the archive inside a protected process.
- Reports contain opaque IDs, field names, source locations, and verdicts only.
  No values or hashes are retained.
- Provider candidates were checked against official read-only status endpoints.
- MCP tokens were checked with non-mutating MCP initialization requests.
- The `popdam` SSH password was not tested by authentication.

One database-URI metadata parser proved unsafe because escaped JSON newlines let
a match run into neighboring environment text. Its temporary output was deleted
immediately and none of that parser's database output is used in this report.
Database credentials remain grouped by their 1Password item/field identity only.

## Confirmed still live and exposed

### MCP access — six values

All six current values appear exactly in the archive and were accepted by their
live MCP endpoints with HTTP 200:

- `designflow-mcp` / `devops_token`
- `designflow-mcp` / `nas_token`
- `devops-mcp-client-tokens` / `codex`
- `devops-mcp-client-tokens` / `chatgpt`
- `devops-mcp-client-tokens` / `gemini`
- `devops-mcp-client-tokens` / `claude`

The July 14 replacements were themselves captured in later transcripts. Rotate
the five `devops-mcp` tokens as one coordinated group and the `nas-mcp` bearer as
a separate group because they have different runtime owners and clients.

### AI provider keys

Confirmed current, exposed, and accepted by the provider:

- `ai-provider-api-keys` / `openai`
- `ai-provider-api-keys` / `deepseek`
- `ai-provider-api-keys` / `dashscope`

The current Anthropic and Gemini fields also appear in the archive, but their
providers reject them with HTTP 401; classify them as already dead, not live.

Five historical OpenRouter keys were found. Four are still accepted with HTTP
200 and one is rejected with HTTP 401. The four live keys are associated by
redacted source context with the Restore Wizard, Hiclaw, Synology Monitor, and a
Railway production environment. None matches the current Oracle-local
OpenRouter field in 1Password, so each deployment/account must be identified and
rotated independently.

Three Google-shaped keys were found. One historical key is still accepted by
Google; two are rejected. The live historical key does not match the current
Gemini field and therefore needs owner/deployment identification before rotation.

### 1Password bootstrap credential

The current `1Password Service Account Token - hetzner_vps` value appears exactly
in the archive and is demonstrably active because it authenticated the protected
vault-wide comparison. A standing owner directive says not to rotate or suggest
rotation of this service-account token. This creates an unresolved incident-risk
exception that must be explicitly decided by Albert; do not silently change it.

### Cloudflare tunnel credentials

The current fields below appear exactly in the archive:

- `cloudflare-tunnel-tokens` / `cloudflare_tunnel_token`
- `cloudflare-tunnel-tokens` / `cf_gw_tunnel_token`
- `cf-tunnel-hetz` / `password`

They are backed up from current Cloudflare/Coolify configuration and the tunnels
are active. Treat them as live pending a Cloudflare-side token-status check and
rotate through Cloudflare plus every matching Coolify consumer as coordinated
tunnel groups.

## Confirmed rejected or not matching current storage

- Four GitHub-shaped tokens: all rejected with HTTP 401.
- One Vercel token: rejected with HTTP 403.
- Two transcript Trigger PAT candidates: neither matches the current concealed
  management PAT in 1Password.
- Current Anthropic provider key: rejected with HTTP 401.
- Current Gemini provider key: rejected with HTTP 401.
- One of five historical OpenRouter keys: rejected with HTTP 401.
- Two of three historical Google-shaped keys: rejected by the provider.
- The current `916-alien` private key does not exactly match any private-key
  material detected in the existing archive.

## Current vault values exposed; live state still needs service verification

The following current fields appear exactly in the archive. Their item identity
is sufficient to plan verification, but the audit has not authenticated them to
their services yet:

- ClickUp account/API/MCP credentials and Cloudflare D1 ClickUp credential.
- Coldlion ERP API key.
- Coolify application and database passwords.
- DesignFlow sandbox database password, PLM master-data API key, and frontend
  test-login password.
- `hetz-ai-ssh` password.
- npm publishing token.
- POP CRM live test login and POP CRM Supabase worker service-role key.
- Recall.ai MCP credential.
- Brevo API key.
- Oracle current and old Supabase database URLs/passwords.
- Synology Monitor Supabase database password.
- Shared POP production service-role key.
- Shared-DB preview branch connection strings, JWT secret, and service-role key.
- `vibe_coding-service-account` concealed fields; determine whether these are a
  duplicate representation of the active bootstrap token before any action.

Supabase anon keys and Logo.dev publishable values are public identifiers, not
rotation-worthy secrets. The field
`nas-monitor-secrets/mcp_bearer_token_LEAKED_DO_NOT_USE` is intentionally
quarantined and must not be restored to service.

Directus entries are deprecated vestiges. Confirm no surviving runtime uses
them, then delete the obsolete credentials rather than reactivating or rotating
the retired system.

## SSH private keys and `popdam` password

Eleven archive files contain private-key blocks. The current `916-alien` key was
not an exact match, but the other keys remain unidentified and must be mapped to
their public fingerprints/authorized hosts using an in-memory parser before the
incident can be closed. Do not write extracted private keys to disk.

The `popdam` NAS SSH password remains **UNKNOWN**. It is not represented by an
obvious current item in the scoped vault. Do not test it by authenticating.
Identify its authoritative storage/host configuration by a non-login route or
perform a precautionary password reset with the NAS lockout and dependent jobs
planned in advance.

## Recommended rotation waves

Each wave requires explicit approval before any value changes:

1. **MCP access:** five `devops-mcp` client tokens, then the independent
   `nas-mcp` bearer. Update 1Password first, Coolify second, clients from `op://`
   references, deploy, and prove old values return 401.
2. **Billable AI providers:** OpenAI, DeepSeek, DashScope, four live OpenRouter
   keys, and the separate live Google key. Rotate at each provider first into
   1Password `_next`, update every application/Trigger/Coolify/Railway consumer,
   verify, then revoke old keys.
3. **Cloudflare tunnels:** map each token to tunnel/container, stage replacements,
   update Coolify, verify routes, then revoke old tokens.
4. **Database and service-role credentials:** coordinate through the owning
   repository/platform. Shared Supabase schema changes remain governed by
   `u2giants/shared-db`; credential rotation must update every application and
   deployment consumer atomically.
5. **Business-service credentials:** ClickUp, Coldlion, Brevo, Recall.ai, npm,
   DesignFlow PLM, and application logins.
6. **SSH/password cleanup:** identify the eleven private keys and reset the
   unknown `popdam` password without authentication probing.
7. **Bootstrap-token exception:** Albert must explicitly resolve the standing
   no-rotation directive versus the confirmed exposure of the active 1Password
   service-account token.

## GitHub residue

File GitHub Support sensitive-data removal requests for unreachable historical
objects in `u2giants/ai-devops` and for the still-secret-bearing history of
`u2giants/synology-monitor`. This limits casual retrieval but does not replace
credential rotation.

## Definition of done still outstanding

- Classify and safely verify every current-exposed vault field listed above.
- Identify the four live OpenRouter owners and the one live historical Google key.
- Identify all eleven private keys without writing them to disk.
- Resolve/reset the unknown `popdam` password.
- Complete approved rotations and prove every old live value is rejected.
- Store final safe artifacts under `/home/ai/rotation/` and update this report
  with completion evidence.
