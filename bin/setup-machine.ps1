<#
setup-machine.ps1 - one-script new-machine setup for a Windows coding computer.

Run in PowerShell 7 (pwsh) - NOT Windows PowerShell 5.1:
  pwsh -ExecutionPolicy Bypass -File .\bin\setup-machine.ps1

  `powershell` is 5.1 and this script throws on it (see the version guard below).
  Install pwsh with: winget install Microsoft.PowerShell

NOT fully unattended: step 3 prompts once with Read-Host for the 1Password
service-account token, unless -Token is passed or the token file already exists
at %USERPROFILE%\.config\ai-devops\op-service-account. An automated/AI session
will BLOCK there.

What it does (idempotent - safe to re-run):
  1. Ensures git, the 1Password CLI (op), and (best-effort) Node/npx are present.
  2. Clones/updates the ai-devops repo and installs Claude + Codex skills and the
     global instruction files (delegates to install-ai-devops-windows.ps1).
  3. Stores the vault-locked 1Password SERVICE-ACCOUNT token ONCE in a
     user-only file  %USERPROFILE%\.config\ai-devops\op-service-account.
     (Not an environment variable: the Store/MSIX Claude Desktop sandbox does
     not inherit user env vars, and can strip env blocks from its config.)
  4. Installs the central reference file  ...\ai-devops\mcp.env  (op:// refs).
  5. Writes MCP launchers backed by one single-flight `op run --env-file`
     refresh. Parallel MCP startups wait on an OS mutex and reuse a 15-minute
     DPAPI-encrypted, user-scoped cache instead of hammering 1Password.
  6. Restores the 916-alien SSH key from 1Password to ~\.ssh\916-alien (+ .pub)
     and installs the managed SSH host aliases (~/.ssh/ai-devops.conf, Included
     from ~/.ssh/config), so `ssh vps` / `ssh vps2` / `ssh seafile` etc. work
     immediately. Uses cloudflared so it works on any network without Tailscale.
  7. Wires the MCP server set into Claude Desktop, Claude Code, and Codex
     (each backed up first). Every server is DEFINED exactly once, in step 5d.
     Step 5d-2 then decides WHERE each one is wired:
       - GLOBAL (every session, every repo): 1password, supabase (--read-only),
         chrome-devtools, playwright, codex-cli
       - PROJECT-SCOPED (only sessions opened in that repo, via its own
         .mcp.json, written in step 7b): trigger + recall-ai -> oracle,
         railway -> popdam3, ag-grid -> dflow_plm/designflow-frontend,
         devops-mcp + synology-monitor -> synology-monitor
       - Codex-only native HTTP    : vercel (browser OAuth)

     WHY THE SPLIT: Claude Code starts every GLOBAL server in every session.
     Measured on edge-dev 2026-08-26, 11 global servers x 22 open Claude Desktop
     sessions = 416 node processes holding 18.1 GB on a 32 GB machine. A server
     only one project uses must be project-scoped. See step 5d-2.

     No token is ever written into any config; only URLs and op:// references.
     Servers we do not define (the Windows-MCP extension, anything hand-added)
     and all other settings keys are preserved untouched.

IMPORTANT - Claude Desktop limitations you must know (verified):
  - Claude Desktop does NOT expand ${VAR} in its config, and neither does
    mcp-remote in --header. So tokens are resolved to real values by `op` at
    launch (inside a launcher .cmd), not by placeholder substitution.
  - MSIX sandbox does not inherit setx env vars and can strip `env` blocks, so
    the token is read from a file by the launcher, never set as a system var.
  - This script's Desktop-config step is BEST-EFFORT and could not be tested on
    Linux; after running, verify in Claude Desktop that all three MCPs show
    connected. A validation checklist is printed at the end.

Flags:
  -Token <ops_...>     Provide the token non-interactively (else you are asked).
  -SkipDesktopMcp      Do the token/env/skills wiring but do not touch the
                       Claude Desktop config.
  -SkipRailwayCliReconcile
                       Internal bootstrap flag; Railway was already reconciled.
  -EnableMemorySyncSchedule
                       Opt in to the private-memory task after qualification.
                       The default is disabled during incident remediation.
  -RepoPath <path>     Where ai-devops lives (default: $HOME\repos\ai-devops).
  -PrivateConfigRoot <path>
                       Override the protected configuration checkout location.
#>

[CmdletBinding()]
param(
  [string]$Token = "",
  [switch]$SkipDesktopMcp,
  [switch]$SkipRailwayCliReconcile,
  [switch]$EnableMemorySyncSchedule,
  [string]$RepoPath = "",
  [string]$SupabaseProjectRef = "",
  [string]$PrivateConfigRoot = ""
)

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSVersion.Major -lt 7) {
  throw "Run this with PowerShell 7 (pwsh), not Windows PowerShell 5.1. Install: winget install Microsoft.PowerShell"
}
# Resolve the directory holding a USABLE codex.exe - one whose sandbox helper is
# reachable. Prefer the real standalone package bin
# (~\.codex\packages\standalone\current\bin) over the visible junction
# (...\Programs\OpenAI\Codex\bin): only `bin` is junctioned, so from the visible
# path Codex resolves <exe_dir>\..\codex-resources\ to a directory that does not
# exist and cannot launch codex-windows-sandbox-setup.exe. `current` is itself a
# junction that the Codex updater re-points, so this stays correct across upgrades.
# Returns $null when no standalone install is present (npm-global is then used).
function Get-CodexBin {
  $candidates = @(
    (Join-Path $env:USERPROFILE ".codex\packages\standalone\current\bin"),
    (Join-Path $env:LOCALAPPDATA "Programs\OpenAI\Codex\bin")
  )
  foreach ($dir in $candidates) {
    $exe = Join-Path $dir "codex.exe"
    if (Test-Path -LiteralPath $exe) {
      # Only trust a dir whose sandbox helper is actually reachable.
      $helper = Join-Path (Split-Path $dir -Parent) "codex-resources\codex-windows-sandbox-setup.exe"
      if ((Test-Path -LiteralPath $helper) -or (Test-Path -LiteralPath (Join-Path $dir "codex-windows-sandbox-setup.exe"))) {
        return $dir
      }
    }
  }
  return $null
}

function Step($m){ Write-Host "`n==> $m" -ForegroundColor Cyan }
function Note($m){ Write-Host "    $m" }
function Ok($m){   Write-Host "    ok $m" -ForegroundColor Green }
function Warn($m){ Write-Host "[WARN] $m" -ForegroundColor Yellow }

# --------------------------------------------------------------------------
# Paths
# --------------------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($RepoPath)) {
  # Default to the checkout this script is running FROM. Defaulting to a fixed
  # $HOME\repos\ai-devops path made every run clone a second, unrelated copy even when
  # started from an existing checkout (observed on 916, T16 and 4837: run from
  # D:\repos\ai-devops, cloned again into C:\Users\<user>\repos\ai-devops).
  $selfRepo = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
  if (Test-Path -LiteralPath (Join-Path $selfRepo "config\mcp.env.example")) {
    $RepoPath = $selfRepo
  } else {
    throw "Could not resolve the ai-devops checkout from $PSCommandPath; pass -RepoPath explicitly."
  }
}

