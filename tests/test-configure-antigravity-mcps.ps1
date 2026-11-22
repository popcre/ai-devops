# Offline tests for bin/configure-antigravity-mcps.ps1
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Script = Join-Path $RepoRoot "bin\configure-antigravity-mcps.ps1"

$pass = 0
$fail = 0
$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("test-agy-mcps-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

function Assert-True([bool]$Cond, [string]$Label) {
  if ($Cond) { $script:pass++; Write-Host "PASS: $Label" }
  else { $script:fail++; Write-Host "FAIL: $Label" -ForegroundColor Red }
}

try {
  $cfgPath = Join-Path $tmpDir "mcp_config.json"

  # 1. Seed initial config with a foreign server
  @{
    mcpServers = @{
      foreign = @{ command = "node"; args = @("foreign.js") }
    }
  } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $cfgPath -Encoding UTF8

  # 2. Add managed 1password server
  $servers = [ordered]@{
    "1password" = [ordered]@{
      command = "C:\Users\test\.config\ai-devops\mcp-launch.cmd"
      args    = @("1password-mcp.cmd")
    }
  }
  & $Script -Servers $servers -ManagedNames @("1password", "retired") -ConfigPath $cfgPath | Out-Null
  $cfg = Get-Content -LiteralPath $cfgPath -Raw | ConvertFrom-Json
  Assert-True ($null -ne $cfg.mcpServers.foreign) "preserves foreign server"
  Assert-True ($cfg.mcpServers.'1password'.command -eq "C:\Users\test\.config\ai-devops\mcp-launch.cmd") "writes managed 1password command"
  Assert-True ($cfg.mcpServers.'1password'.args[0] -eq "1password-mcp.cmd") "writes managed 1password args"

  # 3. Idempotent re-run writes nothing
  $before = (Get-Item -LiteralPath $cfgPath).LastWriteTimeUtc
  Start-Sleep -Milliseconds 50
  & $Script -Servers $servers -ManagedNames @("1password", "retired") -ConfigPath $cfgPath | Out-Null
  $after = (Get-Item -LiteralPath $cfgPath).LastWriteTimeUtc
  Assert-True ($before -eq $after) "idempotent re-run does not rewrite file"

  # 4. Removing a managed server retires it while keeping foreign
  & $Script -Servers ([ordered]@{}) -ManagedNames @("1password") -ConfigPath $cfgPath | Out-Null
  $cfg2 = Get-Content -LiteralPath $cfgPath -Raw | ConvertFrom-Json
  Assert-True ($null -ne $cfg2.mcpServers.foreign) "foreign server survives retirement"
  Assert-True ($null -eq $cfg2.mcpServers.'1password') "deselected managed server is removed"

  # 5. Rejects unknown schema keys
  $threw = $false
  try {
    & $Script -Servers ([ordered]@{ bad = [ordered]@{ command = "x"; timeoutMs = 1000 } }) -ConfigPath $cfgPath | Out-Null
  } catch {
    $threw = $true
  }
  Assert-True $threw "rejects unknown schema key timeoutMs"

  Write-Host "`nSummary: $pass passed, $fail failed"
  if ($fail -gt 0) { exit 1 }
} finally {
  Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
}
