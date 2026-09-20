$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $repoRoot "bin\configure-codex-agent-limit.ps1"
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-agent-limit-" + [guid]::NewGuid().ToString("N"))
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

[agents]
enabled = true
max_threads = 6
max_concurrent_threads_per_session = 8

[agents.reviewer]
description = "Keep me"

[projects.'C:\repos\private']
trust_level = "trusted"
'@ -Encoding utf8

  & $scriptPath -ConfigPath $configPath | Out-Null
  $updated = Get-Content -LiteralPath $configPath -Raw
  Assert-True ($updated -match 'model = "local-model"') "preserves root settings"
  Assert-True ($updated -match 'enabled = true') "preserves unrelated agent settings"
  Assert-True ($updated -match 'description = "Keep me"') "preserves custom agents"
  Assert-True ($updated -match '\[projects\.\''C:\\repos\\private\''\]') "preserves later sections"
  Assert-True ([regex]::Matches($updated, '(?m)^max_threads\s*=\s*20\r?$').Count -eq 1) "writes one compatible limit"
  Assert-True ([regex]::Matches($updated, '(?m)^max_concurrent_threads_per_session\s*=').Count -eq 0) "removes the incompatible spelling"
  Assert-True ((Get-ChildItem $testRoot -Filter 'config.toml.aidevops-*.bak').Count -eq 1) "backs up before changing"

  & $scriptPath -ConfigPath $configPath | Out-Null
  Assert-True ((Get-ChildItem $testRoot -Filter 'config.toml.aidevops-*.bak').Count -eq 1) "is idempotent"

  Remove-Item -LiteralPath $configPath
  Get-ChildItem $testRoot -Filter '*.bak' | Remove-Item -Force
  Set-Content -LiteralPath $configPath -Value @'
[agents.reviewer]
description = "Keep me"
'@ -Encoding utf8
  & $scriptPath -ConfigPath $configPath | Out-Null
  $created = Get-Content -LiteralPath $configPath -Raw
  Assert-True ($created.IndexOf('[agents]') -lt $created.IndexOf('[agents.reviewer]')) "creates the parent table before a custom agent"
  Assert-True ($created -match '(?m)^max_threads = 20\r?$') "created parent table has the standard limit"

  Remove-Item -LiteralPath $configPath
  Get-ChildItem $testRoot -Filter '*.bak' | Remove-Item -Force
  & $scriptPath -ConfigPath $configPath | Out-Null
  $newConfig = Get-Content -LiteralPath $configPath -Raw
  Assert-True ($newConfig -match '^\[agents\]') "creates a missing config"
  Assert-True ($newConfig -match '(?m)^max_threads = 20\r?$') "new config has the standard limit"

  Write-Host "passed $passed, failed 0"
} finally {
  if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}
