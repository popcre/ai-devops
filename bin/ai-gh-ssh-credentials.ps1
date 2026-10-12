# Make GitHub CLI and Git credentials readable from SSH logons on Windows.
#
# Key-based OpenSSH logons cannot unlock the user's DPAPI master key, so the
# Windows Credential Manager ("keyring") is empty for them: gh reports the
# token invalid and Git's credential manager cannot read or store anything.
# The supported gh alternative is its own config store (hosts.yml, written by
# `gh auth login --insecure-storage`). This script moves a working keyring
# login there, locks the file to the current user and SYSTEM, and points Git
# at gh for github.com (`gh auth setup-git`), so interactive and SSH sessions
# share one credential. The token only ever travels through a pipe.
#
# Exit codes: 0 ready, 2 no working GitHub login to move (run
# `gh auth login --web --insecure-storage` in an interactive session), 1 error.
[CmdletBinding()]
param(
    [string]$GhCommand = 'gh',
    [string]$BackupRoot = (Join-Path $HOME '.ai-devops\backups\gh-ssh-credentials')
)
$ErrorActionPreference = 'Stop'

function Invoke-Gh([string[]]$Arguments, $InputText) {
    $prior = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        if ($null -ne $InputText) { $out = @($InputText | & $GhCommand @Arguments 2>$null) }
        else { $out = @(& $GhCommand @Arguments 2>$null) }
        return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $out }
    } finally { $ErrorActionPreference = $prior }
}

function Backup-File([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null
    $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
    Copy-Item -LiteralPath $Path -Destination (Join-Path $BackupRoot ("{0}.{1}.bak" -f (Split-Path -Leaf $Path), $stamp))
}

$configDir = if ($env:GH_CONFIG_DIR) { $env:GH_CONFIG_DIR } else { Join-Path $env:APPDATA 'GitHub CLI' }
$hosts = Join-Path $configDir 'hosts.yml'

function Test-FileToken {
    (Test-Path -LiteralPath $hosts) -and
        ((Get-Content -LiteralPath $hosts -Raw) -match '(?m)^\s+oauth_token:\s*\S')
}

if (-not (Test-FileToken)) {
    $login = Invoke-Gh @('api', 'user', '--jq', '.login') $null
    if ($login.ExitCode -ne 0) {
        Write-Output 'No working GitHub login to share with SSH sessions. In an interactive session run: gh auth login --web --insecure-storage'
        exit 2
    }
    Backup-File $hosts
    $token = Invoke-Gh @('auth', 'token', '--hostname', 'github.com') $null
    if ($token.ExitCode -ne 0 -or -not $token.Output) { throw 'gh auth token returned no token.' }
    $moved = Invoke-Gh @('auth', 'login', '--hostname', 'github.com', '--git-protocol', 'https', '--with-token', '--insecure-storage') ($token.Output -join '')
    $token = $null
    if ($moved.ExitCode -ne 0 -or -not (Test-FileToken)) { throw 'gh could not save the login to its config file.' }
}

# Only this user and SYSTEM may read the stored login.
$acl = & icacls $hosts /inheritance:r /grant:r "${env:USERDOMAIN}\${env:USERNAME}:F" '*S-1-5-18:F' 2>&1
if ($LASTEXITCODE -ne 0) { throw "Could not restrict access to the GitHub login file: $acl" }

$gitConfig = Join-Path $HOME '.gitconfig'
Backup-File $gitConfig
$setup = Invoke-Gh @('auth', 'setup-git', '--hostname', 'github.com') $null
if ($setup.ExitCode -ne 0) { throw 'gh auth setup-git failed.' }

$check = Invoke-Gh @('api', 'user', '--jq', '.login') $null
if ($check.ExitCode -ne 0) {
    Write-Output 'The stored GitHub login is rejected by GitHub. In an interactive session run: gh auth login --web --insecure-storage'
    exit 2
}
Write-Output "GitHub login shared with SSH sessions for $($check.Output -join '')."
exit 0
