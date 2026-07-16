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
  6. Restores the 916-alien SSH key from 1Password to ~\.ssh\916-alien (+ .pub)
     and installs the managed SSH host aliases (~/.ssh/ai-devops.conf, Included
     from ~/.ssh/config), so `ssh vps` / `ssh vps2` / `ssh seafile` etc. work
     immediately. Uses cloudflared so it works on any network without Tailscale.
  7. Best-effort: wires MCP servers into Claude Desktop's
     claude_desktop_config.json (backed up first) — supabase, trigger and
     1password (stdio, via the op launcher) plus devops-mcp and synology-monitor
     (remote, via the mcp-remote shim), plus codex-cli (stdio, no launcher — it
     has no token, only a PATH to the codex binary). No token is ever written into
     the config; only URLs and op:// references. Other servers already present
     (ag-grid, playwright, vercel, recall-ai, ...) are preserved untouched.

IMPORTANT — Claude Desktop limitations you must know (verified):
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
# Resolve the directory holding a USABLE codex.exe — one whose sandbox helper is
# reachable. Prefer the real standalone package bin
# (~\.codex\packages\standalone\current\bin) over the visible junction
# (…\Programs\OpenAI\Codex\bin): only `bin` is junctioned, so from the visible
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
if ([string]::IsNullOrWhiteSpace($RepoPath)) { $RepoPath = Join-Path $HOME "repos\ai-devops" }
$CfgDir    = Join-Path $HOME ".config\ai-devops"
$TokenFile = Join-Path $CfgDir "op-service-account"
$McpEnv    = Join-Path $CfgDir "mcp.env"
$Launcher  = Join-Path $CfgDir "mcp-launch.cmd"
$RemoteLauncher = Join-Path $CfgDir "mcp-remote-launch.cmd"

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

# cloudflared — used by the SSH config's ProxyCommand so `ssh vps` works on any network.
if (-not (Get-Command cloudflared -ErrorAction SilentlyContinue)) { Ensure-Winget "Cloudflare.cloudflared" "cloudflared" }
if (Get-Command cloudflared -ErrorAction SilentlyContinue) { Ok "cloudflared" } else { Warn "cloudflared not found; `ssh vps` (tunnel) will not work until it is installed." }

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
$launcherBody = @'
@echo off
rem [ai-devops] read the vault-locked service-account token from the user file,
rem then run the given MCP server under op with the central reference env-file.
rem No secret is stored in claude_desktop_config.json.
set /p OP_SERVICE_ACCOUNT_TOKEN=<"%USERPROFILE%\.config\ai-devops\op-service-account"
op run --no-masking --env-file="%USERPROFILE%\.config\ai-devops\mcp.env" -- %*
'@
Set-Content -Path $Launcher -Value $launcherBody -Encoding ascii
Ok "Wrote $Launcher"

# A second launcher for REMOTE/HTTP MCP servers. mcp-remote does NOT expand
# ${VAR} in --header, so the bearer token must be a real value before it runs.
# This reads the vault-locked token, `op read`s the bearer token IN MEMORY, and
# passes it to mcp-remote. Args carry the URL + the op:// reference only; the
# token itself is never written to disk or into claude_desktop_config.json.
#   %1 = server URL,  %2 = op:// reference to the bearer token
$remoteBody = @'
@echo off
setlocal
set /p OP_SERVICE_ACCOUNT_TOKEN=<"%USERPROFILE%\.config\ai-devops\op-service-account"
for /f "usebackq delims=" %%T in (`op read %2`) do set "TOK=%%T"
npx -y mcp-remote %1 --header "Authorization: Bearer %TOK%"
'@
Set-Content -Path $RemoteLauncher -Value $remoteBody -Encoding ascii
Ok "Wrote $RemoteLauncher"

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
  Warn "Could not read '$privRef' from 1Password — skipping SSH key restore."
  Warn "  (Item missing, or the service-account token lacks access. Not fatal.)"
}

# --------------------------------------------------------------------------
# 5c. SSH config — host aliases (ssh vps / vps2 / coolify / seafile / ...)
# --------------------------------------------------------------------------
# Installed as ~/.ssh/ai-devops.conf and Included from ~/.ssh/config at the END,
# so any host you already define keeps winning; only NEW aliases (e.g. vps2) are
# added. Never clobbers your existing config.
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
  } elseif (Select-String -Path $mainConf -SimpleMatch "ai-devops.conf" -Quiet) {
    Ok "~/.ssh/config already includes ai-devops.conf"
  } else {
    Add-Content -Path $mainConf -Value "`n# ai-devops managed host aliases (existing entries above still win)`n$incLine"
    Ok "Added 'Include ai-devops.conf' to ~/.ssh/config (appended; your entries win)"
  }
} else {
  Warn "Missing $sshTmpl — skipping SSH config."
}

