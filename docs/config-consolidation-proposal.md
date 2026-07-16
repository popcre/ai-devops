# Proposal — converge all machine config onto ai-devops (phased)

**Status:** Phase 1 SHIPPED (2026-07-10, commit `28c44bc`). **Phase 2 built
2026-07-14** (commits `5868f19`→`26c176f`): 2a/2b/2c shipped; 2d (token rotation)
still open. **Adopted + verified on t16 2026-07-15.** Phase 3 PLANNED, not started.
**Companion docs:** [`config-inventory.md`](config-inventory.md) (the current
scattered state, with all paths/aliases/1Password item titles) and
[`../HANDOFF.md`](../HANDOFF.md) (live next steps).

## Goal
Make `ai-devops` the **single hub** that configures every machine (3 Windows dev
boxes + Ubuntu server[s]) on both OSes, ideally with **one install/update
command** — and retire the scattered Dropbox scripts. **No new tools** (no
chezmoi): reuse the `install.sh` / `install-ai-devops-windows.ps1` /
`bin/ai-install-skills` machinery that already exists and already runs on both
OSes.

### Why not chezmoi (decided 2026-07-10)
chezmoi is a separate sync system that would **duplicate** ai-devops's installer
machinery, and pointing its source dir at a subfolder of this **1.5 GB** repo
would force every machine (incl. servers) to clone 1.5 GB for a few KB of
dotfiles. It also can't auto-resolve cross-machine conflicts and would happily
commit a secret. ai-devops already does per-machine config, both OSes, and
never-clobber semantics. Do not revisit chezmoi.

## Principles
1. **One hub.** If it configures a machine, it lives in or is installed by
   `ai-devops`.
2. **Secrets from 1Password at install time — never committed.** Installers pull
   tokens/keys live from the `vibe_coding` vault (via the scoped service account
   or `op` CLI with `op://` references) and write them to machine-local files.
   The repo stays secret-free (consistent with `AGENTS.md` §Credentials).
3. **Never clobber machine-local values** (same rule as `config/*.env.example`
   → `/etc/ai-devops/`).
4. **Portable-only.** Sync prefs and shared config; leave per-install runtime
   paths (e.g. most of `config.toml`) alone.
5. **Idempotent + `--dry-run`.** Every new script re-runs safely and previews.

---

## Phase 1 — quick wins ✅ SHIPPED (commit `28c44bc`)

| Item | Deliverable | State |
|---|---|---|
| `sync-dotfiles` skill | `skills/claude/sync-dotfiles/SKILL.md` + `skills/codex/codex-sync-dotfiles/SKILL.md` | done; installed on t16 and `916-alien` |
| gcloud dflow defaults | `bin/ai-gcloud-dflow` | done; dry-run verified |
| Memory sync | `bin/ai-sync-memory` + `memory/` tree + `memory/project-map.tsv` | done; dry-run verified; first real push from `916-alien` committed in `c6c6ee3` |
| Docs | this file + `config-inventory.md` + AGENTS.md rows | done |

**What "sync my dotfiles" does now:** pull ai-devops → `ai-sync-memory pull` →
`ai-install-skills` → `ai-gcloud-dflow` → `ai-sync-memory push` → commit+push.
Directions: skills/instructions are repo→machine (repo is source of truth);
memory is two-way (git-merged); gcloud is apply-only. Full procedure in the
skill file.

**Exit criteria (met for implementation and first push):** "sync my dotfiles" on any machine
pulls latest skills + instructions + memory and pushes local changes; gcloud is
correct everywhere the tool is installed.

**Follow-through still owed on Phase 1** (in HANDOFF §6): run the installer and
memory sync on the remaining machines so each receives the skill and
`ai-gcloud-dflow`, then contributes any machine-only memory to the hub.

---

## Phase 2 — fold in the Dropbox scripts (medium risk) — 2a/2b/2c SHIPPED, 2d OPEN

**Built 2026-07-14** (commits `5868f19`→`26c176f`), adopted + verified on t16
2026-07-15. Delivered as two unified onboarding scripts rather than direct ports:
- **[`bin/setup-machine.ps1`](../bin/setup-machine.ps1)** (Windows) — base tools,
  skills/globals install, service-account token file, `mcp.env`, MCP launchers,
  916-alien key restore, SSH aliases, Claude Desktop MCP wiring, memory-sync task.
- **[`bin/setup-secrets.sh`](../bin/setup-secrets.sh)** (Ubuntu) — the secret
  plumbing half (token file, `mcp.env`, shell snippet, legacy cleanup, verify).

Below is the original design; ✅/⬜ marks what's done. The one hard part —
**secret plumbing** — is solved: nothing embeds a secret; everything pulls from
1Password at launch via the vault-locked service account.

### 2a. Secret-plumbing helper (build first) — ✅ SHIPPED
Chosen approach: **`op` CLI + a vault-locked service-account token file**
(`~/.config/ai-devops/op-service-account`, chmod 600 / user-only ACL) plus a
committed **`config/mcp.env.example`** of `op://` references. Ubuntu resolves them
via `op run --env-file mcp.env`; Windows via generated `.cmd` launchers. Answers
open decision #4 in favor of the `op` CLI.
A small helper (bash + PowerShell parity) that reads a named 1Password item from
the `vibe_coding` vault and writes it to a machine-local path, never echoing the
value. Design options:
- **`op` CLI with `op://vault/item/field` references** (`op read`, `op run`), or
- the scoped **service-account token** already used by the MCP.

