# ai-transcript-upload.ps1 - daily copy of this Windows host's AI session transcripts
# into <Dropbox>\ai\chat_transcripts\<live hostname>\ (plan_transcript-store.md step 1).
#
# Same rules as bin/ai-transcript-upload: skip files modified in the last 15 minutes;
# copy through <D>\.partial\ and rename into place only when the size matches the
# source (retry once, then skip); copy when the destination is missing, its size
# differs, or the source is newer. Never deletes in the destination and never reads
# file contents. Symlinked source folders (edge-dev: D:\ai-data) are resolved to
# their target first. Works in Windows PowerShell 5.1 and PowerShell 7.
#
# usage: ai-transcript-upload.ps1 [-DropboxRoot DIR] [-HostName NAME] [-HotMinutes N]
#        ai-transcript-upload.ps1 -Install [-At 06:30] | -Sync | -Check | -Remove
# The installed copy updates itself from merged main at the start of each run; a
# failed update never stops the upload and is logged as self_update=failed. -Check
# fails when the installed files differ from merged main, or main cannot be read.
# -Sync is the installer's stage: install on a host with Dropbox or an existing task,
# otherwise SKIP. -Install keeps a task that already runs logged off.
[CmdletBinding()]
param(
  [string]$DropboxRoot = '',
  [string]$HostName = '',
  [int]$HotMinutes = 15,
  [string[]]$Map = @(),
  [switch]$Install,
  [switch]$Sync,
  [string]$At = '06:30',
  [switch]$Check,
  [switch]$Remove
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$TaskName = 'AiDevOps-TranscriptUpload'
$StateDir = Join-Path $env:LOCALAPPDATA 'ai-devops'
$Installed = Join-Path $StateDir 'ai-transcript-upload.ps1'
$InstalledExporter = Join-Path $StateDir 'zcode_export.py'
$Exporter = Join-Path $PSScriptRoot 'zcode_export.py'
if (-not (Test-Path -LiteralPath $Exporter)) { $Exporter = Join-Path $PSScriptRoot '..\tools\transcript_store\zcode_export.py' }
$SourceBase = if ($env:AI_TRANSCRIPT_UPLOAD_SOURCE) { $env:AI_TRANSCRIPT_UPLOAD_SOURCE } else { 'https://raw.githubusercontent.com/popcre/ai-devops/main' }
$SelfUpdate = ''

function Find-DropboxRoot {
  $info = Join-Path $env:LOCALAPPDATA 'Dropbox\info.json'
  $found = ''
  if (Test-Path -LiteralPath $info) { $found = (Get-Content -Raw -LiteralPath $info | ConvertFrom-Json).personal.path }
  if (-not $found) { $found = Join-Path $env:USERPROFILE 'Dropbox' }
  return $found
}

function Get-MainFile([string]$RepoPath, [string]$Out) {
  if ($SourceBase -like 'http*') {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -UseBasicParsing -TimeoutSec 60 -Uri "$SourceBase/$RepoPath" -OutFile $Out
  } else {
    Copy-Item -LiteralPath (Join-Path $SourceBase $RepoPath) -Destination $Out -Force
  }
}

# Line endings differ between a Windows checkout and main; content does not.
function Test-SameText([string]$A, [string]$B) {
  if (-not (Test-Path -LiteralPath $A) -or -not (Test-Path -LiteralPath $B)) { return $false }
  return (([System.IO.File]::ReadAllText($A)) -replace "`r", '') -ceq (([System.IO.File]::ReadAllText($B)) -replace "`r", '')
}

# Fetch both files from main into a new folder and refuse a script that does not parse.
function Get-VerifiedMain {
  $dir = Join-Path ([System.IO.Path]::GetTempPath()) ('ai-transcript-main-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $script = Join-Path $dir 'ai-transcript-upload.ps1'
  $exp = Join-Path $dir 'zcode_export.py'
  Get-MainFile 'bin/ai-transcript-upload.ps1' $script
  Get-MainFile 'tools/transcript_store/zcode_export.py' $exp
  $tokens = $null; $parseErrors = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile($script, [ref]$tokens, [ref]$parseErrors)
  if ($parseErrors.Count -gt 0 -or (Get-Item -LiteralPath $exp).Length -eq 0) { throw 'main copy failed validation' }
  return $dir
}

if ($Sync) {
  if (-not (Test-Path -LiteralPath (Join-Path (Find-DropboxRoot) 'ai\chat_transcripts')) -and -not (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue)) {
    'SKIP transcript upload: not a Dropbox transcript host'; exit 0
  }
  $Install = $true
}
if ($Remove) {
  Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
  if (Test-Path -LiteralPath $Installed) { Remove-Item -LiteralPath $Installed -Force }
  if (Test-Path -LiteralPath $InstalledExporter) { Remove-Item -LiteralPath $InstalledExporter -Force }
  'OK transcript upload task removed (Dropbox copies are left as they are)'; exit 0
}
if ($Check) {
  $rc = 0
  if (-not (Test-Path -LiteralPath $Installed)) { "ERROR $Installed not installed"; $rc = 1 }
  if (-not (Test-Path -LiteralPath $InstalledExporter)) { "ERROR $InstalledExporter not installed"; $rc = 1 }
  try {
    $mainDir = Get-VerifiedMain
    if (-not (Test-SameText (Join-Path $mainDir 'ai-transcript-upload.ps1') $Installed)) { "ERROR installed ai-transcript-upload.ps1 is stale: differs from merged main"; $rc = 1 }
    if (-not (Test-SameText (Join-Path $mainDir 'zcode_export.py') $InstalledExporter)) { "ERROR installed zcode_export.py is stale: differs from merged main"; $rc = 1 }
    Remove-Item -LiteralPath $mainDir -Recurse -Force
  } catch { "ERROR could not read merged main; installed copy freshness unverified"; $rc = 1 }
  $t = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
  if (-not $t) { "ERROR scheduled task $TaskName not registered"; $rc = 1 }
  elseif ($t.State -eq 'Disabled') { "ERROR scheduled task $TaskName is disabled"; $rc = 1 }
  elseif ("$($t.Principal.LogonType)" -notin @('S4U','Password')) { "ERROR scheduled task $TaskName runs only while logged on ($($t.Principal.LogonType))"; $rc = 1 }
  if ($rc -eq 0) { "OK transcript upload task installed and matches merged main ($($t.Principal.UserId), $($t.Principal.LogonType))" }
  exit $rc
}
if ($Install) {
  New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
  Copy-Item -LiteralPath $PSCommandPath -Destination "$Installed.tmp" -Force
  Move-Item -LiteralPath "$Installed.tmp" -Destination $Installed -Force
  Copy-Item -LiteralPath $Exporter -Destination "$InstalledExporter.tmp" -Force
  Move-Item -LiteralPath "$InstalledExporter.tmp" -Destination $InstalledExporter -Force
  # Re-registering from an unelevated install would downgrade a working logged-off task.
  $current = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
  if ($current -and $current.State -ne 'Disabled' -and "$($current.Principal.LogonType)" -in @('S4U','Password')) {
    "OK transcript upload files refreshed; task $TaskName kept ($($current.Principal.LogonType))"; exit 0
  }
  $ps = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
  $action = New-ScheduledTaskAction -Execute $ps -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Installed`""
  $trigger = New-ScheduledTaskTrigger -Daily -At $At
  $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 2)
  $me = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
  # S4U runs whether or not the user is logged on, without storing a password.
  try {
    $principal = New-ScheduledTaskPrincipal -UserId $me -LogonType S4U -RunLevel Limited
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description 'Daily AI transcript copy to Dropbox (ai-devops; never deletes)' -Force | Out-Null
    $mode = 'S4U'
  } catch {
    $principal = New-ScheduledTaskPrincipal -UserId $me -LogonType Interactive -RunLevel Limited
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description 'Daily AI transcript copy to Dropbox (ai-devops; never deletes)' -Force | Out-Null
    "WARN S4U refused ($($_.Exception.Message)); task registered Interactive and runs only while $me is logged on"
    exit 3
  }
  "OK transcript upload task $TaskName registered daily at $At as $me, logon $mode"; exit 0
}

# ---------- run ----------
if (-not $env:AI_TRANSCRIPT_UPLOAD_UPDATED -and $PSCommandPath -eq $Installed) {
  try {
    $mainDir = Get-VerifiedMain
    if (-not (Test-SameText (Join-Path $mainDir 'zcode_export.py') $InstalledExporter)) {
      Move-Item -LiteralPath (Join-Path $mainDir 'zcode_export.py') -Destination $InstalledExporter -Force
    }
    $restart = -not (Test-SameText (Join-Path $mainDir 'ai-transcript-upload.ps1') $Installed)
    if ($restart) { Move-Item -LiteralPath (Join-Path $mainDir 'ai-transcript-upload.ps1') -Destination $Installed -Force }
    Remove-Item -LiteralPath $mainDir -Recurse -Force
    if ($restart) {
      # Restart once so this run already uses the merged code.
      $env:AI_TRANSCRIPT_UPLOAD_UPDATED = '1'
      & $Installed @PSBoundParameters
      exit $LASTEXITCODE
    }
  } catch {
    $SelfUpdate = ' self_update=failed'
    New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
    Add-Content -LiteralPath (Join-Path $StateDir 'transcript-upload-errors.log') -Value ("{0} self-update failed: {1}" -f [DateTime]::UtcNow.ToString('s'), $_.Exception.Message) -Encoding UTF8
  }
}
if (-not $DropboxRoot) { $DropboxRoot = Find-DropboxRoot }
if (-not $HostName) { $HostName = (& hostname).Trim() }
# Folder and destination names must stay inside chat_transcripts\.
if ($HostName -notmatch '^[A-Za-z0-9._-]+$' -or $HostName -in @('.','..')) { Write-Error "ai-transcript-upload: unsafe host name: $HostName"; exit 2 }
foreach ($m in $Map) {
  if ($m.IndexOf('=') -lt 1) { Write-Error "ai-transcript-upload: -Map needs SRC=DESTREL: $m"; exit 2 }
  $rel = $m.Substring($m.IndexOf('=') + 1)
  if ($rel -notmatch '^[A-Za-z0-9._-]+([\\/][A-Za-z0-9._-]+)*$' -or ($rel -split '[\\/]') -contains '..' -or ($rel -split '[\\/]') -contains '.') { Write-Error "ai-transcript-upload: unsafe destination in -Map: $rel"; exit 2 }
}
$Root = Join-Path $DropboxRoot 'ai\chat_transcripts'
if (-not (Test-Path -LiteralPath $Root)) { Write-Error "ai-transcript-upload: $Root not found (Dropbox missing?)"; exit 1 }
$scanned = 0; $copied = 0; $hot = 0; $errors = 0
if ($Map.Count -eq 0) {
  # ZCode and MiMo keep sessions in sqlite: export them to session files, then copy those like any other.
  $Map = @()
  foreach ($z in @(@('ZCode', 'zcode', '.zcode\cli\db\db.sqlite'), @('MiMo', 'mimo', '.local\share\mimocode\mimocode.db'))) {
    $zdb = Join-Path $env:USERPROFILE $z[2]
    $zstage = Join-Path $StateDir "$($z[1])-export"
    if (Test-Path -LiteralPath $zdb) {
      $py = Get-Command python, python3 -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
      $zrc = 1
      if ($py) {
        $prior = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        & $py.Source $Exporter $zdb $zstage 2>$null | Out-Null
        $zrc = $LASTEXITCODE; $ErrorActionPreference = $prior
      }
      if ($zrc -ne 0) {
        $errors++
        New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
        Add-Content -LiteralPath (Join-Path $StateDir 'transcript-upload-errors.log') -Value ("{0} {1} export failed (exit {2})" -f [DateTime]::UtcNow.ToString('s'), $z[0], $zrc)
      }
    }
    $Map += "$zstage=$($z[1])/sessions"
  }
  $Map += @("$env:USERPROFILE\.claude\projects=claude\projects",
            "$env:USERPROFILE\.codex\sessions=codex\sessions",
            "$env:USERPROFILE\.codex\archived_sessions=codex\archived_sessions")
}
$D = Join-Path $Root $HostName
$now = [DateTime]::UtcNow

function LongPath([string]$p) {
  if ($env:OS -ne 'Windows_NT' -or $p.StartsWith('\\?\')) { return $p }
  if ($p.StartsWith('\\')) { return '\\?\UNC\' + $p.Substring(2) }
  return '\\?\' + $p
}

function Resolve-Source([string]$p) {
  # Follow a symlink or junction to its target (find on the link sees 0 files).
  for ($i = 0; $i -lt 8; $i++) {
    $item = Get-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue
    if (-not $item) { return $null }
    $t = @($item.Target) | Where-Object { $_ } | Select-Object -First 1
    if (-not $t) { return $item.FullName }
    if (-not [System.IO.Path]::IsPathRooted($t)) { $t = Join-Path (Split-Path -Parent $item.FullName) $t }
    $p = $t
  }
  return $null
}

foreach ($m in $Map) {
  $eq = $m.IndexOf('=')
  $src = Resolve-Source $m.Substring(0, $eq)
  $rel = $m.Substring($eq + 1)
  if (-not $src) { continue }
  $destDir = Join-Path $D $rel
  $partDir = Join-Path (Join-Path $D '.partial') $rel
  $srcFull = (Get-Item -LiteralPath $src -Force).FullName.TrimEnd('\')
  foreach ($f in (Get-ChildItem -LiteralPath $src -Recurse -File -Force -ErrorAction SilentlyContinue)) {
    $scanned++
    try {
      $r = $f.FullName.Substring($srcFull.Length).TrimStart('\')
      if (($now - $f.LastWriteTimeUtc).TotalMinutes -lt $HotMinutes) { $hot++; continue }
      # .NET calls with \\?\ paths, so destinations over 260 characters work in PowerShell 5.1.
      $dest = LongPath (Join-Path $destDir $r)
      $srcL = LongPath $f.FullName
      $di = New-Object System.IO.FileInfo $dest
      if ($di.Exists -and $di.Length -eq $f.Length -and $f.LastWriteTimeUtc -le $di.LastWriteTimeUtc) { continue }
      $part = LongPath (Join-Path $partDir $r)
      [void][System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($part))
      [void][System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($dest))
      $want = $f.Length; $done = $false
      for ($try = 1; $try -le 2 -and -not $done; $try++) {
        [System.IO.File]::Copy($srcL, $part, $true)
        [System.IO.File]::SetLastWriteTimeUtc($part, $f.LastWriteTimeUtc)
        $got = (New-Object System.IO.FileInfo $part).Length
        $now2 = (New-Object System.IO.FileInfo $srcL).Length
        if ($got -eq $want -and $now2 -eq $want) {
          # File.Replace rejects \\?\ paths on .NET Framework; replace = delete the old copy, then rename.
          if ([System.IO.File]::Exists($dest)) { [System.IO.File]::Delete($dest) }
          [System.IO.File]::Move($part, $dest)
          $done = $true; $copied++
        } else {
          [System.IO.File]::Delete($part); $want = $now2
        }
      }
    } catch {
      $errors++
      New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
      Add-Content -LiteralPath (Join-Path $StateDir 'transcript-upload-errors.log') -Value ("{0} {1}: {2}" -f [DateTime]::UtcNow.ToString('s'), $f.FullName, $_.Exception.Message) -Encoding UTF8
    }
  }
}

$tz = [TimeZoneInfo]::FindSystemTimeZoneById('Eastern Standard Time')
$et = [TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow, $tz)
$label = if ($tz.IsDaylightSavingTime($et)) { 'EDT' } else { 'EST' }
$line = '{0} {1} host={2} scanned={3} copied={4} skipped_hot={5} errors={6}{7}' -f $et.ToString('yyyy-MM-dd HH:mm:ss'), $label, $HostName, $scanned, $copied, $hot, $errors, $SelfUpdate
New-Item -ItemType Directory -Force -Path $StateDir, $D | Out-Null
Add-Content -LiteralPath (Join-Path $StateDir 'transcript-upload.log') -Value $line -Encoding UTF8
$last = Join-Path $D '.upload-last.txt'
[System.IO.File]::WriteAllText("$last.tmp", $line + "`n")
Move-Item -LiteralPath "$last.tmp" -Destination $last -Force
$line
if ($errors -gt 0) { exit 1 }
exit 0