# --------------------------------------------------------------------------
# 6. Best-effort: wire MCP servers into Claude Desktop config
# --------------------------------------------------------------------------
if ($SkipDesktopMcp) {
  Step "Skipping Claude Desktop config (-SkipDesktopMcp)"
} else {
  Step "Wiring MCP servers into Claude Desktop (best-effort)"
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
    # both run through a shell (spawn cannot run batch files directly). op run
    # injects SUPABASE_ACCESS_TOKEN (from mcp.env) into the server's environment.
    $cfg["mcpServers"]["supabase"] = @{
      command = "cmd"
      args = @("/c", $Launcher, "cmd", "/c", "npx", "-y",
               "@supabase/mcp-server-supabase@latest", "--project-ref", $SupabaseProjectRef)
    }

    # devops-mcp + synology-monitor (remote/HTTP). Wired via the mcp-remote shim
    # under the remote launcher, so the bearer token is resolved from 1Password
    # at launch — never written into this config. Only the URL + op:// ref appear.
    $cfg["mcpServers"]["devops-mcp"] = @{
      command = "cmd"
      args = @("/c", $RemoteLauncher, "https://mcp.designflow.app/mcp",
               "op://vibe_coding/designflow-mcp/devops_token")
    }
    $cfg["mcpServers"]["synology-monitor"] = @{
      command = "cmd"
      args = @("/c", $RemoteLauncher, "https://nas-mcp.designflow.app/mcp",
               "op://vibe_coding/designflow-mcp/nas_token")
    }

    # trigger (stdio, npx). Wrapped in the launcher so `op` injects
    # TRIGGER_ACCESS_TOKEN (from mcp.env) at launch — no token in this config.
    $cfg["mcpServers"]["trigger"] = @{
      command = "cmd"
      args = @("/c", $Launcher, "cmd", "/c", "npx", "-y", "trigger.dev@latest", "mcp")
    }

    # 1password (stdio, npx). The launcher reads the vault-locked service-account
    # token from the user file into OP_SERVICE_ACCOUNT_TOKEN — which is exactly the
    # var this MCP needs — so no token is written into this config either.
    $cfg["mcpServers"]["1password"] = @{
      command = "cmd"
      args = @("/c", $Launcher, "cmd", "/c", "npx", "-y", "@u2giants/1password-mcp")
    }

    # codex-cli (stdio, npx). Deliberately NOT wrapped in the op launcher: Codex
    # carries its own `codex login` session, so there is no token to inject. What it
    # does need is to FIND the codex binary — the MSIX sandbox does not inherit the
    # user PATH, so hand it an explicit PATH covering both install shapes
    # (standalone installer and npm-global).
    #
    # CRITICAL — use Get-CodexBin, NOT …\Programs\OpenAI\Codex\bin. That visible
    # path is a JUNCTION to the package's bin\, and its parent has no sibling
    # codex-resources\ directory. Codex looks for its sandbox helper at
    # <exe_dir>\..\codex-resources\, so through the junction the helper is
    # unreachable and EVERY sandboxed write fails ("program not found") while
    # --version and `codex login status` still pass. Verified 2026-07-16: the same
    # binary fails via the junction and succeeds via the real package bin.
    # Use Codex's OWN `codex mcp-server` (official, stdio) rather than a third-party
    # npx wrapper. Verified 2026-07-16 end-to-end: exposes `codex` (prompt, model,
    # sandbox, approval-policy, cwd, config, *-instructions) and `codex-reply`
    # (thread continuation), and a tools/call with sandbox=workspace-write really
    # writes files. Why native:
    #   - no third-party supply chain and no npx download in the hot path;
    #   - version-locked to the CLI it ships with;
    #   - a wrapper shells out to `codex` resolved from PATH, which re-introduces
    #     the junction bug above; pointing at the absolute exe cannot resolve wrong.
    # Trade-off accepted: we lose the wrapper's changeMode/batch/brainstorm extras,
    # which are reproducible by prompting the `codex` tool.
    $codexBin = Get-CodexBin
    $codexExe = if ($codexBin) { Join-Path $codexBin "codex.exe" } else { $null }
    # Codex jobs run long; don't let the MCP call time out at the default.
    $codexEnv = @{ MCP_TOOL_TIMEOUT = "3600000" }

    if ($codexExe -and (Test-Path -LiteralPath $codexExe)) {
      # Absolute path: the MSIX sandbox does not inherit the user PATH, and an
      # absolute exe also sidesteps PATH resolution picking a broken shim.
      $cfg["mcpServers"]["codex-cli"] = @{
        command = $codexExe
        args    = @("mcp-server")
        env     = $codexEnv
      }
      Ok "codex-cli MCP -> native mcp-server ($codexExe)"
    } elseif ($cmd = Get-Command codex -ErrorAction SilentlyContinue) {
      # No standalone package (e.g. npm-global install). Use what's on PATH, but say
      # so plainly — we have not proven this one's sandbox can write.
      $cfg["mcpServers"]["codex-cli"] = @{
        command = $cmd.Source
        args    = @("mcp-server")
        env     = $codexEnv
      }
      Warn "codex-cli MCP -> $($cmd.Source) (non-standalone; run 'ai-devops doctor' to prove its sandbox can write)"
    } else {
      Warn "Codex CLI not found — codex-cli MCP NOT configured."
      Warn "  Install Codex, run: codex login, then re-run this script."
    }

    ($cfg | ConvertTo-Json -Depth 12) | Set-Content -Path $cfgPath -Encoding utf8
    Ok "Updated $cfgPath (backup: $cfgPath.aidevops.bak)"
    Ok "Wired token-free: supabase, devops-mcp, synology-monitor, trigger, 1password, codex-cli — no tokens in the file"
    Warn "VALIDATE ON THIS MACHINE: fully quit and reopen Claude Desktop, then confirm"
    Warn "  these MCPs show connected: supabase, devops-mcp, synology-monitor, trigger, 1password, codex-cli."
  }
}

