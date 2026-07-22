<#
====================================================================
  INTERNAL DEV COMPUTER TOOLCHAIN SETUP
  TRANSITIONAL/DEPRECATED. Called only by run_me_setup_dev_comp.bat. Do not run
  this helper directly. New setup work belongs in bootstrap-windows-dev.ps1,
  configuration.winget, or setup-machine.ps1.

  Installs (or UPDATES if already present):
    1.  Git for Windows        (needed by Claude & Codex)
    2.  Node.js LTS            (needed by Vercel & Trigger.dev)
    3.  Python 3.13 (native Windows)
    4.  GitHub CLI (gh)
    5.  Google Cloud SDK (gcloud)
    6.  Azure CLI (az)
    7.  Claude Code  (claude)   - native installer, self-updating
    8.  Codex for Windows       (desktop app, via Microsoft Store)
    9.  Vercel CLI   (vercel)   - via npm
   10.  Trigger.dev CLI         - via npm
   11.  Supabase CLI            - via Scoop (official Windows method)
   12.  WSL2 + Ubuntu
   13.  Ansible (inside Ubuntu)

  HOW TO RUN:
    Double-click "run_me_setup_dev_comp.bat". It launches this helper and
    asks for Administrator permission automatically.

  SAFE TO RE-RUN:
    Run it as many times as you like. It checks each tool first and
    only installs what's missing or out of date. You WILL need to run
    it a second time after the WSL2/Ubuntu reboot (the script tells
    you exactly when).
====================================================================
#>

# --------------------------------------------------------------------
# 0. SELF-ELEVATE (re-launch as Administrator if needed)
# --------------------------------------------------------------------
$amAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
   ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $amAdmin) {
    Write-Host "Asking for Administrator permission (a Windows popup will appear)..." -ForegroundColor Yellow
    $psi = "-NoExit -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process -FilePath "powershell.exe" -ArgumentList $psi -Verb RunAs
    exit
}

# Keep window readable
$ErrorActionPreference = "Continue"
$ProgressPreference    = "SilentlyContinue"   # speeds up downloads
$logFile = Join-Path $env:USERPROFILE "dev-setup-log.txt"
try { Start-Transcript -Path $logFile -Append | Out-Null } catch {}

# Collect a status row for the final summary: @{Tool; Status; Version}
$Results = New-Object System.Collections.ArrayList
function Add-Result($tool, $status, $version) {
    [void]$Results.Add([pscustomobject]@{ Tool = $tool; Status = $status; Version = $version })
}

function Banner($text) {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  $text" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
}
function Step($text) { Write-Host "[+] $text" -ForegroundColor Green }
function Warn($text) { Write-Host "[!] $text" -ForegroundColor Yellow }
function Fail($text) { Write-Host "[X] $text" -ForegroundColor Red }

# Refresh PATH for THIS window so tools we just installed are findable
function Update-SessionPath {
    $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $user    = [Environment]::GetEnvironmentVariable("Path", "User")
    $extra   = "$env:USERPROFILE\.local\bin;$env:USERPROFILE\scoop\shims"
    $env:Path = ($machine, $user, $extra | Where-Object { $_ } ) -join ";"
}

# Get a tool's version string, or $null if not on PATH
function Get-ToolVersion($cmd, $args = "--version") {
    $exe = Get-Command $cmd -ErrorAction SilentlyContinue
    if (-not $exe) { return $null }
    try {
        $out = & $cmd $args.Split(" ") 2>&1 | Select-Object -First 1
        return ($out | Out-String).Trim()
    } catch { return "installed" }
}

