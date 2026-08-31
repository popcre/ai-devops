<#
.SYNOPSIS
Bootstraps or updates ai-devops, applies its WinGet/DSC configuration, then
delegates secret-backed machine configuration to setup-machine.ps1.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$RepoPath = 'C:\repos\ai-devops',
  [string]$RepoUrl = 'https://github.com/popcre/ai-devops.git',
  [string]$AnsibleRepoPath = 'C:\repos\ansible',
  [string]$AnsibleRepoUrl = 'https://github.com/u2giants/ansible.git',
  [switch]$SkipMachineSetup,
  [switch]$SkipRemoteAccess,
  [switch]$SkipAnsibleController,
  [switch]$TestOnly
)

$ErrorActionPreference = 'Stop'
$results = [Collections.Generic.List[object]]::new()
function Add-Result([string]$Stage, [string]$Status, [string]$Detail) {
  $results.Add([pscustomobject]@{ Stage=$Stage; Status=$Status; Detail=$Detail })
}
function Refresh-Path {
  $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
    [Environment]::GetEnvironmentVariable('Path','User')
}
. (Join-Path $PSScriptRoot 'repo-identity.ps1')
function Get-CanonicalRemote([string]$Url) { return (Get-AiDevOpsCanonicalRemote -Url $Url) }
function Invoke-GitCommand {
  param([string[]]$Arguments)

  # Windows PowerShell 5.1 can promote successful Git progress from native
  # stderr to NativeCommandError while ErrorActionPreference is Stop. Preserve
  # the diagnostics, but make Git's real exit code the failure authority.
  $priorPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    $output = @(& git @Arguments)
    $script:LastGitExitCode = $LASTEXITCODE
    return $output
  } finally {
    $ErrorActionPreference = $priorPreference
  }
}
function Assert-ReadyRepository([string]$Path) {
  $dirty = Invoke-GitCommand @('-C', $Path, 'status', '--porcelain')
  if ($script:LastGitExitCode -ne 0) { throw 'Could not inspect the existing ai-devops checkout.' }
  if ($dirty) { throw 'The ai-devops checkout has local changes. Preserve or commit them before bootstrap.' }

  $origin = Invoke-GitCommand @('-C', $Path, 'remote', 'get-url', 'origin')
  if ($script:LastGitExitCode -ne 0) { throw 'Could not read the ai-devops origin remote.' }
  Assert-AiDevOpsRepoIdentity -Key 'ai-devops' -Identity (Get-CanonicalRemote $origin) `
    -Message "The ai-devops origin is not canonical: $origin"

  $branch = Invoke-GitCommand @('-C', $Path, 'branch', '--show-current')
  if ($script:LastGitExitCode -ne 0) { throw 'Could not read the ai-devops branch.' }
  if ($branch.Trim() -ne 'main') { throw "The ai-devops checkout must already be on main; found '$branch'." }

  Invoke-GitCommand @('-C', $Path, 'fetch', 'origin', 'main') | Out-Host
  if ($script:LastGitExitCode -ne 0) { throw 'The ai-devops fetch of origin/main failed.' }
  $head = Invoke-GitCommand @('-C', $Path, 'rev-parse', 'HEAD')
  if ($script:LastGitExitCode -ne 0) { throw 'Could not resolve the ai-devops HEAD.' }
  $remoteHead = Invoke-GitCommand @('-C', $Path, 'rev-parse', 'origin/main')
  if ($script:LastGitExitCode -ne 0) { throw 'Could not resolve ai-devops origin/main.' }
  if ($head.Trim() -ne $remoteHead.Trim()) {
    if ($TestOnly) { throw 'The ai-devops checkout is not exactly equal to origin/main; TestOnly will not update it.' }
    $counts = Invoke-GitCommand @('-C', $Path, 'rev-list', '--left-right', '--count', 'HEAD...origin/main')
    if ($script:LastGitExitCode -ne 0) { throw 'Could not compare ai-devops with origin/main.' }
    $parts = @($counts -split '\s+') | Where-Object { $_ }
    if ($parts.Count -ne 2 -or [int]$parts[0] -ne 0) {
      throw 'The ai-devops checkout is ahead of or diverged from origin/main; refusing machine changes.'
    }
    Invoke-GitCommand @('-C', $Path, 'merge', '--ff-only', 'origin/main') | Out-Host
    if ($script:LastGitExitCode -ne 0) { throw 'The ai-devops fast-forward update failed.' }
    $head = Invoke-GitCommand @('-C', $Path, 'rev-parse', 'HEAD')
    if ($script:LastGitExitCode -ne 0) { throw 'Could not resolve updated ai-devops HEAD.' }
    if ($head.Trim() -ne $remoteHead.Trim()) { throw 'The updated checkout is not exactly equal to origin/main.' }
  }
  return $head.Trim()
}

$principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  $elevatedArgs = @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"",
    '-RepoPath', "`"$RepoPath`"", '-RepoUrl', "`"$RepoUrl`"",
    '-AnsibleRepoPath', "`"$AnsibleRepoPath`"", '-AnsibleRepoUrl', "`"$AnsibleRepoUrl`""
  )
  foreach ($switchName in @('SkipMachineSetup','SkipRemoteAccess','SkipAnsibleController','TestOnly')) {
    if ((Get-Variable $switchName -ValueOnly)) { $elevatedArgs += "-$switchName" }
  }
  Write-Host 'Requesting Administrator permission for Windows provisioning...' -ForegroundColor Yellow
  $process = Start-Process powershell.exe -Verb RunAs -Wait -PassThru -ArgumentList $elevatedArgs
  exit $process.ExitCode
}

