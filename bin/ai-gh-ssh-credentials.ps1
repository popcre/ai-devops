# Give SSH logons on Windows their own copy of the GitHub CLI login.
#
# Key-based OpenSSH logons cannot unlock the user's DPAPI master key, so the
# Windows Credential Manager ("keyring") is empty for them: gh reports the
# token invalid and Git's credential manager cannot read or store anything.
# This script copies the working interactive login into a private gh config
# folder (gh's supported `--insecure-storage` file store) that only this user,
# SYSTEM and Administrators can read, and adds a managed ~/.bashrc block that
# points gh at that folder only inside SSH sessions. The normal gh folder, the
# keyring and the Codex sandbox's read-only access to the normal folder stay
# untouched. Git is pointed at gh for github.com (`gh auth setup-git`), so Git
# uses the keyring interactively and the private copy over SSH. Every GitHub
# CLI call goes through the shared ai-gh gate; the token only travels through
# a pipe inside one bash process.
#
# Run it from an interactive session. Exit codes: 0 ready, 2 no working
# interactive GitHub login to copy (run `gh auth login --web` interactively), 1 error.
[CmdletBinding()]
param(
    [string]$ExpectedLogin = 'u2giants',
    [string]$GhGate = '',
    [string]$Bash = '',
    # Under the profile root: packaged desktop apps virtualize AppData writes,
    # which would hide the folder from SSH logons.
    [string]$SshConfigDir = (Join-Path $HOME '.ai-devops\gh-ssh'),
    [string]$BashRc = (Join-Path $HOME '.bashrc'),
    [string]$GitConfig = (Join-Path $HOME '.gitconfig'),
    [string]$BackupRoot = (Join-Path $HOME '.ai-devops\backups\gh-ssh-credentials')
)
$ErrorActionPreference = 'Stop'

if (-not $GhGate) { $GhGate = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'ai-gh' }
if (-not $Bash) {
    $Bash = @("$env:ProgramFiles\Git\bin\bash.exe", "${env:ProgramFiles(x86)}\Git\bin\bash.exe") |
        Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
}
if (-not $Bash) { throw 'Git Bash is required to reach the shared GitHub gate.' }
$gate = $GhGate -replace '\\', '/'
$sshDir = $SshConfigDir -replace '\\', '/'
$gitCfg = $GitConfig -replace '\\', '/'
$me = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value

# Run the gate in bash ($0 gate, $1 SSH folder, $2 Git config); ambient token
# and host settings never choose the account.
function Invoke-Gate([string]$Script) {
    $prior = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $body = 'unset GH_TOKEN GITHUB_TOKEN GH_ENTERPRISE_TOKEN GITHUB_ENTERPRISE_TOKEN GH_HOST GH_CONFIG_DIR; export AI_GH_CALLER=ai-gh-ssh-credentials; set -o pipefail; ' + $Script
        $out = @(& $Bash --noprofile --norc -c $body $gate $sshDir $gitCfg 2>$null)
        return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = ($out -join '') }
    } finally { $ErrorActionPreference = $prior }
}

function Set-PrivateAcl([string]$Path) {
    & icacls $Path /inheritance:r /grant:r "*${me}:(OI)(CI)F" '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Could not make $Path private." }
    foreach ($rule in (Get-Acl -LiteralPath $Path).Access) {
        $sid = $rule.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value
        if (@($me, 'S-1-5-18', 'S-1-5-32-544') -notcontains $sid) { throw "Refusing to store the GitHub login: $($rule.IdentityReference.Value) can read $Path." }
    }
}

function Backup-File([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null
    Set-PrivateAcl $BackupRoot
    $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
    Copy-Item -LiteralPath $Path -Destination (Join-Path $BackupRoot ("{0}.{1}.bak" -f (Split-Path -Leaf $Path), $stamp))
}

$login = Invoke-Gate '"$0" api --hostname github.com user --jq .login'
if ($login.ExitCode -ne 0) {
    Write-Output 'No working interactive GitHub login to copy for SSH sessions. In an interactive session run: gh auth login --web'
    exit 2
}
if ($login.Output -ne $ExpectedLogin) { throw "Refusing to share the GitHub login for $($login.Output); expected $ExpectedLogin." }

# Private folder first, so the token never lands somewhere readable by others.
New-Item -ItemType Directory -Force -Path $SshConfigDir | Out-Null
Set-PrivateAcl $SshConfigDir
Backup-File (Join-Path $SshConfigDir 'hosts.yml')
$copy = Invoke-Gate '"$0" auth token --hostname github.com | GH_CONFIG_DIR="$1" "$0" auth login --hostname github.com --git-protocol https --with-token --insecure-storage'
if ($copy.ExitCode -ne 0) { throw 'The GitHub CLI could not save the SSH copy of the login.' }
Set-PrivateAcl $SshConfigDir

$check = Invoke-Gate 'GH_CONFIG_DIR="$1" "$0" api --hostname github.com user --jq .login'
if ($check.ExitCode -ne 0 -or $check.Output -ne $ExpectedLogin) { throw "The SSH copy of the GitHub login does not work (got '$($check.Output)')." }

# Managed ~/.bashrc block: SSH sessions only.
$begin = '# >>> ai-devops gh-ssh (managed by bin/ai-gh-ssh-credentials.ps1) >>>'
$end = '# <<< ai-devops gh-ssh <<<'
$block = @(
    $begin,
    ('if [ -n "${SSH_CONNECTION:-}" ] && [ -f "' + $sshDir + '/hosts.yml" ]; then'),
    ('  export GH_CONFIG_DIR="' + $sshDir + '"'),
    'fi',
    $end
) -join "`n"
$current = if (Test-Path -LiteralPath $BashRc) { [IO.File]::ReadAllText($BashRc) } else { '' }
$pattern = '(?s)' + [regex]::Escape($begin) + '.*?' + [regex]::Escape($end)
if ($current -match $pattern) {
    $updated = [regex]::Replace($current, $pattern, $block.Replace('$', '$$'))
} else {
    $sep = if ($current) { "`n`n" } else { '' }
    $updated = $current.TrimEnd("`r", "`n") + $sep + $block + "`n"
}
if ($updated -ne $current) {
    Backup-File $BashRc
    [IO.File]::WriteAllText($BashRc, $updated, (New-Object Text.UTF8Encoding $false))
}

Backup-File $GitConfig
$setup = Invoke-Gate 'GIT_CONFIG_GLOBAL="$2" "$0" auth setup-git --hostname github.com'
if ($setup.ExitCode -ne 0) { throw 'Pointing Git at the GitHub CLI failed.' }

Write-Output "GitHub login for $ExpectedLogin copied for SSH sessions."
exit 0