# Seed portable Codex defaults only on a brand-new Codex home. Existing TOML is
# never rewritten or appended to: duplicate keys have broken Codex before, and
# machine-specific paths, plugins, and trust entries must remain local.
$codexConfigPath = Join-Path $env:USERPROFILE ".codex\config.toml"
$codexPortableTemplate = Join-Path $RepoPath "config\codex-portable.toml"
if (-not (Test-Path -LiteralPath $codexConfigPath) -and
    (Test-Path -LiteralPath $codexPortableTemplate)) {
  New-Item -ItemType Directory -Force -Path (Split-Path $codexConfigPath -Parent) | Out-Null
  Copy-Item -LiteralPath $codexPortableTemplate -Destination $codexConfigPath
}
# %USERPROFILE%, never $HOME: on a machine with a roaming profile $HOME can point at a
# network drive (Z:) that nothing reads back, which has silently misplaced installs here
# before.
$CfgDir    = Join-Path $env:USERPROFILE ".config\ai-devops"
$TokenFile = Join-Path $CfgDir "op-service-account"
$McpEnv    = Join-Path $CfgDir "mcp.env"
$Launcher  = Join-Path $CfgDir "mcp-launch.cmd"
$RemoteLauncher = Join-Path $CfgDir "mcp-remote-launch.cmd"
$SecretLauncher = Join-Path $RepoPath "bin\mcp-secret-launch.ps1"
$privateFileHelper = Join-Path $RepoPath "bin\windows-private-file.ps1"
if (-not (Test-Path -LiteralPath $privateFileHelper)) { throw "Missing private-file helper: $privateFileHelper" }
. $privateFileHelper
$jsonFileHelper = Join-Path $RepoPath "bin\windows-json-file.ps1"
if (-not (Test-Path -LiteralPath $jsonFileHelper)) { throw "Missing JSON-file helper: $jsonFileHelper" }
. $jsonFileHelper
$gitBashPathHelper = Join-Path $RepoPath "bin\windows-git-bash-path.ps1"
if (-not (Test-Path -LiteralPath $gitBashPathHelper)) { throw "Missing Git Bash path helper: $gitBashPathHelper" }
. $gitBashPathHelper

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
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { Ensure-Winget "GitHub.cli" "GitHub CLI" }
if (Get-Command gh -ErrorAction SilentlyContinue) { Ok "gh" } else { throw "GitHub CLI is required for protected configuration." }

if (-not (Get-Command op -ErrorAction SilentlyContinue)) { Ensure-Winget "AgileBits.1Password.CLI" "1Password CLI" }
if (Get-Command op -ErrorAction SilentlyContinue) { Ok "op $(op --version 2>$null)" } else { throw "The 1Password CLI (op) is required." }

if (-not (Get-Command npx -ErrorAction SilentlyContinue)) { Ensure-Winget "OpenJS.NodeJS.LTS" "Node.js LTS" }
if (Get-Command npx -ErrorAction SilentlyContinue) { Ok "node/npx" } else { Warn "npx not found; the supabase MCP (npx-based) will not start until Node is installed." }

# Concrete machine topology and provider identifiers live in a separate private
# repository. Sync it before any generated configuration consumes those values.
Step "Protected machine configuration"
$gitBash = "C:\Program Files\Git\bin\bash.exe"
if (-not (Test-Path -LiteralPath $gitBash)) { throw "Git Bash is required at $gitBash." }
$privateConfigTool = Join-Path $RepoPath "bin\ai-private-config"
if (-not (Test-Path -LiteralPath $privateConfigTool)) { throw "Missing protected-configuration helper: $privateConfigTool" }
if (-not [string]::IsNullOrWhiteSpace($PrivateConfigRoot)) { $env:AI_PRIVATE_CONFIG_HOME = $PrivateConfigRoot }
$privateRootOutput = & $gitBash $privateConfigTool sync
if ($LASTEXITCODE -ne 0) { throw "Protected configuration sync failed." }
Ok "protected configuration synchronized"
if ([string]::IsNullOrWhiteSpace($SupabaseProjectRef)) {
  $SupabaseProjectRef = (& $gitBash $privateConfigTool value supabase_project_ref | Select-Object -Last 1).Trim()
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($SupabaseProjectRef)) { throw "Protected Supabase project reference is unavailable." }
}
$sshTmplRaw = (& $gitBash $privateConfigTool path ssh_config | Select-Object -Last 1).Trim()
$sshPathExitCode = $LASTEXITCODE
if ($sshPathExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($sshTmplRaw)) { throw "Protected SSH configuration is unavailable." }
$sshTmpl = ConvertFrom-GitBashPath -Path $sshTmplRaw -GitBashPath $gitBash
$knownHostsTmplRaw = (& $gitBash $privateConfigTool path ssh_known_hosts | Select-Object -Last 1).Trim()
$knownHostsPathExitCode = $LASTEXITCODE
if ($knownHostsPathExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($knownHostsTmplRaw)) { throw "Protected SSH host keys are unavailable." }
$knownHostsTmpl = ConvertFrom-GitBashPath -Path $knownHostsTmplRaw -GitBashPath $gitBash

# Railway's official MCP is bundled into its CLI. Reconcile the current official
# npm package even when setup-machine.ps1 is run directly. npm install is
# idempotent and repairs an outdated or incomplete existing installation.
if (-not $SkipRailwayCliReconcile -and (Get-Command npm -ErrorAction SilentlyContinue)) {
  Write-Host "    reconciling Railway CLI via npm..."
  & npm.cmd install --global '@railway/cli@5.43.1'
  if ($LASTEXITCODE -ne 0) { throw "Railway CLI npm installation failed." }
  $env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")
}
if (Get-Command railway -ErrorAction SilentlyContinue) { Ok "railway $(railway --version 2>$null)" } else { Warn "Railway CLI not found; rerun after Node/npm is available." }

# GitHub CLI creates its config folder with inheritance disabled on some Windows
# installations. Codex's restricted task account can then see the workspace but
# `gh` fails before it can run because config.yml is unreadable. Repair only that
# folder and grant only read/execute; credentials remain in Windows Credential
# Manager and no token is copied or exposed.
$repairGhAccess = Join-Path $RepoPath "bin\repair-codex-github-cli-access.ps1"
if ((Get-Command gh -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath $repairGhAccess)) {
  Step "GitHub CLI access for restricted Codex tasks"
  & $repairGhAccess
}

# cloudflared - used by the SSH config's ProxyCommand so `ssh vps` works on any network.
if (-not (Get-Command cloudflared -ErrorAction SilentlyContinue)) { Ensure-Winget "Cloudflare.cloudflared" "cloudflared" }
if (Get-Command cloudflared -ErrorAction SilentlyContinue) { Ok "cloudflared" } else { Warn "cloudflared not found; `ssh vps` (tunnel) will not work until it is installed." }

# uv - required by the Windows-MCP Claude Desktop extension (installed from the
# Extensions UI, see the checklist at the end). Without uv that extension fails to
# start. winget first; fall back to Astral's installer, which is what the legacy
# Dropbox script used.
if (-not (Get-Command uv -ErrorAction SilentlyContinue)) { Ensure-Winget "astral-sh.uv" "uv" }
if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
  Note "uv not available via winget; using Astral's installer."
  try {
    Invoke-RestMethod https://astral.sh/uv/install.ps1 | Invoke-Expression
    $env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                [Environment]::GetEnvironmentVariable("Path","User")
  } catch { Warn "uv install failed: $($_.Exception.Message)" }
}
if (Get-Command uv -ErrorAction SilentlyContinue) { Ok "uv" } else { Warn "uv not found; the Windows-MCP extension will not start until it is installed." }

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
  git clone https://github.com/popcre/ai-devops.git $RepoPath
  & powershell -ExecutionPolicy Bypass -File (Join-Path $RepoPath "bin\install-ai-devops-windows.ps1") -RepoPath $RepoPath
}

