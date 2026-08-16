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
  7. Wires the FULL MCP server set into BOTH Claude Desktop's
     claude_desktop_config.json and Claude Code's ~/.claude/settings.json (each
     backed up first). The set is defined exactly once, in step 5d, and both
     surfaces merge it - so a server added there reaches every surface on every
     machine, and a fresh machine ends up matching an established one.
       - stdio via the op launcher : supabase (--read-only), trigger, 1password
       - remote via mcp-remote shim: devops-mcp, synology-monitor, recall-ai
       - no secret, plain npx      : playwright, ag-grid, vercel (browser OAuth)
       - codex-cli                 : native `codex mcp-server`, absolute exe
     No token is ever written into either config; only URLs and op:// references.
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
    $RepoPath = Join-Path $env:USERPROFILE "repos\ai-devops"
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

# GitHub CLI creates its config folder with inheritance disabled on some Windows
# installations. Codex's restricted task account can then see the workspace but
# `gh` fails before it can run because config.yml is unreadable. Repair only that
# folder and grant only read/execute; credentials remain in Windows Credential
# Manager and no token is copied or exposed.
$repairGhAccess = Join-Path $RepoPath "bin\repair-codex-github-cli-access.ps1"
if (Get-Command gh -ErrorAction SilentlyContinue -and (Test-Path -LiteralPath $repairGhAccess)) {
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
  git clone https://github.com/u2giants/ai-devops.git $RepoPath
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
# 5d. The MCP server set - ONE definition, used by BOTH Claude Desktop and Code
# --------------------------------------------------------------------------
# Defined once, deliberately. Claude Desktop and Claude Code keeping separate
# hand-maintained server lists is the root cause of every gap this script has
# had: a server wired into one silently never existed in the other, and servers
# this script did not define survived only on machines that happened to already
# have them (created by the legacy Dropbox script) while being absent on any new
# machine. Both consumers below merge THIS hashtable, so anything added here
# reaches every surface on every machine. Add new servers HERE and nowhere else.
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
           "@supabase/mcp-server-supabase@latest", "--read-only",
           "--project-ref", $SupabaseProjectRef)
}

# devops-mcp + synology-monitor (remote/HTTP). Wired via the mcp-remote shim under
# the remote launcher, so the bearer token is resolved from 1Password at launch -
# never written into the config. Only the URL + op:// ref appear.
$McpServers["devops-mcp"] = @{
  command = "cmd"
  args = @("/c", $RemoteLauncher, "https://mcp.designflow.app/mcp",
           "op://vibe_coding/designflow-mcp/devops_token")
}
$McpServers["synology-monitor"] = @{
  command = "cmd"
  args = @("/c", $RemoteLauncher, "https://nas-mcp.designflow.app/mcp",
           "op://vibe_coding/designflow-mcp/nas_token")
}

# recall-ai (remote/HTTP). Same treatment. Until 2026-07-17 this token was
# hard-coded in plaintext in claude_desktop_config.json - the LAST plaintext
# secret left after the Phase 2 token-free pass, which missed it because nothing
# ever rewrote the recall-ai entry. --transport preserves the flag the working
# config used; the launcher passes %3+ through to mcp-remote untouched.
$McpServers["recall-ai"] = @{
  command = "cmd"
  args = @("/c", $RemoteLauncher, "https://us-east-1.recall.ai/mcp",
           "op://vibe_coding/dwvlpanu4odty3bjnmb5my5esy/password",
           "--transport", "http-first")
}

# trigger (stdio, npx). Wrapped in the launcher so `op` injects
# TRIGGER_ACCESS_TOKEN (from mcp.env) at launch - no token in the config.
$McpServers["trigger"] = @{
  command = "cmd"
  args = @("/c", $Launcher, "cmd", "/c", "npx", "-y", "trigger.dev@latest", "mcp")
}

# 1password (stdio, npx). The launcher reads the vault-locked service-account
# token from the user file into OP_SERVICE_ACCOUNT_TOKEN - exactly the var this
# MCP needs - so no token is written into the config either.
$McpServers["1password"] = @{
  command = "cmd"
  args = @("/c", $Launcher, "cmd", "/c", "npx", "-y", "@u2giants/1password-mcp")
}

