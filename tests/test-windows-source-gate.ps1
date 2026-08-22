$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$installer = Join-Path $root 'bin\install-ai-devops-windows.ps1'
$temp = Join-Path ([IO.Path]::GetTempPath()) ('ai-devops-source-gate-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $temp | Out-Null

function Assert([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw "FAIL: $Message" }
}
function New-Fixture([string]$Name) {
  $remote = Join-Path $temp "$Name.git"
  $repo = Join-Path $temp $Name
  git init --bare $remote | Out-Null
  git init -b main $repo | Out-Null
  git -C $repo config user.name test
  git -C $repo config user.email test@example.invalid
  'fixture' | Set-Content (Join-Path $repo 'README.md')
  git -C $repo add README.md
  git -C $repo commit -m initial | Out-Null
  git -C $repo remote add origin $remote
  git -C $repo push -u origin main | Out-Null
  return @{ Repo=$repo; Remote=$remote }
}
function Invoke-Gate($Fixture, [switch]$ExpectFailure) {
  $oldMode=$env:AI_DEVOPS_INSTALL_TEST_MODE; $oldRemote=$env:AI_DEVOPS_TEST_EXPECTED_REMOTE
  try {
    $env:AI_DEVOPS_INSTALL_TEST_MODE='1'; $env:AI_DEVOPS_TEST_EXPECTED_REMOTE=$Fixture.Remote
    $failed=$false
    try { & $installer -RepoPath $Fixture.Repo -SkipGitInstall -SourceGateOnly *>$null } catch { $failed=$true }
    if ($ExpectFailure) { Assert $failed 'hostile source state passed' } else { Assert (-not $failed) 'valid source state failed' }
  } finally { $env:AI_DEVOPS_INSTALL_TEST_MODE=$oldMode; $env:AI_DEVOPS_TEST_EXPECTED_REMOTE=$oldRemote }
}

try {
  $clean=New-Fixture clean; Invoke-Gate $clean

  $dirty=New-Fixture dirty; 'dirty' | Add-Content (Join-Path $dirty.Repo 'README.md'); Invoke-Gate $dirty -ExpectFailure

  $branch=New-Fixture branch; git -C $branch.Repo checkout -b feature | Out-Null; Invoke-Gate $branch -ExpectFailure

  $wrong=New-Fixture wrong; $env:AI_DEVOPS_INSTALL_TEST_MODE='1'; $env:AI_DEVOPS_TEST_EXPECTED_REMOTE=(Join-Path $temp 'different.git')
  $failed=$false; try { & $installer -RepoPath $wrong.Repo -SkipGitInstall -SourceGateOnly *>$null } catch { $failed=$true }
  Assert $failed 'wrong remote passed'

  $fetch=New-Fixture fetch; Move-Item -LiteralPath $fetch.Remote -Destination "$($fetch.Remote).offline"
  Invoke-Gate $fetch -ExpectFailure

  $ahead=New-Fixture ahead; 'ahead' | Add-Content (Join-Path $ahead.Repo 'README.md'); git -C $ahead.Repo add README.md; git -C $ahead.Repo commit -m ahead | Out-Null
  Invoke-Gate $ahead -ExpectFailure

  $source = Get-Content -Raw $installer
  Assert ($source -match 'git -C \$Path fetch origin main\s+if \(\$LASTEXITCODE -ne 0\)') 'fetch exit code is not checked immediately'
  Assert ($source -match 'branch --show-current') 'main branch gate missing'
  Assert ($source -match 'rev-parse origin/main') 'exact origin/main proof missing'
  $bootstrap = Get-Content -Raw (Join-Path $root 'bin\bootstrap-windows-dev.ps1')
  Assert ($bootstrap.Contains("[string]`$RepoPath = 'C:\repos\ai-devops'")) 'bootstrap default is not C:\repos\ai-devops'
  Write-Host 'PASS: Windows source gate rejects dirty, wrong-branch, wrong-remote, failed-fetch, and ahead states'
} finally {
  Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
