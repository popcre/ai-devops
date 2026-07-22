# Windows development-computer setup (transitional launcher)

> Deprecated: use `bin\bootstrap-windows-dev.ps1`, documented in
> [windows-winget-configuration.md](windows-winget-configuration.md). The files
> below remain temporarily so existing shortcuts do not break; do not extend
> them with new setup behavior. Do not use this legacy launcher to validate the
> new minimum-touch workflow.

The former setup entry point was
`bin\\run_me_setup_dev_comp.bat`: double-click it from a normal Explorer
window. It requests Administrator permission and runs its helper automatically.

The helper `bin\\setup_dev_computer_internal.ps1` is intentionally not a
manual entry point. Keeping the small batch launcher and the PowerShell logic
separate gives double-click setup while keeping the real work in a script that
can be tested, versioned, and called by automation.

## What it installs and configures

The launcher was intended to be rerunnable. It is no longer the authority for
new-machine state and must not be treated as evidence that the replacement
bootstrap is live-proven. It installed or updated:

- Git, Node.js LTS, Python 3.13, PowerShell 7, GitHub CLI, Google Cloud SDK,
  and Azure CLI.
- Claude Code, the Codex Windows desktop app, Vercel CLI, Trigger.dev CLI, and
  Supabase CLI.
- WSL2, Ubuntu, and Ansible in Ubuntu.
- The repo-owned AI DevOps setup: Claude/Codex skills and global instructions,
  1Password service-account wiring, MCP configuration, the `916-alien` SSH
  key and host aliases, and memory sync.

During the AI DevOps stage, paste the scoped `vibe_coding` 1Password
service-account token when prompted. It is stored only in the user-restricted
machine location described in [onboarding-secrets.md](onboarding-secrets.md),
never in this repository.

## First-time and reboot flow

1. Clone or download this repository.
2. Double-click `bin\\run_me_setup_dev_comp.bat`.
3. Approve the Windows Administrator prompt.
4. If WSL/Ubuntu was newly installed, reboot, complete Ubuntu's first-run
   username/password prompt, then run the same batch file again.
5. Follow the validation checklist printed by the AI DevOps stage, including
   reopening Claude Desktop and checking its MCP connections.

Do not maintain a second copy of these legacy scripts in Dropbox. The repo is the
source of truth; a local Dropbox shortcut may point to the batch launcher in a
checked-out copy if that is more convenient.

## Boundaries

This setup installs tools and configures the coding workstation. It does not
store secrets in Git, create new cloud credentials, or replace the separate
Ansible setup used for managed Linux hosts.