# Find EVERY copy of a command across the whole system before we decide
# anything. Looks at: the live PATH (all matches), common per-user install
# folders, WinGet/Store registrations, and Microsoft Store (Appx) packages.
# Returns a list of objects: @{ Path; Kind } where Kind is one of:
#   native | npm | scoop | cargo | store-alias | winget | appx | other
function Find-AllInstances($cmdName, $wingetId, $appxLike) {
    Update-SessionPath
    $found = New-Object System.Collections.ArrayList

    # 1) Everything currently resolvable on PATH (ALL matches, not just first)
    foreach ($m in @(Get-Command $cmdName -All -ErrorAction SilentlyContinue)) {
        $src = $m.Source
        if (-not $src) { continue }
        $kind = "other"
        if     ($src -like "*\WindowsApps\*")  { $kind = "store-alias" }
        elseif ($src -like "*\.local\bin\*")   { $kind = "native" }
        elseif ($src -like "*\npm\*")          { $kind = "npm" }
        elseif ($src -like "*\scoop\*")        { $kind = "scoop" }
        elseif ($src -like "*\.cargo\bin\*")   { $kind = "cargo" }
        [void]$found.Add([pscustomobject]@{ Path = $src; Kind = $kind })
    }

    # 2) Known per-user locations even if NOT on PATH right now
    $guesses = @(
        @{ p = "$env:USERPROFILE\.local\bin\$cmdName.exe";        k = "native" },
        @{ p = "$env:APPDATA\npm\$cmdName.cmd";                   k = "npm"    },
        @{ p = "$env:USERPROFILE\scoop\shims\$cmdName.exe";       k = "scoop"  },
        @{ p = "$env:USERPROFILE\.cargo\bin\$cmdName.exe";        k = "cargo"  }
    )
    foreach ($g in $guesses) {
        if ((Test-Path $g.p) -and -not ($found | Where-Object { $_.Path -eq $g.p })) {
            [void]$found.Add([pscustomobject]@{ Path = $g.p; Kind = $g.k })
        }
    }

    # 3) WinGet / Microsoft Store registration by id
    if ($wingetId -and (Get-Command winget -ErrorAction SilentlyContinue)) {
        $wl = (winget list --id $wingetId -e --accept-source-agreements 2>$null | Out-String)
        if ($wl -match [regex]::Escape($wingetId)) {
            [void]$found.Add([pscustomobject]@{ Path = "WinGet/Store: $wingetId"; Kind = "winget" })
        }
    }

    # 4) Microsoft Store (Appx/MSIX) packages by name
    if ($appxLike) {
        $apx = Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -like $appxLike -or $_.PackageFamilyName -like $appxLike
        }
        foreach ($a in $apx) {
            [void]$found.Add([pscustomobject]@{ Path = "Store app: $($a.Name)"; Kind = "appx" })
        }
    }

    return $found
}

Banner "DEV COMPUTER SETUP STARTING"
Write-Host "A full log is being saved to: $logFile" -ForegroundColor DarkGray

# --------------------------------------------------------------------
# 1. Make sure winget exists (Windows Package Manager)
# --------------------------------------------------------------------
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Fail "winget (Windows Package Manager) is not available."
    Warn "Open the Microsoft Store, search 'App Installer', and Update/Install it, then re-run."
    Add-Result "winget" "MISSING - install 'App Installer' from Microsoft Store" "-"
} else {
    Step "winget is available."
}

# Helper: install a winget package if missing, upgrade it if present
function Ensure-Winget($Id, $Name, $VerifyCmd = $null) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Add-Result $Name "SKIPPED (winget missing)" "-"; return
    }
    $listed = (winget list --id $Id -e --accept-source-agreements 2>$null | Out-String)
    if ($listed -match [regex]::Escape($Id)) {
        Step "$Name already installed - checking for updates..."
        winget upgrade --id $Id -e --silent --accept-package-agreements --accept-source-agreements 2>$null | Out-Null
    } else {
        Step "Installing $Name ..."
        winget install --id $Id -e --silent --accept-package-agreements --accept-source-agreements 2>$null | Out-Null
    }
    Update-SessionPath
    $ver = if ($VerifyCmd) { Get-ToolVersion $VerifyCmd } else { "installed" }
    if ($ver) { Add-Result $Name "OK" $ver } else { Add-Result $Name "Installed (restart terminal to verify)" "-" }
}

# --------------------------------------------------------------------
# 2. PREREQUISITES (Git, Node.js) + native-Windows tools
# --------------------------------------------------------------------
Banner "INSTALLING WINDOWS TOOLS"

