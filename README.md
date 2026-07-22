# AI DevOps Toolkit

A backed-up, repeatable AI coding workflow toolkit. Scripts, prompt templates,
restore docs, and skill/MCP scaffolding for a multi-model staged coding workflow
built around **Claude (Opus 4.8)** and **Codex / GPT-5.5**.

This repo exists so the entire workflow can be **restored from zero** on a fresh
Ubuntu server if the current one dies.

> **New here (developer or AI session)?** Read [`AGENTS.md`](AGENTS.md) — it is
> the canonical operating guide and documentation router. Its **Documentation
> map** tells you which docs to load for a given task so you don't have to read
> everything. Claude Code sessions: read [`CLAUDE.md`](CLAUDE.md) first, then
> `AGENTS.md`.

---

## Set up a new machine (start here)

Goal: on a brand-new computer, run **one script**, paste **one code once**, and
then Claude works everywhere with all passwords filled in automatically. You do
not need to know any of the details — just follow the three lines for your
computer type.

You will be asked once for a **service-account code** (it starts with `ops_`).
It comes from 1Password (`vibe_coding` vault, item *"vibe_coding-service-account"*,
field *op_service_account_token*). This one code is locked so it can only ever
read that one vault — nothing else.

### Windows development computer (Claude Desktop, Codex, and dev tools)

Open the built-in **PowerShell** and paste this one line. The bootstrap requests
Administrator permission itself and installs PowerShell 7 as part of the run:

```powershell
if(!(Get-Command git -EA SilentlyContinue)){winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements; $env:Path=[Environment]::GetEnvironmentVariable("Path","Machine")+";"+[Environment]::GetEnvironmentVariable("Path","User")}; $p="$HOME\repos\ai-devops"; if(!(Test-Path "$p\.git")){git clone https://github.com/u2giants/ai-devops.git $p}; powershell -NoProfile -ExecutionPolicy Bypass -File "$p\bin\bootstrap-windows-dev.ps1" -RepoPath $p
```

This is the normal entrypoint for a **new Windows computer**. It may also
reconcile an existing computer, but as of 2026-07-17 the complete workflow has
not yet been run twice on a disposable Windows 11 machine. Until that live gate
passes, use `-TestOnly` on an established machine such as 4837 and do not apply
it there merely to test it. See
[the Windows desired-state guide](docs/windows-winget-configuration.md) for
ownership, expected changes, recovery, and rollout gates.

It installs the complete Windows dev-tool set, configures Tailscale-only
OpenSSH, prepares Ubuntu/WSL as an Ansible controller, configures AI DevOps,
and asks you to paste the code once. If Windows requires a reboot, rerun the
same line afterward; completed stages are reconciled rather than repeated.
When it finishes,
follow the short checklist it prints (fully close and reopen Claude Desktop; if
it lists two "connectors" to add, add them once in Settings → Connectors).

### Ubuntu server (hetz and others) — Claude Code

```bash
git clone https://github.com/u2giants/ai-devops.git /worksp/ai-devops
cd /worksp/ai-devops
./install.sh
```

`install.sh` asks you to paste the code once, then wires everything up. After it
finishes, open a new terminal and just run `claude` in any app folder — the
tokens fill in by themselves.

> Already set the machine up and just want to (re)wire secrets? Run
> `setup-secrets.sh` (Ubuntu) or `bin\setup-machine.ps1` (Windows) again — both
> are safe to re-run.

How and why this works: [`docs/onboarding-secrets.md`](docs/onboarding-secrets.md). Full Windows desired-state setup: [`docs/windows-winget-configuration.md`](docs/windows-winget-configuration.md).

---

## Where this lives

This system lives at:

```
/worksp/ai-devops
```

> Do **not** use `/opt/ai-devops`. Every script, symlink, and doc assumes
> `/worksp/ai-devops`.

Config lives outside the repo (so it is never committed):

```
/etc/ai-devops/models.env     # model command overrides
/etc/ai-devops/server.env     # server-specific settings
/var/log/ai-devops/           # logs
```

---

## What this repo does NOT store

This repo is safe to keep **private** on GitHub. It never stores:

- `.env` files or any real environment files (only `*.env.example`)
- API tokens, secrets, passwords
- `auth.json`, GitHub credentials, `gh` tokens
- SSH private keys (`id_rsa`, `id_ed25519`, `*.pem`, `*.key`)
- `~/.codex`, `~/.claude`, or any login/session state
- Production credentials of any kind

The `.gitignore` actively blocks these patterns. Real config lives in
`/etc/ai-devops/` on each machine, never in git.

---

## The model workflow

