$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Script = Join-Path $RepoRoot "bin\ai-gh-ssh-credentials.ps1"
$TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("ai-gh-ssh-creds-test-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $TempRoot | Out-Null

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
}

# Fake ai-gh gate. The interactive login lives in $FAKE_DEFAULT/token (stands
# in for the keyring); GH_CONFIG_DIR selects a file store instead. A token is
# valid as u2giants when GOOD, as popcre when POPCRE.
$fake = Join-Path $TempRoot 'ai-gh'
@'
#!/usr/bin/env bash
printf '%s|%s|%s\n' "$AI_GH_CALLER" "${GH_CONFIG_DIR:-default}" "$*" >> "$FAKE_DEFAULT/calls.log"
current() {
  [ -n "$GH_TOKEN" ] && { printf '%s' "$GH_TOKEN"; return; }
  if [ -n "$GH_CONFIG_DIR" ]; then
    awk '/^[^ ]/{h=($1=="github.com:")} h&&/oauth_token:/{print $2}' "$GH_CONFIG_DIR/hosts.yml" 2>/dev/null
  else
    tr -d '\r\n' < "$FAKE_DEFAULT/token" 2>/dev/null
  fi
}
case "$1 $2" in
  "api --hostname") case "$(current)" in GOOD) echo u2giants; exit 0 ;; POPCRE) echo popcre; exit 0 ;; esac; exit 1 ;;
  "auth token") t="$(current)"; [ -n "$t" ] && { echo "$t"; exit 0; }; exit 1 ;;
  "auth login") t="$(cat | tr -d '\r\n')"; [ -n "$GH_CONFIG_DIR" ] || exit 4
    printf 'github.com:\n    oauth_token: %s\n    user: u2giants\n' "$t" > "$GH_CONFIG_DIR/hosts.yml"; exit 0 ;;
  "auth setup-git") printf 'helper\n' >> "$GIT_CONFIG_GLOBAL"; exit 0 ;;
esac
exit 3
'@.Replace("`r`n", "`n") | Set-Content -LiteralPath $fake -NoNewline

function Invoke-Script([string]$Dir) {
    $env:FAKE_DEFAULT = $Dir
    $ErrorActionPreference = 'Continue'
    $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Script -GhGate $fake `
        -SshConfigDir (Join-Path $Dir 'gh-ssh') -BashRc (Join-Path $Dir 'home\.bashrc') -PowerShellProfiles (Join-Path $Dir 'ps\profile.ps1') `
        -GitConfig (Join-Path $Dir 'gitconfig') -BackupRoot (Join-Path $Dir 'backups') 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    return [pscustomobject]@{ Exit = $code; Output = ($out -join ' '); Dir = $Dir }
}

function Invoke-Case([string]$Name, [string]$Token, [string]$BashRcText = '') {
    $dir = Join-Path $TempRoot $Name
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    if ($Token) { $Token | Set-Content -LiteralPath (Join-Path $dir 'token') }
    New-Item -ItemType Directory -Force -Path (Join-Path $dir 'home') | Out-Null
    [IO.File]::WriteAllText((Join-Path $dir 'home\.bash_profile'), "test -f ~/.bashrc && . ~/.bashrc`n")
    if ($BashRcText) { [IO.File]::WriteAllText((Join-Path $dir 'home\.bashrc'), $BashRcText) }
    return Invoke-Script $dir
}

