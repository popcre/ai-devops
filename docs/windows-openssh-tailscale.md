# Windows OpenSSH over Tailscale only

Use this procedure to make a Windows coding PC available to approved Claude or
Codex sessions through SSH public-key authentication. It deliberately replaces
WinRM: OpenSSH is the appropriate Windows remote-management service when the
managing machines already use SSH keys.

Normal new-computer setup no longer requires running these commands manually:
`bin/bootstrap-windows-dev.ps1` invokes the repo-owned implementation in
`bin/configure-windows-bootstrap-access.ps1`. Keep this page as the detailed
design, troubleshooting, and verification reference.

As of 2026-07-17 this automated path is source-complete and statically
validated, but its first disposable-machine run and second-run idempotency gate
remain outstanding. Do not replace the known-working SSH configuration on 4837
merely to test the automation. Use the bootstrap's `-TestOnly` mode until the
live gates in `windows-winget-configuration.md` pass.

The target state is:

- Windows OpenSSH Server (`sshd`) starts automatically and accepts public keys;
  password logins are disabled.
- The `916-alien` public key is authorized for the Windows administrator
  account. Its private key is never copied or written during this procedure.
- Windows Firewall permits SSH/TCP 22 only where the destination is the PC's
  Tailscale IPv4 address and the source is within Tailscale's `100.64.0.0/10`
  IPv4 range.
- WinRM is stopped and disabled; it has no listener or custom firewall rule.

This is IPv4-only. Do not create an IPv6 exception without an explicit,
reviewed equivalent firewall design.

## Prerequisites

These are prerequisites for the **manual troubleshooting procedure below**.
The normal bootstrap installs/detects Tailscale and OpenSSH and reads the
repo-committed public key itself.

1. Tailscale is installed, signed in, and connected on the target PC.
2. Open **PowerShell as Administrator**.
3. Confirm the `916-alien` public key is present at
   `%USERPROFILE%\.ssh\916-alien.pub`. It is safe to distribute a public key;
   never copy or display the matching private key.
4. Obtain the Tailscale IPv4 address and MagicDNS name:

   ```powershell
   tailscale ip -4
   tailscale status
   ```

## Install the Windows feature

First try the built-in capability command:

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
```

If it remains at `Operation [Running]` for several minutes, press `Ctrl+C`,
verify it is still `NotPresent`, then install it through the Windows UI:

1. **Settings** → **System** → **Optional features**.
2. **View features** beside "Add an optional feature".
3. Search for **OpenSSH Server**, select it, then choose **Next** → **Install**.
4. Wait for **Installed** before continuing.

The PowerShell capability installer depends on Windows servicing/Windows Update
and can stall even though the UI installer succeeds.

## Configure key-only, Tailscale-only access

Set `$tsIp` to the target PC's Tailscale IPv4 address. Run this once in the
elevated PowerShell window after OpenSSH Server is installed.

```powershell
$tsIp = '100.x.y.z'
$keyPath = "$env:USERPROFILE\.ssh\916-alien.pub"

# Remove the obsolete WinRM configuration created by older instructions.
Get-ChildItem WSMan:\LocalHost\Listener -ErrorAction SilentlyContinue |
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Remove-NetFirewallRule -DisplayName 'WinRM HTTPS — Tailscale only' -ErrorAction SilentlyContinue
Stop-Service WinRM -ErrorAction SilentlyContinue
Set-Service WinRM -StartupType Disabled

# Start OpenSSH Server.
Set-Service sshd -StartupType Automatic
Start-Service sshd

# Windows uses this shared file, rather than a profile-local authorized_keys
# file, for members of the local Administrators group.
$key = (Get-Content -Raw $keyPath).Trim()
$authorizedKeys = "$env:ProgramData\ssh\administrators_authorized_keys"
New-Item -ItemType File -Path $authorizedKeys -Force | Out-Null
if (-not (Select-String -Path $authorizedKeys -SimpleMatch $key -Quiet)) {
  Add-Content -Path $authorizedKeys -Value $key
}

# Use SIDs so this works on non-English Windows installations too.
icacls.exe $authorizedKeys /inheritance:r /grant '*S-1-5-18:F' /grant '*S-1-5-32-544:F'

# The final occurrence in sshd_config wins. Add key-only authentication once.
Add-Content "$env:ProgramData\ssh\sshd_config" `
  -Value "`n# Managed: Tailscale-only AI setup access`nPasswordAuthentication no`nPubkeyAuthentication yes"

# Disable the broad feature-created rule and replace it with a narrow one.
Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue |
  Disable-NetFirewallRule
Remove-NetFirewallRule -DisplayName 'OpenSSH Server — Tailscale only' -ErrorAction SilentlyContinue
New-NetFirewallRule `
  -DisplayName 'OpenSSH Server — Tailscale only' `
  -Direction Inbound -Action Allow -Protocol TCP -LocalPort 22 `
  -LocalAddress $tsIp -RemoteAddress '100.64.0.0/10' -Profile Any

Restart-Service sshd
```

## Verify

On the target machine, run:

```powershell
Get-Service sshd,WinRM
Get-CimInstance Win32_Service -Filter "Name='WinRM'" |
  Select-Object Name, State, StartMode
Get-NetFirewallRule -DisplayName 'OpenSSH Server — Tailscale only' |
  Get-NetFirewallAddressFilter
Test-NetConnection -ComputerName $tsIp -Port 22
```

Success requires `sshd` to be running, WinRM to be stopped with `StartMode`
`Disabled`, and `TcpTestSucceeded : True`. Windows displays the firewall CIDR
as `100.64.0.0/255.192.0.0`, which is expected.

From `916-alien`, test the actual public-key authentication:

```powershell
ssh -i "$env:USERPROFILE\.ssh\916-alien" 'IML\ahazan2@<target-MagicDNS-name>' whoami
```

Replace the example Windows account with the intended administrator account and
the placeholder with the target's MagicDNS name. A successful result should
identify that Windows account and must not request a password.

## Access controls and maintenance

The Windows Firewall rule prevents LAN/public SSH access, but it cannot select
individual Tailscale devices. Add a Tailscale ACL permitting only `916-alien`
and any explicitly approved management machines (or a dedicated tag) to reach
the target on `tcp:22`.

For administrator accounts Windows OpenSSH uses
`C:\ProgramData\ssh\administrators_authorized_keys`, and Windows requires that
file to be writable only by `SYSTEM` and Administrators. Incorrect ACLs are a
common cause of `Permission denied (publickey)`.

Never re-enable password authentication, the broad `OpenSSH-Server-In-TCP`
firewall rule, an HTTP/WinRM listener, or WinRM merely to work around a failed
connection. First check the Tailscale ACL, the custom firewall rule, the SSH
key path, file ACL, account name, and SSH client verbose output (`ssh -vvv`).
