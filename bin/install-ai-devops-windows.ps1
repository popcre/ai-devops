<# 
Install or update Albert's AI DevOps toolkit on a Windows computer.

What this does:
- Clones https://github.com/u2giants/ai-devops.git if missing.
- Pulls the latest main branch if the repo already exists.
- Installs Claude skills to $HOME\.claude\skills.
- Installs Codex skills to $HOME\.codex\skills.
- Seeds $HOME\.claude\CLAUDE.md and $HOME\.codex\AGENTS.md only if missing.

Run in PowerShell:
  powershell -ExecutionPolicy Bypass -File .\bin\install-ai-devops-windows.ps1

Or remote one-liner:
  if(!(Get-Command git -EA SilentlyContinue)){winget install --id Git.Git -e --source winget; $env:Path=[Environment]::GetEnvironmentVariable("Path","Machine")+";"+[Environment]::GetEnvironmentVariable("Path","User")}; $p="$HOME\repos\ai-devops"; if(!(Test-Path "$p\.git")){git clone https://github.com/u2giants/ai-devops.git $p} else {git -C $p pull --ff-only}; powershell -ExecutionPolicy Bypass -File "$p\bin\install-ai-devops-windows.ps1"
#>

[CmdletBinding()]
param(
    [string]$RepoUrl = "https://github.com/u2giants/ai-devops.git",
    [string]$InstallRoot = "$HOME\repos",
    [string]$RepoPath = "",
    [switch]$SkipGitInstall,
    [string]$ClaudeHome = (Join-Path $HOME ".claude"),
    [string]$CodexHome = (Join-Path $HOME ".codex"),
    [switch]$SkillsDryRun,
    # Deprecated: retiring skills is now automatic and needs no flag.
    # Accepted so older docs and scripts keep working.
    [switch]$MigrateObsolete
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Note {
    param([string]$Message)
    Write-Host "    $Message"
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        if ($SkillsDryRun) {
            Write-Note "[skills-dry-run] create directory $Path"
        } else {
            New-Item -ItemType Directory -Path $Path | Out-Null
        }
    }
}

function Get-SkillNames {
    param([string]$SourceRoot)

    if (-not (Test-Path -LiteralPath $SourceRoot)) {
        return @()
    }

    return @(Get-ChildItem -LiteralPath $SourceRoot -Directory | Where-Object {
        Test-Path -LiteralPath (Join-Path $_.FullName "SKILL.md")
    } | Select-Object -ExpandProperty Name)
}

function Assert-NoSharedSkillCollisions {
    param([string]$Root)

    $sharedNames = @(Get-SkillNames (Join-Path $Root "skills\shared"))
    foreach ($client in @("claude", "codex")) {
        $clientRoot = Join-Path $Root "skills\$client"
        foreach ($name in $sharedNames) {
            if (Test-Path -LiteralPath (Join-Path $clientRoot "$name\SKILL.md")) {
                throw "Shared skill '$name' also exists in skills/$client; refusing to overwrite it."
            }
        }
    }
}

function Ensure-Git {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        return
    }

    if (-not $SkipGitInstall -and (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Step "Git not found; installing Git for Windows with winget"
        winget install --id Git.Git -e --source winget
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path", "User")
    }

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "Git is not available. Install Git for Windows, then rerun this script: https://git-scm.com/download/win"
    }
}

function Install-SkillFolder {
    param(
        [string]$SourceRoot,
        [string]$DestRoot,
        [string]$Label
    )

    if (-not (Test-Path -LiteralPath $SourceRoot)) {
        Write-Note "No $Label skills found at $SourceRoot"
        return 0
    }

    Ensure-Directory $DestRoot
    $count = 0
    Get-ChildItem -LiteralPath $SourceRoot -Directory | ForEach-Object {
        $skillFile = Join-Path $_.FullName "SKILL.md"
        if (-not (Test-Path -LiteralPath $skillFile)) {
            return
        }

        $dest = Join-Path $DestRoot $_.Name
        if ($SkillsDryRun) {
            Write-Note "[skills-dry-run] replace $dest from $($_.FullName)"
        } else {
            if (Test-Path -LiteralPath $dest) {
                Remove-Item -LiteralPath $dest -Recurse -Force
            }
            Copy-Item -LiteralPath $_.FullName -Destination $dest -Recurse
            # Stamp as ai-devops-managed so a later run may retire it. Vendor
            # skills sharing this root never get the marker and are never moved.
            New-Item -ItemType File -Force -Path (Join-Path $dest ".ai-devops-managed") | Out-Null
        }
        Write-Note "+ $($_.Name)"
        $script:InstalledSkillCount += 1
        $count += 1
    }

    return $count
}

