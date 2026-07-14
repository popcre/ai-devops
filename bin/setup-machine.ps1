<#
setup-machine.ps1 — one-script new-machine setup for a Windows coding computer.

Run in PowerShell:
  powershell -ExecutionPolicy Bypass -File .\bin\setup-machine.ps1

What it does (idempotent — safe to re-run):
  1. Ensures git, the 1Password CLI (op), and (best-effort) Node/npx are present.
  2. Clones/updates the ai-devops repo and installs Claude + Codex skills and the
     global instruction files (delegates to install-ai-devops-windows.ps1).
  3. Stores the vault-locked 1Password SERVICE-ACCOUNT token ONCE in a
     user-only file  %USERPROFILE%\.config\ai-devops\op-service-account.
     (Not an environment variable: the Store/MSIX Claude Desktop sandbox does
     not inherit user env vars, and can strip env blocks from its config.)
  4. Installs the central reference file  ...\ai-devops\mcp.env  (op:// refs).
  5. Writes a launcher  ...\ai-devops\mcp-launch.cmd  that reads the token from
     the file and runs each MCP server under `op run --env-file mcp.env`, so
     secrets resolve at launch and NO secret is ever written into the config.
  6. Best-effort: wires the STDIO MCP servers (e.g. supabase) into Claude
     Desktop's claude_desktop_config.json (backed up first).

IMPORTANT — Claude Desktop limitations you must know (verified against docs):
  - Claude Desktop does NOT expand ${VAR} placeholders in its config. That is
    why we inject real values via `op run` at launch instead of placeholders.
  - REMOTE / HTTP MCP servers (devops-mcp, synology-monitor) cannot be wired
    from the config file reliably; add them once via the app's
    Settings -> Connectors -> "Add custom connector" UI. This script prints the
    URLs and (locked) tokens location for that one-time manual step.
  - This script's Desktop-config step is BEST-EFFORT and could not be tested on
    Linux; after running, verify in Claude Desktop that the supabase MCP shows
    connected. A validation checklist is printed at the end.

Flags:
  -Token <ops_...>     Provide the token non-interactively (else you are asked).
  -SkipDesktopMcp      Do the token/env/skills wiring but do not touch the
                       Claude Desktop config.
  -RepoPath <path>     Where ai-devops lives (default: $HOME\repos\ai-devops).
#>

[CmdletBinding()]
param(
  [string]$Token = "",
  [switch]$SkipDesktopMcp,
  [string]$RepoPath = "",
  [string]$SupabaseProjectRef = "<removed-protected-project-ref>"
)

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSVersion.Major -lt 7) {
  throw "Run this with PowerShell 7 (pwsh), not Windows PowerShell 5.1. Install: winget install Microsoft.PowerShell"
}
function Step($m){ Write-Host "`n==> $m" -ForegroundColor Cyan }
function Note($m){ Write-Host "    $m" }
function Ok($m){   Write-Host "    ok $m" -ForegroundColor Green }
function Warn($m){ Write-Host "[WARN] $m" -ForegroundColor Yellow }

# --------------------------------------------------------------------------
# Paths
# --------------------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($RepoPath)) { $RepoPath = Join-Path $HOME "repos\ai-devops" }
$CfgDir    = Join-Path $HOME ".config\ai-devops"
$TokenFile = Join-Path $CfgDir "op-service-account"
$McpEnv    = Join-Path $CfgDir "mcp.env"
$Launcher  = Join-Path $CfgDir "mcp-launch.cmd"

# --------------------------------------------------------------------------
# 1. Base tools: git, op, node/npx
# --------------------------------------------------------------------------
Step "Checking base tools"
function Ensure-Winget($id, $name){
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host "    installing $name via winget..."
    winget install --id $id -e --source winget --accept-package-agreements --accept-source-agreements | Out-Null
    $env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")
  } else {
    Warn "$name not found and winget unavailable; install $name manually."
  }
}
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Ensure-Winget "Git.Git" "Git" }
if (Get-Command git -ErrorAction SilentlyContinue) { Ok "git" } else { throw "git is required." }

