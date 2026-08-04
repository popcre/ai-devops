<#
.SYNOPSIS
  Install the pinned OpenCode GLM server on Windows so `ai-glm` works locally.

.DESCRIPTION
  Windows equivalent of bin/setup-opencode-glm.sh. Idempotent; safe to re-run.

    1. Installs the exact OpenCode version from config/opencode/version into a
       private prefix (never a global npm install, never "latest").
    2. Copies the canonical OpenCode config + agents into an isolated config home.
    3. Generates a random loopback server password if one does not exist.
    4. Installs a launcher that resolves the Z.ai key from 1Password at exec time.
    5. Registers a Scheduled Task that starts the server at logon and starts it now.

  There is no systemd on Windows, so a Scheduled Task takes its place. The launcher
  itself is the SAME bash script used on Ubuntu, run through Git Bash, so there is
  one implementation of the security-critical logic rather than two that can drift.

  `ai-glm` is a bash script and runs under Git Bash. Git for Windows and jq are
  required; this script checks for both and tells you exactly what to install.

.NOTES
  Run as your normal user. Do NOT run elevated: everything lands in your profile.
#>
[CmdletBinding()]
param(
  [string]$RepoPath = $(if ($env:AI_DEVOPS_HOME) { $env:AI_DEVOPS_HOME } else { "C:\repos\ai-devops" }),
  [int]$Port = 4096
)

$ErrorActionPreference = 'Stop'
function Step($m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "[ OK ] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Die($m)  { Write-Host "[FAIL] $m" -ForegroundColor Red; exit 1 }

# HOME on this machine must be the local profile. A roaming Z: home sends the whole
# install to a network drive that nothing reads back. (This has bitten before.)
$HomeDir = $env:USERPROFILE
if (-not $HomeDir) { Die "USERPROFILE is not set." }

$CfgDir  = Join-Path $HomeDir ".config\ai-devops"
$OcHome  = Join-Path $CfgDir  "opencode"
$OcXdg   = Join-Path $CfgDir  "opencode-xdg"
$OcConf  = Join-Path $OcXdg   "opencode"
$LibRoot = Join-Path $HomeDir ".local\lib\ai-devops\opencode"
$BinDir  = Join-Path $HomeDir ".local\bin"
$StateDir= Join-Path $HomeDir ".local\state\ai-devops\glm"

if (-not (Test-Path -LiteralPath $RepoPath)) { Die "ai-devops repo not found at $RepoPath. Pass -RepoPath or set AI_DEVOPS_HOME." }

$VersionFile = Join-Path $RepoPath "config\opencode\version"
if (-not (Test-Path -LiteralPath $VersionFile)) { Die "missing $VersionFile" }
$Version = (Get-Content -Raw -LiteralPath $VersionFile).Trim()
if (-not $Version) { Die "config/opencode/version is empty" }

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------
Step "Checking prerequisites"

# Install anything missing rather than telling a non-programmer to go and do it.
function Ensure-Winget($id, $name) {
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Die "$name is missing and winget is unavailable. Install $name, then re-run this script."
  }
  Step "Installing $name via winget"
  winget install --id $id -e --source winget --accept-package-agreements --accept-source-agreements | Out-Null
  # winget updates the stored PATH, not this session's copy.
  $env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
              [Environment]::GetEnvironmentVariable("Path","User")
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Ensure-Winget "Git.Git" "Git for Windows" }
if (-not (Get-Command node -ErrorAction SilentlyContinue) -or
    -not (Get-Command npm  -ErrorAction SilentlyContinue)) { Ensure-Winget "OpenJS.NodeJS.LTS" "Node.js LTS" }
if (-not (Get-Command op   -ErrorAction SilentlyContinue)) { Ensure-Winget "AgileBits.1Password.CLI" "1Password CLI" }
if (-not (Get-Command jq   -ErrorAction SilentlyContinue)) { Ensure-Winget "jqlang.jq" "jq" }