Ensure-Winget "Git.Git"            "Git for Windows"  "git"
Ensure-Winget "OpenJS.NodeJS.LTS"  "Node.js (LTS)"    "node"
Ensure-Winget "Python.Python.3.13" "Python 3.13"      "python"
Ensure-Winget "Microsoft.PowerShell" "PowerShell 7"    "pwsh"
Ensure-Winget "GitHub.cli"         "GitHub CLI (gh)"  "gh"
Ensure-Winget "Google.CloudSDK"    "Google Cloud SDK" "gcloud"
Ensure-Winget "Microsoft.AzureCLI" "Azure CLI (az)"   "az"

Update-SessionPath

# --------------------------------------------------------------------
# 3. CLAUDE CODE (native installer - self-updating)
# --------------------------------------------------------------------
Banner "CLAUDE CODE"
# Discover EVERY Claude Code install first, then decide. (A copy inside
# WSL/Ubuntu is a separate Linux install and won't appear here.)
# NOTE: the Microsoft Store app literally named "Claude" is the Claude DESKTOP
# CHAT app - a different product - so we do NOT treat that as Claude Code.
$claudeAll = @(Find-AllInstances "claude" "Anthropic.ClaudeCode" $null)

if ($claudeAll.Count -gt 0) {
    Step "Found existing Claude Code install(s):"
    foreach ($i in $claudeAll) { Write-Host "      - [$($i.Kind)] $($i.Path)" -ForegroundColor Gray }
} else {
    Step "No existing Claude Code found anywhere on this machine."
}

$nativeClaude = ($claudeAll | Where-Object { $_.Kind -eq "native" } | Select-Object -First 1)
$wingetClaude = ($claudeAll | Where-Object { $_.Kind -eq "winget" } | Select-Object -First 1)
$anyClaude    = ($claudeAll | Where-Object { $_.Kind -in @("native","npm","scoop","store-alias","winget") } | Select-Object -First 1)

if ($nativeClaude) {
    Step "Updating the native install in place (no second copy)..."
    try { & $nativeClaude.Path update 2>&1 | Out-Null } catch {}
    Update-SessionPath
    $ver = Get-ToolVersion "claude"
    Add-Result "Claude Code" "OK (native, updated)" ($(if($ver){$ver}else{"-"}))
}
elseif ($wingetClaude) {
    Step "Updating the WinGet/Store install through WinGet (no second copy)..."
    winget upgrade --id Anthropic.ClaudeCode -e --silent --accept-package-agreements --accept-source-agreements 2>$null | Out-Null
    Add-Result "Claude Code" "OK (WinGet/Store, updated)" "managed by winget"
}
elseif ($anyClaude) {
    Step "Claude Code is present ($($anyClaude.Kind)); leaving it as-is and not adding another copy."
    Add-Result "Claude Code" "OK (existing: $($anyClaude.Kind))" "-"
}
else {
    Step "Installing the native Claude Code build..."
    try { Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression } catch { Fail "Claude install error: $_" }
    Update-SessionPath
    $ver = Get-ToolVersion "claude"
    if ($ver) { Add-Result "Claude Code" "OK (installed)" $ver } else { Add-Result "Claude Code" "Installed (restart terminal to verify)" "-" }
}

# --------------------------------------------------------------------
# 4. CODEX FOR WINDOWS (desktop app - Microsoft Store / MSIX)
# --------------------------------------------------------------------
Banner "CODEX FOR WINDOWS (desktop app)"
# You want the DESKTOP APP, not the CLI. We discover everything Codex first:
# the app (winget Store id 9PLM9XGG6VKS + Appx) AND any stray 'codex' CLI on
# PATH - so we can report it and avoid installing a duplicate app.
$codexAll = @(Find-AllInstances "codex" "9PLM9XGG6VKS" "*Codex*")

if ($codexAll.Count -gt 0) {
    Step "Found existing Codex install(s):"
    foreach ($i in $codexAll) { Write-Host "      - [$($i.Kind)] $($i.Path)" -ForegroundColor Gray }
} else {
    Step "No Codex (app or CLI) found anywhere on this machine."
}

