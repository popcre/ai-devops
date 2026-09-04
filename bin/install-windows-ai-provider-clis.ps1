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
param([switch]$TestOnly)

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
  $m = [regex]::Match([string]$raw, '(\d+\.\d+\.\d+)')
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
    & icacls.exe $tempDir '/inheritance:r' "/grant:r" "${currentSid}:(OI)(CI)F" '*S-1-5-18:(OI)(CI)F' | Out-Null
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

$providers = @(
  [pscustomobject]@{
    Name = 'Grok Build CLI'
    Command = 'grok'
    InstallUri = 'https://x.ai/cli/install.ps1'
    InstallerSha256 = '9e995d8d6adaa425fd52ad89b5281d6d4d9076c1835d6cc65a666ec89288d5b6'
    ExpectedPath = (Join-Path $HOME '.grok\bin\grok.exe')
  },
  [pscustomobject]@{
    Name = 'Kimi Code CLI'
    Command = 'kimi'
    InstallUri = 'https://code.kimi.com/kimi-code/install.ps1'
    InstallerSha256 = 'b6307003b603f525673ece0fb2174de2b16915a27dd0c8ed7c93d9b4d12ebe8b'
    ExpectedPath = (Join-Path $HOME '.kimi-code\bin\kimi.exe')
  },
  [pscustomobject]@{
    Name = 'Qwen Code CLI'
    Command = 'qwen'
    InstallUri = 'https://qwen-code-assets.oss-cn-hangzhou.aliyuncs.com/installation/install-qwen-standalone.ps1'
    InstallerSha256 = '901f2974d849a7366dcdbfe0fb23a6e85a97a563570e1e7aa5415a5f634da1c8'
    ExpectedPath = (Join-Path $env:LOCALAPPDATA 'qwen-code\bin\qwen.cmd')
  }
)

foreach ($provider in $providers) {
  $required = Get-RequiredProviderVersion -Provider $provider.Command
  $command = Get-Command $provider.Command -ErrorAction SilentlyContinue
  $present = [bool]$command -or (Test-Path -LiteralPath $provider.ExpectedPath)
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

  if (-not $present) {
    Write-Host "Installing $($provider.Name) from its official installer..."
    Invoke-PinnedProviderInstaller -Provider $provider
  }

  $command = Get-Command $provider.Command -ErrorAction SilentlyContinue
  if (-not $command -and -not (Test-Path -LiteralPath $provider.ExpectedPath)) {
    throw "$($provider.Name) installation finished but neither '$($provider.Command)' nor '$($provider.ExpectedPath)' is available. Open a new PowerShell window and rerun the bootstrap."
  }
  $resolved = if ($command) { $command.Source } else { $provider.ExpectedPath }
  if ($required) {
    $have = Get-ReportedProviderVersion -Path $resolved
    if ($have -ne $required) {
      Write-Host "$($provider.Name) reports '$have'; this repository qualifies exactly $required."
      Update-ProviderToExactVersion -Provider $provider -Path $resolved -Version $required
    }
  }
  if ($provider.Command -eq 'qwen') {
    $hardened = Set-QwenChildEnvironmentHardening
    Write-Host "Qwen child-process credential hardening applied: $hardened"
  }
  Result $provider.Name 'APPLIED' $resolved
}

$results | Format-Table -AutoSize | Out-Host
if ($results.Status -contains 'MISSING' -or $results.Status -contains 'STALE') { exit 2 }
exit 0
