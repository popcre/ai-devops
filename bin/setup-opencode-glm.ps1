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
foreach ($t in @('npm','node','op')) {
  if (-not (Get-Command $t -ErrorAction SilentlyContinue)) { Die "$t is required but not on PATH." }
}
$GitBash = $null
foreach ($c in @("C:\Program Files\Git\bin\bash.exe", "C:\Program Files (x86)\Git\bin\bash.exe",
                 (Join-Path $env:LOCALAPPDATA "Programs\Git\bin\bash.exe"))) {
  if (Test-Path -LiteralPath $c) { $GitBash = $c; break }
}
if (-not $GitBash) { Die "Git Bash not found. Install Git for Windows: winget install --id Git.Git" }
& $GitBash -lc "command -v jq" *>$null
if ($LASTEXITCODE -ne 0) {
  Die "jq is required inside Git Bash and was not found.`n       Install it with:  winget install --id jqlang.jq`n       Then re-run this script."
}
Ok "npm, node, op, Git Bash and jq present"

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
# 4. Launcher — the SAME bash launcher logic as Ubuntu, run through Git Bash
# ---------------------------------------------------------------------------
Step "Installing the GLM server launcher"
$LaunchSh = Join-Path $BinDir "opencode-glm-launch"
$binaryBash = "/" + ($Binary -replace '\\','/' -replace '^([A-Za-z]):','$1')
@"
#!/usr/bin/env bash
# Managed by ai-devops setup-opencode-glm.ps1 (Windows).
# Scheduled Task -> Git Bash -> this launcher -> op run -> opencode serve.
# The Z.ai key never touches a task definition, an argv, or a file at rest.
set -euo pipefail
CFG_DIR="`${AI_DEVOPS_CONFIG_DIR:-`$HOME/.config/ai-devops}"
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
Write-Host "Use it from Git Bash, inside a repository:" -ForegroundColor Cyan
Write-Host "  '$RepoPath/bin/ai-glm' doctor"
Write-Host "  '$RepoPath/bin/ai-glm' new my-review --prompt 'your question'"
