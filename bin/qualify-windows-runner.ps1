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
}

$parent = Split-Path -Parent $EvidencePath
New-Item -ItemType Directory -Force -Path $parent | Out-Null
$temporary = "$EvidencePath.tmp"
$evidence | ConvertTo-Json | Set-Content -LiteralPath $temporary -Encoding utf8
Move-Item -LiteralPath $temporary -Destination $EvidencePath -Force
Write-Output "PASS: Windows runner security evidence written to $EvidencePath"