# --------------------------------------------------------------------------
# 2b. Git commit identity.
#     Git has no default identity. With none configured it does NOT stop - it
#     silently invents one from the Windows/AD account and stamps it on every
#     commit. That is how 231 wrong-identity commits reached merged dflow
#     history before anyone noticed. useConfigOnly makes Git fail loudly
#     instead of guessing if the config is ever lost.
#     Set natively here (not via the bash script) so it lands in the Windows
#     profile that native Git and every GUI tool actually read.
# --------------------------------------------------------------------------
Step "Pinning Git commit identity"
git config --global user.name  "Albert Hazan"
git config --global user.email "u2giants@users.noreply.github.com"
git config --global user.useConfigOnly true
Note ("Git identity: " + (git config --global --get user.email) + "  (auto-guess disabled)")

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

# Stage under a user/SYSTEM-only directory, verify the effective ACL, and only
# then atomically publish. ACL failure leaves the existing token byte-identical.
$tokenBytes = [Text.Encoding]::ASCII.GetBytes($Token.Trim())
$tokenBackup = Set-AiDevOpsPrivateFileAtomic -Path $TokenFile -Bytes $tokenBytes
Ok "Token stored with verified private ACL at $TokenFile"
if ($tokenBackup) { Note "Previous protected token retained at $tokenBackup" }

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
rem [ai-devops] one single-flight 1Password refresh, then DPAPI cache reuse.
rem No `--` before %*: PowerShell -File mis-parses it as an empty parameter name.
rem CommandArgs (Position=0) in mcp-secret-launch.ps1 captures the whole child line.
pwsh -NoProfile -File "$SecretLauncher" -Mode Stdio %*
"@
Set-Content -Path $Launcher -Value $launcherBody -Encoding ascii
Ok "Wrote $Launcher"

# A second launcher for REMOTE/HTTP MCP servers. mcp-remote does NOT expand
# ${VAR} in --header, so the bearer token must be a real value before it runs.
# The shared launcher decrypts the already-resolved environment IN MEMORY and
# passes the selected value to mcp-remote. Args carry only the URL + reference;
# token itself is never written to disk or into claude_desktop_config.json.
#   %1 = server URL,  %2 = op:// reference to the bearer token,
#   %3+ = optional extra flags passed straight through to mcp-remote
#         (recall-ai needs --transport http-first; devops/synology pass none,
#          for which EXTRA stays empty and the command is byte-identical to
#          the previous two-argument form).
$remoteBody = @"
@echo off
rem No `--`: PowerShell -File mis-parses it. -Url/-SecretRef bind by name; any
rem extra mcp-remote flags (%3+) are captured by CommandArgs (Position=0).
pwsh -NoProfile -File "$SecretLauncher" -Mode Remote -Url %1 -SecretRef %2 %3 %4 %5 %6 %7 %8 %9
"@
Set-Content -Path $RemoteLauncher -Value $remoteBody -Encoding ascii
Ok "Wrote $RemoteLauncher"

# --------------------------------------------------------------------------
# 5d. The MCP server set - ONE definition, used by Claude and Codex
# --------------------------------------------------------------------------
# Defined once, deliberately. Separate hand-maintained lists are the root cause
# of every gap this script has had: a server wired into one client silently never
# existed in another, and servers this script did not define survived only on
# machines that happened to already have them. Claude Desktop, Claude Code, and
# Codex all consume this hashtable, so anything added here reaches every client
# on every machine. Add new servers HERE and nowhere else.
Step "Building the MCP server set"
$McpServers = [ordered]@{}

# supabase (stdio, npx). command=cmd /c launcher ... so the .cmd + npx.cmd both
# run through a shell (spawn cannot run batch files directly). op run injects
# SUPABASE_ACCESS_TOKEN (from mcp.env) into the server's environment.
#
# --read-only is NOT optional. Every schema/DDL/RLS change to the shared DB is
# authored in u2giants/shared-db (branch + PR), never through this MCP. The flag
# enforces that rule; --project-ref caps the blast radius to the one project.
# The legacy Dropbox script had --read-only; it was dropped when this script took
# over, leaving the MCP write-capable against shared production.
$McpServers["supabase"] = @{
  command = "cmd"
  args = @("/c", $Launcher, "cmd", "/c", "npx", "-y",
           "@supabase/mcp-server-supabase@0.11.0", "--read-only",
           "--project-ref", $SupabaseProjectRef)
}

# devops-mcp + synology-monitor (remote/HTTP). Wired via the mcp-remote shim under
# the remote launcher, so the bearer token is resolved from 1Password at launch -
# never written into the config. Only the URL + op:// ref appear.
$McpServers["devops-mcp"] = @{
  command = "cmd"
  args = @("/c", $RemoteLauncher, "https://mcp.designflow.app/mcp",
           "op://vibe_coding/f335s4oy3m6n74jmwj74hunrtu/devops_token")
}
$McpServers["synology-monitor"] = @{
  command = "cmd"
  args = @("/c", $RemoteLauncher, "https://nas-mcp.designflow.app/mcp",
           "op://vibe_coding/f335s4oy3m6n74jmwj74hunrtu/nas_token")
}

# recall-ai (remote/HTTP). Same treatment. Until 2026-07-17 this token was
# hard-coded in plaintext in claude_desktop_config.json - the LAST plaintext
# secret left after the Phase 2 token-free pass, which missed it because nothing
# ever rewrote the recall-ai entry. --transport preserves the flag the working
# config used; the launcher passes %3+ through to mcp-remote untouched.
#
# The reference MUST be byte-identical to the one in config/mcp.env.example.
# Remote mode looks the ref up in mcp.env by exact string match and throws
# "Secret reference is not managed by ..." on any difference. This entry used the
# item UUID while mcp.env used the title, so recall-ai could never start; the
# mismatch stayed hidden until 2026-08-24 because an earlier failure in the shared
# refresh killed the server before this check ran.
$McpServers["recall-ai"] = @{
  command = "cmd"
  args = @("/c", $RemoteLauncher, "https://us-east-1.recall.ai/mcp",
           "op://vibe_coding/recall-ai MCP/password",
           "--transport", "http-first")
}

# trigger (stdio, npx). Wrapped in the launcher so `op` injects
# TRIGGER_ACCESS_TOKEN (from mcp.env) at launch - no token in the config.
$McpServers["trigger"] = @{
  command = "cmd"
  args = @("/c", $Launcher, "cmd", "/c", "npx", "-y", "trigger.dev@4.4.6", "mcp")
}

# 1password (stdio, npx). The launcher reads the vault-locked service-account
# token from the user file into OP_SERVICE_ACCOUNT_TOKEN - exactly the var this
# MCP needs - so no token is written into the config either.
$McpServers["1password"] = @{
  command = "cmd"
  args = @("/c", $Launcher, "cmd", "/c", "npx", "-y", "@u2giants/1password-mcp")
}

# playwright / chrome-devtools / ag-grid - plain npx stdio servers, no secret.
# Vercel is intentionally absent from Claude. Claude requires the mcp-remote
# OAuth bridge, whose failed/expired refresh loop repeatedly opens browser login
# windows. Codex adds Vercel below using its supported native HTTP transport.
$McpServers["playwright"] = @{
  command = "cmd"
  args = @("/c", "npx", "-y", "@playwright/mcp@0.0.79")
}
$McpServers["chrome-devtools"] = @{
  command = "cmd"
  args = @("/c", "npx", "-y", "chrome-devtools-mcp@1.7.0")
}
$McpServers["ag-grid"] = @{
  command = "cmd"
  args = @("/c", "npx", "-y", "ag-mcp")
}
$McpServers["railway"] = @{
  command = "cmd"
  args = @("/c", "npx", "-y", "mcp-remote@0.1.38", "https://mcp.railway.com")
}

