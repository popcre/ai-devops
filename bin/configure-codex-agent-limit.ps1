[CmdletBinding()]
param(
  [string]$ConfigPath = (Join-Path $env:USERPROFILE ".codex\config.toml")
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path -LiteralPath $ConfigPath)) {
  Write-Host "Codex config has no managed subagent limit."
  exit 0
}
$original = Get-Content -LiteralPath $ConfigPath -Raw
$newline = if ($original.Contains("`r`n")) { "`r`n" } else { "`n" }
$lines = if ($original.Length -gt 0) { $original -split "`r?`n" } else { @() }

$result = [System.Collections.Generic.List[string]]::new()
$inAgents = $false

foreach ($line in $lines) {
  if ($line -match '^\s*\[([^]]+)\]\s*$') {
    $section = $Matches[1]
    $inAgents = ($section -eq 'agents')
  }

  if ($inAgents -and $line -match '^\s*(max_concurrent_threads_per_session|max_threads)\s*=') {
    continue
  }
  $result.Add($line)
}

$updated = ($result -join $newline).TrimEnd("`r", "`n") + $newline
if ($updated -ceq $original) {
  Write-Host "Codex config has no managed subagent limit."
  exit 0
}

if (Test-Path -LiteralPath $ConfigPath) {
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  Copy-Item -LiteralPath $ConfigPath -Destination "$ConfigPath.aidevops-$stamp.bak"
}
[System.IO.File]::WriteAllText($ConfigPath, $updated, [System.Text.UTF8Encoding]::new($false))
Write-Host "Removed the managed Codex subagent limit."
