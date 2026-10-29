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
#        ai-transcript-upload.ps1 -Install [-At 06:30] | -Check | -Remove
[CmdletBinding()]
param(
  [string]$DropboxRoot = '',
  [string]$HostName = '',
  [int]$HotMinutes = 15,
  [string[]]$Map = @(),
  [switch]$Install,
  [string]$At = '06:30',
  [switch]$Check,
  [switch]$Remove
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$TaskName = 'AiDevOps-TranscriptUpload'
$StateDir = Join-Path $env:LOCALAPPDATA 'ai-devops'
$Installed = Join-Path $StateDir 'ai-transcript-upload.ps1'

if ($Remove) {
  Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
  if (Test-Path -LiteralPath $Installed) { Remove-Item -LiteralPath $Installed -Force }
  'OK transcript upload task removed (Dropbox copies are left as they are)'; exit 0
}
if ($Check) {
  $rc = 0
  if (-not (Test-Path -LiteralPath $Installed)) { "ERROR $Installed not installed"; $rc = 1 }
  elseif ((Get-FileHash -LiteralPath $Installed).Hash -ne (Get-FileHash -LiteralPath $PSCommandPath).Hash) { "ERROR installed copy differs from $PSCommandPath"; $rc = 1 }
  $t = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
  if (-not $t) { "ERROR scheduled task $TaskName not registered"; $rc = 1 }
  elseif ($t.State -eq 'Disabled') { "ERROR scheduled task $TaskName is disabled"; $rc = 1 }
  elseif ("$($t.Principal.LogonType)" -notin @('S4U','Password')) { "ERROR scheduled task $TaskName runs only while logged on ($($t.Principal.LogonType))"; $rc = 1 }
  if ($rc -eq 0) { "OK transcript upload task installed ($($t.Principal.UserId), $($t.Principal.LogonType))" }
  exit $rc
}
if ($Install) {
  New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
  Copy-Item -LiteralPath $PSCommandPath -Destination "$Installed.tmp" -Force
  Move-Item -LiteralPath "$Installed.tmp" -Destination $Installed -Force
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
if (-not $DropboxRoot) {
  $info = Join-Path $env:LOCALAPPDATA 'Dropbox\info.json'
  if (Test-Path -LiteralPath $info) { $DropboxRoot = (Get-Content -Raw -LiteralPath $info | ConvertFrom-Json).personal.path }
  if (-not $DropboxRoot) { $DropboxRoot = Join-Path $env:USERPROFILE 'Dropbox' }
}
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
if ($Map.Count -eq 0) {
  $Map = @("$env:USERPROFILE\.claude\projects=claude\projects",
           "$env:USERPROFILE\.codex\sessions=codex\sessions",
           "$env:USERPROFILE\.codex\archived_sessions=codex\archived_sessions")
}
$D = Join-Path $Root $HostName
$now = [DateTime]::UtcNow
$scanned = 0; $copied = 0; $hot = 0; $errors = 0

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
$line = '{0} {1} host={2} scanned={3} copied={4} skipped_hot={5} errors={6}' -f $et.ToString('yyyy-MM-dd HH:mm:ss'), $label, $HostName, $scanned, $copied, $hot, $errors
New-Item -ItemType Directory -Force -Path $StateDir, $D | Out-Null
Add-Content -LiteralPath (Join-Path $StateDir 'transcript-upload.log') -Value $line -Encoding UTF8
$last = Join-Path $D '.upload-last.txt'
[System.IO.File]::WriteAllText("$last.tmp", $line + "`n")
Move-Item -LiteralPath "$last.tmp" -Destination $last -Force
$line
if ($errors -gt 0) { exit 1 }
exit 0
