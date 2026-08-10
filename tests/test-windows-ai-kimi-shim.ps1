$ErrorActionPreference = "Stop"

$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not (Test-Path -LiteralPath (Join-Path $repo "bin\setup-machine.ps1"))) {
  $repo = Split-Path -Parent $PSScriptRoot
}
$setup = Get-Content -Raw (Join-Path $repo "bin\setup-machine.ps1")

foreach ($required in @(
  'Set-Content -NoNewline -Encoding ASCII -Path (Join-Path $delegateBinDir "ai-kimi")',
  'Set-Content -Encoding ASCII -Path (Join-Path $delegateBinDir "ai-kimi.cmd")',
  'export HOME="$homeBash"',
  'exec "$kimiBash" "`$@"'
)) {
  if (-not $setup.Contains($required)) {
    throw "Missing Windows ai-kimi shim control: $required"
  }
}

Write-Host "PASS: setup installs ai-kimi for PowerShell and Git Bash"
