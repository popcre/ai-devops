param(
  [string]$RepoPath = (Split-Path -Parent $PSScriptRoot),
  [string]$CatalogPath,
  [string]$UserProfilePath = $env:USERPROFILE
)
$ErrorActionPreference = "Stop"
if (-not $CatalogPath) { $CatalogPath = Join-Path $RepoPath "config\machine-tools.tsv" }
$target = Join-Path $UserProfilePath ".local\bin"
$gitBash = @(
  (Join-Path $env:ProgramFiles "Git\bin\bash.exe"),
  (Join-Path $env:LOCALAPPDATA "Programs\Git\bin\bash.exe")
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
if (-not $gitBash) { throw "Git Bash is required to install AI command launchers." }
New-Item -ItemType Directory -Force -Path $target | Out-Null
$homeBash = "/" + (($UserProfilePath -replace '\\','/' -replace '^([A-Za-z]):','$1'))
foreach ($line in Get-Content -LiteralPath $CatalogPath) {
  if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) { continue }
  $fields = $line -split "`t"
  $name, $source, $form = $fields[0], $fields[1], $fields[2]
  if ($form -ne 'bash+cmd') { continue }
  $sourcePath = Join-Path $RepoPath ($source -replace '/', '\')
  if (-not (Test-Path -LiteralPath $sourcePath)) { throw "Missing wrapper source: $sourcePath" }
  $sourceBash = "/" + (($sourcePath -replace '\\','/' -replace '^([A-Za-z]):','$1'))
  @"
#!/usr/bin/env bash
# Managed by ai-devops install-machine-tools.ps1.
export HOME="$homeBash"
exec "$sourceBash" "`$@"
"@ | Set-Content -NoNewline -Encoding ASCII -LiteralPath (Join-Path $target $name)
  @"
@echo off
rem Managed by ai-devops install-machine-tools.ps1.
set "HOME=$UserProfilePath"
"$gitBash" "$sourceBash" %*
"@ | Set-Content -Encoding ASCII -LiteralPath (Join-Path $target "$name.cmd")
  Write-Host "OK installed $name"
}
$userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
$entries = @($userPath -split ';' | Where-Object { $_ })
if (-not ($entries | Where-Object { $_.TrimEnd('\') -ieq $target.TrimEnd('\') })) {
  [Environment]::SetEnvironmentVariable('PATH', ((@($target) + $entries) -join ';'), 'User')
  Write-Host "OK added $target to User PATH"
}
$env:Path = $target + ';' + $env:Path
