param(
  [string]$RepoPath = (Split-Path -Parent $PSScriptRoot),
  [string]$CatalogPath,
  [string]$UserProfilePath = $env:USERPROFILE,
  [switch]$RecoverPendingTransactionOnly
)
$ErrorActionPreference = "Stop"
# This is also a direct entry point. Hold the same machine-wide lock as the
# full installer until the launcher receipt and pending authority are closed.
$installMutex = [Threading.Mutex]::new($false, 'Global\AiDevOpsToolkitInstall')
$installMutexHeld = $false
try {
  try { $installMutexHeld = $installMutex.WaitOne(0) }
  catch [Threading.AbandonedMutexException] { $installMutexHeld = $true }
  if (-not $installMutexHeld) { throw 'Another toolkit installation holds the machine-wide install lock.' }
if (-not $CatalogPath) { $CatalogPath = Join-Path $RepoPath "config\machine-tools.tsv" }

# Launchers contain absolute source paths and outlive the process that creates
# them. A linked Git worktree is disposable, so pointing a launcher into one
# guarantees a later "file not found" when that worktree is removed. Fail
# before creating or rewriting anything. Install from the durable primary
# checkout instead.
function Resolve-GitMetadataPath {
  param([string]$Value)
  if ([System.IO.Path]::IsPathRooted($Value)) {
    return [System.IO.Path]::GetFullPath($Value)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $RepoPath $Value))
}

$gitDirRaw = (& git -C $RepoPath rev-parse --git-dir 2>$null)
$gitCommonDirRaw = (& git -C $RepoPath rev-parse --git-common-dir 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $gitDirRaw -or -not $gitCommonDirRaw) {
  throw "RepoPath is not a readable Git checkout: $RepoPath"
}
$gitDir = Resolve-GitMetadataPath $gitDirRaw.Trim()
$gitCommonDir = Resolve-GitMetadataPath $gitCommonDirRaw.Trim()
if ($gitDir -ne $gitCommonDir) {
  throw "Refusing to install durable machine launchers from linked worktree '$RepoPath'. Run the canonical checkout's installer instead."
}
$sourceSha = (& git -C $RepoPath rev-parse HEAD 2>$null).Trim()
if ($LASTEXITCODE -ne 0 -or $sourceSha -notmatch '^[0-9a-f]{40}$') {
  throw "Cannot identify the exact source commit for $RepoPath"
}
$fixture = $env:AI_DEVOPS_INSTALL_TEST_MODE -eq '1' -and $env:AI_DEVOPS_TEST_EXPECTED_REMOTE -and
  $env:AI_DEVOPS_TEST_LAUNCHER -and $env:AI_DEVOPS_TEST_EXPECTED_REMOTE -notmatch 'github[.]com'
