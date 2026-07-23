# 1Password MCP rate-limit hardening — the "parallel initialization storm"

**Written 2026-07-23. Fresh-developer grade: every path, file, and identifier is
defined. If something here would make you ask a question, the answer is below.**

## TL;DR

Multiple AI clients (several Claude Code windows + Claude Desktop + Codex),
across 5 machines that **share one 1Password service account**, were each
launching the 1Password MCP through a launcher that re-resolved **11 `op://`
secrets on every single MCP-server start**. That burst of service-account
requests exceeded 1Password's **per-hour request cap** and temporarily **locked
the account** — the "storm." The fix caps 1Password to **≤1 refresh per 15
minutes per machine** regardless of how many windows/servers/subagents launch,
by resolving all secrets once and reusing a local DPAPI-encrypted cache. All of
it lives in the `ai-devops` repo so it reaches every machine via bootstrap.

## Background: how MCP secrets are launched on Windows

Every AI client that registers an MCP server spawns its **own** child process of
that server (stdio transport, one subprocess per client). Secrets are injected
at launch by a wrapper the `ai-devops` repo generates onto each machine:

- `~/.config/ai-devops/op-service-account` — the raw service-account token
  (user-only ACL). The single bootstrap secret.
- `~/.config/ai-devops/mcp.env` — **references only** (`NAME=op://vault/item/field`),
  no secret values. Currently ~11 `op://` references (supabase, devops-mcp, nas,
  trigger, recall-ai, zai, …).
- `~/.config/ai-devops/mcp-launch.cmd` — the **stdio** launcher.
- `~/.config/ai-devops/mcp-remote-launch.cmd` — the **remote/HTTP** launcher
  (for mcp-remote servers whose bearer token must be a real value, since
  mcp-remote does not expand `${VAR}` in `--header`).
- `bin/mcp-secret-launch.ps1` (in the repo) — the actual launcher logic both
  `.cmd` files call.

Both **Claude Desktop** and **Claude Code** (`~/.claude/settings.json`) reference
the same launcher, and (as of 2026-07-23) so does **Codex**
(`~/.codex/config.toml`).

## Root cause of the storm

The launcher that was actually deployed on the machines (dated 2026-07-17) did:

```bat
set /p OP_SERVICE_ACCOUNT_TOKEN=<"...\op-service-account"
op run --no-masking --env-file="...\mcp.env" -- %*
```

`op run --env-file=mcp.env` resolves **every** reference in `mcp.env` — all ~11 —
from the service account, **on every launch**, whether or not the launched server
needs any of them. So:

| Surface | Servers wrapped per launch | Service-account reads per launch (~11 refs each) |
|---|---|---|
| One Claude Code window | 2 (1password, supabase) | ~22 |
| Claude Desktop | 3 | ~33 |

Multiply by every window open / reload / restart, across **5 machines sharing one
service account**, into a rolling 60-minute window. A handful of restarts, or one
session that spawned subagents, blows through the hourly cap → **lockout**. It
fires even when 1Password is never used, because the cost is in the *wrapper*, not
the server. (The 1Password MCP server itself is already lazy — it authenticates
only on the first tool call.)

### Why a mutex/broker was rejected

- The limit is **total requests per hour**, not concurrency — a concurrency
  semaphore does nothing about total volume.
- A shared local HTTP/SSE broker was rejected: no new always-on moving parts to
  manage across 5 machines.

The correct lever is therefore **resolve once, reuse** — a cache, not a broker.

## The fix: single-flight refresh + 15-minute DPAPI cache

`bin/mcp-secret-launch.ps1` replaces the per-launch `op run`:

1. **`Ensure-Cache`** takes a machine-wide named mutex
   (`Local\ai-devops-1password-refresh`). If the DPAPI cache
   (`~/.config/ai-devops/mcp-secrets.dpapi.json`) is **< 15 minutes old**, it is
   reused and **no 1Password call is made**. Only if stale does it run **one**
   `op run --env-file=mcp.env` refresh for all references and re-encrypt the
   cache (DPAPI, user-scoped, via `ConvertFrom-SecureString`).
2. A cold parallel storm collapses to **one** refresh: the first process holds
   the mutex and refreshes; the rest block, then find the now-fresh cache and
   reuse it.
3. **`Import-Cache`** decrypts values into the child process environment.
4. The child MCP server is then launched with those env vars set.

**Effect:** ≤1 refresh / 15 min / machine ⇒ ~4 refreshes/hr × ~11 refs ≈ **44
reads/hr/machine** worst case, well under 1Password's read cap (1,000/hr Teams /
10,000/hr Business). No broker, no daemon.

Empirically verified on t16 (2026-07-23): cold launch created the cache and ran
the child; a warm launch 2 s later ran the child with the cache **mtime
unchanged** — proving zero 1Password calls on reuse.

## The launcher bug this work also fixed (important)

The caching launcher was **committed but had never been deployed** (the on-disk
file was still the 2026-07-17 `op run` version), so its bug had never surfaced.
When first deployed it failed with:

```
mcp-secret-launch.ps1: Parameter cannot be processed because the parameter
name '' is ambiguous.
```

Two coupled defects in how the `.cmd` invoked the script:

