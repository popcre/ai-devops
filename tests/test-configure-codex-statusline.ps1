$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $repoRoot "bin\configure-codex-statusline.ps1"
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-statusline-" + [guid]::NewGuid().ToString("N"))
$configPath = Join-Path $testRoot "config.toml"
$passed = 0

function Assert-True([bool]$condition, [string]$message) {
  if (-not $condition) { throw "FAIL: $message" }
  $script:passed++
}

try {
  New-Item -ItemType Directory -Force -Path $testRoot | Out-Null
  Set-Content -LiteralPath $configPath -Value @'
model = "local-model"

[tui]
theme = "dark"
status_line = ["current-dir"]
status_line_use_colors = false

[projects.'C:\repos\private']
trust_level = "trusted"
'@ -Encoding utf8

  & $scriptPath -ConfigPath $configPath | Out-Null
  $updated = Get-Content -LiteralPath $configPath -Raw
  Assert-True ($updated -match 'model = "local-model"') "preserves root settings"
  Assert-True ($updated -match 'theme = "dark"') "preserves unrelated tui settings"
  Assert-True ($updated -match '\[projects\.\''C:\\repos\\private\''\]') "preserves later sections"
  Assert-True ([regex]::Matches($updated, '(?m)^status_line\s*=').Count -eq 1) "writes one status_line key"
  Assert-True ([regex]::Matches($updated, '(?m)^status_line_use_colors\s*=').Count -eq 1) "writes one color key"
  Assert-True ($updated -match '"context-remaining"') "shows remaining context"
  Assert-True ($updated -match '"five-hour-limit"') "shows the five-hour allowance"
  Assert-True ($updated -match '"weekly-limit"') "shows the weekly allowance"
  Assert-True ((Get-ChildItem $testRoot -Filter 'config.toml.aidevops-*.bak').Count -eq 1) "backs up before changing"

  & $scriptPath -ConfigPath $configPath | Out-Null
  Assert-True ((Get-ChildItem $testRoot -Filter 'config.toml.aidevops-*.bak').Count -eq 1) "is idempotent"

  Remove-Item -LiteralPath $configPath
  Get-ChildItem $testRoot -Filter '*.bak' | Remove-Item -Force
  & $scriptPath -ConfigPath $configPath | Out-Null
  $created = Get-Content -LiteralPath $configPath -Raw
  Assert-True ($created -match '^\[tui\]') "creates a missing config"
  Assert-True ($created -match '"used-tokens"') "created config includes token usage"
  Write-Host "passed $passed, failed 0"
} finally {
  if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}
