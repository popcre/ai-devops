<#
.SYNOPSIS
Installs the official Windows Grok Build, Kimi Code, Qwen Code, and Google
Antigravity (Gemini) command-line tools.

Authentication deliberately remains interactive. The installers only put the
programs on this computer; each provider opens its own login on first use.

Grok has a version floor. config/provider-cli-versions.json holds the lowest
build this repository accepts (newer builds of the same major version pass), because the Grok wrappers parse that build's
JSON, stop reasons, usage keys and session behaviour. A present-but-off-policy
Grok below the floor is upgraded to it, the result is verified, and a failed
upgrade restores the previous executable. Credentials under ~/.grok are never
read, copied or backed up.
#>
[CmdletBinding()]
param(
  [switch]$TestOnly,
  [ValidateSet('grok', 'kimi', 'qwen', 'gemini')]
  [Alias('Provider')]
  [string[]]$SelectedProvider = @('grok', 'kimi', 'qwen', 'gemini'),
  [ValidatePattern('^v\d+\.\d+\.\d+$')]
  [string]$QwenVersion
)

$ErrorActionPreference = 'Stop'
$results = [Collections.Generic.List[object]]::new()

function Result([string]$Name, [string]$Status, [string]$Detail) {
  $results.Add([pscustomobject]@{ Provider=$Name; Status=$Status; Detail=$Detail })
}

