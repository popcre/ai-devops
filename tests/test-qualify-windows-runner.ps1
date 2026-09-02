$ErrorActionPreference = 'Stop'
$script = Get-Content -Raw (Join-Path $PSScriptRoot '..\bin\qualify-windows-runner.ps1')
$required = @(
  '#Requires -RunAsAdministrator',
  'Get-Tpm',
  'Confirm-SecureBootUEFI',
  'CurrentBuildNumber',
  'C:\Program Files\PowerShell\7\pwsh.exe',
  'C:\Program Files\Git\bin\bash.exe',
  "actions.runner.*",
  'StartMode',
  'recorded_at_utc',
  'Move-Item -LiteralPath $temporary -Destination $EvidencePath -Force'
)
foreach ($marker in $required) {
  if (-not $script.Contains($marker)) { throw "Missing qualification guard: $marker" }
}
Write-Output 'PASS: Administrator Windows runner preflight is complete and atomic'