1. **`--` separator + `pwsh -File`.** The `.cmd` ran
   `pwsh -File mcp-secret-launch.ps1 -Mode Stdio -- %*`. PowerShell's `-File`
   mode mis-parses a bare `--` as an **empty/ambiguous parameter name** and
   aborts before the script runs.
2. **Positional capture swallowed `cmd /c`.** Even without `--`, the child line
   `cmd /c npx -y @u2giants/1password-mcp` had its leading `cmd` and `/c` bound
   positionally to `-Url` and `-SecretRef`, so `$CommandArgs` lost them and the
   launcher ran `npx` **bare** instead of through `cmd` — a silent misbinding
   that only worked by luck.

**Fix (both in the repo):**

- `bin/mcp-secret-launch.ps1`: `$CommandArgs` is declared
  `[Parameter(Position = 0, ValueFromRemainingArguments = $true)]`. Giving it an
  explicit `Position` makes it the **only** positional parameter, which forces
  `-Url`/`-SecretRef` to bind **by name only** (they always are, from the remote
  launcher's `-Url %1 -SecretRef %2`). Now the whole child line lands in
  `$CommandArgs` intact.
- `bin/setup-machine.ps1`: both generated launcher bodies **drop the `--`**
  (`... -Mode Stdio %*` and `... -Mode Remote -Url %1 -SecretRef %2 %3 %4 ...`).

Do **not** re-add `--` and do **not** remove `Position = 0`. Either regression
brings the bug back. There are comments in both files saying so.

## Codex coverage (new 2026-07-23)

`bin/setup-machine.ps1` registers `codex-cli` *into* Claude but never wrote
Codex's own `~/.codex/config.toml`. Left alone, its `[mcp_servers."1password"]`
block used a **direct `npx` + inline plaintext service-account token**, meaning
Codex's 1Password server was (a) outside the shared cache/mutex and (b) storing
the token in cleartext in `config.toml`.

`bin/configure-codex-1password.ps1` (new; called by `setup-machine.ps1`)
surgically rewrites **only** that block to launch through `mcp-launch.cmd`
(same path Claude uses), **deletes the `.env` plaintext-token table**, and
**preserves every `[mcp_servers."1password".tools.*]` approval guard**. It is
idempotent and safe when Codex is absent. It backs up to
`config.toml.aidevops.bak` on first run.

## Where the fix lives / how it persists to a new machine

Nothing here is in the 1Password MCP server's own code, an `.md` file, or a
hand-edited client config. The durable source is the `ai-devops` repo:

| Repo file | Role |
|---|---|
| `bin/mcp-secret-launch.ps1` | Runtime launcher: single-flight mutex + 15-min DPAPI cache. |
| `bin/setup-machine.ps1` | Generator: writes both `.cmd` launchers and merges one server list into Claude Desktop + Claude Code; now also calls the Codex step. |
| `bin/configure-codex-1password.ps1` | Routes Codex's 1Password through the launcher; strips its plaintext token. |
| `config/mcp.env.example` | Template copied to `mcp.env`. |

A new computer bootstraps by cloning `ai-devops` and running
`bin/setup-machine.ps1` (via `bin/bootstrap-windows-dev.ps1` /
`install-ai-devops-windows.ps1`). Because every machine's launcher + configs are
**generated** from these files, the fix travels automatically — provided the
repo changes are committed and pushed.

## Deployment / rollout status (as of 2026-07-23)

- **t16 (this machine):** caching launcher deployed, launcher bug fixed and
  verified, Codex routed through the launcher (plaintext token removed). ✅
- **Repo:** `bin/mcp-secret-launch.ps1`, `bin/setup-machine.ps1` modified and
  `bin/configure-codex-1password.ps1` added — **commit + push still required**
  for the fix to reach other machines.
- **Other 4 machines (916, 4837, and the two dflow boxes / any Ubuntu):** still
  running the old per-launch `op run` launcher. **Re-run `bin/setup-machine.ps1`
  on each** after pull to deploy the caching launcher and Codex routing.

## Known remaining / secondary items

- **Other plaintext secrets in `~/.codex/config.toml`:** the `trigger` and
  `recall-ai` blocks still carry inline tokens (`TRIGGER_ACCESS_TOKEN`,
  recall-ai bearer). Same launcher treatment could remove them; out of scope for
  the storm fix.
- **1Password MCP server hardening (secondary, not the fix):** the fork exposes
  two network-backed MCP **resources** (`1password://vaults`,
  `1password://vaults/{vaultId}/items`) that sign in when read. They duplicate
  the `vault_list`/`item_list` tools (explicit-call only). Removing them plus
  loud 429 handling (fail and suppress further calls until reset) is worthwhile
  defense-in-depth, but Codex's independent review confirmed the **config/launch
  layer is the primary fix**, not the resources.

## Verifying the fix on any machine

```powershell
$launcher = "$HOME\.config\ai-devops\mcp-launch.cmd"
$cache = "$HOME\.config\ai-devops\mcp-secrets.dpapi.json"
[System.IO.File]::Delete($cache)
& $launcher cmd /c "echo OK"              # cold: creates cache, prints OK
$m = [System.IO.File]::GetLastWriteTimeUtc($cache)
& $launcher cmd /c "echo OK"              # warm: prints OK
# mtime must be UNCHANGED => the warm launch made no 1Password call:
[System.IO.File]::GetLastWriteTimeUtc($cache) -eq $m
```