# The desktop app shows up as a winget Store registration or an Appx package.
$codexApp = ($codexAll | Where-Object { $_.Kind -in @("winget","appx","store-alias") } | Select-Object -First 1)
$codexCli = ($codexAll | Where-Object { $_.Kind -in @("native","npm","scoop","cargo") } | Select-Object -First 1)

if ($codexCli) {
    Warn "Note: a Codex CLI is installed at $($codexCli.Path)."
    Warn "You said you only want the desktop app - run the cleanup script to remove the CLI."
}

if ($codexApp) {
    Step "Codex for Windows (desktop app) is already installed - nudging an update check..."
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget upgrade --id 9PLM9XGG6VKS -e --source msstore --accept-package-agreements --accept-source-agreements 2>$null | Out-Null
    }
    Add-Result "Codex for Windows" "OK (already installed)" "desktop app"
} else {
    Step "Codex for Windows not found - installing the desktop app from the Microsoft Store..."
    $codexOk = $false
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id 9PLM9XGG6VKS -s msstore --accept-package-agreements --accept-source-agreements 2>&1 | Out-Host
        Start-Sleep -Seconds 2
        $cxAppx2 = Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*Codex*" }
        if ($cxAppx2) { $codexOk = $true }
    }
    if ($codexOk) {
        Add-Result "Codex for Windows" "OK (installed)" "desktop app"
    } else {
        Warn "Couldn't confirm the install automatically (the Microsoft Store source can be picky)."
        Warn "If Codex didn't appear in your Start menu, install it here:"
        Warn "   https://apps.microsoft.com/detail/9plm9xgg6vks"
        Add-Result "Codex for Windows" "INSTALL FROM STORE LINK (see notes)" "-"
    }
}

# --------------------------------------------------------------------
# 5. NPM-BASED CLIs (Vercel, Trigger.dev)  -- need Node.js
# --------------------------------------------------------------------
Banner "VERCEL + TRIGGER.DEV CLIs (via npm)"
Update-SessionPath
if (Get-Command npm -ErrorAction SilentlyContinue) {

    Step "Installing/updating Vercel CLI ..."
    cmd /c "npm install -g vercel@latest" 2>&1 | Out-Null
    Update-SessionPath
    $ver = Get-ToolVersion "vercel"
    if ($ver) { Add-Result "Vercel CLI" "OK" $ver } else { Add-Result "Vercel CLI" "Installed (restart terminal to verify)" "-" }

    Step "Installing/updating Trigger.dev CLI ..."
    cmd /c "npm install -g trigger.dev@latest" 2>&1 | Out-Null
    Update-SessionPath
    $ver = Get-ToolVersion "trigger.dev" "--version"
    if (-not $ver) { $ver = Get-ToolVersion "trigger" "--version" }
    if ($ver) { Add-Result "Trigger.dev CLI" "OK" $ver } else { Add-Result "Trigger.dev CLI" "Installed (restart terminal to verify)" "-" }

} else {
    Fail "npm not found in this window yet (Node.js was likely just installed)."
    Warn "These two will install automatically the NEXT time you run this script."
    Add-Result "Vercel CLI"      "PENDING - re-run script after restart" "-"
    Add-Result "Trigger.dev CLI" "PENDING - re-run script after restart" "-"
}

# --------------------------------------------------------------------
# 6. SUPABASE CLI (via Scoop - official Windows method)
# --------------------------------------------------------------------
Banner "SUPABASE CLI (via Scoop)"

# 6a. Ensure Scoop exists
if (-not (Get-Command scoop -ErrorAction SilentlyContinue) -and `
    -not (Test-Path "$env:USERPROFILE\scoop\shims\scoop.ps1")) {
    Step "Installing Scoop (package manager Supabase requires on Windows)..."
    try {
        # -RunAsAdmin lets Scoop bootstrap from this elevated window; it still
        # installs into your user profile, so 'supabase' works in normal windows too.
        Invoke-Expression "& {$(Invoke-RestMethod get.scoop.sh)} -RunAsAdmin"
    } catch { Fail "Scoop install error: $_" }
    Update-SessionPath
}

function Invoke-Scoop {
    param([string]$ScoopArgs)
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        cmd /c "scoop $ScoopArgs" 2>&1 | Out-Null
    } elseif (Test-Path "$env:USERPROFILE\scoop\shims\scoop.cmd") {
        cmd /c "`"$env:USERPROFILE\scoop\shims\scoop.cmd`" $ScoopArgs" 2>&1 | Out-Null
    }
}

