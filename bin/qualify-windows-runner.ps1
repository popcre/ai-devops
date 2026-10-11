#Requires -RunAsAdministrator
[CmdletBinding()]
param(
  [string]$EvidencePath = 'C:\ProgramData\ai-devops\windows-runner-security.json'
)

$ErrorActionPreference = 'Stop'
$build = [int](Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuildNumber
if ($build -lt 22000) { throw "Windows 11 is required; build is $build." }

$tpm = Get-Tpm
if (-not $tpm.TpmPresent -or -not $tpm.TpmReady) { throw 'TPM must be present and ready.' }
if (-not (Confirm-SecureBootUEFI)) { throw 'Secure Boot must be enabled.' }

# Remote-admin filtering must stay at its secure defaults (issue #1547).
# Never set LocalAccountTokenFilterPolicy, enable Windows sudo, or weaken UAC —
# those knobs are forbidden and cannot restore pre-2026-09-09 SSH filtering.
$uac = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
if ($uac.EnableLUA -ne 1) { throw "UAC must remain enabled (EnableLUA=1); found '$($uac.EnableLUA)'." }
if ($null -ne $uac.PSObject.Properties['LocalAccountTokenFilterPolicy'] -and $uac.LocalAccountTokenFilterPolicy -ne 0) {
  throw "LocalAccountTokenFilterPolicy must be absent or 0; found '$($uac.LocalAccountTokenFilterPolicy)'."
}
$sudo = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo' -ErrorAction SilentlyContinue
if ($sudo -and $sudo.Enabled -eq 1) { throw 'Windows sudo must not be enabled.' }

$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
  throw 'Qualification must run from an elevated administrator token.'
}
$integrity = whoami /groups | Select-String -Pattern 'Mandatory Label\\(High|Medium|Low|System) Mandatory Level' | ForEach-Object {
  $_.Matches[0].Groups[1].Value
} | Select-Object -First 1

$machinePwsh = 'C:\Program Files\PowerShell\7\pwsh.exe'
$gitBash = 'C:\Program Files\Git\bin\bash.exe'
foreach ($path in @($machinePwsh, $gitBash)) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required machine-wide tool is missing: $path" }
}

$runnerService = @(Get-Service | Where-Object Name -Like 'actions.runner.*')
if ($runnerService.Count -ne 1) { throw "Exactly one GitHub Actions runner service is required; found $($runnerService.Count)." }
if ($runnerService[0].Status -ne 'Running') { throw 'GitHub Actions runner service is not running.' }
$serviceConfig = Get-CimInstance Win32_Service -Filter "Name='$($runnerService[0].Name)'"
if ($serviceConfig.StartMode -ne 'Auto') { throw 'GitHub Actions runner service is not automatic.' }

$evidence = [ordered]@{
  schema_version = 1
  recorded_at_utc = [DateTime]::UtcNow.ToString('o')
  windows_build = $build
  tpm_present = $true
  tpm_ready = $true
  secure_boot = $true
  runner_service_automatic = $true
  machine_pwsh = $machinePwsh
  git_bash = $gitBash
  enable_lua = [int]$uac.EnableLUA
  local_account_token_filter_policy = if ($null -ne $uac.PSObject.Properties['LocalAccountTokenFilterPolicy']) { [int]$uac.LocalAccountTokenFilterPolicy } else { 'absent' }
  windows_sudo_enabled = if ($sudo -and $sudo.Enabled -eq 1) { $true } else { $false }
  caller_token_elevated = $true
  caller_integrity_level = $integrity
  token_posture_note = 'Local-admin Network (SSH) logons yield full elevated tokens since the 2026-09-09 Windows servicing regression (issue #1547). UAC knobs stay at secure defaults; host proofs must measure token posture instead of assuming filtering.'
}

$parent = Split-Path -Parent $EvidencePath
New-Item -ItemType Directory -Force -Path $parent | Out-Null
$temporary = "$EvidencePath.tmp"
$evidence | ConvertTo-Json | Set-Content -LiteralPath $temporary -Encoding utf8
Move-Item -LiteralPath $temporary -Destination $EvidencePath -Force
Write-Output "PASS: Windows runner security evidence written to $EvidencePath"
