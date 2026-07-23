# Unified secrets & new-machine onboarding

How a brand-new machine gets set up so Claude can start coding with **every
secret resolved automatically** — and why it works this way. Written to be read
by a non-programmer as well as an AI session.

For the do-this-now steps, see the **"Set up a new machine"** section of
[`../README.md`](../README.md). This document explains the design behind them.

---

## The one-sentence goal

> New machine = run one script, paste one code once, and then Claude just works
> in every app — no per-app, per-machine secret fiddling ever again.

---

## The problem this solves

- The owner works across many machines: 3 Windows computers, the Hetzner VPS
  (`hetz`), and other Ubuntu servers.
- Many apps (`popdam`, `popcrm-web`, `poppim-web`, `monitor`, `hiclaw`,
  designflow repos) each have a `.mcp.json` that needs the *same kinds* of
  tokens (Supabase access token, DevOps MCP token, NAS MCP token, …).
- Before this, secrets were scattered: hand-edited into `~/.bashrc` (twice, as
  raw values), one-off `op read` blocks per app, a raw token hard-coded inside
  `monitor/app/.mcp.json`, and ad-hoc Windows setup scripts. Every new machine
  meant re-doing all of it by hand.

## The design in four ideas

1. **One source of truth for secrets = 1Password.** Real values live only in the
   `vibe_coding` vault. Repos and config files contain **references**
   (`op://vibe_coding/<item>/<field>`), never values.

2. **One shared token per shared account.** There is ONE Supabase Personal
   Access Token item that *all* apps reference — not one token per app. Same for
   the DevOps/NAS MCP tokens. Rotating a token in 1Password updates every app on
   every machine automatically, with nothing to re-copy.

3. **One central reference file.** [`config/mcp.env.example`](../config/mcp.env.example)
   lists every `op://` reference used by any app. It is copied to
   `~/.config/ai-devops/mcp.env` on each machine. Add a new placeholder to one
   file → every app and machine picks it up.

4. **Resolve once, with a single-flight guard.** One `op run --env-file`
   resolves the shared set at session start. Ubuntu keeps it in the login-shell
   environment. Windows shares a 15-minute, per-user DPAPI-encrypted cache; an
   OS mutex permits only one refresh while parallel MCP startups wait. Plaintext
   values exist only in child-process memory and never in MCP configuration.

Agents must serialize direct `op read`, `op run`, and 1Password MCP calls.
Parallel repository work is fine; parallel vault access is not.

The `ZAI_API_KEY` reference follows the same rule. `ai-glm-agent` resolves it
only when launching an isolated GLM child process. The key is not copied into
Claude settings, Codex config, the repository, prompts, or reports. The model
and endpoint are non-secret entries in the same managed reference file so every
machine uses the same configurable defaults.

## Why a service-account token is the safe choice

The `op` tool can be used two ways:

- **Personal sign-in** — exposes *every* vault and login you own. **Not used
  here.** (The owner correctly disabled this.)
- **Service-account token** — a key that is **scoped to a single vault**
  (`vibe_coding`) and *physically cannot* read anything else. This is what we
  use. It is the same kind of scoped credential the 1Password *MCP server* uses
  under the hood.

So "using op" here does **not** mean exposing all credentials. The token can
only ever read `vibe_coding`.

## The chicken-and-egg bootstrap (the one secret that can't come from 1Password)

To read 1Password you need the service-account token — which itself can't be
read *from* 1Password on a machine that has nothing yet. So exactly one secret
must arrive out-of-band, once per machine:

- **Ubuntu:** the setup script asks you to paste it once, then stores it in
  `~/.config/ai-devops/op-service-account`, `chmod 600` (readable only by you).
- **Windows:** stored in `%USERPROFILE%\.config\ai-devops\op-service-account`
  with a user-only ACL. It is deliberately **not** a Windows environment
  variable, because the Store/MSIX Claude Desktop sandbox does not inherit user
  env vars and can strip env values out of its own config on restart.

The canonical copy of this token also lives in 1Password
(`vibe_coding-service-account`) for reference and rotation.

## Two platforms, one model

The same central `mcp.env` and the same "resolve at launch with `op run`" idea
run on both platforms — the plumbing differs because the two Claude apps differ.

For GLM, both platforms expose the same behavior: the shared `ask-glm` skill
invokes `ai-glm-agent`, which hosts GLM inside Claude Code's coding-agent runtime.
That gives GLM repository search, terminal commands, tests, and multi-step work.
An isolated `CLAUDE_CONFIG_DIR` plus process-scoped Z.ai variables prevents the
GLM child from replacing or inheriting normal Anthropic authentication. Setup
performs a real `GLM_AGENT_OK` capability probe and rejects any returned model
other than the explicitly requested model.

### Ubuntu / Claude Code (hetz and other servers) — fully automated & tested