| Stage | Model | Role |
|-------|-------|------|
| Plan / architecture | **Opus 4.8 (high reasoning)** | Implementation plans, architecture design |
| Plan review | **Opus** | Independent review of the plan |
| Implementation | **GPT-5.5 / Codex** | Writes the code, smallest safe change |
| Diff review | **Opus** | Reviews the git diff for regressions |
| Test | **GPT-5.5 / Codex** | Runs tests, visual checks, fixes, reruns |
| Security review | **Opus** | Auth, data-leak, SQL, secrets review |
| Final review | **Opus 4.8 (high reasoning)** | Final product/architecture sign-off |

High-level roles:

- **Opus 4.8 high reasoning** — implementation plans, architecture review, final
  product/architecture review.
- **GPT-5.5 / Codex** — coding, implementation, testing, fixing.
- **Opus** — independent review throughout: plan review, diff review, security
  review, final review.

The exact CLI flags for each model live in `/etc/ai-devops/models.env` and can be
edited per machine (see `docs/model-setup.md`).

Codex-specific repeated workflows now live in `skills/codex/`; see
[`docs/codex-skills-usage-guide.md`](docs/codex-skills-usage-guide.md) and
[`docs/codex-chat-analysis.md`](docs/codex-chat-analysis.md).

---

## Fresh server install

```bash
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/u2giants/ai-devops.git /worksp/ai-devops
cd /worksp/ai-devops
./install.sh
gh auth login
claude login      # or: claude  (follow login prompt)
codex login       # or: codex   (follow login prompt)
ai-devops doctor
```

Full step-by-step: [`docs/restore-from-zero.md`](docs/restore-from-zero.md).

## Windows computer install

On any Windows vibe-coding computer, run this in PowerShell. It handles both
new computers and computers where the repo already exists:

```powershell
if(!(Get-Command git -EA SilentlyContinue)){winget install --id Git.Git -e --source winget; $env:Path=[Environment]::GetEnvironmentVariable("Path","Machine")+";"+[Environment]::GetEnvironmentVariable("Path","User")}; $p="$HOME\repos\ai-devops"; if(!(Test-Path "$p\.git")){git clone https://github.com/u2giants/ai-devops.git $p} else {git -C $p pull --ff-only}; powershell -ExecutionPolicy Bypass -File "$p\bin\install-ai-devops-windows.ps1"
```

Codex prompt version:
[`templates/prompts/install-ai-devops-windows-codex.md`](templates/prompts/install-ai-devops-windows-codex.md).

---

## Update process

```bash
cd /worksp/ai-devops
./update.sh
```

`update.sh` pulls the latest repo and re-runs `install.sh`. It never overwrites
`/etc/ai-devops/*.env`.

---

## Restore process

If the server dies, provision a new Ubuntu box and follow
[`docs/restore-from-zero.md`](docs/restore-from-zero.md). Everything needed is in
this repo; only the logins (gh / claude / codex) are re-done interactively.

---

## Basic commands

| Command | What it does |
|---------|--------------|
| `ai-devops doctor` | Health-check the toolkit and its dependencies |
| `ai-devops version` | Print the toolkit version |
| `ai-devops paths` | Print the paths this toolkit uses |
| `ai-workspace-status` | Show git/branch/PR safety status of the current repo |
| `ai-codex-review <mode>` | Read-only Codex second-opinion review |
| `ai-model-call <stage> <prompt> <out>` | Generic model invocation helper |
| `ai-run-task "<task>"` | Scaffold a new staged task run (v0.1) |

`ai-codex-review` modes: `plan-review`, `diff-review`, `security-review`,
`visual-review`, `final-check`.

---

## Repo layout

```
AGENTS.md       Canonical operating guide + documentation router (read first)
CLAUDE.md       Claude Code-specific notes (points to AGENTS.md)
bin/            Executable CLI tools (symlinked into /usr/local/bin by install.sh)
config/         *.env.example templates (copied to /etc/ai-devops on install)
templates/      Prompt templates and per-repo doc add-ons
docs/           architecture, development, configuration, deployment, restore, +more
skills/         Claude + Codex skill scaffolding
mcp/            Future MCP wrapper scaffolding
claude_chats/   Archived Claude Code session transcripts (backup; sensitive, ~219 MB)
install.sh      Install/verify deps, config, symlinks; runs doctor
update.sh       Pull + re-install (keeps existing config)
uninstall.sh    Remove symlinks (keeps config/auth unless flagged)
```

---

## Safety notes

- Review scripts (`ai-codex-review`) are **read-only** by default — they never
  commit, push, merge, or delete.
- `ai-run-task` is v0.1 scaffolding — it does not edit code.
- Application repos are **not** touched by this toolkit's setup.
