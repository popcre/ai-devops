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
Write-Host 'PASS: MCP 1Password launcher is parseable, single-flight, and DPAPI-encrypted.'
