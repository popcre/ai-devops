<# Reconcile Windows developer CLIs that are not available as WinGet packages. #>
[CmdletBinding()]
param([switch]$TestOnly)

$ErrorActionPreference = 'Stop'
$results = [Collections.Generic.List[object]]::new()
function Result($Name, $Status, $Detail) {
  $results.Add([pscustomobject]@{ Package=$Name; Status=$Status; Detail=$Detail })
}
function Refresh-Path {
  if ($env:AI_DEVOPS_TEST_MODE -eq '1' -and $env:AI_DEVOPS_TEST_PATH) {
    $env:Path = $env:AI_DEVOPS_TEST_PATH
    return
  }
  $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
    [Environment]::GetEnvironmentVariable('Path','User') + ';' +
    (Join-Path $HOME 'scoop\shims')
}
function Get-NpmPrefix {
  if ($env:AI_DEVOPS_TEST_MODE -eq '1' -and $env:AI_DEVOPS_TEST_NPM_PREFIX) {
    return $env:AI_DEVOPS_TEST_NPM_PREFIX
  }
  $prefix = (& npm.cmd prefix --global 2>$null | Select-Object -Last 1).Trim()
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($prefix)) {
    throw 'npm global prefix could not be resolved.'
  }
  return $prefix
}
function Assert-AstGrepSgOwnership([string]$ExpectedVersion, [switch]$RequireExactVersion) {
  $sgCommands = @(Get-Command sg -All -ErrorAction SilentlyContinue)
  if ($sgCommands.Count -eq 0) { return }
  $prefix = Get-NpmPrefix
  $packageJson = Join-Path $prefix 'node_modules\@ast-grep\cli\package.json'
  if (-not (Test-Path -LiteralPath $packageJson)) {
    throw "Refusing to replace existing sg command: @ast-grep/cli does not own it."
  }
  $metadata = Get-Content -Raw -LiteralPath $packageJson | ConvertFrom-Json
  if ($metadata.name -ne '@ast-grep/cli' -or ($RequireExactVersion -and $metadata.version -ne $ExpectedVersion)) {
    throw "Refusing to replace existing sg command: ownership or version is not the approved @ast-grep/cli@$ExpectedVersion."
  }
  $allowed = @('sg','sg.cmd','sg.ps1') | ForEach-Object {
    [IO.Path]::GetFullPath((Join-Path $prefix $_)).TrimEnd('\')
  }
  foreach ($command in $sgCommands) {
    $resolved = [IO.Path]::GetFullPath($command.Source).TrimEnd('\')
    if ($resolved -notin $allowed) {
      throw "Refusing to replace unrelated sg command at $resolved."
    }
  }
}

Refresh-Path
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
  throw 'npm is unavailable. The WinGet configuration must install Node.js first.'
}

foreach ($package in @(
  @{ Name='Vercel CLI'; Npm='vercel@54.15.1'; Command='vercel' },
  @{ Name='Trigger.dev CLI'; Npm='trigger.dev@4.4.6'; Command='trigger.dev' },
  @{ Name='Railway CLI'; Npm='@railway/cli@5.43.1'; Command='railway' },
  @{ Name='ast-grep'; Npm='@ast-grep/cli@0.45.2'; Command='ast-grep'; Version='0.45.2' }
)) {
  if ($package.Command -eq 'ast-grep') {
    Assert-AstGrepSgOwnership -ExpectedVersion $package.Version
  }
  if ($TestOnly) {
    $command = Get-Command $package.Command -ErrorAction SilentlyContinue
    if (-not $command) {
      Result $package.Name 'MISSING' $package.Command
    } elseif ($package.Version) {
      $reported = (& $command.Source --version 2>$null | Out-String).Trim()
      $exact = $LASTEXITCODE -eq 0 -and $reported -match "(?<![0-9.])$([regex]::Escape($package.Version))(?![0-9.])"
      Result $package.Name $(if($exact){'OK'}else{'DRIFT'}) "$($package.Command) expected $($package.Version), reported $reported"
    } else {
      Result $package.Name 'OK' $package.Command
    }
    continue
  }
  & npm.cmd install --global $package.Npm
  if ($LASTEXITCODE -ne 0) { throw "$($package.Name) npm reconciliation failed." }
  Refresh-Path
  if ($package.Command -eq 'ast-grep') {
    Assert-AstGrepSgOwnership -ExpectedVersion $package.Version -RequireExactVersion
    $reported = (& ast-grep --version 2>$null | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $reported -notmatch "(?<![0-9.])$([regex]::Escape($package.Version))(?![0-9.])") {
      throw "ast-grep installation did not report approved version $($package.Version)."
    }
  }
  Result $package.Name 'APPLIED' $package.Npm
}

if ($TestOnly) {
  $present = [bool](Get-Command supabase -ErrorAction SilentlyContinue)
  Result 'Supabase CLI' $(if($present){'OK'}else{'MISSING'}) 'scoop:supabase'
} else {
  if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    $installer = Join-Path $env:TEMP 'install-scoop-ai-devops.ps1'
    Invoke-WebRequest -UseBasicParsing -Uri 'https://get.scoop.sh' -OutFile $installer
    try { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installer -RunAsAdmin }
    finally { Remove-Item -LiteralPath $installer -Force -ErrorAction SilentlyContinue }
    if ($LASTEXITCODE -ne 0) { throw 'Official Scoop bootstrap failed.' }
    Refresh-Path
  }
  if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    throw 'Scoop was installed but is not visible in this session; open a new terminal and rerun.'
  }
  $buckets = (& scoop bucket list | Out-String)
  if ($buckets -notmatch '(?m)^supabase\s') {
    & scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
    if ($LASTEXITCODE -ne 0) { throw 'Adding the official Supabase Scoop bucket failed.' }
  }
  $installed = (& scoop list supabase 2>$null | Out-String)
  if ($installed -match '(?m)^supabase\s') { & scoop update supabase }
  else { & scoop install supabase }
  if ($LASTEXITCODE -ne 0) { throw 'Supabase CLI reconciliation failed.' }
  Result 'Supabase CLI' 'APPLIED' 'scoop:supabase'
}

$results | Format-Table -AutoSize | Out-Host
if (@($results | Where-Object Status -ne 'OK').Count -gt 0 -and $TestOnly) { exit 2 }
exit 0