if ((Get-Command scoop -ErrorAction SilentlyContinue) -or (Test-Path "$env:USERPROFILE\scoop\shims\scoop.cmd")) {
    $supList = (cmd /c "scoop list supabase" 2>&1 | Out-String)
    if ($supList -match "supabase") {
        Step "Supabase CLI already installed - updating..."
        Invoke-Scoop "update supabase"
    } else {
        Step "Adding Supabase bucket and installing Supabase CLI..."
        Invoke-Scoop "bucket add supabase https://github.com/supabase/scoop-bucket.git"
        Invoke-Scoop "install supabase"
    }
    Update-SessionPath
    $ver = Get-ToolVersion "supabase"
    if ($ver) { Add-Result "Supabase CLI" "OK" $ver } else { Add-Result "Supabase CLI" "Installed (restart terminal to verify)" "-" }
} else {
    Fail "Scoop is not available; Supabase CLI was skipped."
    Add-Result "Supabase CLI" "PENDING - re-run script" "-"
}

# --------------------------------------------------------------------
# 7. WSL2 + UBUNTU
# --------------------------------------------------------------------
Banner "WSL2 + UBUNTU"
$env:WSL_UTF8 = "1"   # makes wsl output readable to PowerShell
$rebootNeeded = $false
$ubuntuReady  = $false

if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    Fail "wsl.exe not found. This usually means a very old Windows build."
    Add-Result "WSL2 + Ubuntu" "MANUAL - update Windows first" "-"
} else {
    # What distros are installed right now?
    $distros = @()
    try { $distros = (wsl.exe -l -q) 2>$null | Where-Object { $_ -and $_.Trim() -ne "" } } catch {}
    $hasUbuntu = ($distros -join "`n") -match "Ubuntu"

    # Keep the WSL engine itself current (safe even on fresh installs)
    try { wsl.exe --update 2>&1 | Out-Null } catch {}

    if ($hasUbuntu) {
        # Confirm we can actually run commands inside it
        $probe = ""
        try { $probe = (wsl.exe -d Ubuntu -u root -- echo READY 2>$null | Out-String).Trim() } catch {}
        if ($probe -match "READY") {
            Step "Ubuntu is installed and ready."
            $ubuntuReady = $true
            Add-Result "WSL2 + Ubuntu" "OK" "Ubuntu present"
        } else {
            Warn "Ubuntu is installed but not finished setting up."
            Warn "Open the Start menu, launch 'Ubuntu', create your username+password, then re-run this script."
            Add-Result "WSL2 + Ubuntu" "NEEDS FIRST-RUN SETUP (open Ubuntu once)" "-"
        }
    } else {
        Step "Installing WSL2 + Ubuntu (this enables Windows features)..."
        try { wsl.exe --install -d Ubuntu 2>&1 | Out-Host } catch { Fail "WSL install error: $_" }
        $rebootNeeded = $true
        Add-Result "WSL2 + Ubuntu" "INSTALLED - REBOOT REQUIRED" "-"
    }
}

