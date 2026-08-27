# AI DevOps Toolkit

A backed-up, repeatable AI coding workflow toolkit. Scripts, prompt templates,
restore docs, and skill/MCP scaffolding for a multi-model staged coding workflow
built around **Claude Opus 5** and **Codex / GPT-5.6**.

This repo exists so the entire workflow can be **restored from zero** on a fresh
Ubuntu server if the current one dies.

Recovery-critical package, MCP, and model versions are recorded in
[`config/tool-versions.json`](config/tool-versions.json); restore paths use
those reviewed pins instead of mutable `latest` releases.

This repository is public. Concrete machine topology, SSH host identities, and
provider project identifiers live in the private
`u2giants/ai-devops-private-config` repository and are restored by
`ai-private-config`; transcripts and portable facts have their own private
repositories. Historical public commits are being removed as part of the 2026
strategy remediation, so old clones must be replaced after that rewrite.

> **New here (developer or AI session)?** Read [`AGENTS.md`](AGENTS.md) — it is
> the canonical operating guide and documentation router. Its **Documentation
> map** tells you which docs to load for a given task so you don't have to read
> everything. Claude Code sessions: read [`CLAUDE.md`](CLAUDE.md) first, then
> `AGENTS.md`.

---

## Set up a new machine (start here)

Goal: on a brand-new computer, run **one script**, complete GitHub's one-time
browser authorization for the private restore inputs, paste **one 1Password
code once**, and then Claude works everywhere with all passwords filled in
automatically.

You will be asked once for a **service-account code** (it starts with `ops_`).
It comes from 1Password (`vibe_coding` vault, item *"vibe_coding-service-account"*,
field *op_service_account_token*). This one code is locked so it can only ever
read that one vault — nothing else.

### Windows development computer (Claude Desktop, Codex, and dev tools)

Open the built-in **PowerShell** and paste this one line. The bootstrap requests
Administrator permission itself and installs PowerShell 7 as part of the run:

```powershell
if(!(Get-Command git -EA SilentlyContinue)){winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements; $env:Path=[Environment]::GetEnvironmentVariable("Path","Machine")+";"+[Environment]::GetEnvironmentVariable("Path","User")}; $p="$HOME\repos\ai-devops"; if(!(Test-Path "$p\.git")){git clone https://github.com/popcre/ai-devops.git $p}; powershell -NoProfile -ExecutionPolicy Bypass -File "$p\bin\bootstrap-windows-dev.ps1" -RepoPath $p
```

This is the normal entrypoint for a **new Windows computer**. It may also
reconcile an existing computer, but as of 2026-07-17 the complete workflow has
not yet been run twice on a disposable Windows 11 machine. Until that live gate
passes, use `-TestOnly` on an established machine such as 4837 and do not apply
it there merely to test it. See
[the Windows desired-state guide](docs/windows-winget-configuration.md) for
ownership, expected changes, recovery, and rollout gates.

It installs the complete Windows dev-tool set, including Grok Build and Kimi
Code, configures Tailscale-only
OpenSSH, prepares Ubuntu/WSL as an Ansible controller, configures AI DevOps,
and asks you to authorize GitHub and paste the code once. If Windows requires a reboot, rerun the
same line afterward; completed stages are reconciled rather than repeated.
When it finishes,
follow the short checklist it prints (fully close and reopen Claude Desktop; if
it lists two "connectors" to add, add them once in Settings → Connectors).
The first Grok and Kimi use each open their provider's sign-in page; that login
is not automated or stored by AI DevOps.

### Ubuntu server (hetz and others) — Claude Code

```bash
git clone https://github.com/popcre/ai-devops.git /worksp/ai-devops
cd /worksp/ai-devops
./install.sh
```

`install.sh` asks for one-time GitHub authorization and the 1Password code,
then wires everything up. After it
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

This repo is deliberately **public** on GitHub. Its current tree never stores:

- `.env` files or any real environment files (only `*.env.example`)
- API tokens, secrets, passwords
- `auth.json`, GitHub credentials, `gh` tokens
- SSH private keys (`id_rsa`, `id_ed25519`, `*.pem`, `*.key`)
- `~/.codex`, `~/.claude`, or any login/session state
- Production credentials of any kind
- Concrete machine addresses, SSH host keys, or provider project identifiers

The public-boundary test rejects credential-shaped content and protected
topology. Runtime config lives under `/etc/ai-devops/`; private restore inputs
come from `ai-private-config`, never this repository.

---

## The model workflow

