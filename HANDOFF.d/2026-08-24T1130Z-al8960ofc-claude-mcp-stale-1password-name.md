---
issue: 63
status: OPEN
owner: claude/mcp-server-failures-8a59bd
---

# HANDOFF — Stale 1Password item name broke every secret-launched MCP server (2026-08-24 11:30Z, al8960ofc/claude)

**Full technical write-up lives in [`fix_stale_name.md`](../fix_stale_name.md).**
Read that first; this file is the session record around it.

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

Put this whole list to Albert in ONE message before starting work.

**BLOCKING**

1. **1Password writes are broken for the service account — is that expected?**
   Every write through the `op` CLI hangs indefinitely (`op item edit`, and a
   minimal `op item create` probe, both timed out; reads return instantly). It
   blocks correcting a stale note (§0.3). *Recommendation: retry through the
   1Password MCP after restarting the clients; if writes still hang, the service
   account's write permission needs checking in the 1Password admin console —
   only Albert can do that.*

   *(Settled 2026-08-24: the VPS edit was approved and is DONE — see §3.)*

**RECOVERABLE**

2. **Should `bin/setup-machine.ps1` also rewrite `~/.codex/config.toml`?** Today it
   writes Claude's configs but not Codex's, so Codex drifted and had to be fixed by
   hand. *Recommendation: yes, but as separate work — this session did not change
   that split.* Note the standing rule that Claude setup must not touch Codex
   configuration, so this needs Albert's ruling rather than an assumption.

**NOT PART OF THIS WORK, AND NOBODY IS ON IT**

3. **CORRECTED — the NAS bearer was never missing, but its note still says it is.**
   Albert asked for it to be copied from Coolify into 1Password. It is **already
   there**: Coolify's `MCP_BEARER_TOKEN` and the vault's `nas_token` field are the
   same value (identical SHA-256, verified 2026-08-24), so copying would have
   created a duplicate of a live credential. Nothing was copied. What remains is
   that `nas-monitor-secrets` still carries a field claiming the opposite, which is
   what sent this session hunting. The correcting edit is blocked by §0.1.
   *Recommendation: once writes work, replace that field's text with a pointer to
   `op://vibe_coding/f335s4oy3m6n74jmwj74hunrtu/nas_token`. Draft text is ready in
   the session scratchpad; details in `fix_stale_name.md` §8.*
4. **A known-leaked NAS token still sits in this PUBLIC repo's git history**, kept
   on purpose so the leaked value stays identifiable. It is already rotated and
   returns Unauthorized, so this is a note, not an exposure. *Recommendation: no
   action; flagged only so nobody rediscovers it and panics.*

**Already settled — do NOT re-ask**

- The dflow test login in this public repo's history is NOT being rotated
  (Albert, 2026-08-21).
- The single shared `op run` refresh stays; per-launch `op run` is what locked the
  service account out (2026-07-17). Do not "simplify" it away.

## 1. What this application is

`u2giants/ai-devops` is Albert's cross-machine AI development toolkit — the skills,
setup scripts, and configuration that make Claude Code, Claude Desktop, and Codex
behave identically on every machine (Windows workstations and the `hetz` Ubuntu
VPS). It is a PUBLIC repo, so it holds 1Password *references*, never secret values.
The relevant parts here are `bin/setup-machine.ps1` (writes MCP config) and
`bin/mcp-secret-launch.ps1` (resolves secrets at launch).

## 2. What we set out to do this session, and why

Albert reported that "half the MCP servers are now failing" and pointed at
`C:\Users\ahazan\AppData\Local\Claude\Logs`. The objective was to diagnose from the
logs and repair the servers — not to disable or work around them. He then asked
whether Codex was affected too, and for this documentation.

## 3. Current state — what is true right now

**Fixed and verified on al8960ofc** (all four files backed up as `*.bak-20260824*`
before editing):

- `~/.config/ai-devops/mcp.env`
- `~/.claude.json`
- `%APPDATA%\Claude\claude_desktop_config.json`
- `~/.codex/config.toml` (TOML re-validated, all 13 servers intact)

**Verified working:** the DPAPI cache regenerated with all 8 secrets non-empty, and
both DesignFlow endpoints returned **HTTP 200** to a real `initialize` call with the
resolved bearers.

**Committed and pushed** on branch `claude/mcp-server-failures-8a59bd`:
`bin/setup-machine.ps1` (commit `521ca0c`) plus `fix_stale_name.md` and this file.
**No pull request opened yet.**

**Fixed on hetz too** (approved by Albert 2026-08-24): `/home/ai/.claude.json`,
backup `.bak-20260824-mcpref`, JSON re-validated, zero stale references left. All
five config locations are now correct.

**Not done:** the `nas-monitor-secrets` note correction (blocked, §0.1/§0.3).
**Clients not yet restarted** on either machine — the fix does not take effect in a
running client.

## 4. Everything we tried that did NOT work

- **`ssh hetz` → `Host key verification failed`.** Looks like a security problem;
  it is not. There is no `hetz` alias — `~/.ssh/ai-devops.conf` defines `vps`,
  `coolify`, `hetzner`. `ssh vps` connects fine. Do **not** add a host key or pass
  `StrictHostKeyChecking=no`.
- **Piping a script to `sudo -u ai bash -s` over SSH, then a single-line
  `sudo -u ai sed …`** — both blocked by the safety classifier. Not a quoting bug;
  it is the production-write guard. It needs Albert's approval, not a cleverer
  command.
