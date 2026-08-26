# Windows half of the project-scoped MCP contract in bin/setup-machine.ps1.
#
# This file exists because a review on 2026-08-26 found that Windows still had
# the "configured nowhere" bug after it had been fixed on Linux, and the Linux
# test stayed green throughout. The Linux test cannot see this script at all.
#
# These are contract assertions read from the source, not a full execution of
# setup-machine.ps1 (which needs 1Password, network and a real machine).
$ErrorActionPreference = "Stop"
$root   = Split-Path -Parent $PSScriptRoot
$script = Join-Path $root "bin\setup-machine.ps1"
$src    = Get-Content -LiteralPath $script -Raw

$pass = 0; $fail = 0
function Check($cond, $msg) {
  if ($cond) { Write-Host "  ok   $msg" -ForegroundColor Green; $script:pass++ }
  else       { Write-Host "  FAIL $msg" -ForegroundColor Red;   $script:fail++ }
}

Write-Host "contract: Claude Code prunes ONLY what reached a project file"
Check ($src -match '\$McpScopedDone\s*=\s*@\(\)') `
  'the confirmed-scoped list exists'
Check ($src -match 'foreach \(\$name in \$McpScopedDone\)\s*\{\s*\$null = \$cc\["mcpServers"\]\.Remove') `
  'Claude Code removes names from $McpScopedDone'
Check ($src -notmatch 'foreach \(\$name in \$McpProjectScope\.Keys\)\s*\{\s*\$null = \$c[cf]g?\["mcpServers"\]\.Remove') `
  'nothing prunes the whole scope map unconditionally (the original bug)'

Write-Host "contract: Claude Desktop keeps the full set"
# Desktop has no .mcp.json mechanism, so removing a name there deletes it.
$desktopBlock = [regex]::Match($src, '# 6\. Best-effort.*?# 7\.', 'Singleline').Value
Check ($desktopBlock -match 'foreach \(\$name in \$McpServers\.Keys\)') `
  'Desktop is written from the FULL server set'
Check ($desktopBlock -notmatch '\$McpProjectScope\.Keys\)\s*\{\s*\$null') `
  'Desktop never prunes project-scoped names'

Write-Host "contract: seeding happens BEFORE the global configs are written"
$iSeed    = $src.IndexOf('Step "Project-scoped MCP servers')
$iDesktop = $src.IndexOf('# 6. Best-effort: wire MCP servers into Claude Desktop')
$iCode    = $src.IndexOf('Step "Token-free MCP for Claude Code')
Check ($iSeed -gt 0 -and $iDesktop -gt 0 -and $iCode -gt 0) 'all three sections found'
Check ($iSeed -lt $iDesktop -and $iSeed -lt $iCode) `
  'seeding precedes both global writes (else the prune list is empty)'

Write-Host "contract: fail safe, never fail closed"
Check ($src -match 'STAY GLOBAL so they keep working') `
  'a project that cannot be written leaves its servers global'
Check ($src -match 'is not valid JSON - left alone') `
  'invalid project JSON is skipped, not overwritten'
Check ($src -match 'Join-Path \$candidate "\.git"') `
  'a project must be a real git checkout, not just a directory of that name'
Check ($src -match 'check-ignore') `
  'a gitignored seed is reported (it would never travel to other clones)'

Write-Host "contract: portability of the seeded file"
Check ($src -match 'function ConvertTo-AiDevOpsPortableMcp') `
  'a recursive portability helper exists'
Check ($src -notmatch 'ConvertTo-Json -Depth 12\)\.Replace\(\$env:USERPROFILE') `
  'no Replace() on JSON TEXT - PowerShell escapes backslashes so it never matches'
Check ($src -match 'Windows definitions point at \.cmd launchers') `
  'the Windows-seeding skip list is documented in place'
Check ($src -match '\$McpProjectWindowsSkip\s*=\s*@\("synology-monitor"\)') `
  'synology-monitor is never seeded from Windows (its repo is used from Linux)'

Write-Host "contract: the two scripts agree on ownership"
$sh = Get-Content -LiteralPath (Join-Path $root "bin\setup-secrets.sh") -Raw
foreach ($pair in @(@('trigger','oracle'), @('recall-ai','oracle'), @('railway','popdam3'),
                    @('ag-grid','designflow-frontend'), @('devops-mcp','synology-monitor'),
                    @('synology-monitor','synology-monitor'))) {
  $n, $p = $pair
  $inPs = $src -match ([regex]::Escape('"' + $n + '"') + '\s*=\s*"' + [regex]::Escape($p) + '"')
  $inSh = $sh  -match ([regex]::Escape('"' + $n + '"') + '\s*:\s*"' + [regex]::Escape($p) + '"')
  Check ($inPs -and $inSh) "$n -> $p in BOTH scripts"
}

Write-Host ""
if ($fail -gt 0) { Write-Host "$pass passed, $fail failed" -ForegroundColor Red; exit 1 }
Write-Host "$pass passed, 0 failed" -ForegroundColor Green
