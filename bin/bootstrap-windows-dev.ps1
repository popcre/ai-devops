<#
.SYNOPSIS
Bootstraps or updates ai-devops, applies its WinGet/DSC configuration, then
delegates secret-backed machine configuration to setup-machine.ps1.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$RepoPath = (Join-Path $HOME 'repos\ai-devops'),
  [string]$RepoUrl = 'https://github.com/u2giants/ai-devops.git',
  [string]$AnsibleRepoPath = (Join-Path $HOME 'repos\ansible'),
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
    $dirty = git -C $RepoPath status --porcelain
    if ($LASTEXITCODE -ne 0) { throw 'Could not inspect the existing ai-devops checkout.' }
    if ($dirty) {
      Add-Result 'Repository' 'PRESERVED' 'Local changes exist; skipped pull.'
    } elseif (-not $TestOnly) {
      git -C $RepoPath pull --ff-only
      if ($LASTEXITCODE -ne 0) { throw 'The ai-devops fast-forward pull failed.' }
      Add-Result 'Repository' 'OK' 'Updated from GitHub with fast-forward only.'
    } else { Add-Result 'Repository' 'OK' 'Checkout present; TestOnly skipped pull.' }
  } elseif ($TestOnly) {
    throw "Repository is absent at $RepoPath; TestOnly never clones."
  } else {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $RepoPath) | Out-Null
    git clone $RepoUrl $RepoPath
    if ($LASTEXITCODE -ne 0) { throw 'Clone failed. Authenticate GitHub first because this repository is private.' }
    Add-Result 'Repository' 'OK' 'Cloned from GitHub.'
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
    Add-Result 'Package-manager exceptions' $status 'Vercel, Trigger.dev, and Supabase CLI'
  } else {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $exceptions
    if ($LASTEXITCODE -ne 0) { throw "Package exception reconciliation failed with exit code $LASTEXITCODE." }
    Add-Result 'Package-manager exceptions' 'APPLIED' 'Vercel, Trigger.dev, and Supabase CLI'
  }

  if (-not $SkipRemoteAccess) {
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
    & $pwsh.Source -NoProfile -ExecutionPolicy Bypass -File $setup -RepoPath $RepoPath
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
