<#
.SYNOPSIS
  Install the StepFun OpenCode harness on Windows so `ai-stepfun` works locally.

.DESCRIPTION
  Windows path for ai-stepfun. StepCode is not available on Windows, so the
  harness runs through the same pinned OpenCode binary GLM/Muse/DeepSeek use.

    1. Installs the exact OpenCode version from config/opencode/version into a
       private prefix (shared with the other OpenCode harnesses).
    2. Installs `ai-stepfun` as a command on the user PATH.
    3. Verifies the protected key store (run `ai-stepfun store-key` if missing).

  Idempotent; safe to re-run. Run as your normal user (do NOT run elevated).

.NOTES
  After setup, open a NEW PowerShell window and run:
    ai-stepfun doctor
    ai-stepfun review --repo . --prompt-file brief.md
#>
[CmdletBinding()]
param(
  [string]$RepoPath = ""
)

$ErrorActionPreference = 'Stop'
function Step($m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "[ OK ] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Die($m)  { Write-Host "[FAIL] $m" -ForegroundColor Red; exit 1 }

$HomeDir = $env:USERPROFILE
if (-not $HomeDir) { Die "USERPROFILE is not set." }

$CfgDir  = Join-Path $HomeDir ".config\ai-devops"
$LibRoot = Join-Path $HomeDir ".local\lib\ai-devops\opencode"
$BinDir  = Join-Path $HomeDir ".local\bin"
$StateDir= Join-Path $HomeDir ".local\state\ai-devops\stepfun"
$KeyStore= Join-Path $CfgDir "secrets\stepfun-api-key"

if ([string]::IsNullOrWhiteSpace($RepoPath)) {
  $selfRepo = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
  if (Test-Path -LiteralPath (Join-Path $selfRepo "config\opencode\version")) {
    $RepoPath = $selfRepo
  } elseif ($env:AI_DEVOPS_HOME) {
    $RepoPath = $env:AI_DEVOPS_HOME
  } else {
    $RepoPath = Join-Path $env:USERPROFILE "repos\ai-devops"
  }
}
if (-not (Test-Path -LiteralPath (Join-Path $RepoPath "config\opencode\version"))) {
  Die "No ai-devops checkout at $RepoPath (config\opencode\version is missing). Pass -RepoPath <path-to-your-checkout>."
}

$VersionFile = Join-Path $RepoPath "config\opencode\version"
$Version = (Get-Content -Raw -LiteralPath $VersionFile).Trim()
if (-not $Version) { Die "config/opencode/version is empty" }

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------
Step "Checking prerequisites"

function Ensure-Winget($id, $name) {
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Die "$name is missing and winget is unavailable. Install $name, then re-run this script."
  }
  Step "Installing $name via winget"
  winget install --id $id -e --source winget --accept-package-agreements --accept-source-agreements | Out-Null
  $env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
              [Environment]::GetEnvironmentVariable("Path","User")
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Ensure-Winget "Git.Git" "Git for Windows" }
if (-not (Get-Command node -ErrorAction SilentlyContinue) -or
    -not (Get-Command npm  -ErrorAction SilentlyContinue)) { Ensure-Winget "OpenJS.NodeJS.LTS" "Node.js LTS" }
if (-not (Get-Command jq   -ErrorAction SilentlyContinue)) { Ensure-Winget "jqlang.jq" "jq" }

foreach ($t in @('npm','node','git')) {
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
Ok "git, node, npm, Git Bash and jq present"

# ---------------------------------------------------------------------------
# 1. Pinned OpenCode binary (shared with GLM/Muse/DeepSeek)
# ---------------------------------------------------------------------------
$Prefix = Join-Path $LibRoot $Version
$Binary = Join-Path $Prefix "node_modules\opencode-ai\bin\opencode.exe"
if (-not (Test-Path -LiteralPath $Binary)) {
  Step "Installing opencode-ai@$Version into $Prefix"
  New-Item -ItemType Directory -Force -Path $Prefix | Out-Null
  & npm install --prefix $Prefix "opencode-ai@$Version" --no-audit --no-fund | Out-Null
  if (-not (Test-Path -LiteralPath $Binary)) {
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
# 2. ai-stepfun on PATH
# ---------------------------------------------------------------------------
Step "Installing the ai-stepfun command for PowerShell"
New-Item -ItemType Directory -Force -Path $BinDir, $StateDir | Out-Null
$aiStepfunBash = "/" + (((Join-Path $RepoPath "bin\ai-stepfun")) -replace '\\','/' -replace '^([A-Za-z]):','$1')
# Invoke bash with the script as its first argument so argv passes through untouched.
@"
@echo off
rem Managed by ai-devops setup-opencode-stepfun.ps1. Runs the shared bash ai-stepfun client.
rem HOME is pinned to the Windows profile: Git Bash `$HOME can be a roaming network
rem drive, and then ai-stepfun would look for its config and sessions in the wrong place.
set "HOME=$HomeDir"
set "AI_DEVOPS_CONFIG_DIR=$CfgDir"
"$GitBash" "$aiStepfunBash" %*
"@ | Set-Content -Encoding ASCII -Path (Join-Path $BinDir "ai-stepfun.cmd")

$userPath = [Environment]::GetEnvironmentVariable("PATH","User")
if (($userPath -split ';') -notcontains $BinDir) {
  [Environment]::SetEnvironmentVariable("PATH", ($BinDir + ';' + $userPath), "User")
  Ok "Added $BinDir to your PATH (new windows will see it)"
}
$env:Path = $BinDir + ';' + $env:Path
Ok "ai-stepfun is now callable from PowerShell"

# ---------------------------------------------------------------------------
# 3. Key store
# ---------------------------------------------------------------------------
if (Test-Path -LiteralPath $KeyStore) {
  # NTFS ignores chmod: the key store is protected only if its ACL has no
  # inherited entries and grants nobody but the current user (plus SYSTEM and
  # Administrators). Restrict it, then verify before calling it protected (#1086).
  & icacls.exe $KeyStore /inheritance:r /grant:r "$($env:USERNAME):F" | Out-Null
  $acl = Get-Acl -LiteralPath $KeyStore
  $others = @($acl.Access | Where-Object {
      $_.IsInherited -or ($_.IdentityReference.Value -notmatch ('\\' + [regex]::Escape($env:USERNAME) + '$|^NT AUTHORITY\\SYSTEM$|^BUILTIN\\Administrators$'))
    })
  if ($acl.AreAccessRulesProtected -and $others.Count -eq 0) {
    Ok "Protected key store present (current-user-only ACL): $KeyStore"
  } else {
    Warn "Key store ACL is not current-user-only; ai-stepfun will refuse it: $KeyStore"
    Warn "  ai-stepfun store-key"
  }
} else {
  Warn "Protected key store is missing. Run this once to fill it from 1Password:"
  Warn "  ai-stepfun store-key"
}

Ok "StepFun OpenCode harness is installed (OpenCode $Version)"
Write-Host ""
Write-Host "Open a NEW PowerShell window, then from inside a repository:" -ForegroundColor Cyan
Write-Host "  ai-stepfun doctor"
Write-Host "  ai-stepfun review --repo . --prompt-file brief.md"