# codex-cli (stdio). Deliberately NOT wrapped in the op launcher: Codex carries
# its own `codex login` session, so there is no token to inject.
#
# CRITICAL - use Get-CodexBin, NOT ...\Programs\OpenAI\Codex\bin. That visible path
# is a JUNCTION to the package's bin\, and its parent has no sibling
# codex-resources\ directory. Codex looks for its sandbox helper at
# <exe_dir>\..\codex-resources\, so through the junction the helper is unreachable
# and EVERY sandboxed write fails ("program not found") while --version and
# `codex login status` still pass. Verified 2026-07-16: the same binary fails via
# the junction and succeeds via the real package bin.
# Use Codex's OWN `codex mcp-server` (official, stdio) rather than a third-party
# npx wrapper. Verified 2026-07-16 end-to-end: exposes `codex` (prompt, model,
# sandbox, approval-policy, cwd, config, *-instructions) and `codex-reply`
# (thread continuation), and a tools/call with sandbox=workspace-write really
# writes files. Why native:
#   - no third-party supply chain and no npx download in the hot path;
#   - version-locked to the CLI it ships with;
#   - a wrapper shells out to `codex` resolved from PATH, which re-introduces the
#     junction bug above; pointing at the absolute exe cannot resolve wrong.
# Trade-off accepted: we lose the wrapper's changeMode/batch/brainstorm extras,
# which are reproducible by prompting the `codex` tool.
$codexBin = Get-CodexBin
$codexExe = if ($codexBin) { Join-Path $codexBin "codex.exe" } else { $null }
# Codex jobs run long; don't let the MCP call time out at the default.
$codexEnv = @{ MCP_TOOL_TIMEOUT = "3600000" }

if ($codexExe -and (Test-Path -LiteralPath $codexExe)) {
  # Absolute path: the MSIX sandbox does not inherit the user PATH, and an
  # absolute exe also sidesteps PATH resolution picking a broken shim.
  $McpServers["codex-cli"] = @{
    command = $codexExe
    args    = @("mcp-server")
    env     = $codexEnv
  }
  Ok "codex-cli -> native mcp-server ($codexExe)"
} elseif ($cmd = Get-Command codex -ErrorAction SilentlyContinue) {
  # No standalone package (e.g. npm-global install). Use what's on PATH, but say
  # so plainly - we have not proven this one's sandbox can write.
  $McpServers["codex-cli"] = @{
    command = $cmd.Source
    args    = @("mcp-server")
    env     = $codexEnv
  }
  Warn "codex-cli -> $($cmd.Source) (non-standalone; run 'ai-devops doctor' to prove its sandbox can write)"
} else {
  Warn "Codex CLI not found - codex-cli MCP NOT configured."
  Warn "  Install Codex, run: codex login, then re-run this script."
}

# --------------------------------------------------------------------------
# 5d-2. PROJECT-SCOPED MCP SERVERS
#
# WHY THIS EXISTS (measured on edge-dev, 2026-08-26):
# Claude Code starts EVERY globally-configured MCP server in EVERY session, in
# EVERY repository. With 11 global servers and 22 open Claude Desktop sessions
# that was 416 node processes holding 18.1 GB of RAM on a 32 GB machine:
#   1password 58 procs / 3.6 GB   chrome-devtools 63 / 2.8 GB
#   trigger   42 / 1.7 GB         supabase 42 / 1.7 GB
#   playwright 42 / 1.7 GB        ag-grid  42 / 1.5 GB
#   railway   29 / 1.4 GB
# Nothing was leaking; the config was simply asking for all of it every time.
#
# THE RULE: a server that only ONE project ever uses must NOT be global. It is
# declared here and written into that project's own .mcp.json, so it starts only
# in sessions opened in that repository.
#
# Ownership decided by Albert, 2026-08-26. Add to this map, never to the global
# set, when a new server serves a single project.
$McpProjectScope = [ordered]@{
  "trigger"          = "oracle"
  "recall-ai"        = "oracle"
  "railway"          = "popdam3"
  "ag-grid"          = "designflow-frontend"
  "devops-mcp"       = "synology-monitor"
  "synology-monitor" = "synology-monitor"
}

# WHERE THE PROJECT FILE COMES FROM
#
# The authority is the .mcp.json COMMITTED IN EACH PROJECT REPO. That file travels
# with git, so it reaches every machine (Windows and the hetz Ubuntu VPS), every
# fresh clone, every EXTRA clone that lands in a sibling directory, and every
# linked worktree - none of which this script knows about or could enumerate.
#
# This step is therefore a BOOTSTRAP CONVENIENCE only: it seeds the file on this
# machine so it can be committed once. Do NOT make it the source of truth, and
# never hardcode a single repo root - checkouts live under different roots on
# different machines.
#
# Candidate roots are probed in order; the first that contains the project wins.
$McpProjectRoots = @(
  (Join-Path $env:USERPROFILE "repos"),
  "C:\repos",
  "D:\repos",
  "/worksp"
) | Where-Object { Test-Path -LiteralPath $_ }

# Projects whose servers must NOT be seeded from Windows. synology-monitor is
# worked on ~90% of the time from the hetz Ubuntu VPS; the Windows definitions
# point at .cmd launchers that do not exist there, and a committed Windows seed
# would break the machine that repo is actually used from.
$McpProjectWindowsSkip = @("synology-monitor")

# Servers that stay global: needed from any repository. NOTE this is the
# INTENTION, not the outcome - a project-scoped server still stays global if its
# checkout is missing or unwritable. The actual prune list is $McpScopedDone,
# computed in step 5d-3.
$McpGlobalNames = @($McpServers.Keys | Where-Object { -not $McpProjectScope.Contains($_) })

$McpServerList = ($McpGlobalNames -join ", ")
Ok "Global server set: $McpServerList"
Ok "Project-scoped:    $(($McpProjectScope.Keys) -join ', ')"

# --------------------------------------------------------------------------
# 5b. Restore the 916-alien SSH key (Windows dev machines -> hetz VPS)
# --------------------------------------------------------------------------
# Reads the private + public key from 1Password at runtime (via op) and writes
# them to ~\.ssh with a user-only ACL. Private keys need LF newlines and a
# trailing newline, so we write bytes explicitly rather than via Set-Content.
Step "SSH key: 916-alien (Windows dev machines -> hetz VPS)"
$sshDir  = Join-Path $HOME ".ssh"
$keyPath = Join-Path $sshDir "916-alien"
$privRef = "op://vibe_coding/916-alien SSH key/private key"
$pubRef  = "op://vibe_coding/916-alien SSH key/public key"
$priv = & op read $privRef 2>$null
if ($LASTEXITCODE -eq 0 -and $priv) {
  New-Item -ItemType Directory -Force -Path $sshDir | Out-Null
  # op read returns lines as an array; rejoin with LF and guarantee trailing LF.
  $privText = (($priv -join "`n") -replace "`r`n", "`n")
  if (-not $privText.EndsWith("`n")) { $privText += "`n" }
  $keyBackup = Set-AiDevOpsPrivateFileAtomic -Path $keyPath -Bytes ([Text.Encoding]::UTF8.GetBytes($privText))
  $pub = & op read $pubRef 2>$null
  if ($LASTEXITCODE -eq 0 -and $pub) {
    [System.IO.File]::WriteAllText("$keyPath.pub", ((($pub -join " ").Trim()) + "`n"))
  }
  Ok "Restored $keyPath (+ .pub), verified private ACL"
  if ($keyBackup) { Note "Previous protected key retained at $keyBackup" }
} else {
  Warn "Could not read '$privRef' from 1Password - skipping SSH key restore."
  Warn "  (Item missing, or the service-account token lacks access. Not fatal.)"
}