try {
    $r = Invoke-Case 'copies' 'GOOD' "case `$- in *i*) ;; *) return ;; esac`nalias ll='ls -l'`n"
    Assert-True ($r.Exit -eq 0) "working login is copied (exit $($r.Exit): $($r.Output))"
    $sshHosts = Join-Path $r.Dir 'gh-ssh\hosts.yml'
    Assert-True ((Get-Content $sshHosts -Raw) -match 'oauth_token: GOOD') 'token saved in the SSH folder'
    Assert-True ((Get-Content (Join-Path $r.Dir 'token') -Raw) -match 'GOOD') 'interactive login left in place'
    $calls = @(Get-Content (Join-Path $r.Dir 'calls.log'))
    Assert-True (@($calls | Where-Object { $_ -match 'GOOD' }).Count -eq 0) 'token never passed as an argument'
    Assert-True (@($calls | Where-Object { $_ -notmatch '^ai-gh-ssh-credentials\|' }).Count -eq 0) 'every call goes through the gate with a caller label'
    Assert-True (@($calls | Where-Object { $_ -match '\|default\|auth login' }).Count -eq 0) 'the normal gh folder is never rewritten'
    Assert-True ((Get-Content (Join-Path $r.Dir 'gitconfig') -Raw) -match 'helper') 'git pointed at gh'
    $rc = Get-Content (Join-Path $r.Dir 'home\.bashrc') -Raw
    Assert-True ($rc -match "alias ll='ls -l'") 'existing bashrc kept'
    $sshFwd = (Join-Path $r.Dir 'gh-ssh') -replace '\\', '/'
    Assert-True ($rc.Contains("[ -f '" + $sshFwd + "'/hosts.yml ]; then") -and $rc.Contains("  export GH_CONFIG_DIR='" + $sshFwd + "'")) 'bashrc points SSH sessions at the copy'
    # Real Git Bash login startup, with a non-interactive early return in .bashrc.
    $env:SSH_CONNECTION = '127.0.0.1 1 127.0.0.1 22'
    $oldHome = $env:HOME; $env:HOME = (Join-Path $r.Dir 'home').Replace('\', '/')
    $seen = & "$env:ProgramFiles\Git\bin\bash.exe" -lc 'printf %s "$GH_CONFIG_DIR"'
    $env:HOME = $oldHome
    $psSeen = & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ". '$(Join-Path $r.Dir 'ps\profile.ps1')'; `$env:GH_CONFIG_DIR"
    Remove-Item Env:SSH_CONNECTION
    $psNoSsh = & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ". '$(Join-Path $r.Dir 'ps\profile.ps1')'; [string]`$env:GH_CONFIG_DIR"
    Assert-True ($psSeen -eq (Join-Path $r.Dir 'gh-ssh')) "PowerShell profile sets GH_CONFIG_DIR in SSH sessions (got '$psSeen')"
    Assert-True (-not $psNoSsh) 'PowerShell profile leaves interactive sessions alone'
    Assert-True ($seen -eq $sshFwd) "bashrc block sets GH_CONFIG_DIR in SSH sessions (got '$seen')"
    Assert-True (@(Get-ChildItem (Join-Path $r.Dir 'backups') -Filter '.bashrc.home.*.bak').Count -eq 1) 'bashrc backed up first'
    $me = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    foreach ($p in @((Join-Path $r.Dir 'gh-ssh'), $sshHosts, (Join-Path $r.Dir 'backups'))) {
        $sids = @((Get-Acl $p).Access | ForEach-Object { $_.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value })
        Assert-True (@($sids | Where-Object { @($me, 'S-1-5-18', 'S-1-5-32-544') -notcontains $_ }).Count -eq 0) "$p readable only by this user, SYSTEM and Administrators"
    }

    $r2 = Invoke-Script $r.Dir
    Assert-True ($r2.Exit -eq 0) "rerun succeeds (exit $($r2.Exit))"
    $rc = Get-Content (Join-Path $r.Dir 'home\.bashrc') -Raw
    Assert-True (([regex]::Matches($rc, 'ai-devops gh-ssh \(managed')).Count -eq 1) 'rerun keeps one managed block'

    $env:GH_TOKEN = 'AMBIENT'; $env:GH_HOST = 'ghe.example.com'
    $r = Invoke-Case 'env-token' 'GOOD'
    Remove-Item Env:GH_TOKEN, Env:GH_HOST
    Assert-True ($r.Exit -eq 0) "ambient token variables are ignored (exit $($r.Exit): $($r.Output))"

    $r = Invoke-Case 'other-account' 'POPCRE'
    Assert-True ($r.Exit -ne 0 -and $r.Exit -ne 2) "another GitHub account is refused (exit $($r.Exit))"
    Assert-True (-not (Test-Path (Join-Path $r.Dir 'gh-ssh\hosts.yml'))) 'no other-account token written'

    $r = Invoke-Case 'dead' 'BAD'
    Assert-True ($r.Exit -eq 2) "dead login reports exit 2 (got $($r.Exit))"
    Assert-True ($r.Output -match 'gh auth login --web') 'dead login names the re-login step'

    $r = Invoke-Case 'none' ''
    Assert-True ($r.Exit -eq 2) "missing login reports exit 2 (got $($r.Exit))"

    Write-Output 'PASS test-ai-gh-ssh-credentials'
} finally {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