# --------------------------------------------------------------------
# 8. ANSIBLE (inside Ubuntu) -- only if Ubuntu is ready right now
# --------------------------------------------------------------------
Banner "ANSIBLE (inside Ubuntu)"
if ($ubuntuReady) {
    # Already installed?
    $ansibleHave = (wsl.exe -d Ubuntu -- bash -lc "command -v ansible || true" 2>$null | Out-String).Trim()
    if ($ansibleHave) {
        Step "Ansible found - updating to the latest in Ubuntu's repo..."
    } else {
        Step "Installing Ansible inside Ubuntu..."
    }
    # -u root avoids a sudo password prompt; install OR upgrade in one shot
    wsl.exe -d Ubuntu -u root -- bash -lc "export DEBIAN_FRONTEND=noninteractive; apt-get update -y && apt-get install -y ansible" 2>&1 | Out-Host
    $ansVer = (wsl.exe -d Ubuntu -- bash -lc "ansible --version 2>/dev/null | head -n1" 2>$null | Out-String).Trim()
    if ($ansVer) { Add-Result "Ansible (in Ubuntu)" "OK" $ansVer }
    else         { Add-Result "Ansible (in Ubuntu)" "Check manually: wsl -d Ubuntu -- ansible --version" "-" }
} else {
    Warn "Skipping Ansible for now - Ubuntu isn't ready yet (see the WSL step above)."
    Add-Result "Ansible (in Ubuntu)" "PENDING - finishes after Ubuntu setup + re-run" "-"
}

# --------------------------------------------------------------------
# 9. AI DEVOPS: skills, 1Password wiring, MCPs, and SSH configuration
# --------------------------------------------------------------------
Banner "AI DEVOPS SETUP"
$repoRoot = Split-Path -Parent $PSScriptRoot
$aiDevOpsSetup = Join-Path $repoRoot "setup-machine.ps1"
$pwsh = Get-Command pwsh -ErrorAction SilentlyContinue

if (-not (Test-Path $aiDevOpsSetup)) {
    Fail "Missing AI DevOps setup script: $aiDevOpsSetup"
    Add-Result "AI DevOps setup" "SKIPPED - helper missing" "-"
} elseif (-not $pwsh) {
    Warn "PowerShell 7 is not available in this window yet."
    Warn "Re-run this setup after opening a new terminal; it will then run AI DevOps setup."
    Add-Result "AI DevOps setup" "PENDING - re-run after PowerShell 7 install" "-"
} else {
    Step "Running AI DevOps setup (skills, 1Password, MCPs, and SSH)..."
    & $pwsh.Source -NoProfile -ExecutionPolicy Bypass -File $aiDevOpsSetup -RepoPath $repoRoot
    if ($LASTEXITCODE -eq 0) {
        Add-Result "AI DevOps setup" "OK" "skills, secrets, MCPs, SSH"
    } else {
        Warn "AI DevOps setup did not complete. Review its output, correct the reported issue, then re-run this launcher."
        Add-Result "AI DevOps setup" "CHECK OUTPUT" "-"
    }
}

# --------------------------------------------------------------------
# 10. SUMMARY
# --------------------------------------------------------------------
Update-SessionPath
Banner "SETUP SUMMARY"
$Results | Format-Table -AutoSize | Out-Host

Write-Host ""
Write-Host "Full log saved to: $logFile" -ForegroundColor DarkGray

if ($rebootNeeded) {
    Banner "ACTION NEEDED: 3 SIMPLE STEPS"
    Write-Host "WSL2 + Ubuntu was just installed and needs a reboot to finish." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  STEP 1:  Reboot your computer." -ForegroundColor White
    Write-Host "  STEP 2:  After restart, an 'Ubuntu' window opens by itself." -ForegroundColor White
    Write-Host "           When it asks, type a username and a password" -ForegroundColor White
    Write-Host "           (pick anything you'll remember - it's just for Ubuntu)." -ForegroundColor White
    Write-Host "  STEP 3:  Double-click 'run_me_setup_dev_comp.bat' again." -ForegroundColor White
    Write-Host "           It skips everything already done and installs Ansible." -ForegroundColor White
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "All done. Close this window and open a NEW PowerShell so every" -ForegroundColor Green
    Write-Host "freshly installed command (claude, codex, gh, etc.) is on your PATH." -ForegroundColor Green
}

Write-Host ""
Write-Host "TIP: If 'python' opens the Microsoft Store instead of running, go to" -ForegroundColor DarkGray
Write-Host "Settings > Apps > Advanced app settings > App execution aliases and" -ForegroundColor DarkGray
Write-Host "turn OFF the two 'python.exe' / 'python3.exe' aliases." -ForegroundColor DarkGray

try { Stop-Transcript | Out-Null } catch {}
Write-Host ""
Read-Host "Press Enter to close this window"