- `bin/setup-secrets.sh` stores the token, drops `mcp.env`, and installs a
  managed shell snippet (`~/.config/ai-devops/shellrc`, sourced by `~/.bashrc`
  and `~/.profile`; POSIX-safe so it also works under `dash`).
- On login the snippet loads the vault-locked token, then resolves all of
  `mcp.env` with one `op run` into the shell environment (it never
  overwrites a value you set yourself). So every app's `.mcp.json` `${...}`
  placeholder — and every other CLI (`supabase`, scripts) — is authorized with
  no special launcher. You just run `claude`.
- **Why shell-export and not an `op run` wrapper here?** It's the pattern that
  already works on `hetz`, so nothing regresses; it authorizes *all* tools in
  the session, not only Claude; and it's the simplest mental model for a
  non-programmer ("log in and it's just there"). Windows can't do this (a
  clicked GUI app has no login shell), which is why Windows uses `op run` at
  MCP-launch instead.
- The script also **cleans up the old mess**: it comments out (with a backup)
  any raw `export OP_SERVICE_ACCOUNT_TOKEN=ops_...` lines and old per-app
  `op read` blocks left in `~/.bashrc`, so the token lives only in the 600 file.

### Windows / Claude Desktop (the 3 computers) — automated where reliable, plus known manual bits

Claude **Desktop** (the Store/MSIX app the owner clicks) behaves differently
from Claude Code, and these are *verified* limitations:

- **It does not expand `${VAR}`** in `claude_desktop_config.json`. So we cannot
  rely on placeholders; instead the launched command injects real values via
  `op run` at start.
- **MSIX sandbox** does not inherit `setx` env vars and may strip `env` blocks
  from the config on restart — so the token is read from a file by a small
  launcher (`~/.config/ai-devops/mcp-launch.cmd`), and no secret is ever written
  into the config.
- **npx needs a `cmd /c` wrapper** to spawn on Windows.
- **Remote/HTTP MCP servers** (`devops-mcp`, `synology-monitor`) run through the
  `mcp-remote` stdio shim. Note that `mcp-remote` **also** does not expand
  `${VAR}` in `--header` (verified — its parser stores the header value
  verbatim). So the bearer token is resolved to a real value by a launcher that
  `op read`s it in memory just before starting `mcp-remote`; only the URL and
  the `op://` reference ever appear in the config or the script.

It also restores the **916-alien SSH key** from 1Password
(`op://vibe_coding/916-alien SSH key/...`) to `~\.ssh\916-alien` (+ `.pub`) with
a user-only ACL, and installs the managed **SSH host aliases**
(`config/ssh-config.template` → `~/.ssh/ai-devops.conf`, `Include`d from
`~/.ssh/config` at the end so any existing entry still wins), so `ssh vps`,
`ssh vps2` (same box), `ssh seafile`, etc. work immediately. The tunnel-backed
hosts connect via `cloudflared` (installed by the script) so they work on any
network without Tailscale — the same path on Windows and Linux. The private key
is written straight from 1Password at runtime and never stored in the repo; the
config is non-secret (hostnames + the public key path only).

`bin/setup-machine.ps1` wires all three servers (supabase stdio + the two
remotes) with **no token written to disk**, using two launchers:
`mcp-launch.cmd` (injects env for stdio servers) and `mcp-remote-launch.cmd`
(builds the bearer header for remote servers). It prints a **validation
checklist** for the parts that can only be confirmed on the machine itself. The
Desktop-config step is best-effort and was authored, not executed, from a Linux
box — always confirm in the app that all three MCPs show connected after running
it.

## Memories in sync across machines

