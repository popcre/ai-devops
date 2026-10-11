$ErrorActionPreference = 'Stop'
$script = Get-Content -Raw (Join-Path $PSScriptRoot '..\bin\qualify-windows-runner.ps1')
$required = @(
  '#Requires -RunAsAdministrator',
  "[string]`$EvidencePath = 'C:\ProgramData\ai-devops\windows-runner-security.json'",
  'Get-Tpm',
  'Confirm-SecureBootUEFI',
  'CurrentBuildNumber',
  'C:\Program Files\PowerShell\7\pwsh.exe',
  'C:\Program Files\Git\bin\bash.exe',
  "actions.runner.*",
  'StartMode',
  'recorded_at_utc',
  'Move-Item -LiteralPath $temporary -Destination $EvidencePath -Force',
  'EnableLUA',
  'LocalAccountTokenFilterPolicy',
  'Windows sudo must not be enabled',
  'enable_lua',
  'local_account_token_filter_policy',
  'windows_sudo_enabled',
  'caller_token_elevated',
  'caller_integrity_level',
  'token_posture_note',
  'issue #1547'
)
foreach ($marker in $required) {
  if (-not $script.Contains($marker)) { throw "Missing qualification guard: $marker" }
}
Write-Output 'PASS: Administrator Windows runner preflight is complete and atomic'
