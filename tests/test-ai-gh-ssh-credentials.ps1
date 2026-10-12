$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Script = Join-Path $RepoRoot "bin\ai-gh-ssh-credentials.ps1"
$TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("ai-gh-ssh-creds-test-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $TempRoot | Out-Null

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
}

# Fake gh: keyring token lives in keyring.txt, "valid" when it equals GOOD.
$fake = Join-Path $TempRoot 'gh.ps1'
@'
$cfg = $env:GH_CONFIG_DIR
$hosts = Join-Path $cfg 'hosts.yml'
$keyring = Join-Path $cfg 'keyring.txt'
$log = Join-Path $cfg 'calls.log'
Add-Content -LiteralPath $log -Value ($args -join ' ')
function Current {
    if ((Test-Path $hosts) -and ((Get-Content $hosts -Raw) -match 'oauth_token:\s*(\S+)')) { return $Matches[1] }
    if (Test-Path $keyring) { return (Get-Content $keyring -Raw).Trim() }
    return ''
}
switch ($args[0] + ' ' + $args[1]) {
    'api user'   { if ((Current) -eq 'GOOD') { 'u2giants'; exit 0 } else { exit 1 } }
    'auth token' { $t = Current; if ($t) { $t; exit 0 } else { exit 1 } }
    'auth login' {
        $t = (@($input) -join '').Trim()
        Set-Content -LiteralPath $hosts -Value "github.com:`n    oauth_token: $t`n    user: u2giants"
        Remove-Item -LiteralPath $keyring -ErrorAction SilentlyContinue
        exit 0
    }
    'auth setup-git' { exit 0 }
}
exit 3
'@ | Set-Content -LiteralPath $fake

function Invoke-Case([string]$Name, [string]$Keyring) {
    $dir = Join-Path $TempRoot $Name
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    'github.com:' | Set-Content -LiteralPath (Join-Path $dir 'hosts.yml')
    if ($Keyring) { $Keyring | Set-Content -LiteralPath (Join-Path $dir 'keyring.txt') }
    $env:GH_CONFIG_DIR = $dir
    $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Script -GhCommand $fake -BackupRoot (Join-Path $dir 'backups')
    return [pscustomobject]@{ Exit = $LASTEXITCODE; Output = ($out -join ' '); Dir = $dir }
}

try {
    $r = Invoke-Case 'moves' 'GOOD'
    Assert-True ($r.Exit -eq 0) "working keyring login is shared (exit $($r.Exit): $($r.Output))"
    Assert-True ((Get-Content (Join-Path $r.Dir 'hosts.yml') -Raw) -match 'oauth_token: GOOD') 'token saved in gh config'
    Assert-True (@(Get-ChildItem (Join-Path $r.Dir 'backups') -Filter 'hosts.yml.*.bak').Count -eq 1) 'hosts.yml backed up first'
    $calls = Get-Content (Join-Path $r.Dir 'calls.log') -Raw
    Assert-True ($calls -notmatch 'GOOD') 'token never passed as an argument'
    Assert-True ($calls -match 'auth setup-git') 'git pointed at gh'
    $acl = (Get-Acl (Join-Path $r.Dir 'hosts.yml')).Access
    Assert-True (-not ($acl | Where-Object { $_.IdentityReference -match 'Users|Everyone|Authenticated' })) 'login file not readable by other users'

    $r = Invoke-Case 'dead' 'BAD'
    Assert-True ($r.Exit -eq 2) "dead login reports exit 2 (got $($r.Exit))"
    Assert-True ($r.Output -match 'insecure-storage') 'dead login names the re-login step'

    $r = Invoke-Case 'none' ''
    Assert-True ($r.Exit -eq 2) "missing login reports exit 2 (got $($r.Exit))"

    Write-Output 'PASS test-ai-gh-ssh-credentials'
} finally {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
