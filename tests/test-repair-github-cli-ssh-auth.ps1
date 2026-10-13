$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$repair = Join-Path $repoRoot "bin\repair-github-cli-ssh-auth.ps1"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("gh-ssh-auth-" + [guid]::NewGuid())

function Write-FakeGh([string]$Path, [string]$Storage, [string]$LoggedIn = "Logged in to") {
  # A fake gh that reports a fixed storage location and records every call.
  Set-Content -LiteralPath $Path -Encoding ascii -Value @(
    "@echo off",
    "echo %* >> `"%~dp0calls.log`"",
    "if `"%1 %2`"==`"auth status`" echo   $LoggedIn github.com account test ($Storage)",
    "exit /b 0"
  )
}

try {
  New-Item -ItemType Directory -Path $tempRoot | Out-Null
  $hosts = Join-Path $tempRoot "hosts.yml"
  $fakeGh = Join-Path $tempRoot "gh.cmd"
  $users = ([Security.Principal.SecurityIdentifier]'S-1-5-32-545').Translate([Security.Principal.NTAccount]).Value

  # 1. No hosts.yml: nothing happens.
  Write-FakeGh $fakeGh "keyring"
  & $repair -GitHubConfigDir $tempRoot -GhPath $fakeGh
  if (Test-Path -LiteralPath (Join-Path $tempRoot "calls.log")) { throw "gh was called without a login." }

  # 2. File storage already: hosts.yml is locked to owner/SYSTEM/Administrators,
  #    removing an inherited-style grant to another group.
  Set-Content -LiteralPath $hosts -Value "github.com:`n    oauth_token: placeholder" -Encoding utf8
  & icacls.exe $hosts /grant "${users}:(R)" | Out-Null
  Write-FakeGh $fakeGh $hosts
  & $repair -GitHubConfigDir $tempRoot -GhPath $fakeGh
  $others = @((Get-Acl -LiteralPath $hosts).Access | Where-Object { $_.IdentityReference.Value -ieq $users })
  if ($others.Count -ne 0) { throw "Other users can still read hosts.yml." }
  if ((Get-Content (Join-Path $tempRoot "calls.log") -Raw) -match 'login') { throw "Login ran although storage was already a file." }

  # 3. Keyring token unreadable (SSH logon): warn, never migrate or fail.
  Remove-Item -LiteralPath (Join-Path $tempRoot "calls.log")
  Write-FakeGh $fakeGh "keyring" "X Failed to log in to"
  & $repair -GitHubConfigDir $tempRoot -GhPath $fakeGh 3>$null
  if ((Get-Content (Join-Path $tempRoot "calls.log") -Raw) -match 'login') { throw "Login ran with an unreadable keyring token." }

  # 4. Readable keyring token: a backup is kept and the token is moved with
  #    --insecure-storage through stdin. The fake keeps reporting keyring, so the
  #    script must refuse to claim success.
  Write-FakeGh $fakeGh "keyring"
  $failed = $false
  try { & $repair -GitHubConfigDir $tempRoot -GhPath $fakeGh } catch { $failed = $_.Exception.Message -match 'still reports keyring' }
  if (-not $failed) { throw "A migration that left keyring storage was reported as success." }
  if ((Get-Content (Join-Path $tempRoot "calls.log") -Raw) -notmatch 'auth login --hostname github.com --insecure-storage --with-token') {
    throw "Migration did not use file storage with a piped token."
  }
  if (-not (Get-ChildItem -LiteralPath $tempRoot -Filter 'hosts.yml.bak-*')) { throw "No backup was made before migrating." }

  Write-Host "repair-github-cli-ssh-auth tests passed."
} finally {
  Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