# Quarantine skills ai-devops installed that the repo no longer ships. Generic
# on purpose: no skill name lives here, so retiring a skill is just "delete it
# from skills/ and commit". Only directories carrying the .ai-devops-managed
# marker (or named in config/retired-skills.txt, the pre-marker migration list)
# are eligible — vendor skills in the same root are never touched. Nothing is
# deleted; orphans move to <client>\skills-quarantine\.
function Invoke-OrphanSkillPruning {
    param(
        [string]$ClientHome,
        [string]$Label,
        [string]$Root,
        [string[]]$SourceRoots
    )

    $destRoot = Join-Path $ClientHome "skills"
    if (-not (Test-Path -LiteralPath $destRoot)) { return }

    $expected = @()
    foreach ($src in $SourceRoots) {
        if (-not (Test-Path -LiteralPath $src)) { continue }
        Get-ChildItem -LiteralPath $src -Directory | ForEach-Object {
            if (Test-Path -LiteralPath (Join-Path $_.FullName "SKILL.md")) { $expected += $_.Name }
        }
    }
    # An empty repo set means a broken checkout, not that everything retired.
    if ($expected.Count -eq 0) {
        Write-Warning "No $Label skills found in the repo — skipping orphan pruning."
        return
    }

    $retired = @()
    $retiredList = Join-Path $Root "config\retired-skills.txt"
    if (Test-Path -LiteralPath $retiredList) {
        $retired = Get-Content -LiteralPath $retiredList |
            ForEach-Object { ($_ -replace '#.*', '').Trim() } |
            Where-Object { $_ -ne '' }
    }

    $quarantineRoot = Join-Path $ClientHome "skills-quarantine"
    Get-ChildItem -LiteralPath $destRoot -Directory | ForEach-Object {
        if (-not (Test-Path -LiteralPath (Join-Path $_.FullName "SKILL.md"))) { return }
        if ($expected -contains $_.Name) { return }
        $managed = (Test-Path -LiteralPath (Join-Path $_.FullName ".ai-devops-managed")) -or
                   ($retired -contains $_.Name)
        if (-not $managed) { return }

        $quarantine = Join-Path $quarantineRoot $_.Name
        if ($SkillsDryRun) {
            Write-Note "[skills-dry-run] retire $($_.FullName) -> $quarantine"
        } else {
            New-Item -ItemType Directory -Force -Path $quarantineRoot | Out-Null
            # Re-running must not fail: replace any earlier quarantine copy.
            if (Test-Path -LiteralPath $quarantine) {
                Remove-Item -LiteralPath $quarantine -Recurse -Force
            }
            Move-Item -LiteralPath $_.FullName -Destination $quarantine
        }
        Write-Note "- $($_.Name) ($Label) retired -> $quarantine (recoverable)"
    }
}