foreach ($t in @('npm','node','op','git')) {
  if (-not (Get-Command $t -ErrorAction SilentlyContinue)) {
    Die "$t is still missing after the install attempt. Close and reopen this window, then re-run."
  }
}
$GitBash = $null
foreach ($c in @("C:\Program Files\Git\bin\bash.exe", "C:\Program Files (x86)\Git\bin\bash.exe",
                 (Join-Path $env:LOCALAPPDATA "Programs\Git\bin\bash.exe"))) {
  if (Test-Path -LiteralPath $c) { $GitBash = $c; break }
}
if (-not $GitBash) { Die "Git Bash still not found after installing Git. Close and reopen this window, then re-run." }
& $GitBash -lc "command -v jq" *>$null
if ($LASTEXITCODE -ne 0) {
  Die "jq is installed but Git Bash cannot see it. Close and reopen this window, then re-run."
}
Ok "git, node, npm, op, Git Bash and jq present"

# ---------------------------------------------------------------------------
# 1. Pinned OpenCode binary
# ---------------------------------------------------------------------------
$Prefix = Join-Path $LibRoot $Version
$Binary = Join-Path $Prefix "node_modules\opencode-ai\bin\opencode.exe"
if (-not (Test-Path -LiteralPath $Binary)) {
  Step "Installing opencode-ai@$Version into $Prefix"
  New-Item -ItemType Directory -Force -Path $Prefix | Out-Null
  & npm install --prefix $Prefix "opencode-ai@$Version" --no-audit --no-fund | Out-Null
  if (-not (Test-Path -LiteralPath $Binary)) {
    # npm's allow-scripts gate blocks the postinstall that materializes the platform
    # binary, so run it explicitly rather than hoping npm did it.
    Step "Running opencode postinstall to materialize the platform binary"
    & node (Join-Path $Prefix "node_modules\opencode-ai\postinstall.mjs")
  }
  if (-not (Test-Path -LiteralPath $Binary)) { Die "OpenCode binary missing after install: $Binary" }
} else {
  Ok "opencode-ai@$Version already installed"
}
$Actual = (& $Binary --version | Select-Object -Last 1).Trim()
if ($Actual -ne $Version) { Die "pinned version is $Version but the installed binary reports '$Actual'" }
Ok "OpenCode $Version verified"

# ---------------------------------------------------------------------------
# 2. Canonical config + agents
#
# INTENTIONAL force-copy, exactly as on Ubuntu: the agents' `tools:` map is the only
# working read-only enforcement in OpenCode, so the repo copy must always win.
# ---------------------------------------------------------------------------
Step "Installing canonical OpenCode config into $OcConf"
foreach ($d in @($OcConf, (Join-Path $OcConf "agent"), $OcHome, $StateDir, $BinDir,
                 (Join-Path $StateDir "sessions"), (Join-Path $StateDir "locks"),
                 (Join-Path $StateDir "wt"), (Join-Path $StateDir "logs"))) {
  New-Item -ItemType Directory -Force -Path $d | Out-Null
}
Copy-Item -Force (Join-Path $RepoPath "config\opencode\opencode.json") (Join-Path $OcConf "opencode.json")
Remove-Item -Force (Join-Path $OcConf "agent\*.md") -ErrorAction SilentlyContinue
Copy-Item -Force (Join-Path $RepoPath "config\opencode\agent\*.md") (Join-Path $OcConf "agent\")
Set-Content -NoNewline -Path (Join-Path $OcHome "installed-version") -Value $Version

# ---------------------------------------------------------------------------
# 3. Loopback server password
# ---------------------------------------------------------------------------
$PwFile = Join-Path $OcHome "server-password"
if (-not (Test-Path -LiteralPath $PwFile) -or -not (Get-Content -Raw -LiteralPath $PwFile).Trim()) {
  Step "Generating loopback server password"
  $bytes = New-Object byte[] 24
  [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
  $pw = [Convert]::ToBase64String($bytes) -replace '[^A-Za-z0-9]',''
  Set-Content -NoNewline -Path $PwFile -Value $pw
}
# Restrict to the current user only (the NTFS equivalent of chmod 600).
$acl = Get-Acl -LiteralPath $PwFile
$acl.SetAccessRuleProtection($true, $false)
$acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) | Out-Null }
$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
  "$env:USERDOMAIN\$env:USERNAME", 'FullControl', 'Allow')))
Set-Acl -LiteralPath $PwFile -AclObject $acl
Ok "Server password stored, current user only"

