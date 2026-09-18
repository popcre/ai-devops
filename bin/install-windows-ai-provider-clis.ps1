<#
.SYNOPSIS
Installs the official Windows Grok Build, Kimi Code, and Qwen Code command-line tools.

Authentication deliberately remains interactive. The installers only put the
programs on this computer; each provider opens its own login on first use.

Grok is version-pinned. config/provider-cli-versions.json holds the one exact
build this repository qualifies, because the Grok wrappers parse that build's
JSON, stop reasons, usage keys and session behaviour. A present-but-off-policy
Grok is upgraded to that exact version, the result is verified, and a failed
upgrade restores the previous executable. Credentials under ~/.grok are never
read, copied or backed up.
#>
[CmdletBinding()]
param(
  [switch]$TestOnly,
  [ValidateSet('grok', 'kimi', 'qwen')]
  [Alias('Provider')]
  [string[]]$SelectedProvider = @('grok', 'kimi', 'qwen'),
  [ValidatePattern('^v\d+\.\d+\.\d+$')]
  [string]$QwenVersion
)

$ErrorActionPreference = 'Stop'
$results = [Collections.Generic.List[object]]::new()

function Result([string]$Name, [string]$Status, [string]$Detail) {
  $results.Add([pscustomobject]@{ Provider=$Name; Status=$Status; Detail=$Detail })
}