# --------------------------------------------------------------------------
# 5c. SSH config - host aliases (ssh vps / vps2 / coolify / seafile / ...)
# --------------------------------------------------------------------------
# Installed as ~/.ssh/ai-devops.conf and Included FIRST from ~/.ssh/config.
# OpenSSH uses the first value it finds for each setting, so placing this Include
# last allowed stale blocks left by the old Dropbox script to override it.
Step "SSH config (host aliases: vps, vps2, coolify, seafile, ...)"
$aidevConf = Join-Path $sshDir "ai-devops.conf"
$mainConf  = Join-Path $sshDir "config"
if (Test-Path $sshTmpl) {
  New-Item -ItemType Directory -Force -Path $sshDir | Out-Null
  Copy-Item $sshTmpl $aidevConf -Force
  try { icacls $aidevConf /inheritance:r | Out-Null; icacls $aidevConf /grant:r "$($env:USERNAME):(R,W)" | Out-Null } catch {}
  $incLine = "Include ai-devops.conf"
  if (-not (Test-Path $mainConf)) {
    Set-Content -Path $mainConf -Value $incLine -Encoding ascii
    try { icacls $mainConf /inheritance:r | Out-Null; icacls $mainConf /grant:r "$($env:USERNAME):(R,W)" | Out-Null } catch {}
    Ok "Created ~/.ssh/config with Include ai-devops.conf"
  } else {
    $mainText = [System.IO.File]::ReadAllText($mainConf)
    $withoutManagedInclude = [regex]::Replace(
      $mainText,
      '(?im)^\s*#\s*ai-devops managed host aliases[^\r\n]*\r?\n\s*Include\s+ai-devops\.conf\s*\r?\n?|^\s*Include\s+ai-devops\.conf\s*\r?\n?',
      ''
    ).TrimStart("`r", "`n")
    $newMainText = if ($withoutManagedInclude) { "$incLine`r`n`r`n$withoutManagedInclude" } else { "$incLine`r`n" }
    [System.IO.File]::WriteAllText($mainConf, $newMainText, [System.Text.Encoding]::ASCII)
    try { icacls $mainConf /inheritance:r | Out-Null; icacls $mainConf /grant:r "$($env:USERNAME):(R,W)" | Out-Null } catch {}
    Ok "Placed 'Include ai-devops.conf' first in ~/.ssh/config (managed aliases are authoritative)"
  }
} else {
  Warn "Missing $sshTmpl - skipping SSH config."
}

# --------------------------------------------------------------------------
# 5d. SSH known hosts - verified server identity keys
# --------------------------------------------------------------------------
# Keep the public server keys in source control so a fresh Windows setup can
# connect without an interactive trust prompt.  A changed entry is recoverable:
# preserve the complete prior file before replacing only the managed host entry.
Step "SSH known hosts (verified server keys)"
$knownHosts = Join-Path $sshDir "known_hosts"
$knownHostsSync = Join-Path $RepoPath "bin\sync-ssh-known-hosts.ps1"
if ((Test-Path $knownHostsTmpl) -and (Test-Path $knownHostsSync)) {
  try { & $knownHostsSync -TemplatePath $knownHostsTmpl -KnownHostsPath $knownHosts } catch { Warn "Could not install managed SSH server keys: $_" }
} else { Warn "Managed SSH server-key source is missing - skipping it." }

# --------------------------------------------------------------------------
# 5d-3. Seed project-scoped MCP servers into each project's own .mcp.json
#
# THIS MUST RUN BEFORE THE GLOBAL CONFIGS ARE WRITTEN. Claude Code may only drop
# a server from the global config once that server actually reached a project
# file. Pruning unconditionally is how a server ends up configured NOWHERE -
# found by review 2026-08-26 after the same bug was fixed on the Linux side.
#
# Claude Code reads .mcp.json from the repository root and starts those servers
# ONLY in sessions opened there. Claude Desktop and Codex have no equivalent, so
# they keep the FULL set (see step 5d-2).
#
# The AUTHORITY is the .mcp.json committed in the project repo; this only seeds
# it. Entries the repo already owns are never overwritten, and any project this
# cannot write is reported and its servers stay global.
# --------------------------------------------------------------------------
Step "Project-scoped MCP servers (per-repo .mcp.json)"

# Names that genuinely reached a project file. ONLY these may be pruned from the
# Claude Code global config.
$McpScopedDone = @()

# Replace this machine's profile path with ${USERPROFILE}, recursively.
#
# Substitute on the STRINGS, not on ConvertTo-Json output: PowerShell encodes
# C:\Users\foo as C:\\Users\\foo, so a literal .Replace on the JSON text matches
# nothing and the real path ships. Confirmed empirically 2026-08-26.
function ConvertTo-AiDevOpsPortableMcp {
  param($Value)
  if ($Value -is [string]) {
    if ($env:USERPROFILE) { return $Value.Replace($env:USERPROFILE, '${USERPROFILE}') }
    return $Value
  }
  if ($Value -is [System.Collections.IDictionary]) {
    $out = @{}
    foreach ($k in $Value.Keys) { $out[$k] = ConvertTo-AiDevOpsPortableMcp $Value[$k] }
    return $out
  }
  if ($Value -is [System.Collections.IEnumerable]) {
    return @($Value | ForEach-Object { ConvertTo-AiDevOpsPortableMcp $_ })
  }
  return $Value
}

$McpByProject = @{}
foreach ($name in $McpProjectScope.Keys) {
  $proj = $McpProjectScope[$name]
  if (-not $McpByProject.ContainsKey($proj)) { $McpByProject[$proj] = @() }
  $McpByProject[$proj] += $name
}

