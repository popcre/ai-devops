$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Script = Join-Path $RepoRoot "bin\ai-gh-ssh-credentials.ps1"
$TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("ai-gh-ssh-creds-test-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $TempRoot | Out-Null

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
}

# Fake ai-gh gate: keyring token lives in keyring.txt, "valid" when it equals GOOD.
$fake = Join-Path $TempRoot 'ai-gh'
@'
#!/usr/bin/env bash
cfg="$GH_CONFIG_DIR"; hosts="$cfg/hosts.yml"; keyring="$cfg/keyring.txt"
printf '%s|%s\n' "$AI_GH_CALLER" "$*" >> "$cfg/calls.log"
current() {
  [ -n "$GH_TOKEN" ] && { printf "%s" "$GH_TOKEN"; return; }
  t="$(awk '/^[^ ]/{h=($1=="github.com:")} h&&/oauth_token:/{print $2}' "$hosts" 2>/dev/null)"
  [ -n "$t" ] || t="$(cat "$keyring" 2>/dev/null | tr -d '\r\n')"
  printf '%s' "$t"
}
case "$1 $2" in
  "api --hostname") [ "$(current)" = GOOD ] && { echo u2giants; exit 0; }; exit 1 ;;
  "auth token") t="$(current)"; [ -n "$t" ] && { echo "$t"; exit 0; }; exit 1 ;;
  "auth login") t="$(cat | tr -d '\r\n')"
    printf 'github.com:\n    oauth_token: %s\n    user: u2giants\n' "$t" >> "$hosts"
    rm -f "$keyring"; exit 0 ;;
  "auth setup-git") exit 0 ;;
esac
exit 3
'@.Replace("`r`n", "`n") | Set-Content -LiteralPath $fake -NoNewline

function Invoke-Case([string]$Name, [string]$Keyring, [string]$Hosts = 'github.com:', [switch]$Broad) {
    $dir = Join-Path $TempRoot $Name
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    # Mirror a real profile folder: only this user and SYSTEM.
    $me = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    & icacls $dir /inheritance:r /grant:r "*${me}:(OI)(CI)F" '*S-1-5-18:(OI)(CI)F' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "FAIL: could not set the fixture ACL on $dir" }
    $Hosts | Set-Content -LiteralPath (Join-Path $dir 'hosts.yml')
    if ($Keyring) { $Keyring | Set-Content -LiteralPath (Join-Path $dir 'keyring.txt') }
    if ($Broad) {
        & icacls $dir /grant '*S-1-1-0:(OI)(CI)R' | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "FAIL: could not widen the fixture ACL on $dir" }
    }
    $env:GH_CONFIG_DIR = $dir
    $ErrorActionPreference = 'Continue'
    $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Script -GhGate $fake -BackupRoot (Join-Path $dir 'backups') -GitConfig (Join-Path $dir 'gitconfig') 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    return [pscustomobject]@{ Exit = $code; Output = ($out -join ' '); Dir = $dir }
}

try {
    $r = Invoke-Case 'moves' 'GOOD'
    Assert-True ($r.Exit -eq 0) "working keyring login is shared (exit $($r.Exit): $($r.Output))"
    Assert-True ((Get-Content (Join-Path $r.Dir 'hosts.yml') -Raw) -match 'oauth_token: GOOD') 'token saved in gh config'
    Assert-True (@(Get-ChildItem (Join-Path $r.Dir 'backups') -Filter 'hosts.yml.*.bak').Count -eq 1) 'hosts.yml backed up first'
    $calls = Get-Content (Join-Path $r.Dir 'calls.log') -Raw
    Assert-True ($calls -notmatch 'GOOD') 'token never passed as an argument'
    Assert-True ($calls -match 'auth setup-git') 'git pointed at gh'
    Assert-True (@((Get-Content (Join-Path $r.Dir 'calls.log')) | Where-Object { $_ -notmatch '^ai-gh-ssh-credentials\|' }).Count -eq 0) 'every call goes through the gate with a caller label'

    $r = Invoke-Case 'other-host' 'GOOD' "ghe.example.com:`n    oauth_token: OTHER`ngithub.com:"
    Assert-True ($r.Exit -eq 0) "another host's token does not skip github.com (exit $($r.Exit): $($r.Output))"
    Assert-True ((Get-Content (Join-Path $r.Dir 'hosts.yml') -Raw) -match 'oauth_token: GOOD') 'github.com token saved beside the other host'

    $r = Invoke-Case 'broad' 'GOOD' -Broad
    Assert-True ($r.Exit -ne 0 -and $r.Exit -ne 2) "a folder readable by Everyone is refused (exit $($r.Exit))"
    Assert-True ((Get-Content (Join-Path $r.Dir 'hosts.yml') -Raw) -notmatch 'oauth_token') 'no token written into a broad folder'

    $r = Invoke-Case 'dead' 'BAD'
    Assert-True ($r.Exit -eq 2) "dead login reports exit 2 (got $($r.Exit))"
    Assert-True ($r.Output -match 'insecure-storage') 'dead login names the re-login step'

    $r = Invoke-Case 'none' ''
    Assert-True ($r.Exit -eq 2) "missing login reports exit 2 (got $($r.Exit))"

    $env:GH_TOKEN = 'AMBIENT'; $env:GH_HOST = 'ghe.example.com'
    $r = Invoke-Case 'env-token' 'GOOD'
    Remove-Item Env:GH_TOKEN, Env:GH_HOST
    Assert-True ($r.Exit -eq 0) 'ambient token variables are ignored'

    Write-Output 'PASS test-ai-gh-ssh-credentials'
} finally {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
