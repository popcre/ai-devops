$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
$installer = Join-Path $repo "bin\install-machine-tools.ps1"
$catalog = Join-Path $repo "config\machine-tools.tsv"
$text = Get-Content -Raw $installer
foreach ($required in @('bash+cmd', 'Set-Content -NoNewline -Encoding ASCII', 'SetEnvironmentVariable')) {
  if (-not $text.Contains($required)) { throw "Missing catalog installer control: $required" }
}

# Regression: launchers are durable machine state, so a disposable linked
# worktree must never become their absolute source path.
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("ai-machine-tools-worktree-" + [guid]::NewGuid().ToString("N"))
$primary = Join-Path $tempRoot "primary"
$linked = Join-Path $tempRoot "linked"
$profile = Join-Path $tempRoot "profile"
try {
  New-Item -ItemType Directory -Force -Path $primary | Out-Null
  git -C $primary init -q
  git -C $primary config user.name "Test"
  git -C $primary config user.email "test@example.invalid"
  New-Item -ItemType Directory -Force -Path (Join-Path $primary "bin"), (Join-Path $primary "config") | Out-Null
  Set-Content -LiteralPath (Join-Path $primary "bin\probe") -Value '#!/usr/bin/env bash' -Encoding ASCII
  Set-Content -LiteralPath (Join-Path $primary "config\machine-tools.tsv") -Value "probe`tbin/probe`tbash+cmd" -Encoding ASCII
  git -C $primary add -- bin/probe config/machine-tools.tsv
  git -C $primary commit -qm "fixture"
  git -C $primary worktree add -q $linked

  $failedClosed = $false
  try {
    & $installer -RepoPath $linked -UserProfilePath $profile -CatalogPath (Join-Path $linked "config\machine-tools.tsv")
  } catch {
    $failedClosed = $_.Exception.Message -like '*Refusing to install durable machine launchers from linked worktree*'
  }
  if (-not $failedClosed) { throw "Linked-worktree launcher install did not fail closed." }
  if (Test-Path -LiteralPath (Join-Path $profile ".local\bin\probe")) {
    throw "Linked-worktree launcher install wrote a wrapper before refusing."
  }
} finally {
  if (Test-Path -LiteralPath $primary) { git -C $primary worktree remove --force $linked 2>$null }
  if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
$rows = Get-Content $catalog | Where-Object { $_ -and -not $_.StartsWith('#') }
$names = $rows | ForEach-Object { ($_ -split "`t")[0] }
foreach ($name in @('ai-grok-review','ai-grok-implement','ai-gemini','ai-kimi','ai-deepseek-agent','ai-glm')) {
  if ($names -notcontains $name) { throw "Catalog missing $name" }
}
$glm = $rows | Where-Object { $_.StartsWith("ai-glm`t") }
if (($glm -split "`t")[2] -ne 'cmd-only-external') { throw 'GLM must remain cmd-only-external' }
foreach ($file in @($installer)) {
  $bytes = [IO.File]::ReadAllBytes($file)
  if ($bytes | Where-Object { $_ -gt 127 }) { throw "PowerShell file is not ASCII: $file" }
  [void][scriptblock]::Create((Get-Content -Raw $file))
}
[void][scriptblock]::Create((Get-Content -Raw (Join-Path $repo 'bin\setup-machine.ps1')))
Write-Host "PASS: catalog-driven Windows launcher controls are valid"