if (-not (Get-Command op -ErrorAction SilentlyContinue)) { Ensure-Winget "AgileBits.1Password.CLI" "1Password CLI" }
if (Get-Command op -ErrorAction SilentlyContinue) { Ok "op $(op --version 2>$null)" } else { throw "The 1Password CLI (op) is required." }

if (-not (Get-Command npx -ErrorAction SilentlyContinue)) { Ensure-Winget "OpenJS.NodeJS.LTS" "Node.js LTS" }
if (Get-Command npx -ErrorAction SilentlyContinue) { Ok "node/npx" } else { Warn "npx not found; the supabase MCP (npx-based) will not start until Node is installed." }

# --------------------------------------------------------------------------
# 2. Repo + skills + global files (delegates to the existing installer)
# --------------------------------------------------------------------------
Step "Installing ai-devops repo, skills and global instruction files"
$existingInstaller = Join-Path $RepoPath "bin\install-ai-devops-windows.ps1"
if (Test-Path $existingInstaller) {
  & powershell -ExecutionPolicy Bypass -File $existingInstaller -RepoPath $RepoPath
} else {
  # Repo not present yet: clone, then run its installer.
  Note "Repo not found at $RepoPath; cloning."
  git clone https://github.com/u2giants/ai-devops.git $RepoPath
  & powershell -ExecutionPolicy Bypass -File (Join-Path $RepoPath "bin\install-ai-devops-windows.ps1") -RepoPath $RepoPath
}

# --------------------------------------------------------------------------
# 3. The one bootstrap secret: the service-account token (paste once)
# --------------------------------------------------------------------------
Step "Service-account token (vault-locked to 'vibe_coding')"
New-Item -ItemType Directory -Force -Path $CfgDir | Out-Null

if ([string]::IsNullOrWhiteSpace($Token)) {
  if ((Test-Path $TokenFile) -and (Get-Content $TokenFile -Raw).Trim().Length -gt 0) {
    Ok "Reusing token already stored at $TokenFile"
    $Token = (Get-Content $TokenFile -Raw).Trim()
  } else {
    Write-Host "    Paste the 1Password service-account token for vault 'vibe_coding'."
    Write-Host "    (It starts with 'ops_'. You do this once on this computer.)"
    $secure = Read-Host -AsSecureString "Token"
    $Token  = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
  }
}
if ([string]::IsNullOrWhiteSpace($Token)) { throw "No token provided." }

# Write the token file and lock its ACL to the current user only.
Set-Content -Path $TokenFile -Value $Token.Trim() -NoNewline -Encoding ascii
try {
  icacls $TokenFile /inheritance:r | Out-Null
  icacls $TokenFile /grant:r "$($env:USERNAME):(R,W)" | Out-Null
  Ok "Token stored (user-only ACL) at $TokenFile"
} catch { Warn "Stored token but could not tighten ACL: $_" }

$env:OP_SERVICE_ACCOUNT_TOKEN = $Token.Trim()
$who = (op whoami 2>$null | Out-String)
if ($who -match "SERVICE_ACCOUNT") { Ok "Token authenticates as a scoped SERVICE ACCOUNT" }
else { Warn "op whoami did not confirm a service account; check the token." }

# --------------------------------------------------------------------------
# 4. Central reference file
# --------------------------------------------------------------------------
Step "Central references -> $McpEnv"
$example = Join-Path $RepoPath "config\mcp.env.example"
if (-not (Test-Path $example)) { throw "Missing $example" }
Copy-Item $example $McpEnv -Force
Ok "Installed mcp.env (op:// references only, no secrets)"

