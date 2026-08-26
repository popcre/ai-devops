# Restore From Zero

How to rebuild this AI coding workflow on a new Windows 11 computer or Ubuntu
server. This public repository is the setup engine; the private
`u2giants/ai-devops-private-config` repository supplies machine topology and
provider identifiers. Secrets are restored at runtime from 1Password vault
`vibe_coding`; secret values never belong in Git.

## Windows 11

1. Clone this repository first. The bootstrap reads the repository identity
   allow-list in `config/repo-identities.tsv` through `bin/repo-identity.ps1`,
   so it must run from inside a checkout, not as a lone saved file:

```powershell
git clone https://github.com/popcre/ai-devops.git C:\repos\ai-devops
```

2. Run the bootstrap from an elevated-capable PowerShell session; it installs
   Git when needed and owns the canonical `C:\repos\ai-devops` clone:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File C:\repos\ai-devops\bin\bootstrap-windows-dev.ps1 -RepoPath C:\repos\ai-devops
```

The bootstrap proves the source is clean canonical `main` exactly equal to
`origin/main` before any machine change. Recovery-critical WinGet, npm, MCP,
and model versions come from the reviewed `config/tool-versions.json` catalog,
so a restore cannot silently pick a newer release. It then obtains one-time
GitHub authorization for the private restore-input repository, installs skills,
restores protected SSH and MCP wiring, fixes the Codex executable path, and registers background memory
sync (the schedule stays disabled until explicitly qualified). If the protected service-account token file is absent, supply the token
once from the `vibe_coding` vault. Do not paste it into a repo file.

Verify with the script's final checks and a real `codex exec` sandbox write.
Fully quit and reopen Claude Desktop before checking its MCP servers.

## Ubuntu

> Target path is always `/worksp/ai-devops`. Never `/opt/ai-devops`.

## Exact steps

### 1. Create an Ubuntu server

Provision a fresh Ubuntu box (any recent LTS). Log in as a sudo-capable user.

### 2. Install Git and GitHub CLI

```bash
sudo apt-get update
sudo apt-get install -y git gh
```

### 3. Clone this repo to /worksp/ai-devops

```bash
sudo mkdir -p /worksp
sudo chown "$USER":"$USER" /worksp
git clone https://github.com/popcre/ai-devops.git /worksp/ai-devops
cd /worksp/ai-devops
```

### 4. Authenticate GitHub CLI

The private configuration and memory hubs are part of a complete restore, so
authenticate before installing:

```bash
gh auth login
```

### 5. Run install.sh

```bash
./install.sh --require-secrets
```

This installs base dependencies, synchronizes and validates the protected
configuration repository, creates `/etc/ai-devops` and
`/var/log/ai-devops`, seeds `models.env` / `server.env` (without overwriting any
existing real config), installs skills, calls `bin/setup-secrets.sh` for the
1Password-backed MCP wiring, symlinks the `bin/` tools into `/usr/local/bin`,
and runs `ai-devops doctor`. The final stage summary must have no required
failure; the command returns nonzero otherwise.

On a brand-new Claude home, the required private-memory stage clones and
validates the private hub but has no project directory to populate yet. It
reports `fresh-machine seed complete` and uploads nothing. After Claude creates
a project, run `ai-memory-sync` manually to apply that project's portable
memory; the installer does not enable a recurring writer.

The model and npm/MCP selections are the exact reviewed values in
`config/tool-versions.json`. Do not substitute `latest` during recovery. Version
upgrades are a separate tested change after the machine is healthy.

### 6. Log in to Claude

```bash
claude login        # or run `claude` and follow the login prompt
```

### 7. Log in to Codex

```bash
codex login         # or run `codex` and follow the login prompt
```

### 8. Verify with doctor

```bash
ai-devops doctor
```

All **required** checks should pass. Warnings about optional tools are fine.

## After restore

- Review `/etc/ai-devops/models.env` and adjust the model CLI flags to match
  what your installed `claude` / `codex` accept (see `docs/model-setup.md`).
- Onboard your application repos separately (see `docs/repo-onboarding.md`).
  This toolkit does **not** modify application repos automatically.

## What is NOT restored (by design)

- Secret values and real `.env` files. Safe `op://` references live in the repo;
  installers restore required machine-local values from 1Password.
- Claude/Codex/gh login state — recreated by the `login` steps above.
- Application source code — cloned separately per project.
