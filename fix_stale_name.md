# fix_stale_name.md — a renamed 1Password item silently kills every secret-launched MCP server

**Incident date:** 2026-08-24 · **Machines:** al8960ofc (Windows) + hetz (VPS) ·
**Status:** the stale-name outage is fixed and the fix is merged to `main`.
`recall-ai` remains down for an unrelated reason that is **not** ours to fix
(§9). Three separate faults were stacked here — read §2, §8, and §9 as distinct
problems.

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
| 5 | `/home/ai/.claude.json` | hetz (VPS) | ✅ |
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

**Only `recall-ai` (§9b), and it is not a configuration problem.** Everything else is
done: all five locations carry the item UUID, the repo fix is merged to `main` so
`setup-machine.ps1` can no longer reinstate the old name, and `devops-mcp` and
`synology-monitor` were each launched for real and started cleanly.

Restart the clients after any of this — a running client keeps its old config.

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

0. **Merge the fix to `main` before hand-editing live configs.** `setup-machine.ps1`
   is the canonical writer; an unmerged fix gets overwritten the next time it runs,
   which is exactly what happened here (§8).
1. **Renaming a `vibe_coding` item is a breaking change.** Before renaming, grep the
   fleet for the old title; after renaming, switch its references to the **UUID**.
2. **Use the UUID whenever a title contains `(` or `)`** — `op` cannot parse those in
   a name-based reference at all. Two items already require this
   (`Trigger.dev Personal Access Token (management)`, and now this one).
3. **Treat `mcp.env.example` drifting from the deployed `mcp.env` as a live defect.**
   The repo was already correct here and the machine was still broken; nothing
   compared them. A periodic diff of the reference *names* (never the values) would
   have caught this before the outage.
4. **Keep `setup-machine.ps1` and `config/mcp.env.example` spelling the same
   `op://` reference identically** — remote servers match it as a literal string
   (§9a). A UUID-vs-title mismatch is silently fatal.
5. **Read the failing set before debugging individual servers.** "Exactly the
   secret-launched servers" is a signature that points at one line in one file.

## 8. Second fault: a restart "didn't work" — `setup-machine.ps1` undid the fix

After every config was corrected and the clients restarted, the same
`designflow-mcp` error came back. Nothing regressed on its own:

**`bin/setup-machine.ps1` ran from `main` at 09:57 local and rewrote all three
client configs with the stale name.** The repo fix was sitting on an unmerged
branch, so the canonical writer still carried the old reference — exactly the
resurrection §4 warned about, arriving before the branch was merged. Its own
backups (`*.aidevops.<timestamp>.bak`) are what date the run.

**Rule this establishes: a config fix is not finished until the writer is merged to
`main`.** Hand-editing `~/.claude.json`, the Desktop config, or `config.toml` only
holds until the next setup run. Merge first, then fix the live files.

**Correction to an earlier note in this file's history:** `setup-machine.ps1` *does*
write Codex's `~/.codex/config.toml` — the 09:57 run reverted it along with the
Claude configs. An earlier draft said it did not.

## 9. Third fault: `recall-ai` — two problems, one still open

### (a) A reference mismatch that could never have worked — FIXED

Remote-mode servers hit a second check the batch failure had been masking.
`bin/mcp-secret-launch.ps1:99` looks the `op://` argument up in `mcp.env` **by exact
string match** and throws `Secret reference is not managed by ...` on any difference.

`setup-machine.ps1` passed recall-ai's token as the item **UUID**
(`dwvlpanu4odty3bjnmb5my5esy/password`) while `mcp.env` declared the same secret by
**title** (`recall-ai MCP/password`). Same secret, different spelling, so recall-ai
could never start — a latent bug, invisible until the stale-name failure upstream was
cleared. Now aligned to the title form in both files.

> **When adding a remote MCP server, the `op://` string in `setup-machine.ps1` must
> be byte-identical to the one in `config/mcp.env.example`.** UUID vs title is not
> interchangeable here, even though `op` resolves both.

### (b) Recall.ai is blocking the account server-side — NOT FIXED, needs Albert

With the reference fixed, recall-ai gets past every local check and is then refused
by Recall.ai itself:

```
HTTP 403 {"code":"request_blocked","detail":"Request was blocked due to security
rules. This is likely due to providing a localhost URL in your payload."}
```

The stated reason is misleading — the block is **not** about localhost and not about
our config:

- A plain `curl` containing no URL of any kind gets the same 403.
- All four `mcp-remote` transports (`http-first`, `http-only`, `sse-first`,
  `sse-only`) fail identically, so it is not the transport.
- **A deliberately wrong token returns 401, while the stored token returns 403.** The
  token therefore authenticates successfully and is then blocked — the credential is
  valid and correctly stored.
- `us-west-2` and `eu-central-1` return 401 (regions are separate accounts), so
  `us-east-1` is the right endpoint.

Tracked as issue #68. This is an account- or workspace-level rule on Recall.ai's side. It cannot be
repaired from configuration; it needs Recall.ai's dashboard or their support. The MCP
entry is left in place and working up to that point — **not** removed or disabled.

## 10. Follow-on finding: the NAS bearer was never missing

While fixing the above, the `nas-monitor-secrets` item in `vibe_coding` was found to
carry a field asserting that the live client→nas-mcp bearer is **not** stored in
1Password and must be fetched from Coolify. **That is no longer true**, and acting on
it wastes a session.

**Verified 2026-08-24.** The Coolify env var `MCP_BEARER_TOKEN` on the nas-mcp app
(`efl17f5iocnz94840pexre9d` on hetz, serving `nas-mcp.designflow.app`) and the vault
field `op://vibe_coding/f335s4oy3m6n74jmwj74hunrtu/nas_token` have **identical
SHA-256 hashes** — same 64-character value. The app accepts exactly one token
(`/app/apps/nas-mcp/dist/index.js:416` compares the request header against
`MCP_BEARER_TOKEN`), and a deliberately wrong bearer returns `401 Unauthorized`, so
the enforcement is real and the stored value is the live one.

Comparison was done by hash on each side; **the value itself was never printed,
transported, or written anywhere.**

> **Method warning that nearly caused a wrong conclusion.** A first attempt piped the
> value through `tee >(wc -c)` inside an `ssh` command. The remote shell does not
> support process substitution, so `tee` treated `>(wc` as a filename and corrupted
> the stream — producing a *different* hash and the false impression that Coolify held
> a second, unstored token. **Fingerprint with a plain `| sha256sum` pipeline only**,
> and re-verify any "these differ" result before acting on it.

**Nothing needs copying.** Adding a second copy of a live credential is how the two
drift apart; the correct fix is to correct the stale pointer text, not duplicate the
secret.

**Done 2026-08-24.** The `nas-monitor-secrets` notes and its stale pointer field now
name the correct location. The seven secret fields were re-checked afterwards and are
unchanged (64 chars each).

### `op` CLI writes appear to hang — it is waiting on stdin

Worth knowing, because it looks exactly like a broken permission and wasted time
here. `op item edit` and `op item create` **hang forever when stdin is left open**,
which is the default in most agent/CI shells. There is no error and no timeout — the
CLI simply waits. Reads (`op read`, `op item get`) are unaffected.

**Redirect stdin from /dev/null on every `op` write:**

```bash
op item edit <id> --vault vibe_coding "field[text]=value" < /dev/null
```

The same edit that hung twice completed instantly with `< /dev/null`. Do not
conclude from a hang that the service account has lost write permission.

## 11. Related reading

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
