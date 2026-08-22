# Config inventory — where every machine-level config actually lives

**Purpose:** a durable, exhaustive map of all the AI-tool, shell, SSH, and cloud
config spread across Albert's machines, so no future session (human or AI) has to
rediscover it the hard way. The completed consolidation reasoning and failed
approaches are retained in [`config-consolidation-proposal.md`](config-consolidation-proposal.md)
and [`../plan_phase3-config-consolidation.md`](../plan_phase3-config-consolidation.md).
Read this to answer "where does X config live,
what manages it, and is it synced?"

**Audience:** a developer or AI with zero prior context. Terms and paths are
defined inline.

## Repo-owned local AI commands

`config/machine-tools.tsv` is the one list of skill-taught AI command launchers.
`bin/ai-machine-tools-doctor` checks that list without calling a model or reading
credentials. `bin/install-machine-tools.ps1` repairs the Windows Bash and cmd
launchers in `%USERPROFILE%\.local\bin`; `bin/install-machine-tools.sh` repairs
catalog links on Ubuntu. Windows `ai-glm.cmd` remains owned by
`setup-opencode-glm.ps1`. Missing optional provider programs `grok` and `kimi`
are reported as information, not as broken repo launchers. `ai-install-skills`
also runs a fail-closed bootstrap check so a sync using an older loaded skill
cannot quietly claim complete after pulling a newer command catalog.

**One-line summary:** config is spread across **three overlapping sync systems
plus several things synced by nothing**. `ai-devops` (this repo) is the intended
long-term single hub; the migration plan is
[`config-consolidation-proposal.md`](config-consolidation-proposal.md).

> ⚠️ **No secret values in this doc.** Secret-bearing files are named by type,
> and secrets are referenced by their **1Password item title** only. Real values
> live in the 1Password `vibe_coding` vault and in machine-local files that are
> never committed.

## Machines in scope