Claude's auto-memory (facts it learns per project) is kept in sync across every
machine through the ai-devops repo as the hub, by `bin/ai-memory-sync` (built on
the consolidation effort's `bin/ai-sync-memory`). It runs automatically — every
30 minutes via cron on Ubuntu and a Scheduled Task on Windows — so you never
think about it.

It is safe by design:

- **Isolated clone.** It works in `~/.cache/ai-devops-memory`, never your live
  `/worksp/ai-devops` checkout, so it can't disturb work in progress.
- **Secret gate.** Before any upload it scans the memory files for credential
  patterns (`ops_`, `ghp_`, `AKIA`, JWTs, `PRIVATE KEY`, …). If anything looks
  like a secret it **aborts the upload** and logs the file — memory is meant to
  be facts, not credentials. Sync resumes once the file is cleaned.
- **Upload-before-download ordering + file-level union.** Each fact is its own
  file, and the copy never deletes, so machines' facts merge rather than
  overwrite; this machine's newest edits are captured before incoming is applied.
- **Conflict-tolerant push.** Only the `memory/` subtree is committed; pushes
  retry with rebase if another machine pushed first.

`ai-memory-sync pull` does incoming-only (safe). A brand-new machine has nothing
to sync until you have actually opened a project there (memory is stored per
project by folder location) — after that it stays matched to your other machines.

## What lives where (boundary with Ansible)

Per the host-change boundary, **installing host packages** (the `op` CLI,
`gh`, node) belongs in [`/worksp/ansible`](../../ansible) — and already does:
`roles/apt_repos` + `roles/packages` install `1password-cli`, and the
`ai_devops` role clones this repo and runs `install.sh`. The Ansible
`ai_devops` role deliberately **writes no secret to disk**.

This repo owns the **secret wiring** (token file, central references, launcher,
`.bashrc` cleanup) — the step Ansible intentionally leaves out. The setup
scripts still self-install `op` if it's missing, so machines *not* managed by
Ansible (Windows boxes, ad-hoc servers) are covered too.

| Concern | Owner |
|---|---|
| Install `op`/`gh`/node packages on managed hosts | Ansible (`roles/packages`, `roles/apt_repos`) |
| Clone ai-devops + run `install.sh` on managed hosts | Ansible (`roles/ai_devops`) |
| Store the service-account token, drop `mcp.env`, install the `claude` launcher, clean `.bashrc` | **ai-devops** (`bin/setup-secrets.sh`) |
| Windows: token file, `mcp.env`, launcher, Desktop MCP config | **ai-devops** (`bin/setup-machine.ps1`) |
| Real secret values | 1Password `vibe_coding` only |

## Rules

- **Never** write a real secret value into any repo or config file. Only `op://`
  references (`config/mcp.env.example`) or the single locked-down token file.
- Add a new app placeholder by adding one line to `config/mcp.env.example`.
- To rotate a **referenced** secret (anything an `op://` line points at — Supabase
  PAT, MCP bearers, GLM key, …): change it in 1Password. Nothing else to do —
  every machine picks it up on the next launch. This "nothing else to do" rule
  applies **only** to referenced secrets, **not** to the bootstrap
  service-account token itself (see below).

## Rotating the bootstrap service-account token (the exception)

The `OP_SERVICE_ACCOUNT_TOKEN` is the one credential that **cannot** come from
1Password (chicken-and-egg), so rotating it does **not** auto-propagate. When it
changes, every machine-local raw copy must be updated by hand:

- the token file `%USERPROFILE%\.config\ai-devops\op-service-account` (Windows) /
  `~/.config/ai-devops/op-service-account` (Ubuntu);
- on machines still using the older literal-token model, the raw token embedded
  in the `1password` MCP entry of `~/.claude/settings.json`, `~/.codex/config.toml`,
  and `%APPDATA%\Claude\claude_desktop_config.json`;
- the OS env var `OP_SERVICE_ACCOUNT_TOKEN` if a machine sets one (al8960ofc does);
- the vault backup fields on item `vibe_coding-service-account`
  (`op_service_account_token` **and** `credential`), which need a read-write SA.

MCP processes cache the token at startup — **restart** Claude Code / Claude
Desktop / Codex after updating.

### If the rotation moves to a NEW 1Password account (2026-07-22)

The service account was migrated from `my.1password.com` to
`popcreations.1password.com` (vault `vibe_coding`, id `pimcaogmxxzoafh7lsluj6uxkq`).
Two things bite here that a same-account rotation does not:

- **Every UUID-pinned `op://vibe_coding/<UUID>/…` reference breaks** — the new
  account re-created the items under new UUIDs. Fix: prefer **name-based**
  references (`op://vibe_coding/<item title>/<field>`), which survive account
  migrations. Name-based refs (even with spaces in the title *and* field label)
  resolve fine via `op run --env-file` — verified. Keep a UUID **only** in two
  cases: (a) the title contains parentheses, which `op` rejects in any reference
  (`invalid character '('`) — e.g. the Trigger management PAT; (b) the ref is
  passed **inline** through the mcp-remote launcher (`recall-ai` in
  `bin/setup-machine.ps1` / `bin/setup-secrets.sh`), where a space would break the
  launcher's argument / `op read` parsing.
- **`op whoami` lies after a delete.** It decodes the token **locally**, so it
  keeps showing a deleted service account's Integration ID while every real
  server call returns `(403) Service Account Deleted`. Always prove the token
  with a real `op item create` + `delete`, never `whoami`.

The full re-pointing done in this migration (and the read-only-then-read-write
SA saga) is recorded in the `op-account-migration-2026-07` memory.

## Known follow-ups (not done by this tooling)

- `monitor/app/.mcp.json` contains a **raw NAS token** and should be changed to
  `${NAS_MCP_TOKEN}` in that app repo (an app-repo change, out of scope here).
- The Windows Desktop MCP wiring in `setup-machine.ps1` needs a first-run
  validation on an actual Windows machine.
