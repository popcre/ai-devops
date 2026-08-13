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
    # Replace an installed global that differs from the repo copy. Without this
    # switch a differing global is reported and left alone. The old file is
    # copied to <client>\globals-backup\ first.
    [switch]$AdoptGlobals,
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

$script:ManagedMarker = ".ai-devops-managed"

# --- reconciliation primitives ----------------------------------------------
# Byte-for-byte the same contract as bin/ai-install-skills: same marker format,
# same five states, same backup locations. The two installers must produce the
# same managed outcome on the same inputs, so anything changed here changes
# there too.

function Get-TreeHashes {
    param([string]$Dir)

    $map = @{}
    if (-not (Test-Path -LiteralPath $Dir)) { return $map }
    $base = (Resolve-Path -LiteralPath $Dir).Path.TrimEnd('\') + '\'
    Get-ChildItem -LiteralPath $Dir -Recurse -Force -File |
        Where-Object { $_.Name -ne $script:ManagedMarker } |
        ForEach-Object {
            $rel = $_.FullName.Substring($base.Length).Replace('\', '/')
            $map[$rel] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLower()
        }
    return $map
}

function Read-SkillMarker {
    param([string]$Path)

    $records = @{}
    if (-not (Test-Path -LiteralPath $Path)) { return $records }
    foreach ($line in (Get-Content -LiteralPath $Path)) {
        if ($line -match '^\s*#' -or [string]::IsNullOrWhiteSpace($line)) { continue }
        $parts = $line.Trim() -split '\s+', 2
        if ($parts.Count -eq 2) { $records[$parts[1].Trim()] = $parts[0].ToLower() }
    }
    return $records
}

function Write-SkillMarker {
    param([string]$Dest, [hashtable]$SourceHashes)

    if ($SkillsDryRun) { return }
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# ai-devops managed skill. Rewritten on every install; do not edit.")
    $lines.Add("# <sha256>  <path relative to this skill directory>")
    # Ordinal sort, to match the Bash installer's LC_ALL=C sort byte for byte.
    # PowerShell's default Sort-Object is culture-aware and case-insensitive,
    # which puts "agents/openai.yaml" before "SKILL.md" while `sort` does not.
    $ordered = [string[]]@($SourceHashes.Keys)
    [Array]::Sort($ordered, [StringComparer]::Ordinal)
    foreach ($rel in $ordered) {
        $lines.Add("$($SourceHashes[$rel])  $rel")
    }
    # LF, so the Bash installer reads the same file without stray CR.
    [System.IO.File]::WriteAllText((Join-Path $Dest $script:ManagedMarker),
        ($lines -join "`n") + "`n")
}

# Returns @{ State = ...; Changed = @(...); SourceHashes = @{} }.
# States: absent | identical | update | local-edits | unmanaged.
function Get-SkillState {
    param([string]$Source, [string]$Dest)

    $srcHashes = Get-TreeHashes $Source
    $result = @{ State = "absent"; Changed = @(); SourceHashes = $srcHashes }
    if (-not (Test-Path -LiteralPath $Dest)) { return $result }
    if (-not (Test-Path -LiteralPath (Join-Path $Dest $script:ManagedMarker))) {
        $result.State = "unmanaged"
        return $result
    }

    $dstHashes = Get-TreeHashes $Dest
    $records = Read-SkillMarker (Join-Path $Dest $script:ManagedMarker)
    $edited = $false
    foreach ($rel in $records.Keys) {
        if ($dstHashes[$rel] -ne $records[$rel]) { $edited = $true }
    }

    $changed = New-Object System.Collections.Generic.List[string]
    foreach ($rel in $srcHashes.Keys) {
        if ($dstHashes[$rel] -ne $srcHashes[$rel]) { $changed.Add($rel) }
    }
    foreach ($rel in $records.Keys) {
        if ($srcHashes.ContainsKey($rel)) { continue }
        if ($dstHashes.ContainsKey($rel)) { $changed.Add("-$rel") }
    }

    $result.Changed = @($changed)
    if ($changed.Count -eq 0) {
        $result.State = "identical"
    } elseif ($edited -or $records.Count -eq 0) {
        # A legacy marker carries no record, so nothing can prove the difference
        # came from the repo rather than from a person. Assume the person.
        $result.State = "local-edits"
    } else {
        $result.State = "update"
    }
    return $result
}

function Backup-InstalledPath {
    param([string]$Path, [string]$BackupRoot, [string]$Name)

    $backup = Join-Path $BackupRoot $Name
    Write-Note "    backup: $Path -> $backup"
    if ($SkillsDryRun) { return }
    New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null
    if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Recurse -Force }
    Copy-Item -LiteralPath $Path -Destination $backup -Recurse
}

# Copy the changed source files over an installed skill WITHOUT touching files
# the repo does not ship, so a local extension survives every update.
function Sync-SkillFiles {
    param([string]$Source, [string]$Dest, [string[]]$Changed)

    if ($SkillsDryRun) { return }
    New-Item -ItemType Directory -Force -Path $Dest | Out-Null
    foreach ($entry in $Changed) {
        if ([string]::IsNullOrEmpty($entry)) { continue }
        if ($entry.StartsWith("-")) {
            # Only files WE installed that the repo has since dropped.
            $target = Join-Path $Dest ($entry.Substring(1).Replace('/', '\'))
            if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Force }
        } else {
            $target = Join-Path $Dest ($entry.Replace('/', '\'))
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
            Copy-Item -LiteralPath (Join-Path $Source ($entry.Replace('/', '\'))) -Destination $target -Force
        }
    }
}

function Install-SkillFolder {
    param(
        [string]$SourceRoot,
        [string]$DestRoot,
        [string]$Label,
        [string]$ClientHome
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

        # Capture these BEFORE the switch: inside a switch block $_ is the
        # switch's own value, not the pipeline item, so $_.Name would be empty.
        $skillName = $_.Name
        $skillPath = $_.FullName
        $dest = Join-Path $DestRoot $skillName
        $info = Get-SkillState -Source $skillPath -Dest $dest
        $changed = $info.Changed
        $prefix = ""
        if ($SkillsDryRun) { $prefix = "[skills-dry-run] " }

        switch ($info.State) {
            "identical" {
                Write-Note "$prefix= $skillName ($Label) up to date"
                # One-time upgrade of a legacy marker so the NEXT run can tell a
                # local edit apart. Writes only the marker, and only once.
                if ((Read-SkillMarker (Join-Path $dest $script:ManagedMarker)).Count -eq 0) {
                    Write-SkillMarker -Dest $dest -SourceHashes $info.SourceHashes
                }
                $script:InstalledSkillCount += 1
                $count += 1
                return
            }
            "absent" {
                Write-Note "$prefix+ $skillName ($Label) install"
                $changed = @($info.SourceHashes.Keys)
            }
            "update" {
                Write-Note "$prefix~ $skillName ($Label) update, $($changed.Count) file(s): $($changed -join ' ')"
            }
            "local-edits" {
                Write-Warning "! $skillName ($Label) LOCAL EDITS - backing up, then updating: $($changed -join ' ')"
                Backup-InstalledPath -Path $dest -BackupRoot (Join-Path $ClientHome "skills-backup") -Name $skillName
            }
            "unmanaged" {
                Write-Warning "! $skillName ($Label) exists but ai-devops never installed it - backing up, then adopting"
                Backup-InstalledPath -Path $dest -BackupRoot (Join-Path $ClientHome "skills-backup") -Name $skillName
                if (-not $SkillsDryRun) { Remove-Item -LiteralPath $dest -Recurse -Force }
                $changed = @($info.SourceHashes.Keys)
            }
        }

        Sync-SkillFiles -Source $skillPath -Dest $dest -Changed $changed
        # Stamp as ai-devops-managed so a later run may retire it. Vendor skills
        # sharing this root never get the marker and are never moved.
        Write-SkillMarker -Dest $dest -SourceHashes $info.SourceHashes
        $script:InstalledSkillCount += 1
        $count += 1
    }

    return $count
}

# Quarantine skills ai-devops installed that the repo no longer ships. Generic
# on purpose: no skill name lives here, so retiring a skill is just "delete it
# from skills/ and commit". Only directories carrying the .ai-devops-managed
# marker (or named in config/retired-skills.txt, the pre-marker migration list)
# are eligible - vendor skills in the same root are never touched. Nothing is
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
        Write-Warning "No $Label skills found in the repo - skipping orphan pruning."
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
        if ($SkillsDryRun) {
            Write-Note "[skills-dry-run] install $Label -> $Dest"
        } else {
            Copy-Item -LiteralPath $Source -Destination $Dest
            Write-Note "Installed $Label -> $Dest"
        }
        return
    }

    $srcHash = (Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash
    $dstHash = (Get-FileHash -LiteralPath $Dest -Algorithm SHA256).Hash
    $backupRoot = Join-Path (Split-Path -Parent $Dest) "globals-backup"
    $leaf = Split-Path -Leaf $Dest
    if ($srcHash -eq $dstHash) {
        Write-Note "$Label already up to date."
    } elseif ($AdoptGlobals) {
        # A global is the one file that carries per-machine additions, so
        # replacing it needs an explicit managed boundary: -AdoptGlobals.
        Write-Note "$Dest differs - -AdoptGlobals given, replacing it."
        Backup-InstalledPath -Path $Dest -BackupRoot $backupRoot -Name $leaf
        if (-not $SkillsDryRun) {
            Copy-Item -LiteralPath $Source -Destination $Dest -Force
        }
        Write-Note "    restore with: Copy-Item `"$backupRoot\$leaf`" `"$Dest`""
    } else {
        Write-Note "$Dest exists and differs; not overwriting local edits."
        Write-Note "Compare with: code --diff `"$Dest`" `"$Source`""
        Write-Note "Replace it deliberately with: -AdoptGlobals"
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
    -Label "Claude" `
    -ClientHome $ClaudeHome
Write-Note "$claudeCount Claude skills installed."
$sharedClaudeCount = Install-SkillFolder `
    -SourceRoot (Join-Path $RepoPath "skills\shared") `
    -DestRoot (Join-Path $ClaudeHome "skills") `
    -Label "shared" `
    -ClientHome $ClaudeHome
Write-Note "$sharedClaudeCount shared skills installed for Claude."
Invoke-OrphanSkillPruning -ClientHome $ClaudeHome -Label "Claude" -Root $RepoPath -SourceRoots @(
    (Join-Path $RepoPath "skills\claude"), (Join-Path $RepoPath "skills\shared"))

Write-Step "Installing Codex skills"
$codexCount = Install-SkillFolder `
    -SourceRoot (Join-Path $RepoPath "skills\codex") `
    -DestRoot (Join-Path $CodexHome "skills") `
    -Label "Codex" `
    -ClientHome $CodexHome
Write-Note "$codexCount Codex skills installed."
$sharedCodexCount = Install-SkillFolder `
    -SourceRoot (Join-Path $RepoPath "skills\shared") `
    -DestRoot (Join-Path $CodexHome "skills") `
    -Label "shared" `
    -ClientHome $CodexHome
Write-Note "$sharedCodexCount shared skills installed for Codex."
Invoke-OrphanSkillPruning -ClientHome $CodexHome -Label "Codex" -Root $RepoPath -SourceRoots @(
    (Join-Path $RepoPath "skills\codex"), (Join-Path $RepoPath "skills\shared"))

Write-Step "Installing global instruction files"
Install-GlobalFile `
    -Source (Join-Path $RepoPath "templates\system\CLAUDE-global.md") `
    -Dest (Join-Path $ClaudeHome "CLAUDE.md") `
    -Label "Claude global instructions"
Install-GlobalFile `
    -Source (Join-Path $RepoPath "templates\system\AGENTS-global-codex.md") `
    -Dest (Join-Path $CodexHome "AGENTS.md") `
    -Label "Codex global instructions"

# A dry run is a preview of everything, globals included, and stops before the
# environment checks that would otherwise look like part of the plan.
if ($SkillsDryRun) {
    Write-Step "Skills dry-run complete"
    Write-Host "No files were changed."
    exit 0
}

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