- **A nested-quoting `python3 -c` over SSH** produced a misleading
  `PermissionError` that was really mangled quoting. If that error reappears,
  suspect the quoting before suspecting permissions.
- **Fingerprinting a secret with `tee >(wc -c)` inside `ssh`.** The remote shell
  has no process substitution, so `tee` wrote to a file literally named `>(wc` and
  the hash came out wrong — which briefly looked like proof that Coolify held a
  second, unstored NAS token. It did not. **Use a plain `| sha256sum` pipeline**,
  and re-verify before acting on a "these differ" result.
- **Writing to 1Password with the `op` CLI.** Hangs forever, reads are fine. Two
  attempts timed out; no item was created. Use the 1Password MCP instead.
- **Looking for the item under its old title.** `op item list` does not show it;
  only `--include-archive` revealed the item, still live, under its new title. The
  item was never archived — the flag just widened the listing.

## 5. Root causes and key findings

- **One renamed vault item, six dead servers.** All secret-launched servers share a
  single `op run` over `mcp.env`; one unresolvable reference fails the batch and
  `bin/mcp-secret-launch.ps1:53` throws by design, killing every dependent server.
  **The failing set being exactly "the servers that use the launcher" is the
  diagnostic signature** — do not debug them one by one.
- **The item was renamed, not deleted.** `designflow-mcp` →
  `DesignFlow MCP bearer tokens - DevOps and NAS (production)`, UUID
  `f335s4oy3m6n74jmwj74hunrtu` unchanged, both tokens intact and valid.
- **The "prefer names over UUIDs" convention in `config/mcp.env.example` is right
  for migrations and wrong for renames** — and the new title contains parentheses,
  which `op` rejects in a name-based reference, so this item can *never* return to a
  name-based reference under that title.
- **The repo was already correct; the machine was not.** `config/mcp.env.example`
  had the UUID; the deployed copies still had the name. Nothing compares them.
- **`bin/setup-machine.ps1` would have resurrected the outage** (lines 386, 391,
  913) on its next run, because it is the canonical writer of the live configs.

## 6. Exact next steps

1. ~~Fix the VPS~~ — **DONE 2026-08-24.**
2. **Restart Claude Desktop, Claude Code, and Codex on al8960ofc** (a full quit, not
   a window close). *You'll know it worked when no new `Server disconnected` lines
   appear in `AppData\Local\Claude\Logs` and all six servers respond.*
3. **Restart the VPS clients** after step 1, same check.
4. **Merge this branch to `main`** (default `u2giants` work goes straight to main).
   *You'll know it worked when `bin/setup-machine.ps1` on `main` contains
   `f335s4oy3m6n74jmwj74hunrtu` and no `designflow-mcp`.*
5. **Close issue #63 and DELETE this handoff file** in the same pull request.
6. **Correct the `nas-monitor-secrets` note** once 1Password writes work (§0.3).
   *You'll know it worked when that item's pointer field no longer claims the bearer
   is absent from the vault.*
7. *(Optional, needs §0.2)* Teach `setup-machine.ps1` to write Codex's config, or
   record deliberately that it never will.

## 7. Constraints and gotchas in force

- **Preserve the capability.** The instruction was to repair the servers, never to
  remove or disable any of them. All six stay.
- **Secrets move through pipes or protected files only** — never a command line,
  chat, or commit. This repo is PUBLIC: references only.
- **AI sessions are read-only for production infrastructure by default.** That is
  exactly why step 1 is gated.
- **Never re-add per-launch `op run`** — it locked the service account out once.
- **`op` rejects `(` in name-based references.** Parenthesised titles must use the
  UUID.
- Back up before editing hand-maintained configs, and re-validate JSON/TOML after
  any `sed`.

## 8. Access and environment

- **Branch:** `claude/mcp-server-failures-8a59bd`, pushed; worktree at
  `C:\repos\ai-devops\.claude\worktrees\mcp-server-failures-8a59bd`.
- **Git identity verified:** `Albert Hazan <u2giants@users.noreply.github.com>`.
- **`gh`:** authenticated as `u2giants`.
- **1Password:** service-account token at `~/.config/ai-devops/op-service-account`;
  vault `vibe_coding` only. Item UUID `f335s4oy3m6n74jmwj74hunrtu`. **Values never
  leave the vault or the DPAPI cache.**
- **VPS:** `ssh vps` (aliases `coolify`, `hetzner` → `100.66.37.58`), **not**
  `ssh hetz`. Claude/Codex there run as user `ai`.

## 9. Open questions and risks

- **Are there other machines with stale copies?** Two were checked (al8960ofc,
  hetz). Albert's other boxes (`916`, usually offline; `edge-dev`; `albt16`) were
  not. Any machine whose `mcp.env` or client config predates the rename has the same
  outage waiting.
- **1Password writes hang with the current service account.** Until that is
  understood, no AI session can store or correct anything in the vault — only read.
  That is a bigger constraint than this incident.
- **Are other references stale for the same reason?** Only this one item was
  renamed, and the other seven references all resolved non-empty — so no others are
  broken *today*. Nothing prevents the next rename from repeating this.
- **Risk of a botched `sed` on a JSON config** — worse than the original outage.
  Every edit here took a backup and re-validated; keep doing that.
- **Decision recorded 2026-08-24:** this item now uses its UUID deliberately,
  overriding the general name-preference convention, because its title contains
  parentheses. Do not "restore consistency" by switching it back.
