# Make GitHub CLI and Git credentials readable from SSH logons on Windows.
#
# Key-based OpenSSH logons cannot unlock the user's DPAPI master key, so the
# Windows Credential Manager ("keyring") is empty for them: gh reports the
# token invalid and Git's credential manager cannot read or store anything.
# The supported gh alternative is its own config store (hosts.yml, written by
# `gh auth login --insecure-storage`). This script moves a working keyring
# login there, after proving only this user, SYSTEM, Administrators and the
# read-only Codex sandbox group can read that folder, and points Git at gh for
# github.com (`gh auth setup-git`), so interactive and SSH sessions share one
# credential. Every GitHub CLI call goes through the shared ai-gh gate; the
# token only ever travels through a pipe.
#
# Exit codes: 0 ready, 2 no working GitHub login to move (run
# `gh auth login --web --insecure-storage` in an interactive session), 1 error.
[CmdletBinding()]
param(
    [string]$GhGate = '',
    [string]$Bash = '',
    [string]$BackupRoot = (Join-Path $HOME '.ai-devops\backups\gh-ssh-credentials'),
    [string]$GitConfig = (Join-Path $HOME '.gitconfig')
)
$ErrorActionPreference = 'Stop'

if (-not $GhGate) { $GhGate = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'ai-gh' }
if (-not $Bash) {
    $Bash = @("$env:ProgramFiles\Git\bin\bash.exe", "${env:ProgramFiles(x86)}\Git\bin\bash.exe") |
        Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
}
if (-not $Bash) { throw 'Git Bash is required to reach the shared GitHub gate.' }
$gate = $GhGate -replace '\\', '/'

function Invoke-Gate([string[]]$Arguments) {
    $prior = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $call = @('--noprofile', '--norc', '-c', 'unset GH_TOKEN GITHUB_TOKEN GH_ENTERPRISE_TOKEN GITHUB_ENTERPRISE_TOKEN GH_HOST; AI_GH_CALLER=ai-gh-ssh-credentials "$0" "$@"', $gate) + $Arguments
        $out = @(& $Bash @call 2>$null)
        return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $out }
    } finally { $ErrorActionPreference = $prior }
}

function Backup-File([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null
    # Backups may hold credentials: this user and SYSTEM only.
    $me = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    & icacls $BackupRoot /inheritance:r /grant:r "*${me}:(OI)(CI)F" '*S-1-5-18:(OI)(CI)F' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Could not make $BackupRoot private." }
    Assert-PrivateFolder $BackupRoot
    $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
    Copy-Item -LiteralPath $Path -Destination (Join-Path $BackupRoot ("{0}.{1}.bak" -f (Split-Path -Leaf $Path), $stamp))
}

# Refuse to store a token where anyone beyond the expected principals can read it.
function Assert-PrivateFolder([string]$Path) {
    $me = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $allowed = @($me, 'S-1-5-18', 'S-1-5-32-544', 'S-1-3-0')
    foreach ($rule in (Get-Acl -LiteralPath $Path).Access) {
        if ($rule.AccessControlType -ne 'Allow') { continue }
        try { $sid = $rule.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value } catch { $sid = $rule.IdentityReference.Value }
        if ($allowed -contains $sid) { continue }
        if ($rule.IdentityReference.Value -match '\\CodexSandboxUsers$') { continue }
        throw "Refusing to store the GitHub login: $($rule.IdentityReference.Value) can read $Path."
    }
}

$configDir = if ($env:GH_CONFIG_DIR) { $env:GH_CONFIG_DIR } else { Join-Path $env:APPDATA 'GitHub CLI' }
$hosts = Join-Path $configDir 'hosts.yml'

# True when the github.com section of hosts.yml holds a token.
function Test-FileToken {
    if (-not (Test-Path -LiteralPath $hosts)) { return $false }
    $inGithub = $false
    foreach ($line in Get-Content -LiteralPath $hosts) {
        if ($line -match '^(\S[^:]*):') { $inGithub = ($Matches[1] -eq 'github.com'); continue }
        if ($inGithub -and $line -match '^\s+oauth_token:\s*\S') { return $true }
    }
    return $false
}

New-Item -ItemType Directory -Force -Path $configDir | Out-Null
Assert-PrivateFolder $configDir
if (Test-Path -LiteralPath $hosts) { Assert-PrivateFolder $hosts }

if (-not (Test-FileToken)) {
    $login = Invoke-Gate @('api', '--hostname', 'github.com', 'user', '--jq', '.login')
    if ($login.ExitCode -ne 0) {
        Write-Output 'No working GitHub login to share with SSH sessions. In an interactive session run: gh auth login --web --insecure-storage'
        exit 2
    }
    Backup-File $hosts
    # The token flows gate-to-gate inside one bash pipe and never reaches PowerShell.
    $pipe = 'set -o pipefail; unset GH_TOKEN GITHUB_TOKEN GH_ENTERPRISE_TOKEN GITHUB_ENTERPRISE_TOKEN GH_HOST; export AI_GH_CALLER=ai-gh-ssh-credentials; "$0" auth token --hostname github.com | "$0" auth login --hostname github.com --git-protocol https --with-token --insecure-storage'
    $prior = $ErrorActionPreference
    try { $ErrorActionPreference = 'Continue'; & $Bash --noprofile --norc -c $pipe $gate 2>$null | Out-Null; $moved = $LASTEXITCODE }
    finally { $ErrorActionPreference = $prior }
    if ($moved -ne 0 -or -not (Test-FileToken)) { throw 'The GitHub CLI could not save the login to its config file.' }
    Assert-PrivateFolder $hosts
}

Backup-File $GitConfig
$env:GIT_CONFIG_GLOBAL = $GitConfig
$setup = Invoke-Gate @('auth', 'setup-git', '--hostname', 'github.com')
if ($setup.ExitCode -ne 0) { throw 'Pointing Git at the GitHub CLI failed.' }

$check = Invoke-Gate @('api', '--hostname', 'github.com', 'user', '--jq', '.login')
if ($check.ExitCode -ne 0) {
    Write-Output 'The stored GitHub login is rejected by GitHub. In an interactive session run: gh auth login --web --insecure-storage'
    exit 2
}
Write-Output "GitHub login shared with SSH sessions for $($check.Output -join '')."
exit 0
