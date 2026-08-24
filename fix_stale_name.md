# fix_stale_name.md — a renamed 1Password item silently kills every secret-launched MCP server

**Incident date:** 2026-08-24 · **Machine:** al8960ofc (Windows) · **Status:** fixed on
al8960ofc; one remote file still pending (see [Remaining work](#remaining-work)).

---

## 1. The symptom

Roughly half the MCP servers fail to start, in Claude Desktop, Claude Code, **and**
Codex. In `C:\Users\ahazan\AppData\Local\Claude\Logs`, each failing server logs the
same three lines:

```
[ERROR] could not resolve item UUID for item designflow-mcp:
        could not find item designflow-mcp in vault pimcaogmxxzoafh7lsluj6uxkq
Exception: C:\repos\ai-devops\bin\mcp-secret-launch.ps1:53
        The single 1Password environment refresh failed (exit 1).
Server transport closed unexpectedly ... Server disconnected.
```

Servers **down**: `1password`, `devops-mcp`, `recall-ai`, `supabase`,
`synology-monitor`, `trigger`.
Servers **up**: `ag-grid`, `chrome-devtools`, `codex-cli`, `playwright`, `vercel`.

## 2. Why one bad reference takes down six servers

This is the single most confusing part of the failure, and the reason it looks like
six unrelated outages.

All six failing servers launch through
[`bin/mcp-secret-launch.ps1`](bin/mcp-secret-launch.ps1). That launcher does **one**
`op run --env-file ~/.config/ai-devops/mcp.env` for the whole set, caches the results
in a DPAPI-encrypted file for 15 minutes, and shares that cache across every server.
The design is deliberate — per-launch `op run` calls once overran the service
account's hourly rate cap and locked it out.

The consequence: `op run` resolves **every** line in `mcp.env` before it returns
anything. One unresolvable reference fails the whole batch (exit 1), the launcher
throws by design at
[`bin/mcp-secret-launch.ps1:53`](bin/mcp-secret-launch.ps1:53), and **every** server
depending on that refresh dies — including the five that never needed the broken
secret. The five survivors are simply the servers that need no secrets at all.

> **Diagnostic rule:** if the failing set is exactly "the servers that use
> `mcp-secret-launch`", suspect **one** bad reference in `mcp.env`, not six broken
> servers. Do not debug them individually.

## 3. Root cause

The vault item holding the two DesignFlow bearer tokens was **renamed**:

| | |
|---|---|
| Old title (referenced everywhere) | `designflow-mcp` |
| New title | `DesignFlow MCP bearer tokens - DevOps and NAS (production)` |
| Item UUID (unchanged) | `f335s4oy3m6n74jmwj74hunrtu` |
| Vault | `vibe_coding` |
| Fields | `devops_token`, `nas_token` (both intact, 64 chars, still valid) |

Nothing was deleted and no credential expired. Only the **name** the configs pointed
at stopped existing, so `op://vibe_coding/designflow-mcp/devops_token` resolved to
nothing.

### Why the "prefer names over UUIDs" convention backfired here

`config/mcp.env.example` documents a rule adopted after the 2026-07-22 account
migration: **prefer name-based references**, because a migration re-creates every
item under a new UUID while titles survive. That rule is right for *migrations* and
wrong for *renames* — and it hides a second trap:

**The new title contains parentheses, and `op` rejects `(` in a name-based
reference.** So this item can never go back to a name-based reference while it keeps
that title. It must use the UUID.

`config/mcp.env.example` in the repo had **already** been corrected to the UUID. The
deployed copies on the machine had not — they still carried the old name. The repo
and the live machine had silently drifted apart.

## 4. The fix

Replace the name with the UUID everywhere:

```
op://vibe_coding/designflow-mcp/devops_token
  ->  op://vibe_coding/f335s4oy3m6n74jmwj74hunrtu/devops_token
op://vibe_coding/designflow-mcp/nas_token
  ->  op://vibe_coding/f335s4oy3m6n74jmwj74hunrtu/nas_token
```

### Every location that holds this reference

Five places, on two machines. Missing any one leaves a client broken.

| # | Location | Machine | Fixed |
|---|---|---|---|
| 1 | `~/.config/ai-devops/mcp.env` | al8960ofc | ✅ |
| 2 | `~/.claude.json` (`devops-mcp`, `synology-monitor` args) | al8960ofc | ✅ |
| 3 | `%APPDATA%\Claude\claude_desktop_config.json` | al8960ofc | ✅ |
| 4 | `~/.codex/config.toml` | al8960ofc | ✅ |
| 5 | `/home/ai/.claude.json` | hetz (VPS) | ❌ pending |
| — | `bin/setup-machine.ps1` (lines 386, 391, 913) | repo | ✅ committed |
| — | `config/mcp.env.example` | repo | already correct |
| — | `/home/ai/.config/ai-devops/mcp.env` | hetz (VPS) | already correct |

**`bin/setup-machine.ps1` matters even though it is not read at launch.** It is the
canonical writer of MCP config. Left unfixed, the next `setup-machine` run would
rewrite the broken name straight back into `~/.claude.json` and the Desktop config,
resurrecting the outage.

### The commands

Windows (Git Bash). Back up first — these files are hand-edited and not in git:

```bash
cd ~/.config/ai-devops && cp mcp.env mcp.env.bak-$(date +%Y%m%d) && sed -i 's|op://vibe_coding/designflow-mcp/|op://vibe_coding/f335s4oy3m6n74jmwj74hunrtu/|g' mcp.env
```

Repeat for `~/.claude.json`, `%APPDATA%\Claude\claude_desktop_config.json`, and
`~/.codex/config.toml`. **Validate each after editing** — a botched `sed` on a JSON
config is a worse outage than the one being fixed:

```bash
python -c "import json;json.load(open(r'C:/Users/ahazan/.claude.json'));print('json ok')"
```

Then force a cache refresh and confirm every value resolves non-empty:

```bash
rm -f ~/.config/ai-devops/mcp-secrets.dpapi.json
```

Restart the client; the next launch rebuilds the cache. Note the launcher refuses to
cache an empty value on purpose — an empty resolve is treated as a failure, not a
blank.

## 5. How it was verified

1. **All eight secrets resolve.** After deleting the cache and re-running the
   launcher, `mcp-secrets.dpapi.json` regenerated with non-empty encrypted values
   for all 8 references.
2. **Both tokens authenticate live.** A real `initialize` JSON-RPC POST to each
   endpoint with the resolved bearer:
   - `https://mcp.designflow.app/mcp` → **HTTP 200**
   - `https://nas-mcp.designflow.app/mcp` → **HTTP 200**
3. **Configs still parse** — JSON validated for both `.claude.json` files, TOML
   validated for `config.toml` (all 13 Codex servers intact).

A restart of each client is what actually clears the failures from the logs; success
is **no new `Server disconnected` lines**.

## 6. Remaining work

**`/home/ai/.claude.json` on hetz still carries the stale name** (2 occurrences,
confirmed 2026-08-24). Codex and Claude Code on the VPS will keep failing the same
six servers until it is corrected. The VPS's own `mcp.env` is already fine, so this
one file is the whole remaining job.

An AI session's attempt to edit it was **blocked by the safety classifier** —
correctly, as an unattended write to a production host. It needs Albert's explicit
go-ahead or a human hand.

```bash
ssh vps "sudo -u ai cp /home/ai/.claude.json /home/ai/.claude.json.bak-20260824 && sudo -u ai sed -i 's|op://vibe_coding/designflow-mcp/|op://vibe_coding/f335s4oy3m6n74jmwj74hunrtu/|g' /home/ai/.claude.json && sudo -u ai python3 -m json.tool /home/ai/.claude.json > /dev/null && echo 'json ok'"
```

### SSH gotcha met while investigating

`ssh hetz` fails with **`Host key verification failed`**. That is *not* a security
problem and *not* a reason to touch `known_hosts`: **there is no `hetz` alias.**
`~/.ssh/ai-devops.conf` defines the host as `vps`, `coolify`, or `hetzner` (all →
`100.66.37.58`, which is already trusted). Typing `hetz` sends SSH to a literal
hostname that was never trusted under that name, and `BatchMode=yes` suppresses the
interactive trust prompt, so it fails outright.

**Use `ssh vps`.** Never "fix" this by adding a key or passing
`StrictHostKeyChecking=no` — that disables the protection that catches a genuine
machine-in-the-middle.

## 7. How to stop this recurring

1. **Renaming a `vibe_coding` item is a breaking change.** Before renaming, grep the
   fleet for the old title; after renaming, switch its references to the **UUID**.
2. **Use the UUID whenever a title contains `(` or `)`** — `op` cannot parse those in
   a name-based reference at all. Two items already require this
   (`Trigger.dev Personal Access Token (management)`, and now this one).
3. **Treat `mcp.env.example` drifting from the deployed `mcp.env` as a live defect.**
   The repo was already correct here and the machine was still broken; nothing
   compared them. A periodic diff of the reference *names* (never the values) would
   have caught this before the outage.
4. **Read the failing set before debugging individual servers.** "Exactly the
   secret-launched servers" is a signature that points at one line in one file.

## 8. Related reading

- [`bin/mcp-secret-launch.ps1`](bin/mcp-secret-launch.ps1) — the shared refresh, the
  DPAPI cache, and the deliberate throw at line 53.
- [`bin/setup-machine.ps1`](bin/setup-machine.ps1) — canonical writer of every MCP
  entry; the only place a new server should be added.
- [`config/mcp.env.example`](config/mcp.env.example) — the reference list and the
  name-vs-UUID convention.
- [`docs/mcp-1password-rate-limit-hardening.md`](docs/mcp-1password-rate-limit-hardening.md)
  — why the single shared refresh exists; do not replace it with per-launch `op run`.
- [`docs/config-inventory.md`](docs/config-inventory.md) — the 2026-07-22 migration
  that first broke these references.
