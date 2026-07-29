---
name: onepassword-mcp-token-race
description: "Why the 1Password MCP intermittently fails with \"Service account token is required\", and the fix"
metadata: 
  node_type: memory
  type: reference
  originSessionId: c2fb38ad-dde0-459e-9563-443c4d2c38e1
  modified: 2026-07-27T21:59:48.390Z
---

If the 1Password MCP suddenly fails **every** call with
`Service account token is required...OP_SERVICE_ACCOUNT_TOKEN`, the token is not
expired or revoked — the MCP process just started without it.

**Mechanism.** All MCPs launch through
`~/.config/ai-devops/mcp-launch.cmd` → `C:\repos\ai-devops\bin\mcp-secret-launch.ps1`,
which injects only the variables listed in `~/.config/ai-devops/mcp.env` (via a
DPAPI cache at `mcp-secrets.dpapi.json`, 15-minute freshness). **`OP_SERVICE_ACCOUNT_TOKEN`
is NOT in `mcp.env`**, so it is never cached. The launcher set it only on the
*refresh* path (stale cache), so whether the 1Password MCP got a token was a race:
start it while the cache was fresh — e.g. a reconnect right after another MCP
refreshed it — and it came up tokenless until Claude Code was restarted.

**The MCP server made it worse** (it is our code, `C:\repos\1password-mcp` →
npm `@u2giants/1password-mcp`): `getConfig()` resolved the token **once at startup
and cached it forever**, and the only non-env fallback was a **macOS-only** Keychain
lookup. So on Windows a transient env gap became a permanently dead server for its
whole lifetime.

**FIXED AND LIVE (verified 2026-07-27)** — both layers shipped; the MCP is working:
- ai-devops `81954f8` + `f5b7646`: the launcher always injects the token from
  `~/.config/ai-devops/op-service-account`, scoped to the `1password-mcp` child only
  (the vault token is NOT handed to supabase/trigger/recall-ai/nas children), and
  also passes `OP_SERVICE_ACCOUNT_TOKEN_FILE` (a path, not a secret).
- 1password-mcp **2.7.0 — published to npm 2026-07-27** (`npm view
  @u2giants/1password-mcp version` → `2.7.0`): adds a cross-platform token-file source
  (`--service-account-token-file` / `OP_SERVICE_ACCOUNT_TOKEN_FILE`) and
  `refreshServiceAccountToken()`, so `requireServiceAccountToken()` re-resolves once
  before failing.

**Scope of the retry (corrected in `a980f6e` — do not overstate it):** the recheck
recovers a **token FILE** that appears or becomes readable after startup. It canNOT
recover an env-only setup, because a parent process cannot inject a new environment
variable into an already-running child. Env-only configs still need a restart.

A running MCP needs a **Claude Code restart** to pick up either fix (it now has).

**Workaround when the MCP is down:** the `op` CLI works independently —
`OP_SERVICE_ACCOUNT_TOKEN` is present in the ordinary shell env, so
`op read "op://vibe_coding/<item>/<field>"` and `op item edit` work fine from the
Bash/PowerShell tools. See [[op-run-mcp-wsl-env-trap]].
