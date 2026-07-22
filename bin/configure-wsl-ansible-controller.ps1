<# Install Ansible and its collections inside the first available Ubuntu WSL distribution. #>
[CmdletBinding()]
param(
  [string]$AnsibleRepoPath = (Join-Path $HOME 'repos\ansible'),
  [string]$AnsibleRepoUrl = 'https://github.com/u2giants/ansible.git',
  [switch]$TestOnly
)

$ErrorActionPreference = 'Stop'
if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
  Write-Host 'WSL: REBOOT_REQUIRED (wsl.exe is not available yet)'
  exit 2
}

$distros = @(& wsl.exe --list --quiet 2>$null | ForEach-Object { ($_ -replace "`0", '').Trim() } | Where-Object { $_ -match '^Ubuntu' })
if (-not $distros.Count) {
  Write-Host 'Ubuntu WSL: REBOOT_OR_FIRST_START_REQUIRED'
  exit 2
}
$distro = $distros[0]

$probe = (& wsl.exe -d $distro -u root -- sh -lc 'printf READY' 2>$null | Out-String).Trim()
if ($probe -ne 'READY') {
  Write-Host "Ubuntu WSL ($distro): FIRST_START_REQUIRED"
  exit 2
}

if (-not (Test-Path (Join-Path $AnsibleRepoPath '.git'))) {
  if ($TestOnly) { Write-Host "Ansible repo: MISSING ($AnsibleRepoPath)"; exit 2 }
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $AnsibleRepoPath) | Out-Null
  git clone $AnsibleRepoUrl $AnsibleRepoPath
  if ($LASTEXITCODE -ne 0) { throw 'Could not clone the private Ansible repo; authenticate GitHub and rerun.' }
} elseif (-not $TestOnly) {
  $dirty = git -C $AnsibleRepoPath status --porcelain
  if ($LASTEXITCODE -ne 0) { throw 'Could not inspect the Ansible checkout.' }
  if (-not $dirty) {
    git -C $AnsibleRepoPath pull --ff-only
    if ($LASTEXITCODE -ne 0) { throw 'Ansible repo fast-forward pull failed.' }
  } else { Write-Host 'Ansible repo has local changes; preserving them and skipping pull.' -ForegroundColor Yellow }
}

$linuxRepo = (& wsl.exe -d $distro -u root -- wslpath -a $AnsibleRepoPath | Out-String).Trim()
if ($TestOnly) {
  & wsl.exe -d $distro -u root -- bash -lc 'command -v ansible >/dev/null && command -v ansible-lint >/dev/null'
  if ($LASTEXITCODE -ne 0) { Write-Host "Ansible controller ($distro): DRIFT"; exit 2 }
  Write-Host "Ansible controller ($distro): COMPLIANT"
  exit 0
}

& wsl.exe -d $distro -u root -- bash -lc 'export DEBIAN_FRONTEND=noninteractive; apt-get update -y && apt-get install -y ansible ansible-lint'
if ($LASTEXITCODE -ne 0) { throw "Ansible installation failed inside $distro." }
& wsl.exe -d $distro -u root -- ansible-galaxy collection install -r "$linuxRepo/requirements.yml"
if ($LASTEXITCODE -ne 0) { throw 'Ansible collection installation failed.' }
Write-Host "Ansible controller ($distro): READY; repo=$linuxRepo"
exit 0
