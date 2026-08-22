<#
.SYNOPSIS
Installs the official Windows Grok Build, Kimi Code, and Qwen Code command-line tools.

Authentication deliberately remains interactive. The installers only put the
programs on this computer; each provider opens its own login on first use.
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
  $command = Get-Command $provider.Command -ErrorAction SilentlyContinue
  $present = [bool]$command -or (Test-Path -LiteralPath $provider.ExpectedPath)
  if ($TestOnly) {
    Result $provider.Name $(if ($present) { 'OK' } else { 'MISSING' }) $(if ($command) { $command.Source } else { $provider.ExpectedPath })
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
  if ($provider.Command -eq 'qwen') {
    $hardened = Set-QwenChildEnvironmentHardening
    Write-Host "Qwen child-process credential hardening applied: $hardened"
  }
  Result $provider.Name 'APPLIED' $resolved
}

$results | Format-Table -AutoSize | Out-Host
if ($results.Status -contains 'MISSING') { exit 2 }
exit 0