$canonicalCatalog = [IO.Path]::GetFullPath((Join-Path $RepoPath 'config\machine-tools.tsv'))
if ([IO.Path]::GetFullPath($CatalogPath) -ine $canonicalCatalog -or
    -not (Test-Path -LiteralPath $canonicalCatalog -PathType Leaf) -or
    ((Get-Item -LiteralPath $canonicalCatalog).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
  throw 'Launcher installation requires the canonical complete machine-tools catalog.'
}
if (-not $fixture -and [IO.Path]::GetFullPath($UserProfilePath).TrimEnd('\') -ine
    [IO.Path]::GetFullPath($env:USERPROFILE).TrimEnd('\')) {
  throw 'Launcher installation requires the signed-in user profile.'
}
$target = if ($fixture) { Split-Path -Parent $env:AI_DEVOPS_TEST_LAUNCHER } else { Join-Path $UserProfilePath ".local\bin" }
$gitBash = @(
  (Join-Path $env:ProgramFiles "Git\bin\bash.exe"),
  (Join-Path $env:LOCALAPPDATA "Programs\Git\bin\bash.exe")
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
if (-not $gitBash) { throw "Git Bash is required to install AI command launchers." }
$catalogHash = (Get-FileHash -LiteralPath $canonicalCatalog -Algorithm SHA256).Hash.ToLowerInvariant()
$homeBash = "/" + (($UserProfilePath -replace '\\','/' -replace '^([A-Za-z]):','$1'))
$items = [Collections.Generic.List[object]]::new()
$seen = @{}
foreach ($line in Get-Content -LiteralPath $CatalogPath) {
  if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) { continue }
  $fields = $line -split "`t"
  if ($fields.Count -lt 3) { throw 'Machine-tools catalog has a malformed entry.' }
  $name, $source, $form = $fields[0], $fields[1], $fields[2]
  if ($form -ne 'bash+cmd') { continue }
  if ($name -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$' -or $seen.ContainsKey($name)) {
    throw 'Machine-tools catalog has an unsafe or duplicate command name.'
  }
  $seen[$name] = $true
  if ($source -cnotmatch '^bin/[A-Za-z0-9._/-]+$' -or $source.Contains('..')) {
    throw 'Machine-tools catalog has an unsafe source path.'
  }
  $sourcePath = Join-Path $RepoPath ($source -replace '/', '\')
  if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw "Missing wrapper source: $sourcePath" }
  $sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
  $sourceBash = "/" + (($sourcePath -replace '\\','/' -replace '^([A-Za-z]):','$1'))
  $bashText = @"
#!/usr/bin/env bash
# Managed by ai-devops install-machine-tools.ps1.
# source-sha=$sourceSha
# source-hash=$sourceHash
export HOME="$homeBash"
exec "$sourceBash" "`$@"
"@
  $cmdText = @"
@echo off
rem Managed by ai-devops install-machine-tools.ps1.
rem source-sha=$sourceSha
rem source-hash=$sourceHash
set "HOME=$UserProfilePath"
"$gitBash" "$sourceBash" %*
"@
  $items.Add([pscustomobject]@{ Name=$name; BashText=$bashText; CmdText=$cmdText })
}
if (-not $seen.ContainsKey('ai-task-gates') -or $items.Count -lt 2) {
  throw 'Canonical machine-tools catalog is incomplete.'
}
$pendingAuthorization = if ($fixture) { Join-Path $target ('install-authorizations\' + $sourceSha + '.json.consuming') } else {
  Join-Path $UserProfilePath ('.local\state\ai-devops\task-gates\install-authorizations\' + $sourceSha + '.json.consuming')
}
$transactionRoot = if ($fixture) { Join-Path $target 'launcher-transactions' } else {
  Join-Path $UserProfilePath '.local\state\ai-devops\task-gates\launcher-transactions'
}
$transactionPath = Join-Path $transactionRoot "$sourceSha.json"
$fixturePathStore=Join-Path $target '.user-path-fixture'
function Get-UserPathValue {
  if ($fixture) {
    if (Test-Path -LiteralPath $fixturePathStore -PathType Leaf) { return [IO.File]::ReadAllText($fixturePathStore) }
    return ''
  }
  return [string][Environment]::GetEnvironmentVariable('PATH','User')
}
function Set-UserPathValue($Value) {
  if ($fixture) { [IO.File]::WriteAllText($fixturePathStore,[string]$Value) }
  else { [Environment]::SetEnvironmentVariable('PATH',$Value,'User') }
}
function Publish-StagedFile([string]$Stage, [string]$Destination) {
  $existing=Get-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
  if ($existing) {
    if ($existing.PSIsContainer -or ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
      throw "Refusing non-regular managed launcher: $Destination"
    }
    $swapBackup=Join-Path (Split-Path -Parent $Stage) ('.swapped-' + [guid]::NewGuid().ToString('N'))
    [IO.File]::Replace($Stage,$Destination,$swapBackup,$true)
    [IO.File]::Delete($swapBackup)
  } else {
    [IO.File]::Move($Stage,$Destination)
  }
}
foreach ($directory in @($target,$transactionRoot)) {
  $existingDirectory=Get-Item -LiteralPath $directory -Force -ErrorAction SilentlyContinue
  if ($existingDirectory -and ($existingDirectory.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw "Refusing linked launcher transaction directory: $directory"
  }
}

function Get-FileState([string]$Path) {
  $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
  if (-not $item) { return [pscustomobject]@{ Exists=$false; Bytes=''; Hash='' } }
  if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw "Refusing non-regular managed launcher: $Path"
  }
  $bytes = [IO.File]::ReadAllBytes($Path)
  return [pscustomobject]@{ Exists=$true; Bytes=[Convert]::ToBase64String($bytes);
    Hash=(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
}
function Restore-Transaction($record) {
  if ($record.schema_version -ne 1 -or $record.source_sha -cne $sourceSha -or
      $record.repo_path -ine [IO.Path]::GetFullPath($RepoPath) -or
      $record.target_dir -ine [IO.Path]::GetFullPath($target) -or
      $record.catalog_sha256 -cne $catalogHash -or @($record.files).Count -ne ($items.Count * 2) -or
      ($record.had_pending -ne $true -and $record.had_pending -ne $false) -or
      [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath([string]$record.stage_dir)) -ine [IO.Path]::GetFullPath($target) -or
      [IO.Path]::GetFileName([string]$record.stage_dir) -cnotmatch '^\.ai-devops-staging-[0-9a-f]{32}$' -or
      $record.old_user_path -isnot [string] -or $record.new_user_path -isnot [string]) {
    throw 'Launcher recovery record does not match this exact source and catalog.'
  }
  $expectedNames = @($items | ForEach-Object { $_.Name; "$($_.Name).cmd" })
  $currentUserPath=Get-UserPathValue
  if ($currentUserPath -cne $record.old_user_path -and $currentUserPath -cne $record.new_user_path) {
    throw 'User PATH changed outside the pending installation transaction.'
  }
  $allNew = $true
  for ($index=0; $index -lt $expectedNames.Count; $index++) {
    $row=$record.files[$index]
    if ($row.name -cne $expectedNames[$index] -or $row.name -eq '' -or
        $row.old_exists -ne $true -and $row.old_exists -ne $false -or
        $row.new_sha256 -cnotmatch '^[0-9a-f]{64}$') { throw 'Launcher recovery inventory changed.' }
    $path=Join-Path $target $row.name
    $current=Get-FileState $path
    if ($current.Hash -cne $row.new_sha256) { $allNew=$false }
    if ($row.old_exists) {
      $oldBytes=[Convert]::FromBase64String([string]$row.old_bytes)
      $oldHash=[BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($oldBytes)).Replace('-','').ToLowerInvariant()
      if ($oldHash -cne $row.old_sha256) { throw 'Launcher recovery backup hash changed.' }
    } elseif ($row.old_sha256 -or $row.old_bytes) { throw 'Launcher recovery absence changed.' }
    if (($current.Exists -and $current.Hash -cne $row.old_sha256 -and $current.Hash -cne $row.new_sha256) -or
        (-not $current.Exists -and $row.old_exists)) {
      throw 'Launcher changed outside the pending installation transaction.'
    }
  }
  if ($record.had_pending -and -not (Test-Path -LiteralPath $pendingAuthorization -PathType Leaf)) {
    if (-not $allNew) { throw 'Pending authority disappeared before launcher transaction completed.' }
    if ($currentUserPath -cne $record.new_user_path) { throw 'Completed launcher PATH differs from the recorded value.' }
    if (Test-Path -LiteralPath $record.stage_dir) { Remove-Item -LiteralPath $record.stage_dir -Recurse -Force }
    Remove-Item -LiteralPath $transactionPath -Force
    return
  }
  if ($currentUserPath -cne $record.old_user_path) { Set-UserPathValue $record.old_user_path }
  $stageItem=Get-Item -LiteralPath $record.stage_dir -Force -ErrorAction SilentlyContinue
  if (-not $stageItem -or -not $stageItem.PSIsContainer -or
      ($stageItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw 'Launcher recovery staging directory is missing or linked.'
  }
  for ($index=0; $index -lt $expectedNames.Count; $index++) {
    $row=$record.files[$index]; $path=Join-Path $target $row.name
    if ($row.old_exists) {
      $restoreStage=Join-Path $record.stage_dir ('.restore-' + [guid]::NewGuid().ToString('N'))
      [IO.File]::WriteAllBytes($restoreStage, [Convert]::FromBase64String([string]$row.old_bytes))
      Publish-StagedFile $restoreStage $path
      if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $row.old_sha256) {
        throw 'Launcher recovery copy did not verify.'
      }
    } elseif (Test-Path -LiteralPath $path) { [IO.File]::Delete($path) }
  }
  if (Test-Path -LiteralPath $record.stage_dir) { Remove-Item -LiteralPath $record.stage_dir -Recurse -Force }
  Remove-Item -LiteralPath $transactionPath -Force
}

# An interrupted prior write is restored under the mutex before source-gate
# preflight. The receipt therefore still names the approved old baseline.
if (Test-Path -LiteralPath $transactionPath) {
  if ((Get-Item -LiteralPath $transactionPath).Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw 'Refusing symlinked launcher recovery record.'
  }
  $prior = Get-Content -Raw -LiteralPath $transactionPath | ConvertFrom-Json
  Restore-Transaction $prior
  if ($fixture -and $env:AI_DEVOPS_TEST_FAIL_AFTER_RECOVERY -eq '1') {
    throw 'Injected stop after exact PATH and launcher recovery.'
  }
}

if ($RecoverPendingTransactionOnly) { return }

# This is the common receipt-stamping boundary. Run it on the same PowerShell
# thread so a child of the full installer can re-enter the held mutex.
$sourceGate = Join-Path $RepoPath 'bin\install-ai-devops-windows.ps1'
try { & $sourceGate -RepoPath $RepoPath -LauncherGateOnly -ExpectedHead $sourceSha }
catch { throw "Managed command launcher source gate refused this checkout: $($_.Exception.Message)" }

New-Item -ItemType Directory -Force -Path $target, $transactionRoot | Out-Null
foreach ($directory in @($target,$transactionRoot)) {
  if ((Get-Item -LiteralPath $directory -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw "Refusing linked launcher transaction directory: $directory"
  }
}
$rows = [Collections.Generic.List[object]]::new()
$stageDir=Join-Path $target ('.ai-devops-staging-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stageDir | Out-Null
foreach ($item in $items) {
  foreach ($part in @(@($item.Name,$item.BashText,$false),@("$($item.Name).cmd",$item.CmdText,$true))) {
    $name=[string]$part[0]; $path=Join-Path $target $name
    $before=Get-FileState $path
    $staged=Join-Path $stageDir ('.staged-' + [guid]::NewGuid().ToString('N'))
    if ($part[2]) { [string]$part[1] | Set-Content -Encoding ASCII -LiteralPath $staged }
    else { [string]$part[1] | Set-Content -NoNewline -Encoding ASCII -LiteralPath $staged }
    $after=(Get-FileHash -LiteralPath $staged -Algorithm SHA256).Hash.ToLowerInvariant()
    $rows.Add([pscustomobject]@{ name=$name; old_exists=$before.Exists; old_bytes=$before.Bytes;
      old_sha256=$before.Hash; new_sha256=$after; staged_path=$staged })
  }
}
$userPathBefore=[string](Get-UserPathValue)
$pathEntries=@($userPathBefore -split ';' | Where-Object { $_ })
$userPathAfter=if ($pathEntries | Where-Object { $_.TrimEnd('\') -ieq $target.TrimEnd('\') }) {
  $userPathBefore
} else { (@($target) + $pathEntries) -join ';' }
$record=[pscustomobject]@{ schema_version=1; source_sha=$sourceSha;
  repo_path=[IO.Path]::GetFullPath($RepoPath); target_dir=[IO.Path]::GetFullPath($target);
  catalog_sha256=$catalogHash; stage_dir=$stageDir; had_pending=(Test-Path -LiteralPath $pendingAuthorization -PathType Leaf);
  old_user_path=$userPathBefore; new_user_path=$userPathAfter;
  files=@($rows | ForEach-Object { [pscustomobject]@{name=$_.name;old_exists=$_.old_exists;
    old_bytes=$_.old_bytes;old_sha256=$_.old_sha256;new_sha256=$_.new_sha256} }) }
$transactionTemp="$transactionPath.tmp.$PID"
$record | ConvertTo-Json -Depth 5 -Compress | Set-Content -Encoding UTF8 -LiteralPath $transactionTemp
Move-Item -LiteralPath $transactionTemp -Destination $transactionPath
try {
  foreach ($row in $rows) {
    Publish-StagedFile $row.staged_path (Join-Path $target $row.name)
    if ((Get-FileHash -LiteralPath (Join-Path $target $row.name) -Algorithm SHA256).Hash.ToLowerInvariant() -cne $row.new_sha256) {
      throw "Managed launcher $($row.name) differs from staged bytes."
    }
    if ($fixture -and $env:AI_DEVOPS_TEST_FAIL_AFTER_GATE -eq '1' -and $row.name -ceq 'ai-task-gates.cmd') {
      throw 'Injected failure after gate launcher stamping.'
    }
    if ($fixture -and $env:AI_DEVOPS_TEST_HARD_CRASH_AFTER_GATE -eq '1' -and $row.name -ceq 'ai-task-gates.cmd') {
      [Diagnostics.Process]::GetCurrentProcess().Kill()
    }
    Write-Host "OK installed $($row.name)"
  }
if ((Get-UserPathValue) -cne $userPathBefore) { throw 'User PATH changed while launchers were being installed.' }
if ($userPathAfter -cne $userPathBefore) {
  Set-UserPathValue $userPathAfter
  Write-Host "OK added $target to User PATH"
}
if ($fixture -and $env:AI_DEVOPS_TEST_HARD_CRASH_AFTER_PATH -eq '1') {
  [Diagnostics.Process]::GetCurrentProcess().Kill()
}
if (-not $fixture) {
  $env:Path = $target + ';' + $env:Path
}
if (Test-Path -LiteralPath $pendingAuthorization -PathType Leaf) {
  Remove-Item -LiteralPath $pendingAuthorization -Force
  $issuedSeal = ($pendingAuthorization -replace '\.consuming$', '') + '.seal'
  if (Test-Path -LiteralPath $issuedSeal -PathType Leaf) {
    Remove-Item -LiteralPath $issuedSeal -Force -ErrorAction SilentlyContinue
  }
}
} catch {
  $failure=$_.Exception.Message
  try {
    Restore-Transaction $record
  } catch { throw "Launcher install failed ($failure); exact rollback needs repair: $($_.Exception.Message)" }
  throw "Launcher install failed and exact prior launchers were restored: $failure"
} finally {
  if (-not (Test-Path -LiteralPath $transactionPath)) {
    Remove-Item -LiteralPath $stageDir -Recurse -Force -ErrorAction SilentlyContinue
  }
}
Remove-Item -LiteralPath $stageDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $transactionPath -Force
} finally {
  if ($installMutexHeld) { $installMutex.ReleaseMutex() }
  $installMutex.Dispose()
}
