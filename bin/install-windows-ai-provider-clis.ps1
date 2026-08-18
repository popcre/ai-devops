<#
.SYNOPSIS
Installs the official Windows Grok Build and Kimi Code command-line tools.

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

$providers = @(
  [pscustomobject]@{
    Name = 'Grok Build CLI'
    Command = 'grok'
    InstallUri = 'https://x.ai/cli/install.ps1'
    ExpectedPath = (Join-Path $HOME '.grok\bin\grok.exe')
  },
  [pscustomobject]@{
    Name = 'Kimi Code CLI'
    Command = 'kimi'
    InstallUri = 'https://code.kimi.com/kimi-code/install.ps1'
    ExpectedPath = (Join-Path $HOME '.kimi-code\bin\kimi.exe')
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
    $installer = Invoke-RestMethod -Uri $provider.InstallUri
    if ([string]::IsNullOrWhiteSpace($installer)) { throw "$($provider.Name) installer download was empty." }
    Invoke-Expression $installer
  }

  $command = Get-Command $provider.Command -ErrorAction SilentlyContinue
  if (-not $command -and -not (Test-Path -LiteralPath $provider.ExpectedPath)) {
    throw "$($provider.Name) installation finished but neither '$($provider.Command)' nor '$($provider.ExpectedPath)' is available. Open a new PowerShell window and rerun the bootstrap."
  }
  $resolved = if ($command) { $command.Source } else { $provider.ExpectedPath }
  Result $provider.Name 'APPLIED' $resolved
}

$results | Format-Table -AutoSize | Out-Host
if ($results.Status -contains 'MISSING') { exit 2 }
exit 0