foreach ($proj in $McpByProject.Keys) {
  $names   = $McpByProject[$proj]
  $projDir = $null
  foreach ($root in $McpProjectRoots) {
    # Some projects live one level down inside a parent checkout
    # (dflow_plm/designflow-frontend). Probe both, exactly like the Linux script.
    foreach ($candidate in @((Join-Path $root $proj), (Join-Path $root (Join-Path "dflow_plm" $proj)))) {
    # Require a real git checkout. A bare directory of the same name - a leftover
    # folder, or a coincidental name in the home directory - would otherwise get
    # a seeded .mcp.json that is never committed, while the server is pruned from
    # the global config. `.git` is a FILE in a linked worktree, so test both.
      if (Test-Path -LiteralPath (Join-Path $candidate ".git")) { $projDir = $candidate; break }
    }
    if ($projDir) { break }
  }

  if (-not $projDir) {
    Warn "No git checkout found under any known root, skipped: $proj"
    Warn "  owns: $($names -join ', ') - these STAY GLOBAL so they keep working."
    Warn "  roots probed: $($McpProjectRoots -join ', ')"
    continue
  }

  # A project whose servers only work on another OS must never be seeded here:
  # the Windows definitions point at .cmd launchers that do not exist on Linux,
  # and committing them would break the machine that repo is actually used from.
  if ($McpProjectWindowsSkip -contains $proj) {
    Warn "Seeding $proj from Windows is not allowed; left GLOBAL."
    Warn "  owns: $($names -join ', ')"
    Warn "  Its .mcp.json must be authored on Linux (see docs/mcp-server-scope.md)."
    continue
  }

  # A GITIGNORED .mcp.json can never travel. Seeding it would work on THIS
  # machine while every other clone, worktree and machine has the server
  # nowhere - the authority is the COMMITTED file. Found live on the hetz VPS
  # 2026-08-26: synology-monitor ignores .mcp.json at .gitignore:54.
  # Fail safe: leave the servers global, which works, and say why.
  & git -C $projDir check-ignore -q ".mcp.json" 2>$null
  if ($LASTEXITCODE -eq 0) {
    Warn "$proj ignores .mcp.json - a seed there would never be committed."
    Warn "  $($names -join ', ') left GLOBAL so every clone keeps working."
    Warn "  Do NOT just un-ignore it: that rule can be a deliberate safeguard."
    Warn "  synology-monitor ignores it because the file has held a raw NAS"
    Warn "  token and one already leaked. See docs/mcp-server-scope.md."
    continue
  }

  $projCfg = Join-Path $projDir ".mcp.json"

  # Never overwrite an entry the repo already owns: it may have been made
  # portable by hand for a non-Windows machine (the hetz Ubuntu VPS).
  $alreadyOwned = @()
  if (Test-Path -LiteralPath $projCfg) {
    try {
      $existing = Get-Content -LiteralPath $projCfg -Raw | ConvertFrom-Json
    } catch {
      Warn "$projCfg is not valid JSON - left alone."
      Warn "  $($names -join ', ') STAY GLOBAL so they keep working."
      continue
    }
    if ($existing.mcpServers) {
      $alreadyOwned = @($names | Where-Object { $existing.mcpServers.PSObject.Properties.Name -contains $_ })
    }
  }
  if ($alreadyOwned) {
    Note "$proj already carries: $($alreadyOwned -join ', ') - left untouched"
    $McpScopedDone += $alreadyOwned
  }
  $toWrite = @($names | Where-Object { $alreadyOwned -notcontains $_ })
  if (-not $toWrite) { continue }

  # FAIL SAFE, NEVER FAIL CLOSED: an unwritable directory, a full disk or a
  # read-only checkout must not cost the capability. On failure the servers stay
  # global, where they still work.
  try {
    if (-not (Test-Path -LiteralPath $projCfg)) { '{}' | Set-Content -LiteralPath $projCfg -Encoding utf8 }
    $projResult = Update-AiDevOpsJsonFileAtomic -Path $projCfg -Depth 12 -Update {
      param($cfg)
      if (-not $cfg.ContainsKey("mcpServers")) { $cfg["mcpServers"] = @{} }
      foreach ($n in $toWrite) {
        $cfg["mcpServers"][$n] = ConvertTo-AiDevOpsPortableMcp $McpServers[$n]
      }
      return $cfg
    }
  } catch {
    Warn "Could not write $projCfg ($($_.Exception.Message))"
    Warn "  $($toWrite -join ', ') STAY GLOBAL so they keep working."
    continue
  }

  $McpScopedDone += $toWrite
  Ok "$projCfg <- $($toWrite -join ', ')"
  if ($projResult.Backup) { Note "  protected prior JSON: $($projResult.Backup)" }

}

if ($McpScopedDone) { Ok "Project-scoped and safe to prune globally: $($McpScopedDone -join ', ')" }
else                { Note "Nothing reached a project file; every server stays global." }

# --------------------------------------------------------------------------
# 6. Best-effort: wire MCP servers into Claude Desktop config
# --------------------------------------------------------------------------
if ($SkipDesktopMcp) {
  Step "Skipping Claude Desktop config (-SkipDesktopMcp)"
} else {
  Step "Wiring MCP servers into Claude Desktop (best-effort)"
  # The Store/MSIX install keeps the REAL config here (the "Edit Config" button
  # opens the wrong %APPDATA% copy - do not use it).
  $msix = Join-Path $env:LOCALAPPDATA "Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude_desktop_config.json"
  $std  = Join-Path $env:APPDATA "Claude\claude_desktop_config.json"
  $cfgPath = if (Test-Path (Split-Path $msix)) { $msix } elseif (Test-Path (Split-Path $std)) { $std } else { $null }

  if (-not $cfgPath) {
    Warn "Could not find a Claude Desktop config folder. Is Claude Desktop installed and run once?"
    Warn "Expected (MSIX): $msix"
  } else {
    New-Item -ItemType Directory -Force -Path (Split-Path $cfgPath) | Out-Null
    $desktopResult = Update-AiDevOpsJsonFileAtomic -Path $cfgPath -Depth 12 -Update {
      param($cfg)
      if (-not $cfg.ContainsKey("mcpServers")) { $cfg["mcpServers"] = @{} }
      # CLAUDE DESKTOP GETS THE FULL SET, INCLUDING PROJECT-SCOPED NAMES.
      #
      # .mcp.json is a Claude CODE mechanism. Claude Desktop has no per-project
      # scope at all, so removing a name here does not move it anywhere - it
      # deletes the capability outright. Same reasoning as Codex (step 5d-2).
      # Desktop therefore keeps every server; only Claude Code is scoped.
      foreach ($name in $McpServers.Keys) { $cfg["mcpServers"][$name] = $McpServers[$name] }
      $null = $cfg["mcpServers"].Remove("vercel")
      return $cfg
    }
    Ok "Updated $cfgPath atomically"
    if ($desktopResult.Backup) {
      Ok "  protected prior JSON: $($desktopResult.Backup)"
      Note "  recovery: Copy-Item -LiteralPath '$($desktopResult.Backup)' -Destination '$cfgPath' -Force"
    }
    Ok "Wired token-free: $McpServerList - no tokens in the file"
    Warn "KNOWN FAULT (seen 2026-08-20): the app itself rewrites this file and"
    Warn "  DELETES the whole mcpServers block - every other key survives, no error,"
    Warn "  no org blocklist involved. Settings > Developer (not Connectors) is the"
    Warn "  screen that reads it; after a wipe it shows 0 servers. If you re-run this"
    Warn "  script and they vanish again, re-installing them is a band-aid - the app"
    Warn "  version has stopped honouring the file. Claude Code is NOT affected; it"
    Warn "  reads ~/.claude.json (step 7)."
    Warn "VALIDATE ON THIS MACHINE: fully quit and reopen Claude Desktop, then confirm"
    Warn "  these MCPs show connected: $McpServerList."
  }
}

