$ErrorActionPreference = 'Stop'
$script = Join-Path (Split-Path $PSScriptRoot -Parent) 'bin\mcp-secret-launch.ps1'
$tokens = $null
$errors = $null
[Management.Automation.Language.Parser]::ParseFile($script, [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count) { throw "mcp-secret-launch.ps1 has parser errors: $($errors -join '; ')" }

$text = Get-Content -Raw -LiteralPath $script
foreach ($required in @('Threading.Mutex', 'op run', 'ConvertFrom-SecureString', 'ConvertTo-SecureString', 'cacheMinutes = 15')) {
  if (-not $text.Contains($required)) { throw "Missing concurrency/cache safeguard: $required" }
}
if ($text -match '\bop read\b') { throw 'The Windows launcher must resolve the shared environment once, not call op read per key.' }
if ($text -match '& npx') { throw 'The Windows launcher must not resolve an MCP package on the startup hot path.' }
if (-not $text.Contains('mcp-runtime\node_modules\.bin\mcp-remote.cmd')) { throw 'The Windows launcher must use the pinned MCP runtime.' }
if (-not $text.Contains('mcp-session-guard.mjs')) { throw 'The Windows launcher must start MCP helpers under the session guard.' }
if (-not $text.Contains('[Environment]::SetEnvironmentVariable(''MCP_REMOTE_AUTH_HEADER'', "Bearer $token", ''Process'')')) { throw 'The Windows remote bearer value must stay in the child environment.' }
if (-not $text.Contains('--header ''Authorization:${MCP_REMOTE_AUTH_HEADER}''')) { throw 'The Windows remote header must reach pinned mcp-remote as an argv placeholder.' }
if ($text.Contains('--header "Authorization: Bearer $token"')) { throw 'The Windows remote launcher leaks the bearer value through process argv.' }
Write-Host 'PASS: MCP 1Password launcher is parseable, single-flight, DPAPI-encrypted, session-guarded, and keeps remote bearer values out of argv.'