function Test-QwenChildEnvironmentHardened {
  param([string]$Root = $(Join-Path $env:LOCALAPPDATA 'qwen-code\qwen-code'))
  # Read-only: true only when the one sanitizer chunk already lists the key.
  # Anything unexpected answers false, so the caller backs up before patching.
  try {
    $chunkRoot = Join-Path $Root 'lib\chunks'
    $hits = @(Get-ChildItem -LiteralPath $chunkRoot -Filter '*.js' -File -ErrorAction Stop | Where-Object {
      $text = Get-Content -Raw -LiteralPath $_.FullName
      $text.Contains('var INTERNAL_SECRET_ENV_VARS') -and $text.Contains('function sanitizeChildEnv')
    })
    if ($hits.Count -ne 1) { return $false }
    $declaration = [regex]::Match((Get-Content -Raw -LiteralPath $hits[0].FullName), 'var INTERNAL_SECRET_ENV_VARS\s*=\s*\[[\s\S]*?\];')
    return ($declaration.Success -and $declaration.Value.Contains('"BAILIAN_CODING_PLAN_API_KEY"'))
  } catch { return $false }
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
    $backup = Join-Path $backupDir ("{0}.{1}.bak" -f $candidates[0].Name, ('{0}-{1}' -f (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ'), [guid]::NewGuid().ToString('N').Substring(0,8)))
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

function Test-ProviderVersionSatisfied {
  # Mirrors bin/ai-provider-version satisfies: "exact" (default) needs the same
  # version; "minimum" accepts that version or newer within the same major, compared numerically per
  # part (issue #686: Grok auto-updates past its floor).
  param([Parameter(Mandatory)][string]$Provider, [AllowNull()][AllowEmptyString()][string]$Version)
  $required = Get-RequiredProviderVersion -Provider $Provider
  if (-not $required) { return $true }
  if ([string]::IsNullOrEmpty($Version) -or $Version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') { return $false }
  $policyPath = if ($env:AI_PROVIDER_VERSIONS_FILE) { $env:AI_PROVIDER_VERSIONS_FILE }
                else { Join-Path $PSScriptRoot '..\config\provider-cli-versions.json' }
  $mode = (Get-Content -Raw -LiteralPath $policyPath | ConvertFrom-Json).providers.$Provider.version_match
  if (-not $mode) { $mode = 'exact' }
  if ($mode -eq 'exact') { return $Version -eq $required }
  if ($mode -ne 'minimum') { throw "Unknown version_match '$mode' for $Provider" }
  # Same major version only: a new major release needs its own qualification.
  return (([version]$Version).Major -eq ([version]$required).Major) -and (([version]$Version) -ge ([version]$required))
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

function Set-TomlKey {
  # Mirrors set_toml_key in bin/install-ai-provider-clis.sh: replace KEY inside
  # [SECTION], add it to that section, or append the section. $Value is raw TOML.
  param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Section,
        [Parameter(Mandatory)][string]$Key, [Parameter(Mandatory)][string]$Value)
  [void](New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path))
  $lines = if (Test-Path -LiteralPath $Path) { @([IO.File]::ReadAllLines($Path)) } else { @() }
  $out = [Collections.Generic.List[string]]::new()
  $header = "[$Section]"; $inSection = $false; $seen = $false; $done = $false
  $keyPattern = '^\s*' + [regex]::Escape($Key) + '\s*='
  foreach ($line in $lines) {
    if ($line -match '^\s*\[') {
      if ($inSection -and -not $done) { $out.Add("$Key = $Value"); $done = $true }
      $inSection = (($line -replace '\s', '') -eq $header); if ($inSection) { $seen = $true }
      $out.Add($line); continue
    }
    if ($inSection -and $line -match $keyPattern) {
      if (-not $done) { $out.Add("$Key = $Value"); $done = $true }
      continue
    }
    $out.Add($line)
  }
  if ($inSection -and -not $done) { $out.Add("$Key = $Value"); $done = $true }
  if (-not $seen) { $out.Add(''); $out.Add($header); $out.Add("$Key = $Value") }
  $temp = "$Path.ai-devops.$PID.tmp"
  try {
    [IO.File]::WriteAllText($temp, (($out -join "`n") + "`n"), [Text.UTF8Encoding]::new($false))
    Move-Item -Force -LiteralPath $temp -Destination $Path
  } finally { if (Test-Path -LiteralPath $temp) { Remove-Item -Force -LiteralPath $temp } }
}

function Set-GrokModelLock {
  # Owner ruling 2026-09-25: Grok 4.6 only, never 4.7. Mirrors pin_grok_model in
  # bin/install-ai-provider-clis.sh. xAI launch campaigns replace the default
  # model and beat config.toml, so every known campaign naming another default
  # is marked dismissed in campaigns_state.json, then models.default and
  # allowed_models are set in config.toml. requirements.toml is unusable: Grok's
  # deployment sync deletes it on start. allowed_models with an undismissed
  # campaign refuses every session, even --model <pin>.
  param([string]$GrokHome = $(if ($env:GROK_HOME) { $env:GROK_HOME } else { Join-Path $HOME '.grok' }))
  $policyPath = if ($env:AI_PROVIDER_VERSIONS_FILE) { $env:AI_PROVIDER_VERSIONS_FILE }
                else { Join-Path $PSScriptRoot '..\config\provider-cli-versions.json' }
  $grokPolicy = (Get-Content -Raw -LiteralPath $policyPath | ConvertFrom-Json).providers.grok
  $model = $grokPolicy.model_pin
  if (-not $model) { return $null }
  if ($model -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') { throw "Malformed grok model_pin '$model' in $policyPath" }
  $ids = [Collections.Generic.List[string]]::new()
  foreach ($id in @($grokPolicy.dismiss_campaigns)) { if ($id) { $ids.Add([string]$id) } }
  $cache = Join-Path $GrokHome 'settings_cache.json'
  try {
    $settings = ((Get-Content -Raw -LiteralPath $cache -ErrorAction Stop | ConvertFrom-Json).payload | ConvertFrom-Json).settings
    foreach ($c in @($settings.campaigns)) {
      if ($c -and $c.id -and $c.models.default -and $c.models.default -ne $model) { $ids.Add([string]$c.id) }
    }
  } catch { }  # no or unreadable cache: only the policy's campaigns apply
  $statePath = Join-Path $GrokHome 'campaigns_state.json'
  [void](New-Item -ItemType Directory -Force -Path $GrokHome)
  $state = if (Test-Path -LiteralPath $statePath) { Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json } else { $null }
  if ($null -eq $state) { $state = [pscustomobject]@{} }
  foreach ($old in @($state.dismissed_ids)) { if ($old) { $ids.Add([string]$old) } }
  $dismissed = @($ids | Where-Object { $_ -match '^[A-Za-z0-9][A-Za-z0-9._-]*$' } | Sort-Object -Unique -CaseSensitive)
  $state | Add-Member -Force -NotePropertyName dismissed_ids -NotePropertyValue $dismissed
  $temp = "$statePath.ai-devops.$PID.tmp"
  try {
    [IO.File]::WriteAllText($temp, ($state | ConvertTo-Json -Compress -Depth 10), [Text.UTF8Encoding]::new($false))
    Move-Item -Force -LiteralPath $temp -Destination $statePath
  } finally { if (Test-Path -LiteralPath $temp) { Remove-Item -Force -LiteralPath $temp } }
  $config = Join-Path $GrokHome 'config.toml'
  Set-TomlKey -Path $config -Section models -Key default -Value "`"$model`""
  Set-TomlKey -Path $config -Section models -Key allowed_models -Value "[`"$model*`"]"
  return $model
}

function Update-ProviderToExactVersion {
  param([Parameter(Mandatory)]$Provider, [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Version)
  if ($Provider.Command -ne 'grok') {
    throw "No exact-version upgrade path is defined for $($Provider.Name)."
  }
  $backupDir = Join-Path $HOME '.local\state\ai-devops\provider-cli\backups'
  [void](New-Item -ItemType Directory -Force -Path $backupDir)
  $backup = Join-Path $backupDir ("{0}.{1}.bak" -f $Provider.Command, ('{0}-{1}' -f (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ'), [guid]::NewGuid().ToString('N').Substring(0,8)))
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
  $backup = Join-Path $backupRoot ("runtime-{0}" -f ('{0}-{1}' -f (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ'), [guid]::NewGuid().ToString('N').Substring(0,8)))
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
  $stamp = ('{0}-{1}' -f (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ'), [guid]::NewGuid().ToString('N').Substring(0,8))
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
  },
  [pscustomobject]@{
    Name = 'Google Antigravity CLI (Gemini)'
    Id = 'gemini'
    Command = 'agy'
    InstallUri = 'https://antigravity.google/cli/install.ps1'
    InstallerSha256 = '51c2cb4fada22ce0228da71b9506370383d6544bfebcec85fe7616a52b805344'
    ExpectedPath = (Join-Path $env:LOCALAPPDATA 'agy\bin\agy.exe')
  }
)

foreach ($providerDefinition in $providerCatalog) {
  if ($providerDefinition.Id -notin $SelectedProvider) { continue }
  $provider = $providerDefinition
  $required = Get-RequiredProviderVersion -Provider $provider.Id
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
      if (-not (Test-ProviderVersionSatisfied -Provider $provider.Command -Version $have)) { $status = 'STALE'; $detail = "$probe reports '$have', policy requires $required" }
      else { $detail = "$probe ($have; policy $required)" }
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
      if (-not (Test-ProviderVersionSatisfied -Provider $provider.Command -Version $have)) {
        Write-Host "$($provider.Name) reports '$have'; this repository's policy requires $required."
        Update-ProviderToExactVersion -Provider $provider -Path $resolved -Version $required
      }
    }
    if ($provider.Command -eq 'grok') {
      $lockedModel = Set-GrokModelLock
      if ($lockedModel) { Write-Host "Grok locked to $lockedModel (config.toml default + allowed_models; other-model campaigns dismissed)." }
    }
    if ($provider.Command -eq 'qwen') {
      # Hardening patches the live bundle even when no install ran. Only when a
      # patch is actually due, take a backup first and arm the restore path; an
      # already-hardened runtime is left untouched and needs no copy.
      if (-not $backup -and -not (Test-QwenChildEnvironmentHardened)) {
        $backup = Backup-QwenRuntime
        Write-QwenInstallEvent ("harden: backup={0}" -f $backup)
        $installStarted = $true
      }
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
