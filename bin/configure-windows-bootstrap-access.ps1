<# Configure the local prerequisites that Ansible cannot create before its first connection. #>
[CmdletBinding()]
param(
  [string]$RepoPath = (Split-Path -Parent $PSScriptRoot),
  [switch]$TestOnly,
  [switch]$SkipTailscaleLogin
)

$ErrorActionPreference = 'Stop'
$results = [Collections.Generic.List[object]]::new()
function Result($Name, $Status, $Detail) {
  $results.Add([pscustomobject]@{ Check=$Name; Status=$Status; Detail=$Detail })
}
function Get-TailscaleExe {
  $command = Get-Command tailscale -ErrorAction SilentlyContinue
  if ($command) { return $command.Source }
  $candidate = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'
  if (Test-Path $candidate) { return $candidate }
  throw 'Tailscale was not found after WinGet configuration.'
}
function Get-TailscaleIPv4([string]$TailscaleExe) {
  $value = (& $TailscaleExe ip -4 2>$null | Select-Object -First 1)
  if ($value -and $value.Trim() -match '^100\.') { return $value.Trim() }
  return $null
}

$principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  throw 'Run the Windows bootstrap from an elevated Administrator PowerShell window.'
}

$tailscale = Get-TailscaleExe
$tsIp = Get-TailscaleIPv4 $tailscale
if (-not $tsIp -and -not $TestOnly -and -not $SkipTailscaleLogin) {
  Write-Host 'Tailscale needs its one-time account authorization. Complete the browser sign-in that opens.' -ForegroundColor Yellow
  & $tailscale up
  if ($LASTEXITCODE -ne 0) { throw 'Tailscale authorization did not complete.' }
  $tsIp = Get-TailscaleIPv4 $tailscale
}
if ($tsIp) { Result 'Tailscale' 'OK' $tsIp }
else { Result 'Tailscale' 'NEEDS_AUTH' 'Run tailscale up and complete the browser sign-in.' }

$capability = Get-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
if ($capability.State -ne 'Installed' -and -not $TestOnly) {
  Write-Host 'Installing the Windows OpenSSH Server capability. Windows Update may take several minutes.' -ForegroundColor Cyan
  Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 | Out-Null
  $capability = Get-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
}
if ($capability.State -eq 'Installed') { Result 'OpenSSH capability' 'OK' 'Installed' }
else { Result 'OpenSSH capability' 'MISSING' $capability.State }

$publicKeyPath = Join-Path $RepoPath 'config\916-alien.pub'
if (-not (Test-Path $publicKeyPath)) { throw "Missing committed public key: $publicKeyPath" }

if (-not $TestOnly -and $capability.State -eq 'Installed') {
  Set-Service sshd -StartupType Automatic
  Start-Service sshd

  $authorizedKeys = Join-Path $env:ProgramData 'ssh\administrators_authorized_keys'
  $publicKey = (Get-Content -Raw $publicKeyPath).Trim()
  if (-not (Test-Path $authorizedKeys)) { New-Item -ItemType File -Path $authorizedKeys -Force | Out-Null }
  $existingKeys = @(Get-Content $authorizedKeys -ErrorAction SilentlyContinue)
  if ($existingKeys -notcontains $publicKey) { Add-Content -Path $authorizedKeys -Value $publicKey }
  & icacls.exe $authorizedKeys /inheritance:r /grant '*S-1-5-18:F' /grant '*S-1-5-32-544:F' | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Could not secure administrators_authorized_keys ACLs.' }

  $sshdConfig = Join-Path $env:ProgramData 'ssh\sshd_config'
  $content = Get-Content -Raw $sshdConfig
  $start = '# BEGIN AI-DEVOPS KEY-ONLY AUTH'
  $end = '# END AI-DEVOPS KEY-ONLY AUTH'
  $managedPattern = '(?ms)^' + [regex]::Escape($start) + '.*?^' + [regex]::Escape($end) + '\s*'
  $content = [regex]::Replace($content, $managedPattern, '')
  $block = "$start`r`nPasswordAuthentication no`r`nPubkeyAuthentication yes`r`n$end`r`n`r`n"
  $match = [regex]::Match($content, '(?im)^\s*Match\s+')
  if ($match.Success) { $content = $content.Insert($match.Index, $block) }
  else { $content = $content.TrimEnd() + "`r`n`r`n$block" }
  $originalConfig = Get-Content -Raw $sshdConfig
  Set-Content -Path $sshdConfig -Value $content -Encoding ascii
  & "$env:WINDIR\System32\OpenSSH\sshd.exe" -t -f $sshdConfig
  if ($LASTEXITCODE -ne 0) {
    Set-Content -Path $sshdConfig -Value $originalConfig -Encoding ascii
    throw 'The managed sshd_config failed validation; the original was restored.'
  }
  Restart-Service sshd

  Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue | Disable-NetFirewallRule
  Remove-NetFirewallRule -DisplayName 'OpenSSH Server — Tailscale only' -ErrorAction SilentlyContinue
  if (-not $tsIp) { throw 'OpenSSH is installed, but the Tailscale address is unavailable; firewall access was not opened.' }
  New-NetFirewallRule -DisplayName 'OpenSSH Server — Tailscale only' -Direction Inbound -Action Allow `
    -Protocol TCP -LocalPort 22 -LocalAddress $tsIp -RemoteAddress '100.64.0.0/10' -Profile Any | Out-Null

  Get-NetFirewallRule -DisplayGroup 'Windows Remote Management' -ErrorAction SilentlyContinue | Disable-NetFirewallRule
  Remove-NetFirewallRule -DisplayName 'WinRM HTTPS — Tailscale only' -ErrorAction SilentlyContinue
  Stop-Service WinRM -ErrorAction SilentlyContinue
  Set-Service WinRM -StartupType Disabled
}

$sshd = Get-Service sshd -ErrorAction SilentlyContinue
$firewall = Get-NetFirewallRule -DisplayName 'OpenSSH Server — Tailscale only' -ErrorAction SilentlyContinue
$keyInstalled = Test-Path (Join-Path $env:ProgramData 'ssh\administrators_authorized_keys')
Result 'sshd service' $(if($sshd -and $sshd.Status -eq 'Running'){'OK'}else{'MISSING'}) $(if($sshd){$sshd.Status}else{'not installed'})
Result 'SSH public key' $(if($keyInstalled){'OK'}else{'MISSING'}) 'administrators_authorized_keys'
Result 'Tailscale SSH firewall' $(if($firewall -and $firewall.Enabled){'OK'}else{'MISSING'}) $(if($tsIp){$tsIp}else{'no Tailscale IPv4'})
$results | Format-Table -AutoSize | Out-Host
if ($results.Status | Where-Object { $_ -ne 'OK' }) { exit 2 }
exit 0
