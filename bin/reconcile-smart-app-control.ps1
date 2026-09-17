<#
.SYNOPSIS
Reconciles Windows Smart App Control to Off for official GitHub runner compatibility.

.DESCRIPTION
Smart App Control has no supported arbitrary local allowlist. Turning it Off is
irreversible without resetting or reinstalling Windows, so this script backs up
the exact policy registry key and active Code Integrity policies before the one
permitted mutation. A compliant second run performs no write and creates no
backup. -TestOnly reports drift with exit code 2 and never changes state.
#>
[CmdletBinding()]
param(
  [switch]$TestOnly,
  [string]$RegistryPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy',
  [string]$RegistryNativeKey = 'HKLM\SYSTEM\CurrentControlSet\Control\CI\Policy',
  [string]$BackupRoot = (Join-Path $env:ProgramData 'ai-devops\backups'),
  [string]$CiToolPath = (Join-Path $env:WINDIR 'System32\CiTool.exe'),
  [string]$RefreshMarkerPath = (Join-Path $env:ProgramData 'ai-devops\smart-app-control-off-refreshed.json'),
  [string[]]$ActivePolicyPaths = @(
    (Join-Path $env:WINDIR 'System32\CodeIntegrity\CiPolicies\Active'),
    (Join-Path $env:WINDIR 'System32\CodeIntegrity\SIPolicy.p7b')
  )
)
$ErrorActionPreference = 'Stop'
$valueName = 'VerifiedAndReputablePolicyState'

function Get-PolicyState {
  try {
    return [int](Get-ItemPropertyValue -LiteralPath $RegistryPath -Name $valueName -ErrorAction Stop)
  } catch {
    return $null
  }
}
function Invoke-PolicyRefresh {
  if (-not (Test-Path -LiteralPath $CiToolPath)) { throw "Code Integrity refresh tool is missing: $CiToolPath" }
  & $CiToolPath -r | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "Code Integrity policy refresh failed (CiTool exit $LASTEXITCODE)." }
  $markerParent = Split-Path -Parent $RefreshMarkerPath
  New-Item -ItemType Directory -Force -Path $markerParent | Out-Null
  [pscustomobject]@{ state=0; refreshedAtUtc=[DateTime]::UtcNow.ToString('o'); computer=$env:COMPUTERNAME } |
    ConvertTo-Json -Compress | Set-Content -LiteralPath $RefreshMarkerPath -Encoding ascii
}

$state = Get-PolicyState
if ($state -eq 0) {
  if ($TestOnly -and -not (Test-Path -LiteralPath $RefreshMarkerPath)) {
    Write-Host 'Smart App Control: DRIFT (registry is Off but active-policy refresh is unproven).'
    exit 2
  }
  if (-not $TestOnly) {
    Remove-Item -LiteralPath $RefreshMarkerPath -Force -ErrorAction SilentlyContinue
    Invoke-PolicyRefresh
  }
  Write-Host 'Smart App Control: COMPLIANT (Off; active policy refreshed when applying).'
  exit 0
}
if ($TestOnly) {
  Write-Host "Smart App Control: DRIFT (state=$(if ($null -eq $state) { 'missing' } else { $state }); required=0)."
  exit 2
}

if ($RegistryPath -like 'HKLM:*') {
  $principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
  if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Administrator permission is required to change Smart App Control.'
  }
}
if (-not (Test-Path -LiteralPath $CiToolPath)) { throw "Code Integrity refresh tool is missing: $CiToolPath" }

$stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$backup = Join-Path $BackupRoot "smart-app-control-$stamp"
New-Item -ItemType Directory -Force -Path $backup | Out-Null

& reg.exe export $RegistryNativeKey (Join-Path $backup 'ci-policy.reg') /y | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Could not back up $RegistryNativeKey (reg.exe exit $LASTEXITCODE)." }

$policiesBackup = Join-Path $backup 'active-policies'
New-Item -ItemType Directory -Force -Path $policiesBackup | Out-Null
foreach ($policyPath in $ActivePolicyPaths) {
  if (-not (Test-Path -LiteralPath $policyPath)) { continue }
  $leaf = Split-Path -Leaf $policyPath
  Copy-Item -LiteralPath $policyPath -Destination (Join-Path $policiesBackup $leaf) -Recurse -Force
}

Set-ItemProperty -LiteralPath $RegistryPath -Name $valueName -Type DWord -Value 0
if ((Get-PolicyState) -ne 0) { throw 'Smart App Control did not reconcile to Off after the registry write.' }
Remove-Item -LiteralPath $RefreshMarkerPath -Force -ErrorAction SilentlyContinue
Invoke-PolicyRefresh

Write-Host "Smart App Control: APPLIED (Off). Backup: $backup"
Write-Warning 'Smart App Control cannot be re-enabled without resetting or reinstalling Windows.'
exit 0
