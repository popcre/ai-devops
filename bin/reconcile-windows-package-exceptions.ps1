<# Reconcile Windows developer CLIs that are not available as WinGet packages. #>
[CmdletBinding()]
param([switch]$TestOnly)

$ErrorActionPreference = 'Stop'
$results = [Collections.Generic.List[object]]::new()
function Result($Name, $Status, $Detail) {
  $results.Add([pscustomobject]@{ Package=$Name; Status=$Status; Detail=$Detail })
}
function Refresh-Path {
  $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
    [Environment]::GetEnvironmentVariable('Path','User') + ';' +
    (Join-Path $HOME 'scoop\shims')
}

Refresh-Path
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
  throw 'npm is unavailable. The WinGet configuration must install Node.js first.'
}

foreach ($package in @(
  @{ Name='Vercel CLI'; Npm='vercel@latest'; Command='vercel' },
  @{ Name='Trigger.dev CLI'; Npm='trigger.dev@latest'; Command='trigger.dev' }
)) {
  if ($TestOnly) {
    $present = [bool](Get-Command $package.Command -ErrorAction SilentlyContinue)
    Result $package.Name $(if($present){'OK'}else{'MISSING'}) $package.Command
    continue
  }
  & npm.cmd install --global $package.Npm
  if ($LASTEXITCODE -ne 0) { throw "$($package.Name) npm reconciliation failed." }
  Refresh-Path
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
if ($results.Status -contains 'MISSING') { exit 2 }
exit 0
