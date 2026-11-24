<#
.SYNOPSIS
  Hide, for ZCode only, the second copy of each toolkit skill that ZCode's
  other skill root holds (#2795).

.DESCRIPTION
  ZCode scans two user skill roots: ~/.zcode/skills and ~/.agents/skills. A
  skill's identity there is its file path, so when both roots hold the same
  skill name ZCode lists it twice. The main session loads the ~/.zcode copy
  (scanned first), but every subagent refuses the bare name ("Skill name is
  ambiguous for subagent; use the fully qualified skill name"), and no
  qualified name exists for a skill that is not a plugin skill. Delegated
  work that needs a skill therefore cannot load it.

  No setting removes a root, so this uses ZCode's own per-skill switch: the
  "skill" object of ~/.zcode/cli/config.json, keyed by the absolute path of
  the shadowed SKILL.md, with { "enable": false }. That is the entry ZCode
  writes when a person disables a skill in Settings. ZCode then sees each
  skill once and a subagent loads it by bare name.

  Which entries are this writer's: those whose key is <secondary root>\
  <name>\SKILL.md AND whose <name> is a toolkit skill. A toolkit skill is one
  whose ~/.zcode/skills copy carries the .ai-devops-managed marker, or one
  that sits in ~/.zcode/skills-quarantine because the toolkit retired it. The
  entry is written while the pair exists and removed once it no longer does.
  Every other entry, and every other key of the file, is left untouched.

  Safety: an entry is written only when the two SKILL.md files are different
  files (final paths compared, links resolved). Disabling a path also disables
  its link target, so where the two roots are the same folder an entry would
  switch the skill off in ZCode entirely. Such a pair is skipped and reported.

  Runs under Windows PowerShell 5.1 and PowerShell 7, because the installer
  that calls it is 5.1-safe. Writes atomically with a timestamped
  .aidevops.<stamp>.bak backup, is idempotent, and never creates the config
  file when there is nothing to hide.

  Called by bin/install-ai-devops-windows.ps1; testable standalone.
  Test: tests/test-configure-zcode-skill-shadows.ps1.
#>
[CmdletBinding()]
param(
  [string]$ZCodeHome = (Join-Path $HOME ".zcode"),
  # The other user root ZCode scans. Read only: nothing is ever written there.
  [string]$AgentsSkillsRoot = (Join-Path $HOME ".agents\skills"),
  [string]$ConfigPath = '',
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if (-not $ConfigPath) { $ConfigPath = Join-Path $ZCodeHome "cli\config.json" }
$ConfigPath = [IO.Path]::GetFullPath($ConfigPath)
$primaryRoot = [IO.Path]::GetFullPath((Join-Path $ZCodeHome "skills"))
$secondaryRoot = [IO.Path]::GetFullPath($AgentsSkillsRoot)
$separator = [IO.Path]::DirectorySeparatorChar
$secondaryPrefix = $secondaryRoot.TrimEnd($separator) + $separator
$onWindows = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
$pathComparison = if ($onWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
$ManagedMarker = ".ai-devops-managed"
$ManagedFile = "SKILL.md"

# Folder names ZCode never descends into (verified against its scanner,
# ZCode 4.0.0.10870). Dot folders are skipped too, except .system.
$SkippedNames = @("node_modules", "dist", "build", "out", "target", "vendor",
  "coverage", ".cache", ".next", ".turbo", ".venv", "__pycache__")

# Win32 calls that exist in every PowerShell edition: the final path of a file
# (every link resolved) and an atomic replace. .NET Framework has neither
# File.ResolveLinkTarget nor the overwrite overload of File.Move.
if ($onWindows -and -not ("AiDevOpsSkillShadow.NativeMethods" -as [type])) {
  Add-Type -ErrorAction Stop -Namespace "AiDevOpsSkillShadow" -Name "NativeMethods" -MemberDefinition @'
[DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
public static extern Microsoft.Win32.SafeHandles.SafeFileHandle CreateFile(string name, uint access, uint share, System.IntPtr security, uint creation, uint flags, System.IntPtr template);
[DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
public static extern uint GetFinalPathNameByHandle(Microsoft.Win32.SafeHandles.SafeFileHandle handle, System.Text.StringBuilder path, uint length, uint flags);
[DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
public static extern bool MoveFileEx(string existingName, string newName, uint flags);
'@
}

function Get-FinalPath([string]$Path) {
  if (-not $onWindows) {
    # Resolve links in parent directories as well as links to SKILL.md itself.
    $resolved = & realpath -e -- $Path 2>$null
    if ($LASTEXITCODE -eq 0 -and $resolved -is [string]) { return $resolved }
    return $null
  }
  # FILE_READ_ATTRIBUTES, share all, OPEN_EXISTING.
  $handle = [AiDevOpsSkillShadow.NativeMethods]::CreateFile(
    $Path, [uint32]0x80, [uint32]7, [IntPtr]::Zero, [uint32]3, [uint32]0, [IntPtr]::Zero)
  if ($handle.IsInvalid) { $handle.Dispose(); return $null }
  try {
    $capacity = 512
    $buffer = New-Object System.Text.StringBuilder $capacity
    $needed = [AiDevOpsSkillShadow.NativeMethods]::GetFinalPathNameByHandle(
      $handle, $buffer, [uint32]$capacity, [uint32]0)
    if ($needed -ge $capacity) {
      $capacity = [int]$needed + 1
      $buffer = New-Object System.Text.StringBuilder $capacity
      $needed = [AiDevOpsSkillShadow.NativeMethods]::GetFinalPathNameByHandle(
        $handle, $buffer, [uint32]$capacity, [uint32]0)
    }
    if ($needed -eq 0) { return $null }
    # Kept in the call's own spelling (\\?\C:\...): it is only ever compared
    # with another final path, never shown or written.
    return $buffer.ToString()
  } finally {
    $handle.Dispose()
  }
}

function Get-Sha256([string]$Path) {
  # Not Get-FileHash: a powershell.exe 5.1 session can inherit pwsh's
  # PSModulePath and then fail to discover that cmdlet.
  $hasher = [System.Security.Cryptography.SHA256]::Create()
  $stream = $null
  try {
    $stream = [System.IO.File]::OpenRead($Path)
    return ([System.BitConverter]::ToString($hasher.ComputeHash($stream)) -replace "-", "")
  } finally {
    if ($null -ne $stream) { $stream.Dispose() }
    $hasher.Dispose()
  }
}

function Test-SkillDirectoryName([string]$Name) {
  if ($Name.StartsWith(".")) { return ($Name -eq ".system") }
  return ($SkippedNames -notcontains $Name)
}

# Skill names ZCode lists under a root: one level of folders, each holding
# SKILL.md. The same shape ZCode's own scanner walks.
function Get-SkillNames([string]$Root) {
  if (-not (Test-Path -LiteralPath $Root -PathType Container)) { return @() }
  $names = @()
  foreach ($dir in (Get-ChildItem -LiteralPath $Root -Directory -Force)) {
    if (-not (Test-SkillDirectoryName $dir.Name)) { continue }
    if (Test-Path -LiteralPath (Join-Path $dir.FullName $ManagedFile) -PathType Leaf) {
      $names += $dir.Name
    }
  }
  return $names
}

# The skill name when a config key is this writer's shape
# (<secondary root>\<name>\SKILL.md); otherwise $null, meaning not ours.
function Get-ManagedEntryName([string]$Key) {
  if ([string]::IsNullOrWhiteSpace($Key)) { return $null }
  try { $full = [IO.Path]::GetFullPath($Key) } catch { return $null }
  if (-not $full.StartsWith($secondaryPrefix, $pathComparison)) { return $null }
  $parts = $full.Substring($secondaryPrefix.Length).Split($separator)
  if ($parts.Count -ne 2 -or $parts[1] -ne $ManagedFile) { return $null }
  return $parts[0]
}

function New-DisabledValue {
  return [pscustomobject]@{ enable = $false }
}

function Read-ConfigDocument([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return (New-Object psobject) }
  $text = [IO.File]::ReadAllText($Path)
  # An empty file holds nothing that a rewrite could lose.
  if ([string]::IsNullOrWhiteSpace($text)) { return (New-Object psobject) }
  try {
    $document = $text | ConvertFrom-Json -ErrorAction Stop
  } catch {
    throw "Refusing to replace malformed JSON at $Path. Repair it first; the live file is unchanged. ($($_.Exception.Message))"
  }
  if ($null -eq $document -or $document -isnot [System.Management.Automation.PSCustomObject]) {
    throw "Refusing to edit ${Path}: its top level is not a JSON object. The live file is unchanged."
  }
  return $document
}

# --- 1. Which toolkit skills does the secondary root shadow? -----------------

$toolkitNames = @{}
foreach ($name in (Get-SkillNames $primaryRoot)) {
  if (Test-Path -LiteralPath (Join-Path (Join-Path $primaryRoot $name) $ManagedMarker) -PathType Leaf) {
    $toolkitNames[$name] = $true
  }
}
foreach ($name in (Get-SkillNames (Join-Path $ZCodeHome "skills-quarantine"))) {
  $toolkitNames[$name] = $true
}

$primaryNames = Get-SkillNames $primaryRoot
$desired = [ordered]@{}
$sameFile = @()
$unreadable = @()
foreach ($name in (@(Get-SkillNames $secondaryRoot) | Sort-Object)) {
  if ($primaryNames -notcontains $name) { continue }
  if (-not $toolkitNames.ContainsKey($name)) { continue }
  $secondaryFile = Join-Path (Join-Path $secondaryRoot $name) $ManagedFile
  $primaryFile = Join-Path (Join-Path $primaryRoot $name) $ManagedFile
  $secondaryFinal = Get-FinalPath $secondaryFile
  $primaryFinal = Get-FinalPath $primaryFile
  if (-not $secondaryFinal -or -not $primaryFinal) { $unreadable += $name; continue }
  if ([string]::Equals($secondaryFinal, $primaryFinal, $pathComparison)) {
    $sameFile += $name
    continue
  }
  $desired[$name] = $secondaryFile
}

# --- 2. Reconcile the config's "skill" object --------------------------------

$document = Read-ConfigDocument $ConfigPath
$skillProperty = $null
foreach ($property in $document.PSObject.Properties) {
  if ($property.Name -ceq "skill") { $skillProperty = $property; break }
}
if ($null -ne $skillProperty -and $skillProperty.Value -isnot [System.Management.Automation.PSCustomObject]) {
  throw "config 'skill' key at $ConfigPath exists but is not an object; refusing to touch it."
}

$next = [ordered]@{}
$present = @{}
$added = @()
$rewritten = @()
$removed = @()
if ($null -ne $skillProperty) {
  foreach ($property in $skillProperty.Value.PSObject.Properties) {
    $entryName = Get-ManagedEntryName $property.Name
    if ($null -eq $entryName -or -not $toolkitNames.ContainsKey($entryName)) {
      # Not written by this writer: someone else's choice, kept as it is.
      $next[$property.Name] = $property.Value
      continue
    }
    if (-not $desired.Contains($entryName)) {
      # Ours, and the pair it was written for is gone.
      $removed += $property.Name
      continue
    }
    $value = $property.Value
    $enable = $null
    if ($value -is [pscustomobject]) { $enable = $value.PSObject.Properties["enable"] }
    $alreadyDisabled = $null -ne $enable -and $enable.Value -is [bool] -and -not $enable.Value
    if ($property.Name -cne $desired[$entryName] -or -not $alreadyDisabled) {
      $rewritten += $desired[$entryName]
    }
    if ($value -isnot [pscustomobject]) {
      $value = New-DisabledValue
    } elseif ($null -eq $enable) {
      Add-Member -InputObject $value -NotePropertyName "enable" -NotePropertyValue $false
    } else {
      $enable.Value = $false
    }
    $next[$desired[$entryName]] = $value
    $present[$entryName] = $true
  }
}
foreach ($name in @(@($desired.Keys) | Sort-Object)) {
  if ($present.ContainsKey($name)) { continue }
  $next[$desired[$name]] = New-DisabledValue
  $present[$name] = $true
  $added += $desired[$name]
}
$changed = ($added.Count + $rewritten.Count + $removed.Count) -gt 0

# --- 3. Report, or write ------------------------------------------------------

foreach ($name in $sameFile) {
  Write-Warning "! ZCode skill '$name' is the same file in both skill roots; nothing hidden for it (an entry would switch it off in ZCode entirely)."
}
foreach ($name in $unreadable) {
  Write-Warning "! ZCode skill '$name' could not be compared between the two skill roots; nothing hidden for it."
}

$prefix = ""
if ($DryRun) { $prefix = "[skills-dry-run] " }
if (-not $changed) {
  if ($desired.Count -eq 0) {
    Write-Host "ok ZCode skill shadows: none to hide (no toolkit skill is doubled under $secondaryRoot)" -ForegroundColor Green
  } else {
    Write-Host "ok ZCode skill shadows already current: $($desired.Count) hidden under $secondaryRoot" -ForegroundColor Green
  }
  return
}

foreach ($key in $added) { Write-Host "${prefix}+ hide $key from ZCode" }
foreach ($key in $rewritten) { Write-Host "${prefix}~ hide $key from ZCode" }
foreach ($key in $removed) { Write-Host "${prefix}- stop hiding $key from ZCode (no longer doubled)" }
if ($DryRun) { return }

$nextObject = [pscustomobject]$next
if ($null -ne $skillProperty) {
  $skillProperty.Value = $nextObject
} elseif ($next.Count -gt 0) {
  Add-Member -InputObject $document -NotePropertyName "skill" -NotePropertyValue $nextObject
}
$json = $document | ConvertTo-Json -Depth 20
try { $null = $json | ConvertFrom-Json -ErrorAction Stop }
catch { throw "Generated JSON for $ConfigPath did not validate; the live file is unchanged." }

$parent = Split-Path -Parent $ConfigPath
New-Item -ItemType Directory -Force -Path $parent | Out-Null
$candidate = Join-Path $parent (".ai-devops-json-" + [guid]::NewGuid().ToString("N") + ".tmp")
try {
  [IO.File]::WriteAllBytes($candidate, (New-Object System.Text.UTF8Encoding($false)).GetBytes($json + [Environment]::NewLine))
  $null = [IO.File]::ReadAllText($candidate) | ConvertFrom-Json -ErrorAction Stop
  $backup = $null
  if (Test-Path -LiteralPath $ConfigPath -PathType Leaf) {
    $stamp = [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssfffZ")
    $backup = "$ConfigPath.aidevops.$stamp.bak"
    Copy-Item -LiteralPath $ConfigPath -Destination $backup
    if ((Get-Sha256 $ConfigPath) -ne (Get-Sha256 $backup)) {
      Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue
      throw "Backup verification failed for $ConfigPath; the live file is unchanged."
    }
  }
  # The candidate shares the config's directory, so the Unix move is a rename.
  # Windows uses MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH.
  if (-not $onWindows) {
    [IO.File]::Move($candidate, $ConfigPath, $true)
  } elseif (-not [AiDevOpsSkillShadow.NativeMethods]::MoveFileEx($candidate, $ConfigPath, [uint32]9)) {
    $code = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
    throw "Replacing $ConfigPath failed (Windows error $code); the live file is unchanged."
  }
} finally {
  if (Test-Path -LiteralPath $candidate) { Remove-Item -LiteralPath $candidate -Force }
}

$delta = @()
if ($added.Count -gt 0) { $delta += "+$($added.Count)" }
if ($rewritten.Count -gt 0) { $delta += "~$($rewritten.Count)" }
if ($removed.Count -gt 0) { $delta += "-$($removed.Count)" }
Write-Host "ok ZCode skill shadows configured: $($delta -join ' '); $($desired.Count) hidden under $secondaryRoot" -ForegroundColor Green
if ($backup) {
  Write-Host "   protected prior config: $backup"
  Write-Host "   recovery: Copy-Item -LiteralPath '$backup' -Destination '$ConfigPath' -Force"
}