| Stage | Model | Role |
|-------|-------|------|
| Plan / architecture | **GPT-5.6 / Codex (medium)** | Implementation plans, architecture design |
| Plan review | **Claude Opus 5** | Independent review of the plan |
| Implementation | **GPT-5.6 / Codex (medium)** | Writes the code, smallest safe change |
| Diff review | **Claude Opus 5** | Reviews the git diff for regressions |
| Test | **GPT-5.6 / Codex (medium)** | Runs tests, visual checks, fixes, reruns |
| Security review | **Claude Opus 5** | Auth, data-leak, SQL, secrets review |
| Final review | **Claude Opus 5** | Final product/architecture sign-off |

High-level roles:

- **Claude Opus 5** — independent plan, diff, security, and final review.
- **GPT-5.6 / Codex (medium)** — planning, implementation, testing, fixing.

The exact CLI flags for each model live in `/etc/ai-devops/models.env` and can be
edited per machine (see `docs/model-setup.md`).

Codex-specific repeated workflows now live in `skills/codex/`; see
[`docs/codex-skills-usage-guide.md`](docs/codex-skills-usage-guide.md) and
[`docs/codex-chat-analysis.md`](docs/codex-chat-analysis.md).

### GLM as a full coding agent

`ai-glm` gives Claude and Codex named, persistent GLM sessions hosted by a
loopback-only OpenCode server. A session remembers the whole conversation,
survives a server restart, and keeps its prefix warm so Z.ai serves most of the
context from cache. Review sessions are structurally read-only (no write, edit,
patch or bash tool); implementation runs in a throwaway git worktree that is
deleted before the command exits. The model is pinned to `glm-5.3` and the
Coding Plan key is resolved from 1Password only at launch. See
[docs/glm-opencode.md](docs/glm-opencode.md). The shared `ask-glm` skill lets
either Claude or Codex invoke it when
Albert says “ask GLM” or “run this by GLM.”

### Reviewer health and measurement

`ai-review-preflight check <provider> <repo>` verifies the repository,
evidence packet, writable result area, and provider health before a review is
assigned. Failed providers are temporarily quarantined so the next caller does
not immediately repeat the same failure. Add `--live` only when a small paid
allowance probe is justified.

`ai-review-scoreboard append ...` normalizes outcome metadata from the existing
provider wrappers into a JSONL scoreboard. It reports recurrence of long waits,
missing verdicts, provider failures, and stale evidence. It does not choose a
provider or replace the wrappers.

`ai-reviewer-issue record --provider <name> --summary "title"` records a
detailed local diagnostic package when a reviewer behaves unexpectedly. The
command captures complete matching review reports, recent provider logs,
reviewer metadata, the latest scoreboard outcome, repository state, and machine
facts. Use unrestricted `--details` or `--details-file` for the session's own
account, `--command` for the exact invocation, and `--error-file` to include the
complete error log. Reports stay
under this checkout's git-ignored `.ai/reviewer-issues/` directory. Later
ai-devops sessions can use `ai-reviewer-issue list` and `show <issue-id>`.

---

## Fresh server install

```bash
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/popcre/ai-devops.git /worksp/ai-devops
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
if(!(Get-Command git -EA SilentlyContinue)){winget install --id Git.Git -e --source winget; $env:Path=[Environment]::GetEnvironmentVariable("Path","Machine")+";"+[Environment]::GetEnvironmentVariable("Path","User")}; $p="$HOME\repos\ai-devops"; if(!(Test-Path "$p\.git")){git clone https://github.com/popcre/ai-devops.git $p} else {git -C $p pull --ff-only}; powershell -ExecutionPolicy Bypass -File "$p\bin\install-ai-devops-windows.ps1"
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
| `ai-run-task start "<task>"` | Create an immutable seven-stage run; use `run`, `resume`, and `status` to operate it |
| `ai-glm new|ask|implement <name> ...` | Persistent, named GLM-5.3 sessions (see docs/glm-opencode.md) |

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
transcripts/    Session transcripts. PRIVATE submodule (u2giants/ai-devops-transcripts).
                Never commit transcripts into this repo: it is PUBLIC.
install.sh      Install/verify deps, config, symlinks; runs doctor
update.sh       Pull + re-install (keeps existing config)
uninstall.sh    Remove symlinks (keeps config/auth unless flagged)
```

---

## Safety notes

- Review scripts (`ai-review`, `ai-claude-review`, `ai-codex-review`) are **read-only** — they never
  commit, push, merge, or delete.
- `ai-run-task` is the fail-closed seven-stage orchestrator. Only its
  implementation and testing stages may edit code.
- Application repos are **not** touched by this toolkit's setup.
