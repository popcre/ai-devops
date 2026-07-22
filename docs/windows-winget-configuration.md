# Windows desired-state setup with WinGet and DSC

## Executive decision and current safety status

This replaces separate package, SSH, MCP, dotfile, and skills scripts. The
intended experience is one command on a new Windows computer, one possible
reboot, and the same command again. It is convergent by design: each component
checks existing state, keeps compliant state, adds missing state, and repairs
declared drift.

That does **not** mean this first source version should be trialed on a valuable
working computer. As of 2026-07-17 it has passed static and read-only validation
but has not completed two required live gates: a full run on a disposable clean
Windows 11 machine, followed immediately by a second run showing no unintended
changes. Therefore use normal mode on a new/disposable machine, but use
`-TestOnly` for inspection on an established computer such as 4837 until those
gates pass. The bootstrap may change anything listed under "Owned state"; it
does not preserve working but noncompliant owned settings.

The professional Windows setup entry point is `bin/bootstrap-windows-dev.ps1`.
It updates the private `u2giants/ai-devops` checkout, applies the declarative
`.config/configuration.winget` file, and then calls `bin/setup-machine.ps1` for
Albert-specific configuration.

The bootstrap is also the one-time connection bootstrap: it authorizes
Tailscale when needed, installs Windows OpenSSH Server, authorizes the committed
`916-alien` public key, restricts TCP 22 to the Tailscale address/range, disables
WinRM, clones/updates `u2giants/ansible`, and installs Ansible plus required
collections inside Ubuntu WSL. This removes the circular dependency where
Ansible previously needed SSH before it could configure SSH.

This split is intentional:

- WinGet Configuration and DSC own ordinary packages and non-secret Windows
  settings. Re-running them updates packages and repairs drift.
- `setup-machine.ps1` owns skills, managed dotfiles, SSH aliases and keys, MCP
  launchers, and 1Password references. Secrets are resolved only at runtime and
  are never placed in the WinGet file or Git.
- Ansible may call the same bootstrap remotely; it should not duplicate these
  Windows package declarations.

## Owned state: what an applying run may change

The bootstrap is authoritative for:

- declared WinGet packages, Win32 long-path support, Vercel and Trigger.dev
  through npm, and Supabase CLI through Scoop;
- Tailscale installation and connection detection;
- Windows OpenSSH Server, key-only authentication, the committed `916-alien`
  public key, and the Tailscale-only TCP 22 firewall rule;
- WinRM service/listener/firewall removal;
- WSL, Ubuntu, Ansible, `ansible-lint`, required Galaxy collections, and the
  `u2giants/ansible` checkout;
- the `u2giants/ai-devops` checkout when clean and fast-forwardable;
- AI DevOps-managed Claude/Codex skills, global instructions, managed
  dotfiles/includes, SSH aliases/keys, MCP launchers/configuration, and scoped
  1Password runtime wiring.

Matching state should be left alone, missing state installed, and declared
drift repaired. Package and repository updates may change versions even when a
tool already works. Dirty Git checkouts must fail loudly rather than be
overwritten. The workflow does not own unrelated application repositories,
user documents, undeclared Windows personalization, Tailscale ACL policy, or
cloud credentials outside the documented 1Password flow.

The declarative file covers Git, PowerShell, Node.js, Python, GitHub CLI,
VS Code, 1Password CLI, Google Cloud SDK, Azure CLI, cloudflared, Tailscale,
WSL, Ubuntu, Claude Code, the Codex desktop Store app, and Win32 long-path
support. Vercel and Trigger.dev (npm) and Supabase CLI (Scoop) are not WinGet
packages. The bootstrap calls `bin/reconcile-windows-package-exceptions.ps1`
internally for those three, keeping one user-facing command while leaving the
declarative WinGet file honest about package ownership.

## Run it

From PowerShell in an existing checkout (the script self-elevates):

```powershell
pwsh -NoProfile -File .\bin\bootstrap-windows-dev.ps1
```

On a fresh machine, authenticate GitHub first because this is a private repo,
download the bootstrap script, and run it. It installs Git if necessary and
clones the repo to `%USERPROFILE%\repos\ai-devops` by default. Use `-RepoPath`
to select another location.

Use the read-only modes before rollout:

```powershell
pwsh -NoProfile -File .\bin\bootstrap-windows-dev.ps1 -TestOnly -SkipMachineSetup
pwsh -NoProfile -File .\bin\verify-windows-dev.ps1
pwsh -NoProfile -File .\tests\windows-winget-config.tests.ps1
```

`-TestOnly` validates the file and asks WinGet/DSC to test desired state; it
does not clone, pull, install, or configure. The standalone verification command
writes a non-secret JSON report under `%TEMP%` by default. The structural test
never invokes WinGet and is safe in CI or on a development computer.

Normal mode is for a new/disposable computer or for reconciliation after live
proof. If WSL requests a reboot, reboot and rerun the identical normal command.
A DRIFT result from `-TestOnly` means normal mode would have work to do; it is
not automatic permission to apply those changes.

## Required rollout and idempotency proof

Before approving this for 4837 or another established workstation:

1. Create a disposable clean Windows 11 machine.
2. Run the one-line README entrypoint, completing only GitHub, Tailscale, and
   1Password authentication. Reboot and rerun if Windows requests it.
3. Verify the report, key-only SSH over Tailscale, disabled WinRM, working WSL
   Ansible, installed AI tools/skills, and MCP configuration without secret
   output.
4. Run the bootstrap again without changing the machine. Acceptance requires
   no unintended changes, no duplicate keys/config blocks, and a PASS report.
5. Only then run `-TestOnly` on 4837, review every difference, and explicitly
   approve any applying run.

If the first run fails, fix the repo-owned source, restore a clean disposable
snapshot, and repeat both gates. Do not manually nurse a broken VM into a state
that hides bootstrap defects.

## Failure and recovery behavior

- A dirty repo blocks fast-forward updates so local work is preserved.
- Invalid `sshd_config` must be rejected before SSH restart; the access
  reconciler restores the prior file.
- Missing Tailscale authentication uses the normal authorization boundary; the
  script does not manufacture or embed an auth key.
- OpenSSH/WSL capability installation can stall in Windows servicing. Inspect
  capability state, use Settings > System > Optional features if necessary,
  reboot if required, and rerun the same bootstrap.
- A nonzero or DRIFT result is not success. Preserve its report and diagnose
  the failing stage before managing real computers with Ansible.

## Expected interactive boundaries

The remaining human touchpoints are authentication boundaries: GitHub access
to the private repos, Tailscale's browser authorization, and the initial scoped
`vibe_coding` 1Password service-account token. WSL/Ubuntu installation can
require a Windows reboot; rerun the identical bootstrap afterward and it
continues idempotently. Ubuntu is probed and configured as root for the Ansible
controller, avoiding a separate first-run username prompt for automation. The
automation must never manufacture, print, or commit credentials.

Internal scripts exist for separation and testing, but the user runs only
`bootstrap-windows-dev.ps1`. `-SkipRemoteAccess`, `-SkipAnsibleController`, and
`-SkipMachineSetup` are troubleshooting/advanced flags, not normal setup steps.

The file uses WinGet Configuration schema 0.2, which is supported by WinGet 1.6
and later. This established processor is intentional: WinGet 1.29.280 on the
4837 development machine failed to discover Microsoft's own built-in package
resources when validating the newly released v3 schema on 2026-07-17. Move to
v3 only after Microsoft's validator accepts an equivalent file on a clean PC.