# --------------------------------------------------------------------------
# 6b. Codex on PATH - make `codex exec` actually able to write
# --------------------------------------------------------------------------
# The standalone installer puts ...\Programs\OpenAI\Codex\bin on PATH, but that dir
# is a JUNCTION to the package's bin\ and its parent has no codex-resources\
# sibling. Codex resolves its sandbox helper at <exe_dir>\..\codex-resources\, so
# via that PATH entry every sandboxed write fails with "program not found" - while
# `codex --version` and `codex login status` still succeed. That combination
# (healthy-looking, silently non-functional) cost a full debugging session on
# 2026-07-16. Fix: put the real package bin FIRST on the user PATH. `current` is a
# junction the updater re-points, so this survives Codex upgrades.
Step "Codex PATH (sandbox-capable binary first)"
$codexRealBin = Get-CodexBin
if (-not $codexRealBin) {
  Warn "No sandbox-capable standalone Codex found; leaving PATH alone."
  Warn "  If you use codex, install it and re-run this script."
} else {
  $userPath = [Environment]::GetEnvironmentVariable("PATH","User")
  $entries  = @($userPath -split ';' | Where-Object { $_ -ne '' })
  if ($entries.Count -gt 0 -and $entries[0].TrimEnd('\') -ieq $codexRealBin.TrimEnd('\')) {
    Ok "already first on user PATH ($codexRealBin)"
  } else {
    # Drop any existing copy, then prepend, so it always wins.
    $kept = $entries | Where-Object { $_.TrimEnd('\') -ine $codexRealBin.TrimEnd('\') }
    [Environment]::SetEnvironmentVariable("PATH", ((@($codexRealBin) + $kept) -join ';'), "User")
    Ok "prepended to user PATH: $codexRealBin"
    Note "Open a NEW terminal for this to take effect."
  }
  # Prove it: a real sandboxed write. --version cannot detect this failure mode.
  $probe = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-probe-" + [Guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $probe -Force | Out-Null
  try {
    Push-Location $probe
    & (Join-Path $codexRealBin "codex.exe") exec --sandbox workspace-write --skip-git-repo-check `
        -c model_reasoning_effort='low' `
        'Create a file named probe.txt in the current working directory containing exactly: OK. Then stop.' *> $null
    Pop-Location
    if (Test-Path -LiteralPath (Join-Path $probe "probe.txt")) {
      Ok "verified: codex sandbox can write"
    } else {
      Warn "codex sandbox still cannot write - `codex exec` will silently do nothing."
      Warn "  Check: $codexRealBin\..\codex-resources\codex-windows-sandbox-setup.exe"
    }
  } catch {
    Warn "codex sandbox probe could not run: $($_.Exception.Message)"
  } finally {
    Remove-Item -Recurse -Force $probe -ErrorAction SilentlyContinue
  }
}

# --------------------------------------------------------------------------
# 6c. Repo-owned local AI command launchers
# --------------------------------------------------------------------------
Step "Local AI command launchers"
$machineToolsInstaller = Join-Path $RepoPath "bin\install-machine-tools.ps1"
if (Test-Path -LiteralPath $machineToolsInstaller) {
  & $machineToolsInstaller -RepoPath $RepoPath
  Ok "catalog-driven AI command launchers installed"
} else {
  Warn "$machineToolsInstaller is missing; local AI commands were not installed."
}
if (Get-Command kimi -ErrorAction SilentlyContinue) {
  try {
    $kimiVersion = (& kimi --version 2>$null) -join " "
    if ([string]::IsNullOrWhiteSpace($kimiVersion)) { Ok "kimi found" }
    else { Ok "kimi found: $kimiVersion" }
    Note "Verify auth when needed with: kimi -p `"reply with OK`""
  } catch {
    Warn "kimi exists but `kimi --version` failed: $($_.Exception.Message)"
  }
} else {
  Warn "Kimi Code CLI not found; the kimi-code-delegation skill is installed, but local Kimi jobs will not run."
  Warn "  Install Kimi Code CLI and run `kimi login` once, then re-run this script."
}
if (Get-Command qwen -ErrorAction SilentlyContinue) {
  try {
    $qwenVersion = (& qwen --version 2>$null) -join " "
    if ([string]::IsNullOrWhiteSpace($qwenVersion)) { Ok "qwen found" }
    else { Ok "qwen found: $qwenVersion" }
    Note "Verify the full integration when needed with: ai-qwen doctor --live"
  } catch {
    Warn "qwen exists but `qwen --version` failed: $($_.Exception.Message)"
  }
} else {
  Warn "Qwen Code CLI not found; the qwen-code skill is installed, but local Qwen jobs will not run."
  Warn "  Install the official Qwen Code CLI, configure Alibaba Coding Plan authentication, then run: ai-qwen doctor --live"
}

# --------------------------------------------------------------------------
# 7. Claude Code (CLI) MCP config - same token-free treatment
# --------------------------------------------------------------------------
# Claude Code reads local MCP servers from ~/.claude.json ONLY, separate from
# Claude Desktop's claude_desktop_config.json. An "mcpServers" block in
# ~/.claude/settings.json is silently IGNORED: it parses fine, it is right there
# when you open the file, and `claude mcp list` never sees one of them. This
# script wrote to settings.json until 2026-08-20, so every machine it set up in
# fact had ZERO Claude Code MCP servers while looking perfectly configured on
# disk - which is why "my MCP servers keep disappearing" kept coming back. Do NOT
# point this back at settings.json.
#
# It gets the SAME server set (step 5d) rather than its own list. Servers we do
# not define (Windows-MCP, claude-in-chrome, ...) and all other keys in the file
# are preserved untouched. Runs regardless of -SkipDesktopMcp (that flag is about
# Claude Desktop only).
Step "Token-free MCP for Claude Code (~/.claude.json)"
$ccConfig = Join-Path $HOME ".claude.json"
if (-not (Test-Path $ccConfig)) {
  Note "No ~/.claude.json yet - creating one."
}
$ccResult = Update-AiDevOpsJsonFileAtomic -Path $ccConfig -Depth 12 -Update {
  param($cc)
  if (-not $cc.ContainsKey("mcpServers")) { $cc["mcpServers"] = @{} }
  # Write every server, then remove ONLY the ones that actually reached a project
  # file in step 5d-3. Pruning a name whose project is missing, unwritable or
  # holds invalid JSON would leave that server configured NOWHERE.
  foreach ($name in $McpServers.Keys) { $cc["mcpServers"][$name] = $McpServers[$name] }
  foreach ($name in $McpScopedDone)   { $null = $cc["mcpServers"].Remove($name) }
  $null = $cc["mcpServers"].Remove("vercel")
  return $cc
}
Ok "Claude Code wired token-free: $McpServerList"

Step "Private memory sync"
if (Test-Path $gitBash) {
  # Windows path -> Git-bash POSIX path: C:\a\b -> /c/a/b
  $posix = "/" + ($RepoPath.Substring(0,1).ToLower()) + ($RepoPath.Substring(2) -replace '\\','/')
  $syncScript = "$posix/bin/ai-memory-sync"
  # Seed once now and fail visibly if the private hub cannot be verified.
  & $gitBash -lc "'$syncScript' pull"
  if ($LASTEXITCODE -ne 0) { throw "Private memory pull failed; schedule remains disabled." }

  # Task Scheduler launching bash.exe directly opens Windows Terminal whenever
  # the task runs.  Use the GUI-based Windows Script Host as a silent shim so
  # the sync stays in the background even when Windows Terminal is the default
  # console host.  The task limit also prevents a stalled git/network operation
  # from living forever, and IgnoreNew prevents overlapping syncs.
  $taskDir = Join-Path $HOME ".config\ai-devops"
  $taskLauncher = Join-Path $taskDir "ai-memory-sync-hidden.vbs"
  New-Item -ItemType Directory -Force -Path $taskDir | Out-Null
  $escapedBash = $gitBash.Replace('"', '""')
  $escapedSync = $syncScript.Replace('"', '""')
  $launcherBody = @"
Set shell = CreateObject("WScript.Shell")
exitCode = shell.Run("""$escapedBash"" -lc ""'$escapedSync' sync""", 0, True)
WScript.Quit exitCode
"@
  Set-Content -LiteralPath $taskLauncher -Value $launcherBody -Encoding ascii

  if ($EnableMemorySyncSchedule) {
    try {
    $action = New-ScheduledTaskAction -Execute "$env:WINDIR\System32\wscript.exe" `
      -Argument "//B //NoLogo `"$taskLauncher`""
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(30) `
      -RepetitionInterval (New-TimeSpan -Minutes 30)
    $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew `
      -ExecutionTimeLimit (New-TimeSpan -Minutes 15) -StartWhenAvailable
    $principal = New-ScheduledTaskPrincipal -UserId ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) `
      -LogonType Interactive -RunLevel Limited
    Register-ScheduledTask -TaskName "ai-memory-sync" -Action $action -Trigger $trigger `
      -Settings $settings -Principal $principal -Description "Silent AI memory sync every 30 minutes" `
      -Force -ErrorAction Stop | Out-Null
    Ok "Scheduled task 'ai-memory-sync' every 30 min (hidden; 15 min limit)"
    } catch {
      throw "Could not create the private memory scheduled task: $($_.Exception.Message)"
    }
  } else {
    $existingMemoryTask = Get-ScheduledTask -TaskName "ai-memory-sync" -ErrorAction SilentlyContinue
    if ($existingMemoryTask) {
      Disable-ScheduledTask -TaskName "ai-memory-sync" -ErrorAction Stop | Out-Null
      Ok "Scheduled task 'ai-memory-sync' remains disabled pending rollout qualification"
    } else {
      Ok "Private memory schedule not enabled (opt in with -EnableMemorySyncSchedule after qualification)"
    }
  }
} else {
  Warn "Git bash not found (install Git) - memory sync not scheduled."
}

# --------------------------------------------------------------------------
# 6c. Codex's OWN config (~/.codex/config.toml) - install the same complete MCP
# set built above. Codex-specific transport details are applied to a copy so the
# Claude Desktop/Code definitions remain unchanged.
# --------------------------------------------------------------------------
Step "Wiring the complete MCP server set into Codex"
$codexMcpSetup = Join-Path $RepoPath "bin\configure-codex-mcps.ps1"
if (Test-Path -LiteralPath $codexMcpSetup) {
  $CodexMcpServers = [ordered]@{}
  foreach ($name in $McpServers.Keys) {
    $copy = [ordered]@{}
    foreach ($key in $McpServers[$name].Keys) { $copy[$key] = $McpServers[$name][$key] }
    $CodexMcpServers[$name] = $copy
  }

  # Codex supports native Streamable HTTP and OAuth. Keep Vercel native so its
  # stored Codex OAuth session works; mcp-remote is only for Claude consumers.
  $CodexMcpServers['vercel'] = [ordered]@{
    url = 'https://mcp.vercel.com'
    startup_timeout_sec = 20
  }
  # Railway CLI 5.41.2 configures Codex's remote mode through its authenticated
  # CLI proxy. Match the official installer output so `railway login` owns OAuth.
  # Claude consumers retain the shared mcp-remote definition above.
  $CodexMcpServers['railway'] = [ordered]@{
    command = 'railway'
    args = @('mcp', 'proxy')
    startup_timeout_sec = 20
  }
  $CodexMcpServers['chrome-devtools']['env'] = [ordered]@{
    SystemRoot = $(if ($env:SystemRoot) { $env:SystemRoot } else { 'C:\Windows' })
    PROGRAMFILES = $(if ($env:ProgramFiles) { $env:ProgramFiles } else { 'C:\Program Files' })
  }
  $CodexMcpServers['chrome-devtools']['startup_timeout_sec'] = 20
  if ($CodexMcpServers.Contains('codex-cli')) {
    $CodexMcpServers['codex-cli']['tool_timeout_sec'] = 3600
  }

  & $codexMcpSetup -Servers $CodexMcpServers
} else {
  Warn "Missing $codexMcpSetup - Codex MCP server set left as-is."
}

# --------------------------------------------------------------------------
# Done + validation checklist
# --------------------------------------------------------------------------
Step "GLM server (local OpenCode, loopback only)"
# Installs the pinned OpenCode build, the canonical agents, the scheduled task, and
# the `ai-glm` command for PowerShell. It installs its own prerequisites (Git, Node,
# op, jq) via winget, so nothing here has to be done by hand. See docs/glm-opencode.md.
$glmSetup = Join-Path $RepoPath "bin\setup-opencode-glm.ps1"
if (Test-Path -LiteralPath $glmSetup) {
  try {
    & $glmSetup -RepoPath $RepoPath
    if ($LASTEXITCODE -ne 0) { throw "setup-opencode-glm.ps1 exited $LASTEXITCODE" }
    Ok "GLM runs locally: ai-glm is on PATH and the OpenCode server is healthy"
    $museSetup = Join-Path $RepoPath "bin\setup-opencode-muse.sh"
    if (Test-Path -LiteralPath $museSetup) {
      & $gitBash $museSetup
      if ($LASTEXITCODE -ne 0) { throw "setup-opencode-muse.sh exited $LASTEXITCODE" }
      Ok "Muse persistent protected conversations are installed: `$env:AI_MUSE_CALLER='codex'; ai-muse doctor"
    }
  } catch {
    # Loud, not silent: say what broke and what still works.
    Warn "Local GLM setup did not complete: $($_.Exception.Message)"
    Warn "Re-run by hand:  & '$glmSetup'"
    Warn "Until then, GLM is only reachable by running ai-glm on the Ubuntu host over SSH."
  }
} else {
  Warn "Missing $glmSetup - pull the latest ai-devops and re-run."
}

# Retired: bin\ai-glm-agent.ps1 (GLM inside a Claude Code child process). Remove any
# leftover PATH shim so a stale command cannot linger.
foreach ($stale in @((Join-Path $env:USERPROFILE ".local\bin\ai-glm-agent.cmd"),
                     (Join-Path $RepoPath "bin\ai-glm-agent.ps1"))) {
  if (Test-Path -LiteralPath $stale) { Remove-Item -Force -LiteralPath $stale; Note "removed retired $stale" }
}

Step "Done"
Write-Host "Setup summary:"
Write-Host "  token file : $TokenFile   (user-only)"
Write-Host "  references : $McpEnv"
Write-Host "  launcher   : $Launcher"
Write-Host "  remote launcher: $RemoteLauncher"
Write-Host "  ssh key    : $keyPath (+ .pub)"
Write-Host "  ssh config : $aidevConf (Included from ~/.ssh/config)"
Write-Host ""
Write-Host "Validate on this machine:" -ForegroundColor Cyan
Write-Host "  1. Run:  op run --env-file `"$McpEnv`" -- cmd /c echo ok"
Write-Host "     (should print 'ok' with no auth error)"
Write-Host "  2. Run:  cmd /c `"$RemoteLauncher`" https://mcp.designflow.app/mcp op://vibe_coding/f335s4oy3m6n74jmwj74hunrtu/devops_token"
Write-Host "     (mcp-remote should start and authenticate; Ctrl+C to stop)"
Write-Host "  3. Run:  ssh vps whoami   (should print 'root'; first cloudflared use may open a browser to sign in)"
Write-Host "  4. Fully quit and reopen Claude Desktop (MCP servers only re-read config on a full restart)."
Write-Host "  5. Confirm these MCPs show connected: $McpServerList"
Write-Host "  6. Ask Claude or Codex: 'Ask GLM for a read-only second opinion.'"
Write-Host ""
Write-Host "One manual step this script cannot do for you:" -ForegroundColor Yellow
Write-Host "  Windows-MCP is a Claude Desktop EXTENSION, not a config entry, so it must be"
Write-Host "  installed from the UI: Settings -> Extensions -> 'Windows MCP' -> Install,"
Write-Host "  then fully quit and reopen Claude Desktop. (Its dependency, uv, is already"
Write-Host "  installed by this script.)"
