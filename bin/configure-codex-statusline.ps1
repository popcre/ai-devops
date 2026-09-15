[CmdletBinding()]
param(
  [string]$ConfigPath = (Join-Path $env:USERPROFILE ".codex\config.toml")
)

$ErrorActionPreference = "Stop"
$desiredLines = @(
  'status_line = [',
  '  "model-with-reasoning", "current-dir", "git-branch",',
  '  "context-remaining", "used-tokens", "five-hour-limit", "weekly-limit",',
  ']',
  'status_line_use_colors = true'
)

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
$inTui = $false
$sawTui = $false
$inserted = $false
$skipStatusArray = $false

foreach ($line in $lines) {
  if ($skipStatusArray) {
    if ($line -match '\]') { $skipStatusArray = $false }
    continue
  }

  if ($line -match '^\s*\[([^]]+)\]\s*$') {
    $inTui = ($Matches[1] -eq 'tui')
    if ($inTui) {
      $sawTui = $true
      $result.Add($line)
      foreach ($desired in $desiredLines) { $result.Add($desired) }
      $inserted = $true
      continue
    }
  }

  if ($inTui -and $line -match '^\s*status_line\s*=') {
    if ($line -match '\[' -and $line -notmatch '\]') { $skipStatusArray = $true }
    continue
  }
  if ($inTui -and $line -match '^\s*status_line_use_colors\s*=') { continue }
  $result.Add($line)
}

if (-not $sawTui) {
  if ($result.Count -gt 0 -and $result[$result.Count - 1] -ne '') { $result.Add('') }
  $result.Add('[tui]')
  foreach ($desired in $desiredLines) { $result.Add($desired) }
  $inserted = $true
}

if (-not $inserted) { throw 'Could not reconcile the Codex [tui] section.' }
$updated = ($result -join $newline).TrimEnd("`r", "`n") + $newline
if ($updated -ceq $original) {
  Write-Host "Codex status line already configured."
  exit 0
}

if (Test-Path -LiteralPath $ConfigPath) {
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  Copy-Item -LiteralPath $ConfigPath -Destination "$ConfigPath.aidevops-$stamp.bak"
}
[System.IO.File]::WriteAllText($ConfigPath, $updated, [System.Text.UTF8Encoding]::new($false))
Write-Host "Configured the Codex context and usage status line."
