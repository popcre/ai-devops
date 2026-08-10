# Restore From Zero

How to rebuild this AI coding workflow on a new Windows 11 computer or Ubuntu
server. The repository is the only setup source. Secrets are restored at runtime
from 1Password vault `vibe_coding`; secret values never belong in Git.

## Windows 11

1. Install Git and PowerShell 7 if they are absent.
2. Clone `https://github.com/u2giants/ai-devops.git` to `C:\repos\ai-devops`.
3. Run this in PowerShell 7:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File C:\repos\ai-devops\bin\setup-machine.ps1 -RepoPath C:\repos\ai-devops
```

The script installs skills, restores protected SSH and MCP wiring from
1Password, fixes the Codex executable path, and registers background memory
sync. If the protected service-account token file is absent, supply the token
once from the `vibe_coding` vault. Do not paste it into a repo file.

Verify with the script's final checks and a real `codex exec` sandbox write.
Fully quit and reopen Claude Desktop before checking its MCP servers.

## Ubuntu

> Target path is always `/worksp/ai-devops`. Never `/opt/ai-devops`.

## Exact steps

### 1. Create an Ubuntu server

Provision a fresh Ubuntu box (any recent LTS). Log in as a sudo-capable user.

### 2. Install git

```bash
sudo apt-get update
sudo apt-get install -y git
```

### 3. Clone this repo to /worksp/ai-devops

```bash
sudo mkdir -p /worksp
sudo chown "$USER":"$USER" /worksp
git clone https://github.com/u2giants/ai-devops.git /worksp/ai-devops
cd /worksp/ai-devops
```

### 4. Run install.sh

```bash
./install.sh
```

This installs base dependencies, creates `/etc/ai-devops` and
`/var/log/ai-devops`, seeds `models.env` / `server.env` (without overwriting any
existing real config), installs skills, calls `bin/setup-secrets.sh` for the
1Password-backed MCP wiring, symlinks the `bin/` tools into `/usr/local/bin`,
and runs `ai-devops doctor`.

### 5. Authenticate GitHub CLI

```bash
gh auth login
```

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