Acceptance: `helper get "<item title>" <dest-path>` writes the secret with correct
perms and prints only "wrote <dest> (N bytes)".

### 2b. SSH setup → `bin/` — ✅ SHIPPED (Windows)
Delivered as steps 5b/5c of `setup-machine.ps1` + committed
[`config/ssh-config.template`](../config/ssh-config.template) (installed as
`~/.ssh/ai-devops.conf`, `Include`d at the end so existing entries win). The
916-alien key is pulled from the `916-alien SSH key` 1Password item (added to the
vault first, as required). Cloudflared is the primary path so `ssh vps` works on
any network. Ubuntu SSH parity (open decision #3) still deferred.
Original plan below.

Move `master_setupsshwindows.ps1` into `bin/ai-setup-ssh-windows.ps1` (+ an
Ubuntu equivalent if the servers need the alias set — open question). Changes:
- Host-alias blocks become repo-tracked (they're non-secret).
- **The `916-alien` private key is pulled from 1Password**, not embedded. This
  requires first **adding the key to the `vibe_coding` vault** (it isn't there
  yet — see `config-inventory.md`).
- Keep the Windows ACL-fix logic verbatim (owner + SYSTEM + Administrators).

Acceptance: on a fresh Windows box, running it produces a working `~/.ssh/config`
+ key with correct perms, `ssh coolify` connects, and no secret is in the repo.

### 2c. MCP setup → `bin/` — ✅ SHIPPED (Claude Desktop)
Delivered as step 6 of `setup-machine.ps1`: supabase (stdio) + devops-mcp and
synology-monitor (remote, via the `mcp-remote` shim) are wired with **no token in
the config** — the launchers resolve `op://` bearer tokens at launch. Verified
that Claude Desktop does not expand `${VAR}`, so tokens are resolved to real
values by `op` inside the launcher, not by placeholder substitution.
Original plan below.

Move `setup-claude-mcps.ps1` / `setup-codex-mcps.ps1` into `bin/`. The MCP server
shapes become repo-tracked; **all tokens are pulled from 1Password** by the 2a
helper (items: `vibe_coding-service-account`, `devops-mcp-client-tokens`,
`nas-monitor-secrets`, `Trigger.dev Personal Access Token (management)`, etc.).

Acceptance: running it writes `~/.claude/settings.json` with working MCP servers,
tokens sourced live, and the repo contains no token.

### 2d. Hygiene — rotate exposed tokens — ⬜ OPEN (partially done?)
The Trigger PAT and the two MCP bearer tokens sat in plaintext in `settings.json`
(and in an archived transcript). Rotate them as they move to 1Password sourcing.
**Status 2026-07-15:** the `designflow-mcp` item (which now holds the devops-mcp
and NAS bearer tokens) was updated 2026-07-14 17:20 and tagged `mcp-rotation`,
suggesting the two MCP bearers were already rotated. The **Trigger PAT**
(`Trigger.dev Personal Access Token (management)`) was last updated 2026-07-09 —
**appears NOT yet rotated.** Confirm with Albert before rotating (rotation can
break live integrations; needs his approval + click-through).

**Exit criteria:** a fresh machine is fully configured (SSH + MCP + skills +
instructions + gcloud + memory) from ai-devops alone, all secrets sourced from
1Password, nothing secret committed.

**Rollback:** the Dropbox scripts stay in place and untouched during Phase 2, so
reverting is "keep using Dropbox." Don't delete them until Phase 3.

---

## Phase 3 — retire Dropbox + document (low risk) — PLANNED

| Item | Deliverable |
|---|---|
| Retire Dropbox scripts | Replace their contents with a stub/README pointing at ai-devops; stop editing them |
| One-command onboarding | Update `docs/restore-from-zero.md` + a Windows quick-start so a new machine is "clone ai-devops → run installer → done" |
| Portable Codex prefs | Track the ~5 portable `config.toml` lines (`model`, `model_reasoning_effort`, `[windows] sandbox`, `[desktop]` prefs) as a template; apply without clobbering runtime paths |
| Update machine-atlas | Reflect the single-path setup in `templates/system/machine-atlas.md` |

**Exit criteria:** Dropbox is no longer a config source; restore/atlas docs
describe the single path; `HANDOFF.md` can be deleted (project complete).

---

## Suggested ordering & effort
- Phase 1 follow-through (propagate + collect remaining machine memory): do next.
- Phase 2a helper: the keystone — build and test in isolation first.
- Phase 2b/2c: after 2a; test each on ONE machine before rolling out.
- Phase 3: only after Phase 2 is proven on all machines.
Batch 1-follow-through + 2a in one sitting; keep 2b/2c/3 as separate, verified steps.

## Open decisions (need owner input)
1. **Memory sync target:** DECIDED — straight into `ai-devops/memory/`.
2. **Secret source:** DECIDED — scoped `vibe_coding` 1Password service account,
   incl. the `916-alien` SSH key (which must first be added to the vault).
3. **Windows vs Ubuntu SSH parity:** OPEN — do the servers need the full alias set?
4. **`op` CLI vs service-account token** for the 2a helper: OPEN — pick one.

## Non-goals
- No chezmoi or second sync system.
- No syncing of per-install runtime paths or the large chat archives beyond what
  already happens.
- No committing of any secret, ever.