# ---------------------------------------------------------------------------
# 4. Launcher - the SAME bash launcher logic as Ubuntu, run through Git Bash
# ---------------------------------------------------------------------------
Step "Installing the GLM server launcher"
$LaunchSh = Join-Path $BinDir "opencode-glm-launch"
function ConvertTo-BashPath($p) { "/" + ($p -replace '\\','/' -replace '^([A-Za-z]):','$1') }
$binaryBash = ConvertTo-BashPath $Binary
$homeBash   = ConvertTo-BashPath $HomeDir
$cfgBash    = ConvertTo-BashPath $CfgDir
@"
#!/usr/bin/env bash
# Managed by ai-devops setup-opencode-glm.ps1 (Windows).
# Scheduled Task -> Git Bash -> this launcher -> op run -> opencode serve.
# The Z.ai key never touches a task definition, an argv, or a file at rest.
set -euo pipefail
# Git Bash \$HOME is NOT reliably the Windows profile: with a roaming profile it can be a
# network drive (Z:), and then every path below points somewhere nothing was installed.
# PowerShell knows the real profile, so it is baked in here rather than resolved at runtime.
export HOME="$homeBash"
CFG_DIR="`${AI_DEVOPS_CONFIG_DIR:-$cfgBash}"
TOKEN_FILE="`$CFG_DIR/op-service-account"
MCP_ENV="`$CFG_DIR/mcp.env"
OC_HOME="`$CFG_DIR/opencode"

export XDG_CONFIG_HOME="`$CFG_DIR/opencode-xdg"
export XDG_DATA_HOME="`$HOME/.local/share/ai-devops/opencode"
export XDG_STATE_HOME="`$HOME/.local/state/ai-devops/opencode"
export XDG_CACHE_HOME="`$HOME/.cache/ai-devops/opencode"
mkdir -p "`$XDG_DATA_HOME" "`$XDG_STATE_HOME" "`$XDG_CACHE_HOME"

if [ -z "`${ZAI_API_KEY:-}" ]; then
  # Loud-failure guard against an unbounded re-exec loop when the op:// reference
  # resolves to a blank field (op returns "" with exit 0).
  if [ -n "`${AI_GLM_LAUNCH_REEXEC:-}" ]; then
    echo "FATAL: ZAI_API_KEY resolved EMPTY from `$MCP_ENV after 'op run'." >&2
    exit 1
  fi
  command -v op >/dev/null 2>&1 || { echo "FATAL: 1Password CLI (op) not found." >&2; exit 1; }
  [ -s "`$TOKEN_FILE" ] || { echo "FATAL: missing `$TOKEN_FILE" >&2; exit 1; }
  [ -f "`$MCP_ENV" ]    || { echo "FATAL: missing `$MCP_ENV" >&2; exit 1; }
  OP_SERVICE_ACCOUNT_TOKEN="`$(<"`$TOKEN_FILE")"
  export OP_SERVICE_ACCOUNT_TOKEN AI_GLM_LAUNCH_REEXEC=1
  exec op run --env-file "`$MCP_ENV" -- "`$0" "`$@"
fi

export ZHIPU_API_KEY="`$ZAI_API_KEY"
unset ZAI_API_KEY
export OPENCODE_SERVER_USERNAME="`${OPENCODE_SERVER_USERNAME:-opencode}"
OPENCODE_SERVER_PASSWORD="`$(<"`$OC_HOME/server-password")"
export OPENCODE_SERVER_PASSWORD
[ -n "`$OPENCODE_SERVER_PASSWORD" ] || { echo "FATAL: empty server password." >&2; exit 1; }

exec "$binaryBash" serve --hostname 127.0.0.1 --port "`${AI_GLM_PORT:-$Port}"
"@ | Set-Content -NoNewline -Encoding ASCII -Path $LaunchSh

# ---------------------------------------------------------------------------
# 5. Scheduled Task (systemd's stand-in on Windows)
# ---------------------------------------------------------------------------
Step "Installing the ai-glm command for PowerShell"
# `ai-glm` is one bash script shared with Ubuntu. This .cmd shim lets Claude for
# Windows, Codex for Windows, PowerShell and cmd call `ai-glm ...` exactly the way
# they would on the Ubuntu host - nobody has to know Git Bash exists.
$aiGlmBash = "/" + (((Join-Path $RepoPath "bin\ai-glm")) -replace '\\','/' -replace '^([A-Za-z]):','$1')
# Invoke bash with the script as its first argument, NOT via `-lc "... %*"`.
# The -lc form re-parses everything as one string, so a prompt containing spaces or
# quotes would be mangled. This form hands cmd's argv straight through untouched.
@"
@echo off
rem Managed by ai-devops setup-opencode-glm.ps1. Runs the shared bash ai-glm client.
rem HOME is pinned to the Windows profile: Git Bash \$HOME can be a roaming network
rem drive, and then ai-glm would look for its config and sessions in the wrong place.
set "HOME=$HomeDir"
set "AI_DEVOPS_CONFIG_DIR=$CfgDir"
"$GitBash" "$aiGlmBash" %*
"@ | Set-Content -Encoding ASCII -Path (Join-Path $BinDir "ai-glm.cmd")