try {
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "WinGet is missing. Install or update 'App Installer' from Microsoft Store, then rerun."
  }
  Add-Result 'Prerequisite' 'OK' (winget --version)

  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    if ($TestOnly) { throw 'Git is missing; TestOnly never installs software.' }
    winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) { throw "Git installation failed with exit code $LASTEXITCODE." }
    Refresh-Path
  }

  if (Test-Path (Join-Path $RepoPath '.git')) {
    $sourceSha = Assert-ReadyRepository $RepoPath
    Add-Result 'Repository' 'OK' "Canonical clean main equals origin/main at $sourceSha."
  } elseif ($TestOnly) {
    throw "Repository is absent at $RepoPath; TestOnly never clones."
  } else {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $RepoPath) | Out-Null
    Assert-AiDevOpsRepoIdentity -Key 'ai-devops' -Identity (Get-CanonicalRemote $RepoUrl) `
      -Message "RepoUrl is not the canonical ai-devops repository: $RepoUrl"
    Invoke-GitCommand @('clone', '--branch', 'main', '--single-branch', $RepoUrl, $RepoPath) | Out-Host
    if ($script:LastGitExitCode -ne 0) { throw 'Clone failed. Verify network access to the public ai-devops repository.' }
    $sourceSha = Assert-ReadyRepository $RepoPath
    Add-Result 'Repository' 'OK' "Cloned canonical main at $sourceSha."
  }

  $configuration = Join-Path $RepoPath '.config\configuration.winget'
  if (-not (Test-Path $configuration)) { throw "Missing WinGet configuration: $configuration" }
  winget configure validate -f $configuration
  if ($LASTEXITCODE -ne 0) { throw 'WinGet Configuration validation failed.' }
  Add-Result 'WinGet configuration' 'VALID' $configuration

  if ($TestOnly) {
    winget configure test -f $configuration --accept-configuration-agreements --disable-interactivity
    $state = if ($LASTEXITCODE -eq 0) { 'COMPLIANT' } else { 'DRIFT' }
    Add-Result 'Desired state' $state "winget configure test exit code $LASTEXITCODE"
  } else {
    winget configure -f $configuration --accept-configuration-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) { throw "WinGet Configuration failed with exit code $LASTEXITCODE." }
    Add-Result 'Desired state' 'APPLIED' 'Packages updated and Windows settings reconciled.'
    Refresh-Path
  }

  $exceptions = Join-Path $RepoPath 'bin\reconcile-windows-package-exceptions.ps1'
  if ($TestOnly) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $exceptions -TestOnly
    $status = if ($LASTEXITCODE -eq 0) { 'COMPLIANT' } else { 'DRIFT' }
    Add-Result 'Package-manager exceptions' $status 'Vercel, Trigger.dev, Railway, ast-grep, and Supabase CLI'
  } else {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $exceptions
    if ($LASTEXITCODE -ne 0) { throw "Package exception reconciliation failed with exit code $LASTEXITCODE." }
    Add-Result 'Package-manager exceptions' 'APPLIED' 'Vercel, Trigger.dev, Railway, ast-grep, and Supabase CLI'
  }

  $providerClis = Join-Path $RepoPath 'bin\install-windows-ai-provider-clis.ps1'
  if (-not (Test-Path -LiteralPath $providerClis)) { throw "Missing AI provider installer: $providerClis" }
  $providerArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$providerClis)
  if ($TestOnly) { $providerArgs += '-TestOnly' }
  & powershell.exe @providerArgs
  if ($LASTEXITCODE -eq 0) {
    Add-Result 'Grok and Kimi CLIs' $(if ($TestOnly) { 'COMPLIANT' } else { 'APPLIED' }) 'Official Grok Build and Kimi Code installers'
  } elseif ($LASTEXITCODE -eq 2 -and $TestOnly) {
    Add-Result 'Grok and Kimi CLIs' 'DRIFT' 'One or both provider CLIs are missing.'
  } else { throw "Grok/Kimi CLI setup failed with exit code $LASTEXITCODE." }

  if (-not $SkipRemoteAccess) {
    if (-not $TestOnly) {
      $gitBash = 'C:\Program Files\Git\bin\bash.exe'
      $privateConfig = Join-Path $RepoPath 'bin\ai-private-config'
      & $gitBash $privateConfig sync | Out-Null
      if ($LASTEXITCODE -ne 0) { throw 'Protected configuration sync failed. Authenticate GitHub CLI for the private restore inputs.' }
    }
    $remoteAccess = Join-Path $RepoPath 'bin\configure-windows-bootstrap-access.ps1'
    $remoteArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$remoteAccess,'-RepoPath',$RepoPath)
    if ($TestOnly) { $remoteArgs += '-TestOnly' }
    & powershell.exe @remoteArgs
    if ($LASTEXITCODE -eq 0) { Add-Result 'Tailscale/OpenSSH bootstrap' 'OK' 'Key-only SSH on the Tailscale address; WinRM disabled.' }
    elseif ($LASTEXITCODE -eq 2) { Add-Result 'Tailscale/OpenSSH bootstrap' 'DRIFT' 'Authentication or OpenSSH setup still needs completion; rerun the same bootstrap.' }
    else { throw "Tailscale/OpenSSH bootstrap failed with exit code $LASTEXITCODE." }
  } else { Add-Result 'Tailscale/OpenSSH bootstrap' 'SKIPPED' 'SkipRemoteAccess' }

  if (-not $SkipAnsibleController) {
    $ansibleController = Join-Path $RepoPath 'bin\configure-wsl-ansible-controller.ps1'
    $ansibleArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$ansibleController,
      '-AnsibleRepoPath',$AnsibleRepoPath,'-AnsibleRepoUrl',$AnsibleRepoUrl)
    if ($TestOnly) { $ansibleArgs += '-TestOnly' }
    & powershell.exe @ansibleArgs
    if ($LASTEXITCODE -eq 0) { Add-Result 'WSL Ansible controller' 'OK' 'Ubuntu, Ansible, ansible-lint, collections, and repo are ready.' }
    elseif ($LASTEXITCODE -eq 2) { Add-Result 'WSL Ansible controller' 'DRIFT' 'A reboot/Ubuntu initialization or rerun is required.' }
    else { throw "WSL Ansible controller setup failed with exit code $LASTEXITCODE." }
  } else { Add-Result 'WSL Ansible controller' 'SKIPPED' 'SkipAnsibleController' }

  if (-not $SkipMachineSetup -and -not $TestOnly) {
    $setup = Join-Path $RepoPath 'bin\setup-machine.ps1'
    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    if (-not $pwsh) { throw 'PowerShell 7 was installed but is not visible yet. Open a new terminal and rerun.' }
    & $pwsh.Source -NoProfile -ExecutionPolicy Bypass -File $setup -RepoPath $RepoPath -SkipPackageExceptionReconcile
    if ($LASTEXITCODE -ne 0) { throw "AI DevOps machine setup failed with exit code $LASTEXITCODE." }
    Add-Result 'AI DevOps configuration' 'OK' 'Skills, managed dotfiles, SSH, MCPs, and runtime 1Password references reconciled.'
  } else {
    Add-Result 'AI DevOps configuration' 'SKIPPED' $(if ($TestOnly) { 'TestOnly' } else { 'SkipMachineSetup' })
  }
} catch {
  Add-Result 'Setup' 'FAILED' $_.Exception.Message
  $results | Format-Table -AutoSize | Out-Host
  exit 1
}

$results | Format-Table -AutoSize | Out-Host
if ($results.Status -contains 'DRIFT') { exit 2 }
exit 0
