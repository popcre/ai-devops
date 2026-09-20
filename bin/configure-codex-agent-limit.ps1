[CmdletBinding()]
param(
  [string]$ConfigPath = (Join-Path $env:USERPROFILE ".codex\config.toml"),
  [ValidateRange(1, 1000)]
  [int]$MaxConcurrentThreads = 20
)

$ErrorActionPreference = "Stop"
# Codex 0.144.x rejects the newer canonical name, while current releases retain
# max_threads as a documented compatibility alias. Use the one spelling that
# works across both generations.
$desiredLine = "max_threads = $MaxConcurrentThreads"

$parent = Split-Path -Parent $ConfigPath
if (-not (Test-Path -LiteralPath $parent)) {
  New-Item -ItemType Directory -Force -Path $parent | Out-Null
}

$original = if (Test-Path -LiteralPath $ConfigPath) {
  Get-Content -LiteralPath $ConfigPath -Raw
} else { "" }
$newline = if ($original.Contains("`r`n")) { "`r`n" } else { "`n" }
$lines = if ($original.Length -gt 0) { $original -split "`r?`n" } else { @() }

$result = [System.Collections.Generic.List[string]]::new()
$inAgents = $false
$sawAgents = $false

foreach ($line in $lines) {
  if ($line -match '^\s*\[([^]]+)\]\s*$') {
    $section = $Matches[1]
    $inAgents = ($section -eq 'agents')
    if ($inAgents) {
      $sawAgents = $true
      $result.Add($line)
      $result.Add($desiredLine)
      continue
    }
    if (-not $sawAgents -and $section -like 'agents.*') {
      if ($result.Count -gt 0 -and $result[$result.Count - 1] -ne '') { $result.Add('') }
      $result.Add('[agents]')
      $result.Add($desiredLine)
      $result.Add('')
      $sawAgents = $true
    }
  }

  if ($inAgents -and $line -match '^\s*(max_concurrent_threads_per_session|max_threads)\s*=') {
    continue
  }
  $result.Add($line)
}

if (-not $sawAgents) {
  if ($result.Count -gt 0 -and $result[$result.Count - 1] -ne '') { $result.Add('') }
  $result.Add('[agents]')
  $result.Add($desiredLine)
}

$updated = ($result -join $newline).TrimEnd("`r", "`n") + $newline
if ($updated -ceq $original) {
  Write-Host "Codex concurrent subagent limit already set to $MaxConcurrentThreads."
  exit 0
}

if (Test-Path -LiteralPath $ConfigPath) {
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  Copy-Item -LiteralPath $ConfigPath -Destination "$ConfigPath.aidevops-$stamp.bak"
}
[System.IO.File]::WriteAllText($ConfigPath, $updated, [System.Text.UTF8Encoding]::new($false))
Write-Host "Set the Codex concurrent subagent limit to $MaxConcurrentThreads."