# --------------------------------------------------------------------------
# 6b. Codex on PATH — make `codex exec` actually able to write
# --------------------------------------------------------------------------
# The standalone installer puts …\Programs\OpenAI\Codex\bin on PATH, but that dir
# is a JUNCTION to the package's bin\ and its parent has no codex-resources\
# sibling. Codex resolves its sandbox helper at <exe_dir>\..\codex-resources\, so
# via that PATH entry every sandboxed write fails with "program not found" — while
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
      Warn "codex sandbox still cannot write — `codex exec` will silently do nothing."
      Warn "  Check: $codexRealBin\..\codex-resources\codex-windows-sandbox-setup.exe"
    }
  } catch {
    Warn "codex sandbox probe could not run: $($_.Exception.Message)"
  } finally {
    Remove-Item -Recurse -Force $probe -ErrorAction SilentlyContinue
  }
}

# --------------------------------------------------------------------------
# 7. Claude Code (CLI) MCP config — same token-free treatment
# --------------------------------------------------------------------------
# Claude Code reads its OWN ~/.claude/settings.json, separate from Claude Desktop.
# It historically stored the trigger + 1password tokens there in plaintext. Wrap
# both in the op launcher so no token sits in the file. All other servers (and all
# other settings keys) are preserved untouched. Runs regardless of -SkipDesktopMcp
# (that flag is about Claude Desktop only).
Step "Token-free MCP for Claude Code (~/.claude/settings.json)"
$ccSettings = Join-Path $HOME ".claude\settings.json"
if (Test-Path $ccSettings) {
  Copy-Item $ccSettings "$ccSettings.aidevops.bak" -Force
  $cc = $null
  try { $cc = Get-Content $ccSettings -Raw | ConvertFrom-Json -AsHashtable } catch { $cc = $null }
  if ($cc -and $cc.ContainsKey("mcpServers")) {
    $changed = $false
    if ($cc["mcpServers"].ContainsKey("trigger")) {
      $cc["mcpServers"]["trigger"] = @{
        command = "cmd"
        args = @("/c", $Launcher, "cmd", "/c", "npx", "-y", "trigger.dev@latest", "mcp")
      }
      $changed = $true
    }
    if ($cc["mcpServers"].ContainsKey("1password")) {
      $cc["mcpServers"]["1password"] = @{
        command = "cmd"
        args = @("/c", $Launcher, "cmd", "/c", "npx", "-y", "@u2giants/1password-mcp")
      }
      $changed = $true
    }
    if ($changed) {
      ($cc | ConvertTo-Json -Depth 12) | Set-Content -Path $ccSettings -Encoding utf8
      Ok "Rewired trigger + 1password token-free (backup: $ccSettings.aidevops.bak)"
    } else {
      Ok "No trigger/1password entries needed conversion"
    }
  } else {
    Warn "No mcpServers block in $ccSettings — skipping"
  }
} else {
  Note "No ~/.claude/settings.json (Claude Code not configured here) — skipping"
}

# --------------------------------------------------------------------------
# 8. Memory auto-sync — keep Claude memories in sync across machines
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
  $tr = '"' + $gitBash + '" -lc "''' + $syncScript + '''"'
  schtasks /Create /TN "ai-memory-sync" /SC MINUTE /MO 30 /TR $tr /F /RL LIMITED 2>$null | Out-Null
  if ($LASTEXITCODE -eq 0) { Ok "Scheduled task 'ai-memory-sync' every 30 min" }
  else { Warn "Could not create the scheduled task; run '$syncScript' from Git bash to sync manually." }
} else {
  Warn "Git bash not found (install Git) — memory sync not scheduled."
}

# --------------------------------------------------------------------------
# Done + validation checklist
# --------------------------------------------------------------------------
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
Write-Host "  4. Fully quit and reopen Claude Desktop."
Write-Host "  5. Confirm all three MCPs show connected: supabase, devops-mcp, synology-monitor."