# --------------------------------------------------------------------------
# 5. Launcher that injects secrets at MCP-server start
# --------------------------------------------------------------------------
Step "MCP launcher -> $Launcher"
$launcherBody = @"
@echo off
rem [ai-devops] read the vault-locked service-account token from the user file,
rem then run the given MCP server under op with the central reference env-file.
rem No secret is stored in claude_desktop_config.json.
set /p OP_SERVICE_ACCOUNT_TOKEN=<"%USERPROFILE%\.config\ai-devops\op-service-account"
op run --no-masking --env-file="%USERPROFILE%\.config\ai-devops\mcp.env" -- %*
"@
Set-Content -Path $Launcher -Value $launcherBody -Encoding ascii
Ok "Wrote $Launcher"

# --------------------------------------------------------------------------
# 6. Best-effort: wire stdio MCP servers into Claude Desktop config
# --------------------------------------------------------------------------
if ($SkipDesktopMcp) {
  Step "Skipping Claude Desktop config (-SkipDesktopMcp)"
} else {
  Step "Wiring stdio MCP servers into Claude Desktop (best-effort)"
  # The Store/MSIX install keeps the REAL config here (the "Edit Config" button
  # opens the wrong %APPDATA% copy — do not use it).
  $msix = Join-Path $env:LOCALAPPDATA "Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude_desktop_config.json"
  $std  = Join-Path $env:APPDATA "Claude\claude_desktop_config.json"
  $cfgPath = if (Test-Path (Split-Path $msix)) { $msix } elseif (Test-Path (Split-Path $std)) { $std } else { $null }

  if (-not $cfgPath) {
    Warn "Could not find a Claude Desktop config folder. Is Claude Desktop installed and run once?"
    Warn "Expected (MSIX): $msix"
  } else {
    New-Item -ItemType Directory -Force -Path (Split-Path $cfgPath) | Out-Null
    $cfg = @{}
    if (Test-Path $cfgPath) {
      Copy-Item $cfgPath "$cfgPath.aidevops.bak" -Force
      try { $cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json -AsHashtable } catch { $cfg = @{} }
    }
    if (-not $cfg.ContainsKey("mcpServers")) { $cfg["mcpServers"] = @{} }

    # supabase (stdio, npx). command=cmd /c launcher ... so the .cmd + npx.cmd
    # both run through a shell (spawn cannot run batch files directly).
    $cfg["mcpServers"]["supabase"] = @{
      command = "cmd"
      args = @("/c", $Launcher, "cmd", "/c", "npx", "-y",
               "@supabase/mcp-server-supabase@latest", "--project-ref", $SupabaseProjectRef)
    }

    ($cfg | ConvertTo-Json -Depth 12) | Set-Content -Path $cfgPath -Encoding utf8
    Ok "Updated $cfgPath (backup: $cfgPath.aidevops.bak)"
    Warn "VALIDATE ON THIS MACHINE: fully quit and reopen Claude Desktop, then confirm the 'supabase' MCP shows connected."
  }

  Step "Remote MCP servers (manual, one time)"
  Note "Claude Desktop cannot script remote/HTTP MCPs. Add these via"
  Note "  Settings -> Connectors -> Add custom connector:"
  Note "    devops-mcp        https://mcp.designflow.app/mcp"
  Note "    synology-monitor  https://nas-mcp.designflow.app/mcp"
  Note "  Their bearer tokens are DEVOPS_MCP_TOKEN / NAS_MCP_TOKEN in 1Password"
  Note "  (vibe_coding vault, item 'designflow-mcp'). Never paste them into files."
}

# --------------------------------------------------------------------------
# Done + validation checklist
# --------------------------------------------------------------------------
Step "Done"
Write-Host "Setup summary:"
Write-Host "  token file : $TokenFile   (user-only)"
Write-Host "  references : $McpEnv"
Write-Host "  launcher   : $Launcher"
Write-Host ""
Write-Host "Validate on this machine:" -ForegroundColor Cyan
Write-Host "  1. Run:  op run --env-file `"$McpEnv`" -- cmd /c echo ok"
Write-Host "     (should print 'ok' with no auth error)"
Write-Host "  2. Fully quit and reopen Claude Desktop."
Write-Host "  3. Confirm the 'supabase' MCP shows connected in Claude Desktop."
Write-Host "  4. Add the two remote connectors via the UI (see above), if not already present."