function Install-GlobalFile {
    param(
        [string]$Source,
        [string]$Dest,
        [string]$Label
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        Write-Note "Missing source for $Label`: $Source"
        return
    }

    Ensure-Directory (Split-Path -Parent $Dest)
    if (-not (Test-Path -LiteralPath $Dest)) {
        Copy-Item -LiteralPath $Source -Destination $Dest
        Write-Note "Installed $Label -> $Dest"
        return
    }

    $srcHash = (Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash
    $dstHash = (Get-FileHash -LiteralPath $Dest -Algorithm SHA256).Hash
    if ($srcHash -eq $dstHash) {
        Write-Note "$Label already up to date."
    } else {
        Write-Note "$Dest exists and differs; not overwriting local edits."
        Write-Note "Compare with: code --diff `"$Dest`" `"$Source`""
    }
}

if ([string]::IsNullOrWhiteSpace($RepoPath)) {
    $RepoPath = Join-Path $InstallRoot "ai-devops"
}

if ($SkillsDryRun) {
    if (-not (Test-Path -LiteralPath $RepoPath)) {
        throw "Skills dry-run requires an existing -RepoPath: $RepoPath"
    }
    Write-Step "Previewing skill operations from $RepoPath"
} else {
    Ensure-Git
    Write-Step "Preparing repo at $RepoPath"
    Ensure-Directory (Split-Path -Parent $RepoPath)

    if (Test-Path -LiteralPath (Join-Path $RepoPath ".git")) {
        Write-Note "Repo exists; pulling latest main from GitHub."
        git -C $RepoPath fetch origin
        git -C $RepoPath checkout main
        git -C $RepoPath pull --ff-only origin main
    } elseif (Test-Path -LiteralPath $RepoPath) {
        throw "$RepoPath exists but is not a git repo. Move it aside or pass -RepoPath to a different folder."
    } else {
        Write-Note "Repo missing; cloning from $RepoUrl."
        git clone $RepoUrl $RepoPath
    }
}

Assert-NoSharedSkillCollisions -Root $RepoPath

Write-Step "Installing Claude skills"
$script:InstalledSkillCount = 0
$claudeCount = Install-SkillFolder `
    -SourceRoot (Join-Path $RepoPath "skills\claude") `
    -DestRoot (Join-Path $ClaudeHome "skills") `
    -Label "Claude"
Write-Note "$claudeCount Claude skills installed."
$sharedClaudeCount = Install-SkillFolder `
    -SourceRoot (Join-Path $RepoPath "skills\shared") `
    -DestRoot (Join-Path $ClaudeHome "skills") `
    -Label "shared"
Write-Note "$sharedClaudeCount shared skills installed for Claude."
Invoke-OrphanSkillPruning -ClientHome $ClaudeHome -Label "Claude" -Root $RepoPath -SourceRoots @(
    (Join-Path $RepoPath "skills\claude"), (Join-Path $RepoPath "skills\shared"))

Write-Step "Installing Codex skills"
$codexCount = Install-SkillFolder `
    -SourceRoot (Join-Path $RepoPath "skills\codex") `
    -DestRoot (Join-Path $CodexHome "skills") `
    -Label "Codex"
Write-Note "$codexCount Codex skills installed."
$sharedCodexCount = Install-SkillFolder `
    -SourceRoot (Join-Path $RepoPath "skills\shared") `
    -DestRoot (Join-Path $CodexHome "skills") `
    -Label "shared"
Write-Note "$sharedCodexCount shared skills installed for Codex."
Invoke-OrphanSkillPruning -ClientHome $CodexHome -Label "Codex" -Root $RepoPath -SourceRoots @(
    (Join-Path $RepoPath "skills\codex"), (Join-Path $RepoPath "skills\shared"))

if ($SkillsDryRun) {
    Write-Step "Skills dry-run complete"
    Write-Host "No files were changed."
    exit 0
}

Write-Step "Installing global instruction files"
Install-GlobalFile `
    -Source (Join-Path $RepoPath "templates\system\CLAUDE-global.md") `
    -Dest (Join-Path $ClaudeHome "CLAUDE.md") `
    -Label "Claude global instructions"
Install-GlobalFile `
    -Source (Join-Path $RepoPath "templates\system\AGENTS-global-codex.md") `
    -Dest (Join-Path $CodexHome "AGENTS.md") `
    -Label "Codex global instructions"

Write-Step "Checking optional logins"
if (Get-Command gh -ErrorAction SilentlyContinue) {
    gh auth status 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Note "GitHub CLI is installed but not logged in. Run: gh auth login"
    }
} else {
    Write-Note "GitHub CLI not found. Install when needed: winget install GitHub.cli"
}

if (Get-Command codex -ErrorAction SilentlyContinue) {
    Write-Note "Codex CLI found. If not logged in, run: codex login"
} else {
    Write-Note "Codex CLI not found. Install/login separately on this computer when needed."
}

if (Get-Command claude -ErrorAction SilentlyContinue) {
    Write-Note "Claude CLI found. If not logged in, run: claude login"
} else {
    Write-Note "Claude CLI not found. Install/login separately on this computer when needed."
}

if (Get-Command kimi -ErrorAction SilentlyContinue) {
    $kimiVersion = (& kimi --version 2>$null) -join " "
    if ([string]::IsNullOrWhiteSpace($kimiVersion)) {
        Write-Note "Kimi Code CLI found."
    } else {
        Write-Note "Kimi Code CLI found: $kimiVersion"
    }
    Write-Note "For delegation auth, test: kimi -p `"reply with OK`". If it fails, run kimi login once."
} else {
    Write-Note "Kimi Code CLI not found. Install/login separately if you want the kimi-code-delegation skill to run local Kimi jobs."
}

Write-Step "Done"
Write-Host "AI DevOps repo: $RepoPath"
Write-Host "Codex skills:  $(Join-Path $CodexHome 'skills')"
Write-Host "Claude skills: $(Join-Path $ClaudeHome 'skills')"
Write-Host ""
Write-Host "Future updates on this computer: rerun this same script."