# Put it on the user PATH so plain `ai-glm` resolves in any new shell.
$userPath = [Environment]::GetEnvironmentVariable("PATH","User")
if (($userPath -split ';') -notcontains $BinDir) {
  [Environment]::SetEnvironmentVariable("PATH", ($BinDir + ';' + $userPath), "User")
  Ok "Added $BinDir to your PATH (new windows will see it)"
}
$env:Path = $BinDir + ';' + $env:Path
Ok "ai-glm is now callable from PowerShell"

Step "Smoke-testing the launcher before registering it"
# Run it in the foreground briefly and capture output. Without this, a broken launcher
# only ever shows up as "server did not become healthy", with the actual error buried in
# Task Scheduler history where nobody will look.
$launchBashPre = ConvertTo-BashPath $LaunchSh
$smokeLog = Join-Path $OcHome "launcher-smoke.log"
$smoke = Start-Process -FilePath $GitBash -ArgumentList @($launchBashPre) -PassThru `
           -RedirectStandardOutput $smokeLog -RedirectStandardError "$smokeLog.err" `
           -WindowStyle Hidden
$up = $false
foreach ($i in 1..20) {
  if ($smoke.HasExited) { break }
  try {
    $probe = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/global/health" -TimeoutSec 2 `
               -UseBasicParsing -ErrorAction Stop
    if ($probe.StatusCode -eq 401 -or $probe.StatusCode -eq 200) { $up = $true; break }
  } catch {
    # 401 without credentials still proves the server is listening.
    if ($_.Exception.Response -and $_.Exception.Response.StatusCode.value__ -eq 401) { $up = $true; break }
    Start-Sleep -Seconds 2
  }
}
if (-not $smoke.HasExited) { Stop-Process -Id $smoke.Id -Force -ErrorAction SilentlyContinue }
Get-Process -Name opencode -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
if (-not $up) {
  $err = ""
  foreach ($f in @("$smokeLog.err", $smokeLog)) {
    if (Test-Path -LiteralPath $f) { $err += (Get-Content -Raw -LiteralPath $f) }
  }
  if (-not $err.Trim()) { $err = "(launcher produced no output)" }
  Die "The GLM launcher failed. This is what it said:`n`n$err`nRun it yourself to retry:`n  & '$GitBash' '$launchBashPre'"
}
Ok "Launcher starts the server correctly"

Step "Registering the OpenCodeGlm scheduled task"
$TaskName = "AiDevOps-OpenCodeGlm"
$launchBash = "/" + ($LaunchSh -replace '\\','/' -replace '^([A-Za-z]):','$1')
$action  = New-ScheduledTaskAction -Execute $GitBash -Argument "-lc `"exec '$launchBash'`""
$trigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
              -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) `
              -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings `
  -Description "AI DevOps OpenCode GLM server, loopback only" -Force | Out-Null
Stop-ScheduledTask  -TaskName $TaskName -ErrorAction SilentlyContinue
Start-ScheduledTask -TaskName $TaskName

Step "Waiting for the server to become healthy"
$pw = (Get-Content -Raw -LiteralPath $PwFile).Trim()
$pair = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("opencode:$pw"))
$healthy = $false
foreach ($i in 1..30) {
  try {
    $r = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/global/health" -TimeoutSec 3 `
           -Headers @{ Authorization = "Basic $pair" }
    if ($r.healthy) { $healthy = $true; break }
  } catch { Start-Sleep -Seconds 2 }
}
if (-not $healthy) {
  Die "server did not become healthy. Check the task history for $TaskName, or run the launcher by hand:`n       & '$GitBash' -lc `"'$launchBash'`""
}

Ok "OpenCode GLM server is up on 127.0.0.1:$Port (pinned $Version)"
Write-Host ""
Write-Host "Open a NEW PowerShell window, then from inside a repository:" -ForegroundColor Cyan
Write-Host "  ai-glm doctor"
Write-Host "  ai-glm new my-review --prompt 'your question'"