function Set-QwenChildEnvironmentHardening {
  param([string]$Root = $(Join-Path $env:LOCALAPPDATA 'qwen-code\qwen-code'))
  $chunkRoot = Join-Path $Root 'lib\chunks'
  if (-not (Test-Path -LiteralPath $chunkRoot -PathType Container)) { throw "Qwen bundle directory is missing: $chunkRoot" }
  $candidates = @(Get-ChildItem -LiteralPath $chunkRoot -Filter '*.js' -File | Where-Object {
    $text = Get-Content -Raw -LiteralPath $_.FullName
    $text.Contains('var INTERNAL_SECRET_ENV_VARS') -and $text.Contains('function sanitizeChildEnv')
  })
  if ($candidates.Count -ne 1) { throw "Expected exactly one Qwen child-environment sanitizer bundle under $chunkRoot; found $($candidates.Count)." }
  $path = $candidates[0].FullName
  $content = Get-Content -Raw -LiteralPath $path
  $declaration = [regex]::Match($content, 'var INTERNAL_SECRET_ENV_VARS\s*=\s*\[[\s\S]*?\];')
  if (-not $declaration.Success) { throw 'The known Qwen sanitizer declaration was not found; refusing an unverified patch.' }
  if (-not $declaration.Value.Contains('"BAILIAN_CODING_PLAN_API_KEY"')) {
    $needle = 'var INTERNAL_SECRET_ENV_VARS = ['
    $replacement = "$needle`n  `"BAILIAN_CODING_PLAN_API_KEY`","
    $index = $content.IndexOf($needle, [StringComparison]::Ordinal)
    if ($index -lt 0) { throw 'The known Qwen sanitizer declaration was not found; refusing an unverified patch.' }
    $backupDir = Join-Path $HOME '.local\state\ai-devops\qwen\vendor-backups'
    [void](New-Item -ItemType Directory -Force -Path $backupDir)
    $backup = Join-Path $backupDir ("{0}.{1}.bak" -f $candidates[0].Name, (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'))
    Copy-Item -LiteralPath $path -Destination $backup
    $patched = $content.Substring(0, $index) + $replacement + $content.Substring($index + $needle.Length)
    $temp = "$path.harden.$PID.tmp"
    try {
      [IO.File]::WriteAllText($temp, $patched, [Text.UTF8Encoding]::new($false))
      Move-Item -Force -LiteralPath $temp -Destination $path
    } finally { if (Test-Path -LiteralPath $temp) { Remove-Item -Force -LiteralPath $temp } }
  }
  $node = Join-Path $Root 'node\node.exe'
  $verify = Join-Path $PSScriptRoot '..\tools\verify-qwen-child-env-sanitizer.mjs'
  if (-not (Test-Path -LiteralPath $node -PathType Leaf) -or -not (Test-Path -LiteralPath $verify -PathType Leaf)) { throw 'Qwen sanitizer behavioral verifier or bundled Node runtime is missing.' }
  & $node $verify $Root | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Qwen child-environment sanitizer failed its behavioral proof.' }
  return $path
}

function Get-RequiredProviderVersion {
  param([Parameter(Mandatory)][string]$Provider)
  $policyPath = if ($env:AI_PROVIDER_VERSIONS_FILE) { $env:AI_PROVIDER_VERSIONS_FILE }
                else { Join-Path $PSScriptRoot '..\config\provider-cli-versions.json' }
  if (-not (Test-Path -LiteralPath $policyPath -PathType Leaf)) {
    throw "Provider version policy not found: $policyPath"
  }
  $policy = Get-Content -Raw -LiteralPath $policyPath | ConvertFrom-Json
  if ($policy.schema_version -ne 1 -or -not $policy.providers) {
    throw "Malformed provider version policy: $policyPath"
  }
  $entry = $policy.providers.$Provider
  if ($null -eq $entry) { throw "Unknown provider '$Provider' in $policyPath" }
  return $entry.supported_version
}

function Get-ReportedProviderVersion {
  param([Parameter(Mandatory)][string]$Path)
  try { $raw = & $Path --version 2>&1 | Select-Object -First 1 } catch { return $null }
  if (-not $raw) { return $null }
  # [0-9], not \d: .NET's \d also matches non-ASCII digits, while the Unix
  # reader (bin/ai-provider-version) is ASCII-only. Both must accept and reject
  # exactly the same banner -- tests/fixtures/version-banners.tsv proves it.
  $m = [regex]::Match([string]$raw, '([0-9]+\.[0-9]+\.[0-9]+)')
  if ($m.Success) { return $m.Groups[1].Value }
  return $null
}

function Update-ProviderToExactVersion {
  param([Parameter(Mandatory)]$Provider, [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Version)
  if ($Provider.Command -ne 'grok') {
    throw "No exact-version upgrade path is defined for $($Provider.Name)."
  }
  $backupDir = Join-Path $HOME '.local\state\ai-devops\provider-cli\backups'
  [void](New-Item -ItemType Directory -Force -Path $backupDir)
  $backup = Join-Path $backupDir ("{0}.{1}.bak" -f $Provider.Command, (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'))
  Copy-Item -LiteralPath $Path -Destination $backup
  Write-Host "Backed up $Path -> $backup"
  $restore = {
    try { Copy-Item -Force -LiteralPath $backup -Destination $Path; Write-Host "Restored the previous $($Provider.Name) from $backup" }
    catch { Write-Warning "Restore from $backup FAILED; restore it by hand." }
  }
  # Everything after the backup is inside try/finally. $ErrorActionPreference is
  # 'Stop', so a throwing `update` -- a replaced or locked executable, a failed
  # download -- would otherwise skip the restore entirely and leave the machine
  # with a worse binary than the one it started with. $ok is set only on the
  # single path that ends with the pinned version actually installed.
  $ok = $false
  try {
    & $Path update --version $Version
    if ($LASTEXITCODE -ne 0) {
      throw "$($Provider.Name): 'update --version $Version' exited with status $LASTEXITCODE."
    }
    $now = Get-ReportedProviderVersion -Path $Path
    if ($now -ne $Version) {
      throw "$($Provider.Name): upgrade finished but the binary reports '$now', not $Version."
    }
    $ok = $true
  } finally {
    if (-not $ok) { & $restore }
  }
  Write-Host "$($Provider.Name) is now exactly $Version (previous binary kept at $backup)."
}

function Invoke-PinnedProviderInstaller {
  param([Parameter(Mandatory)]$Provider)
  $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)
  $tempDir = Join-Path $tempRoot ("ai-devops-provider-{0}" -f [Guid]::NewGuid().ToString('N'))
  $installerFile = Join-Path $tempDir 'install.ps1'
  try {
    [void](New-Item -ItemType Directory -Path $tempDir)
    $currentSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    & icacls.exe $tempDir '/inheritance:r' "/grant:r" "*${currentSid}:(OI)(CI)F" '*S-1-5-18:(OI)(CI)F' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Could not protect temporary installer directory: $tempDir" }
    Invoke-WebRequest -UseBasicParsing -Uri $Provider.InstallUri -OutFile $installerFile
    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $installerFile).Hash.ToLowerInvariant()
    if ($actualHash -ne $Provider.InstallerSha256) {
      throw "$($Provider.Name) installer integrity changed. Expected $($Provider.InstallerSha256), received $actualHash. Review and update the repository-owned pin before installing."
    }
    $engine = (Get-Process -Id $PID).Path
    & $engine -NoProfile -ExecutionPolicy Bypass -File $installerFile
    if ($LASTEXITCODE -ne 0) { throw "$($Provider.Name) installer exited with status $LASTEXITCODE." }
  } finally {
    $resolvedTemp = [IO.Path]::GetFullPath($tempDir)
    if ($resolvedTemp.StartsWith("$tempRoot$([IO.Path]::DirectorySeparatorChar)", [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedTemp)) {
      Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
  }
}

function Backup-QwenRuntime {
  param([string]$Root = $(Join-Path $env:LOCALAPPDATA 'qwen-code'))
  if (-not (Test-Path -LiteralPath $Root -PathType Container)) { return $null }
  $backupRoot = Join-Path $HOME '.local\state\ai-devops\qwen\vendor-backups'
  [void](New-Item -ItemType Directory -Force -Path $backupRoot)
  $backup = Join-Path $backupRoot ("runtime-{0}" -f (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'))
  Copy-Item -LiteralPath $Root -Destination $backup -Recurse
  if (-not (Test-Path -LiteralPath $backup -PathType Container)) { throw 'Qwen runtime backup could not be verified.' }
  return $backup
}

function Test-QwenRuntimeTree([string]$Root) {
  # A runtime is complete only when both launchers have content and the bundle
  # has chunks: the shim alone (bundle deleted), zero-byte launchers, or an
  # empty chunks directory are all unusable. ai-qwen's resolve_qwen applies the
  # same rule.
  if (-not $Root) { return $false }
  foreach ($launcher in @('bin\qwen.cmd', 'qwen-code\bin\qwen.cmd')) {
    $item = Get-Item -LiteralPath (Join-Path $Root $launcher) -Force -ErrorAction SilentlyContinue
    if (-not $item -or $item.PSIsContainer -or $item.Length -le 0) { return $false }
  }
  $chunks = Join-Path $Root 'qwen-code\lib\chunks'
  return (Test-Path -LiteralPath $chunks -PathType Container) -and
    [bool](Get-ChildItem -LiteralPath $chunks -Force -ErrorAction SilentlyContinue | Select-Object -First 1)
}

function Test-QwenRuntimeComplete {
  # A qwen found on PATH (for example an npm copy the wrapper refuses) says
  # nothing about the standalone runtime, so only the tree itself counts.
  return Test-QwenRuntimeTree (Join-Path $env:LOCALAPPDATA 'qwen-code')
}

function Restore-QwenRuntime {
  # Put back the exact pre-install runtime after a failed install. The backup
  # is staged and verified beside the live tree first, so the live tree is only
  # swapped once a complete replacement exists. The failed tree is moved aside,
  # never deleted, and is moved back if the swap itself fails.
  param($Backup, [string]$Root = $(Join-Path $env:LOCALAPPDATA 'qwen-code'))
  if (-not (Test-QwenRuntimeTree $Backup)) { Write-QwenInstallEvent "no complete backup to restore ($Backup)"; return $false }
  $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
  $staging = "$Root.restoring.$stamp"
  $failed = "$Root.failed.$stamp"
  try {
    Copy-Item -LiteralPath $Backup -Destination $staging -Recurse -ErrorAction Stop
    if (-not (Test-QwenRuntimeTree $staging)) { throw "staged copy at $staging is incomplete" }
  } catch {
    Write-QwenInstallEvent "restore not attempted, live runtime untouched: $($_.Exception.Message)"
    return $false
  }
  $movedAside = $false
  try {
    if (Test-Path -LiteralPath $Root) { Move-Item -LiteralPath $Root -Destination $failed -ErrorAction Stop; $movedAside = $true }
    Move-Item -LiteralPath $staging -Destination $Root -ErrorAction Stop
  } catch {
    $swapError = $_.Exception.Message
    $putBack = $false
    if ($movedAside -and -not (Test-Path -LiteralPath $Root)) {
      try { Move-Item -LiteralPath $failed -Destination $Root -ErrorAction Stop; $putBack = $true } catch { }
    }
    if ($putBack) { Write-QwenInstallEvent "restore swap failed ($swapError); the pre-restore live tree was put back" }
    else { Write-QwenInstallEvent "restore swap failed ($swapError); live tree state: failed=$failed staged=$staging" }
    return $false
  }
  Write-QwenInstallEvent "restored previous runtime from $Backup (failed runtime kept at $failed)"
  return $true
}

function Write-QwenInstallEvent([string]$Event) {
  # Durable trail of every Qwen install attempt, so the next time the runtime
  # goes missing the log shows which process last touched it and how it ended.
  # Logging is evidence only: it must never stop an install or a restore.
  try {
    $log = Join-Path $HOME '.local\state\ai-devops\qwen\install-events.log'
    [void](New-Item -ItemType Directory -Force -Path (Split-Path $log))
    $parent = try { (Get-CimInstance Win32_Process -Filter "ProcessId=$PID").ParentProcessId } catch { '?' }
    Add-Content -LiteralPath $log -Value ("{0} pid={1} parent={2} {3}" -f (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'), $PID, $parent, $Event)
  } catch { Write-Warning "Qwen install event not logged: $($_.Exception.Message)" }
}

$providerCatalog = @(
  [pscustomobject]@{
    Name = 'Grok Build CLI'
    Id = 'grok'
    Command = 'grok'
    InstallUri = 'https://x.ai/cli/install.ps1'
    InstallerSha256 = '9e995d8d6adaa425fd52ad89b5281d6d4d9076c1835d6cc65a666ec89288d5b6'
    ExpectedPath = (Join-Path $HOME '.grok\bin\grok.exe')
  },
  [pscustomobject]@{
    Name = 'Kimi Code CLI'
    Id = 'kimi'
    Command = 'kimi'
    InstallUri = 'https://code.kimi.com/kimi-code/install.ps1'
    InstallerSha256 = 'b6307003b603f525673ece0fb2174de2b16915a27dd0c8ed7c93d9b4d12ebe8b'
    ExpectedPath = (Join-Path $HOME '.kimi-code\bin\kimi.exe')
  },
  [pscustomobject]@{
    Name = 'Qwen Code CLI'
    Id = 'qwen'
    Command = 'qwen'
    InstallUri = 'https://qwen-code-assets.oss-cn-hangzhou.aliyuncs.com/installation/install-qwen-standalone.ps1'
    InstallerSha256 = '901f2974d849a7366dcdbfe0fb23a6e85a97a563570e1e7aa5415a5f634da1c8'
    ExpectedPath = (Join-Path $env:LOCALAPPDATA 'qwen-code\bin\qwen.cmd')
  }
)

foreach ($providerDefinition in $providerCatalog) {
  if ($providerDefinition.Id -notin $SelectedProvider) { continue }
  $provider = $providerDefinition
  $required = Get-RequiredProviderVersion -Provider $provider.Command
  # An unpinned entry means "presence is enough", which is right for Kimi and
  # Qwen. For Grok it would reinstate the presence-skip this policy exists to
  # remove, so an empty pin is a policy error, not a permission.
  if ($provider.Command -eq 'grok' -and -not $required) {
    throw 'The provider version policy pins no Grok version; Grok must be qualified at an exact version before it is installed.'
  }
  $command = Get-Command $provider.Command -ErrorAction SilentlyContinue
  $present = [bool]$command -or (Test-Path -LiteralPath $provider.ExpectedPath)
  if ($provider.Id -eq 'qwen') {
    $present = Test-QwenRuntimeComplete
    $command = $null
  }
  if ($TestOnly) {
    $probe = if ($command) { $command.Source } else { $provider.ExpectedPath }
    $status = if (-not $present) { 'MISSING' } else { 'OK' }
    $detail = $probe
    if ($present -and $required) {
      $have = Get-ReportedProviderVersion -Path $probe
      if ($have -ne $required) { $status = 'STALE'; $detail = "$probe reports '$have', requires exactly $required" }
      else { $detail = "$probe ($required)" }
    }
    Result $provider.Name $status $detail
    continue
  }

  $forceQwenVersion = $provider.Id -eq 'qwen' -and -not [string]::IsNullOrEmpty($QwenVersion)
  $backup = $null
  $installStarted = $false
  $priorQwenVersion = $env:QWEN_INSTALL_VERSION
  $qwenLock = $null
  try {
    if ($provider.Id -eq 'qwen') {
      # Two sessions reinstalling at once rename the vendor directory under
      # each other. Serialize every Qwen install on this machine, across
      # Windows logon sessions (a Local\ mutex is per-session), and hold the
      # lock through the version pin, hardening and verification.
      $qwenLock = [System.Threading.Mutex]::new($false, 'Global\ai-devops-qwen-install')
      try { $acquired = $qwenLock.WaitOne([TimeSpan]::FromMinutes(10)) } catch [System.Threading.AbandonedMutexException] { $acquired = $true }
      if (-not $acquired) { $qwenLock.Dispose(); $qwenLock = $null; throw 'Another Qwen install on this machine has held the install lock for 10 minutes; not starting a second one.' }
      $present = Test-QwenRuntimeComplete
    }
    if (-not $present -or $forceQwenVersion) {
      Write-Host "Installing $($provider.Name) from its official installer..."
      if ($provider.Id -eq 'qwen') {
        $backup = Backup-QwenRuntime
        Write-QwenInstallEvent ("start: complete={0} requested={1} backup={2}" -f (Test-QwenRuntimeComplete), $QwenVersion, $backup)
      }
      if ($forceQwenVersion) { $env:QWEN_INSTALL_VERSION = $QwenVersion }
      $installStarted = $true
      Invoke-PinnedProviderInstaller -Provider $provider
      if ($provider.Id -eq 'qwen') {
        $complete = Test-QwenRuntimeComplete
        Write-QwenInstallEvent "finished: complete=$complete"
        if (-not $complete) { throw 'The Qwen installer finished but the standalone runtime is still incomplete.' }
      }
      if ($backup) { Write-Host "Recoverable Qwen runtime backup: $backup" }
    }

    $command = Get-Command $provider.Command -ErrorAction SilentlyContinue
    if (-not $command -and -not (Test-Path -LiteralPath $provider.ExpectedPath)) {
      throw "$($provider.Name) installation finished but neither '$($provider.Command)' nor '$($provider.ExpectedPath)' is available. Open a new PowerShell window and rerun the bootstrap."
    }
    $resolved = if ($command -and $provider.Id -ne 'qwen') { $command.Source } else { $provider.ExpectedPath }
    if ($required) {
      $have = Get-ReportedProviderVersion -Path $resolved
      if ($have -ne $required) {
        Write-Host "$($provider.Name) reports '$have'; this repository qualifies exactly $required."
        Update-ProviderToExactVersion -Provider $provider -Path $resolved -Version $required
      }
    }
    if ($provider.Command -eq 'qwen') {
      # Hardening patches the live bundle even when no install ran, so take a
      # backup first and let the restore path cover a failed patch or proof.
      if (-not $backup) {
        $backup = Backup-QwenRuntime
        Write-QwenInstallEvent ("harden: backup={0}" -f $backup)
      }
      $installStarted = $true
      $hardened = Set-QwenChildEnvironmentHardening
      Write-Host "Qwen child-process credential hardening applied: $hardened"
      if ($forceQwenVersion) {
        $versionOutput = (& $provider.ExpectedPath --version 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -ne 0 -or $versionOutput -notmatch [regex]::Escape($QwenVersion.TrimStart('v'))) {
          throw "Qwen version verification failed. Expected $QwenVersion, received '$versionOutput'."
        }
      }
    }
  } catch {
    # Any failure after this run began replacing the runtime (installer,
    # completeness, version pin, hardening, verification) puts back the exact
    # runtime that was there before.
    if ($provider.Id -eq 'qwen' -and $installStarted) {
      $installError = $_.Exception.Message
      Write-QwenInstallEvent "failed: $installError"
      if (-not $backup) {
        throw "Qwen install failed and there was no prior runtime to restore: $installError"
      }
      if (-not (Restore-QwenRuntime -Backup $backup)) {
        throw "Qwen install failed ($installError) AND the previous runtime could not be restored; Qwen may be unusable. Recover it from the backup at $backup (see install-events.log)."
      }
      throw "Qwen install failed ($installError); the previous runtime was restored from $backup."
    }
    throw
  } finally {
    $env:QWEN_INSTALL_VERSION = $priorQwenVersion
    if ($qwenLock) { try { $qwenLock.ReleaseMutex() } catch { }; $qwenLock.Dispose() }
  }
  Result $provider.Name 'APPLIED' $resolved
}

$results | Format-Table -AutoSize | Out-Host
if ($results.Status -contains 'MISSING' -or $results.Status -contains 'STALE') { exit 2 }
exit 0