| Machine | Alias / hostname | OS | Role |
|---|---|---|---|
| 916 | "916-alien" | Windows 11 | dev box |
| t16 | `albt16` | Windows 11 | dev box (this repo's usual checkout) |
| 4837 | — | Windows 11 | dev box |
| Ubuntu server(s) | e.g. `hetz`, `seafile`, `comp` | Ubuntu | dev via Claude/Codex CLI over SSH + host workloads |

User `ahazan2` on Windows; PowerShell 7 primary with git-bash available (bash
tools run via git-bash on Windows).

## The map (top level)

| Location | What it holds | Synced across machines by | Secrets? |
|---|---|---|---|
| **Public `ai-devops` repo** | Reusable skills, global templates, workflow configuration, installers, and the secret-free portable-memory schema/tooling | ✅ git + canonical installer | No; operational facts and transcripts are forbidden |
| **Private `ai-devops-memory` repo** | Portable Claude Markdown facts and complete per-project indexes | ✅ transactional `bin/ai-memory-sync` | No credentials; private operational facts only |
| **Dropbox `\vibe coding\ssh keys\`** | `master_setupsshwindows.ps1` → writes `~/.ssh/config` (all host aliases) + the `916-alien` private key + optional cloudflared | ⚠️ manual script | **Yes — plaintext private key** |
| **Dropbox `\vibe coding\…MCP servers\`** | `setup-claude-mcps.ps1` / `setup-codex-mcps.ps1` → write MCP server entries into Claude/Codex config | ⚠️ manual scripts | **Yes — embed tokens** |
| **`~/.claude.json`** | Claude Code's local MCP server list. **This is the only file Claude Code reads MCP servers from** — an `mcpServers` block in `~/.claude/settings.json` is silently ignored (fixed 2026-08-20; before that both setup scripts wrote to the wrong file, so machines had zero working servers while looking configured). | ✅ `bin/setup-machine.ps1` (Windows), `bin/setup-secrets.sh` (Ubuntu) | No — only `op://` references and launcher paths |
| **`~/.claude/settings.json`** | Claude Code prefs: permissions, hooks, theme, push-notif / auto-update. **Not** MCP servers. | ✅ `bin/ai-claude-permissions` merges the permission allow-list | No |
| **Claude Desktop config** | Claude Desktop settings + local MCP servers | ✅ `bin/setup-machine.ps1` manages the full MCP set; `bin/configure-claude-desktop-chrome-devtools.ps1` safely installs or repairs only Chrome DevTools MCP | Existing settings and hand-added extensions are preserved; a backup is written before changes |
| **`~/.codex/config.toml`** | Codex prefs + machine-specific runtime paths + MCP server list | ✅ new configs seed from `config/codex-portable.toml`; `bin/configure-codex-mcps.ps1` then reconciles the complete repo-owned MCP set from `setup-machine.ps1`, while preserving unrelated machine settings and tool approval guards | Machine-specific paths/plugins remain local; managed MCP blocks are token-free |
| **MCP secret launcher** (`~/.config/ai-devops/mcp-launch.cmd` + `mcp-remote-launch.cmd` → `bin/mcp-secret-launch.ps1`) | Injects `op://` secrets into MCP servers via **one single-flight refresh + 15-min DPAPI cache** (`mcp-secrets.dpapi.json`), not a per-launch `op run`. Caps the shared service account to ≤1 refresh/15 min/machine | ✅ `bin/setup-machine.ps1` writes the `.cmd`s; `bin/mcp-secret-launch.ps1` is repo-owned | No secret on disk except the user-only `op-service-account` token file; cache is DPAPI-encrypted. See [mcp-1password-rate-limit-hardening.md](mcp-1password-rate-limit-hardening.md) |
| **`~/.claude/projects/*/memory/`** | Auto-memory (per-project `MEMORY.md` + fact files) | ✅ `bin/ai-memory-sync` ↔ private `u2giants/ai-devops-memory` | No credentials; automated push proves private visibility first |
| **gcloud config** (`%APPDATA%\gcloud` / `~/.config/gcloud`) | Default project/region for `gcloud` | ⚠️ per-machine; set by `bin/ai-gcloud-dflow` | Contains auth tokens — never git-sync the dir |
| **1Password `vibe_coding` vault** | The actual secrets (tokens, keys, DB creds, logins) | ✅ centralized (the one thing done right) | **Yes — the source of truth** |
| **`/etc/ai-devops/*.env`** (Ubuntu) | Real workflow model commands + paths | ❌ machine-local by design (never committed) | Non-secret command strings |
| **`/etc/ai-devops/config-state.json` + `install-manifest.tsv`** | Applied config schema/source SHA and exact managed-artifact hashes | ✅ regenerated by `install.sh`; machine-local evidence | No |
| **User `PATH` → Codex** (Windows) | Which `codex.exe` a terminal resolves — and therefore whether `codex exec` can write at all | ✅ `bin/setup-machine.ps1` step "Codex PATH" prepends `%USERPROFILE%\.codex\packages\standalone\current\bin` | No |
| **`codex-cli` MCP entry** (Claude Desktop config + `~/.claude.json`) | Lets Claude call Codex as a tool (`codex`, `codex-reply`) instead of shelling out | ✅ Windows: `bin/setup-machine.ps1`; Ubuntu: `bin/setup-secrets.sh` | No — Codex carries its own `codex login`, so it is **not** wrapped in the op launcher and never touches `mcp.env` |
| **Railway CLI + hosted MCP** | Manages Railway projects from the terminal and gives Claude/Codex OAuth-based Railway tools at `https://mcp.railway.com` | ✅ Windows bootstrap installs `@railway/cli`; `bin/setup-machine.ps1` adds Railway to the shared MCP set and gives Codex Railway's authenticated CLI proxy | No repo secret — CLI and MCP use Railway's interactive login/OAuth |
| **Kimi Code CLI** (`kimi`) | Optional local delegation target used by the shared `kimi-code-delegation` skill | ⚠️ Skill is synced by `ai-devops`; CLI install/auth are per-machine. Windows setup installs `ai-kimi` launchers in `%USERPROFILE%\.local\bin` for both PowerShell and Git Bash | No repo secret — Kimi carries its own interactive login |
| **Grok Build CLI** (`grok`) | Optional xAI coding-agent target used by the shared `grok-cli` skill | ⚠️ Skill is synced by `ai-devops`; this machine's native install, docs, config, sessions, and login live under `%USERPROFILE%\.grok`; `%USERPROFILE%\.grok\bin` is on User PATH. Windows setup also installs `ai-grok-review` and `ai-grok-implement` launchers in `%USERPROFILE%\.local\bin` for both PowerShell and Git Bash, so neither wrapper depends on the repo `bin/` being on PATH | No repo secret — never read or sync machine-local `.grok/auth.json` |
| **Qwen Code CLI** (`qwen`) | Optional Qwen coding-agent target used by the shared `qwen-code` skill | ⚠️ The CLI and OAuth login remain per-machine. `ai-qwen` is repo-owned and installed on Windows for PowerShell and Git Bash and on Ubuntu as a normal command. It provides exact named sessions, read-only reviews, bounded runs, and sandboxed disposable-worktree implementation | No repo secret. Qwen stores its own login and project-scoped sessions under `~/.qwen` |
| **GLM sessions** (`ai-glm`) | Named, persistent GLM-5.3 sessions on a loopback-only OpenCode server; read-only reviews and worktree-isolated implementation | ✅ repo-owned client, pinned OpenCode, canonical agents, systemd user service, `ai-glm doctor` | Z.ai key stays in 1Password; only an `op://` reference is distributed |
| **Muse conversations** (`ai-muse`) | Named, persistent Muse Spark 1.2 Contributor reviews and debates in a disposable self-contained copy | ✅ repo-owned direct-session runner, exact session resume, pinned OpenCode, evidence packet, `ai-muse doctor` | Meta key is read from the `vibe_coding` 1Password item at turn time; persistence uses the exact session ID and needs no long-running Muse service |
| **DeepSeek debates** (`ai-deepseek-agent`) | Bounded text-and-file debates used by the shared `deepseek-second-opinion` skill | ✅ repo-owned wrapper and skill; each turn resends the stored conversation | DeepSeek key stays in 1Password; only its `op://` reference is distributed |

The completed reconciliation plan is [`plan_sync-machine-wrapper-reconciliation.md`](../plan_sync-machine-wrapper-reconciliation.md). The command catalog now covers Grok, Kimi, Qwen, GLM, and DeepSeek launchers.

## GLM: persistent sessions on a local OpenCode server

`ai-glm` talks to a pinned OpenCode server bound to `127.0.0.1` and running as a
systemd user service. Claude Code is no longer involved. The server uses
OpenCode's built-in `zai-coding-plan` provider against Z.ai's Coding Plan
endpoint, with the key resolved from 1Password at launch. Sessions are named and
persistent; review sessions have no write, edit, patch or bash tool, and
implementation runs in a throwaway git worktree. Full detail:
[glm-opencode.md](glm-opencode.md). The paragraph below describes the retired
`ai-glm-agent` design and is kept only as history:

Previously `ai-glm-agent` used Claude Code as the agent runtime, sending only that child
process to Z.ai's Anthropic-compatible Coding Plan endpoint. It cleared inherited
Anthropic credentials, used an isolated Claude config directory, requested the
configured GLM model explicitly, and checks Claude Code's returned model record.
Normal `claude`, Claude Desktop, and Codex sessions remain on their existing
providers. Review mode is read-only (`plan`); implementation mode is available
only when explicitly requested. Canonical secret: `GLM z.ai API/credential` in
the `vibe_coding` vault.

## DeepSeek: text-and-file debate transport

`ai-deepseek-agent` is the supported DeepSeek transport. It preserves a
multi-turn thread by resending conversation history, but advances the stored
conversation only after the provider returns successfully: a turn is locked,
then the user and assistant messages are replaced atomically as one update.
Session names and resolved storage paths are contained under the repository's
private `.ai/deepseek-sessions/` folder. Formal `--review` turns additionally
require a usable verdict and save exact-session/exact-HEAD metadata. It can
attach explicitly named files, but does not give DeepSeek general repository
access. The proposed
Codex custom-provider profile was cancelled on 2026-08-10: Codex 0.145.0 accepts
only the Responses API wire format for custom providers, while DeepSeek's
documented tool-calling surface is Chat Completions. No safe common wire format
was available, so no machine `config.toml` was changed.

## Codex: PATH + MCP (added 2026-07-16)

Two related facts that are easy to get wrong, both now automated.

**1. Which `codex.exe` PATH resolves decides whether Codex works at all.**
On Windows the standalone installer puts `%LOCALAPPDATA%\Programs\OpenAI\Codex\bin`
on PATH, but that dir is a **junction** to
`%USERPROFILE%\.codex\packages\standalone\current\bin`. Only `bin` is linked, so the
package's sibling `codex-resources\` (which holds
`codex-windows-sandbox-setup.exe`) is unreachable from it, and every sandboxed
`codex exec` fails with `program not found` — **while `codex --version` and
`codex login status` still exit 0**. `setup-machine.ps1` fixes this by putting the
real package bin first on the user PATH (`current` is a junction the updater
re-points, so it survives upgrades) and then *proving* it with a real write.
Upstream bug: [openai/codex#32655](https://github.com/openai/codex/issues/32655).

**2. The `codex-cli` MCP uses Codex's own `codex mcp-server`, not a wrapper.**
Native is version-locked to the CLI, needs no `npx` download, adds no third-party
supply chain, and — because we pin the **absolute** binary — cannot resolve to a
broken shim. (A wrapper shells out to `codex` from PATH, re-introducing fact 1.)
It exposes `codex` (prompt, model, sandbox, approval-policy, cwd, config,
base/developer-instructions) and `codex-reply` (thread continuation). Trade-off
accepted: we gave up the third-party wrapper's `changeMode`/`fetch-chunk`,
`batch-codex` and `brainstorm` tools; all are reproducible by prompting `codex`.

**3. Vercel on Codex uses Codex's native Streamable HTTP transport.** Run
`codex mcp add vercel --url https://mcp.vercel.com`; do not put Vercel behind
`mcp-remote`. Vercel lists Codex CLI as an approved native OAuth client, and the
old `mcp-remote@0.1.38` entry failed its authorization-code exchange on Hetz even
after clearing its local state. On a headless host, keep the printed login command
running, forward its printed callback port from the computer with the browser
(`ssh -N -L PORT:127.0.0.1:PORT vps`), then open the printed one-time URL. This is
an account-specific authorization step, so machine setup does not overwrite an
established `~/.codex/config.toml` or attempt it non-interactively. Verify with
`codex mcp get vercel`: `transport` must be `streamable_http` and `url` must be
`https://mcp.vercel.com`.

**Verify, never assume:** `ai-devops doctor` performs a real
`--sandbox workspace-write` write and fails loudly if Codex cannot write. A
`--version` probe cannot see this failure mode — that is exactly why it stayed
hidden. Run `ai-devops doctor` after any Codex install or upgrade, on every machine.

## Detail per location

### 1. ai-devops repo (the intended hub)
- **Skills:** `skills/claude/*` is the **source of truth** for `~/.claude/skills`
  on every machine; `bin/ai-install-skills` copies them (repo → machine, one-way).
  `skills/codex/*` mirrors this to `~/.codex/skills`.
- **Global instructions:** `templates/system/CLAUDE-global.md` → `~/.claude/CLAUDE.md`;
  `templates/system/AGENTS-global-codex.md` → `~/.codex/AGENTS.md`;
  `templates/system/machine-atlas.md` → each machine's environment atlas section.
  Installed **only if absent** — never clobbers local edits.
- **Workflow config:** `config/*.env.example` seeds `/etc/ai-devops/` without
  overwriting existing machine-local values.
- **Portable-memory tooling:** public `memory/` contains only the architecture
  pointer and secret-free project mapping. Operational `memory/<project>/`
  directories live only in the private memory repository; see
  [`../memory/README.md`](../memory/README.md).
- **Chat archives:** `claude_chats/` (~662 MB) + `codex_chats/` (~398 MB) —
  transcript backups. Large, may contain secrets, excluded from AI context via
  `.claudeignore`/`.cursorignore`. Never load them.

### 2. Dropbox SSH setup (`master_setupsshwindows.ps1`)
Windows-only, admin PowerShell, idempotent. It:
- Ensures `~/.ssh` exists and fixes Windows ACLs (owner + SYSTEM + Administrators
  only — Windows OpenSSH rejects other ACL entries with "Bad permissions").
- Writes the **`916-alien` OpenSSH private key** in plaintext if missing.
- Optionally installs `cloudflared` (SSH fallback via Cloudflare tunnel when
  Tailscale is unavailable).
- Upserts these **SSH host alias blocks** into `~/.ssh/config` (Tailscale
  preferred, Cloudflare/public fallback via a `Match ... !exec ping` trick):

  | Alias(es) | Target | User | Notes |
  |---|---|---|---|
  | `github.com` | GitHub | git | uses its OWN key `~/.ssh/id_ed25519` (not 916-alien) |
  | `coolify` / `vps` / `hetzner` | Hetzner VPS `<removed-protected-address>` | root | Coolify host; CF fallback `ssh-coolify.designflow.app` |
  | `vps2` | same Hetzner box | ai | `LocalForward 8787 <removed-protected-address>:8787` — optional Headroom tunnel fallback; see [`headroom.md`](headroom.md) |
  | `edgesynology1` / `edge1` | NAS `<removed-protected-address>` | ahazan | LAN preferred, Tailscale `<removed-protected-address>` fallback |
  | `edgesynology2` / `edge2` | NAS `<removed-protected-address>` port 1904 | ahazan | port 22 blocks command exec |
  | `backupwiz` / `wiz` | DigitalOcean `<removed-protected-address>` | root | CF fallback `ssh-backupwiz.designflow.app` |
  | `vpn` / `amnezia` | AmneziaWG `<removed-protected-address>` | root | |
  | `comp` / `hostdare` | Hostdare `<removed-protected-address>` | root | CF fallback `ssh-comp.designflow.app` |
  | `seafile` + raw `<removed-protected-address>` | Linode Seafile | ai | raw-IP block lets Codex use the key automatically |
  | `auth` / `authentik` | `<removed-protected-address>` | root | public fallback `<removed-protected-address>` port 1904 |

  All except `github.com` use `~/.ssh/916-alien`.

### 3. Dropbox MCP setup (`setup-claude-mcps.ps1` / `setup-codex-mcps.ps1`)
Generate the MCP server blocks in Claude/Codex config, embedding auth tokens.
The Claude MCP servers currently provisioned (from `~/.claude.json`; list them with `claude mcp list`):

| MCP server | Transport | Secret? |
|---|---|---|
| `ag-grid` | local `npx ag-mcp` | no |
| `devops-mcp` | remote `https://mcp.designflow.app/mcp` | **Bearer token** |
| `synology-monitor` | remote `https://nas-mcp.designflow.app/mcp` | **Bearer token** |
| `playwright` | local `npx @playwright/mcp` | no |
| `chrome-devtools` | local `npx chrome-devtools-mcp` | no |
| `vercel` | not configured in Claude; Codex uses native HTTP | no (interactive auth) |
| `trigger` | local `npx trigger.dev mcp` | **`TRIGGER_ACCESS_TOKEN`** (admin-level PAT field, rotated 2026-07-26) |
| `1password` | local `npx @u2giants/1password-mcp` | **`OP_SERVICE_ACCOUNT_TOKEN`** |

### 4. `~/.claude/settings.json`
MCP servers (above) + `agentPushNotifEnabled` + `autoUpdatesChannel`. Historically
this **held live tokens in plaintext**; since Phase 2 it is written by
`bin/setup-machine.ps1` and is **token-free** — every secret resolves at launch
through `~/.config/ai-devops/mcp-launch.cmd`. Confirmed token-free on t16
(2026-07-15) and al8960ofc (2026-07-26); assume plaintext on any machine that has
not yet run `setup-machine.ps1`. The Dropbox MCP script is superseded, not the
source of this file any more.

It also carries `permissions.allow`, the list of tools Claude Code may use
without stopping to ask. The entries the toolkit requires live in
`config/claude-permissions.allow` and are merged in by `bin/ai-claude-permissions`
(run by `install.sh` and by every `sync my dotfiles`). That script is additive
only — it never removes an entry and never touches the rest of the file, so
per-machine hand additions survive. Everything else in the file stays
machine-local; only the required-permissions list is synced.

### 5. `~/.codex/config.toml`
Portable Codex CLI settings pin `model = "gpt-5.6-sol"` and
`model_reasoning_effort = "medium"`. Established machine files also contain
`[windows] sandbox = "elevated"`, `[desktop]` UI prefs, enabled plugins
(chrome, documents, spreadsheets, pdf, browser, visualize, …), a local
`node_repl` MCP server, and marketplaces. **Most of the file is machine-specific
runtime paths** (hashed cache dirs, per-install exe paths). Only ~5 lines are
portable (`model`, `model_reasoning_effort`, `[windows] sandbox`, a couple
`[desktop]` prefs). **Do not sync wholesale.**

### 6. Gaps
- **Memory** — handled by `bin/ai-memory-sync` as a private, lossless Git
  transaction. Per-machine path slugs are canonicalized to one project key;
  indexes are unioned, only tombstones delete, and a rejected push preserves
  the exact commit for retry. See `memory/README.md`.
- **Kimi Code CLI** — the skill is now repo-owned under `skills/shared/` and
  installs into both Claude and Codex/ChatGPT. The CLI binary and login remain
  machine-local: verify with `kimi --version` and `kimi -p "reply with OK"`.
  If auth fails, run `kimi login` and complete the device flow once; do not
  attempt to automate authentication inside a delegated coding prompt.
- **Qwen Code CLI** — the skill and `ai-qwen` wrapper are repo-owned. Install the
  official CLI, complete its OAuth flow once, then prove the full path with
  `ai-qwen doctor --live`. A version check alone does not prove model access or
  the terminal-result contract.
- **Installing the three vendor CLIs (Grok, Kimi, Qwen)** — repo-owned, per
  machine, per user:
  - Windows: `bin/install-windows-ai-provider-clis.ps1` (run by
    `bootstrap-windows-dev.ps1`).
  - Linux/macOS: `install-ai-provider-clis.sh [grok|kimi|qwen ...]`.
  Run it as the user that runs AI sessions — on hetz that is `ai`, not root.
  The vendor installers write into `$HOME` (`~/.grok/bin`, `~/.kimi-code/bin`,
  `~/.local/bin`), so installing as root leaves the session user still broken;
  the script refuses to run as root for that reason. Qwen deliberately uses the
  vendor standalone installer rather than npm, because the npm package needs
  Node 22+ and hetz ships Node 20. **Login stays interactive and manual on every
  platform** — never automate it inside a delegated coding prompt.
  Each vendor installer edits a shell rc file to put its own directory on PATH,
  and that is unreliable — on hetz all three CLIs were installed and working
  while `kimi` never reached PATH at all. The script therefore links every
  provider into `~/.local/bin`, which the default Ubuntu profile already puts on
  PATH, and repairs that link on re-runs even when nothing needs installing.
  `ai-machine-tools-doctor` reporting `<provider> provider unavailable` means
  the vendor CLI is not reachable on PATH: either not installed, or installed
  and unlinked. Run the installer; it handles both. Note the doctor sees a
  non-login shell's PATH when run over a bare `ssh host 'cmd'`, so check with a
  login shell (`ssh host 'bash -lc "command -v grok kimi qwen"'`) before
  concluding anything is missing.
- **gcloud defaults** — per-machine. Correct dflow values: project
  `lithe-breaker-323913`, region `us-east4` (Cloud Run/Build/Artifacts/Compute).
  Set via `bin/ai-gcloud-dflow`. **Why regional matters:** Cloud Build here is
  2nd-gen regional; a global `gcloud builds list` returns stale/empty results and
  misleads you into thinking nothing deploys. Always pass
  `--project=lithe-breaker-323913 --region=us-east4`.

- **Production GCP safety** — the global Claude/Codex instructions installed on
  every machine prohibit AI mutation of production/shared infrastructure and
  specifically protect all `*-prod` Cloud Build triggers in
  `lithe-breaker-323913` / `us-east4`. This is a behavioral backstop, not an IAM
  boundary: developer AI sessions still require a dedicated read-only identity,
  never Albert's personal Owner/Editor or Terraform-admin credentials.
- **Portable Codex prefs** — the ~5 lines above; not yet templated (Phase 3).

## Where secrets live (1Password `vibe_coding` — titles only)

> **2026-07-22 account migration.** The 1Password service account moved from
> `my.1password.com` to **`popcreations.1password.com`** (vault `vibe_coding`, new
> vault id `pimcaogmxxzoafh7lsluj6uxkq`). The vault holds the same items but under
> **new UUIDs**, so every UUID-pinned `op://vibe_coding/<UUID>/…` reference had to
> be re-pointed. They are now **name-based** (`op://vibe_coding/<title>/<field>`)
> everywhere the title allows — the migration-proof form — with a UUID kept only
> where the title has parentheses (the Trigger management PAT), which `op` rejects
> in a reference. Also fixed in the same pass: the GLM key lives in the item's
> `api key` field, not `credential` (which resolves to 0 bytes — a silent-empty).
> The live token is machine-local (`OP_SERVICE_ACCOUNT_TOKEN` env var / the
> `op-service-account` file), not the vault; see `docs/onboarding-secrets.md`
> "Rotating the bootstrap service-account token" and the
> `op-account-migration-2026-07` memory. Gotcha: `op whoami` decodes the token
> locally, so it can show a deleted SA while real calls 403 — prove write with a
> real `op item create`/`delete`.

For Phase 2, installers will pull these instead of embedding them. Relevant items
that already exist in the vault:

| Secret | 1Password item title (in `vibe_coding`) |
|---|---|
| 1Password service-account token (for the MCP) | `vibe_coding-service-account` |
| devops-mcp bearer | `devops-mcp-client-tokens` |
| designflow MCP token | `designflow-mcp` |
| NAS monitor token | `nas-monitor-secrets` |
| Trigger PAT | `Trigger.dev Personal Access Token (management)` |
| SSH (existing server logins) | `hetz-ai-ssh`, `ci-deploy-ssh` |
| **`916-alien` SSH key** | ✅ now in 1Password as item **`916-alien SSH key`** (SshKey category; `private key` / `public key` fields; added 2026-07-14). Restored to `~/.ssh/916-alien` by the Phase 2 setup scripts. |

## Security landmines (why naive git-sync is unsafe)
1. **`master_setupsshwindows.ps1` stores the `916-alien` private key in plaintext**
   in Dropbox.
2. **`~/.claude/settings.json` stores live tokens in plaintext** (the 1Password
   service-account token, a Trigger PAT, two MCP bearer tokens).
3. **Transcript leakage:** those `settings.json` tokens were visible in a session
   whose transcript is archived to `claude_chats/`. **Recommended:** rotate the
   Trigger PAT and the two MCP bearer tokens (folds into Phase 2).

Neither secret file may enter a git-synced dotfiles system as-is. The
consolidation plan pulls all secrets from 1Password at install time so nothing
secret is ever committed.

## Decision log
- **2026-08-21:** keep reusable configuration in public `ai-devops`, but move
  operational portable memory to private `u2giants/ai-devops-memory`. Automated
  writers must prove private visibility and pass health/content gates before push.

## See also
- [`config-consolidation-proposal.md`](config-consolidation-proposal.md) — the phased migration plan.
- [`../plan_phase3-config-consolidation.md`](../plan_phase3-config-consolidation.md) — completed implementation, decisions, and verification evidence.
- [`../memory/README.md`](../memory/README.md) — memory sync mechanics.
- `AGENTS.md` §"Credentials and environment" — the repo's existing secret rules.
- `docs/skills-usage-guide.md`, `docs/codex-skills-usage-guide.md` — how skills install per machine.