# playwright / ag-grid - plain npx stdio servers, no secret of any kind.
# vercel is remote but authenticates with an interactive OAuth flow that
# mcp-remote opens in a browser, so it needs no token either - and must NOT go
# through the remote launcher, which would force a bearer header onto it.
$McpServers["playwright"] = @{
  command = "cmd"
  args = @("/c", "npx", "-y", "@playwright/mcp@latest")
}
$McpServers["ag-grid"] = @{
  command = "cmd"
  args = @("/c", "npx", "-y", "ag-mcp")
}
$McpServers["vercel"] = @{
  command = "cmd"
  args = @("/c", "npx", "-y", "mcp-remote@0.1.38", "https://mcp.vercel.com")
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

$McpServerList = ($McpServers.Keys -join ", ")
Ok "Server set: $McpServerList"

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
  [System.IO.File]::WriteAllText($keyPath, $privText)
  try {
    icacls $keyPath /inheritance:r | Out-Null
    icacls $keyPath /grant:r "$($env:USERNAME):(R,W)" | Out-Null
  } catch { Warn "Wrote key but could not tighten ACL: $_" }
  $pub = & op read $pubRef 2>$null
  if ($LASTEXITCODE -eq 0 -and $pub) {
    [System.IO.File]::WriteAllText("$keyPath.pub", ((($pub -join " ").Trim()) + "`n"))
  }
  Ok "Restored $keyPath (+ .pub), user-only ACL"
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
$sshTmpl   = Join-Path $RepoPath "config\ssh-config.template"
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
    $cfg = @{}
    if (Test-Path $cfgPath) {
      Copy-Item $cfgPath "$cfgPath.aidevops.bak" -Force
      try { $cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json -AsHashtable } catch { $cfg = @{} }
    }
    if (-not $cfg.ContainsKey("mcpServers")) { $cfg["mcpServers"] = @{} }

    # Merge the ONE server set defined in step 5d. Servers already present that we
    # do not define (Windows-MCP extension entries, anything hand-added) are left
    # untouched - this only ever adds or refreshes our own.
    foreach ($name in $McpServers.Keys) { $cfg["mcpServers"][$name] = $McpServers[$name] }
    ($cfg | ConvertTo-Json -Depth 12) | Set-Content -Path $cfgPath -Encoding utf8
    Ok "Updated $cfgPath (backup: $cfgPath.aidevops.bak)"
    Ok "Wired token-free: $McpServerList - no tokens in the file"
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
  Warn "  Install the official Qwen Code CLI, complete its OAuth flow, then run: ai-qwen doctor --live"
}

# --------------------------------------------------------------------------
# 7. Claude Code (CLI) MCP config - same token-free treatment
# --------------------------------------------------------------------------
# Claude Code reads its OWN ~/.claude/settings.json, separate from Claude Desktop.
# It gets the SAME server set (step 5d) rather than its own list: this section used
# to only rewrite trigger + 1password *if they already existed*, so it converted
# tokens but never created a server. On a new machine that left Claude Code with
# nothing, and any server added to Desktop silently never reached it. Servers we do
# not define (Windows-MCP, claude-in-chrome, ...) and all other settings keys are
# preserved untouched. Runs regardless of -SkipDesktopMcp (that flag is about
# Claude Desktop only).
Step "Token-free MCP for Claude Code (~/.claude/settings.json)"
$ccSettings = Join-Path $HOME ".claude\settings.json"
$cc = @{}
if (Test-Path $ccSettings) {
  Copy-Item $ccSettings "$ccSettings.aidevops.bak" -Force
  try { $cc = Get-Content $ccSettings -Raw | ConvertFrom-Json -AsHashtable } catch {
    Warn "$ccSettings is not valid JSON; leaving it alone. Fix or delete it and re-run."
    $cc = $null
  }
} else {
  New-Item -ItemType Directory -Force -Path (Split-Path $ccSettings) | Out-Null
  Note "No ~/.claude/settings.json yet - creating one."
}
if ($null -ne $cc) {
  if (-not $cc.ContainsKey("mcpServers")) { $cc["mcpServers"] = @{} }
  foreach ($name in $McpServers.Keys) { $cc["mcpServers"][$name] = $McpServers[$name] }
  ($cc | ConvertTo-Json -Depth 12) | Set-Content -Path $ccSettings -Encoding utf8
  Ok "Claude Code wired token-free: $McpServerList"
}

# --------------------------------------------------------------------------
# 8. Memory auto-sync - keep Claude memories in sync across machines
# --------------------------------------------------------------------------
# ai-memory-sync is a bash script (isolated clone + secret gate); run it through
# Git bash on a 30-minute schedule. Seeds once now, then a Scheduled Task keeps
# it going.
Step "Memory auto-sync (every 30 min)"
$gitBash = "C:\Program Files\Git\bin\bash.exe"
if (Test-Path $gitBash) {
  # Windows path -> Git-bash POSIX path: C:\a\b -> /c/a/b
  $posix = "/" + ($RepoPath.Substring(0,1).ToLower()) + ($RepoPath.Substring(2) -replace '\\','/')
  $syncScript = "$posix/bin/ai-memory-sync"
  # Seed once now.
  & $gitBash -lc "'$syncScript' pull" 2>$null

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
shell.Run """$escapedBash"" -lc ""'$escapedSync' >/dev/null 2>&1""", 0, True
"@
  Set-Content -LiteralPath $taskLauncher -Value $launcherBody -Encoding ascii

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
    Warn "Could not create the scheduled task: $($_.Exception.Message)"
    Warn "  Run '$syncScript' from Git bash to sync manually."
  }
} else {
  Warn "Git bash not found (install Git) - memory sync not scheduled."
}

# --------------------------------------------------------------------------
# 6c. Codex's OWN config (~/.codex/config.toml) - route 1Password through the
# shared caching launcher, so Codex shares the one single-flight refresh + DPAPI
# cache and carries NO plaintext service-account token. Codex reads its own file,
# which the Claude consumers above never touch; without this step the 1password
# block drifts back to a direct `npx` + inline token - outside the cache and a
# contributor to the per-hour rate-limit lockout. Idempotent; safe if Codex absent.
# --------------------------------------------------------------------------
Step "Routing Codex 1Password MCP through the caching launcher"
$codexFix = Join-Path $RepoPath "bin\configure-codex-1password.ps1"
if (Test-Path -LiteralPath $codexFix) {
  & pwsh -NoProfile -File $codexFix -Launcher $Launcher
} else {
  Warn "Missing $codexFix - Codex 1password left as-is."
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
Write-Host "  2. Run:  cmd /c `"$RemoteLauncher`" https://mcp.designflow.app/mcp op://vibe_coding/designflow-mcp/devops_token"
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
