$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Installer = Join-Path $RepoRoot "bin\install-ai-devops-windows.ps1"
$TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("ai-devops-skills-test-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $TempRoot | Out-Null

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "FAIL: $Message" }
}

function New-TestSkill {
    param([string]$Root, [string]$Tree, [string]$Name)
    $dir = Join-Path $Root "skills\$Tree\$Name"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    @("---", "name: $Name", "description: test", "---") | Set-Content -LiteralPath (Join-Path $dir "SKILL.md")
}

function New-Fixture {
    param([string]$Name, [switch]$NoShared)

    $root = Join-Path $TempRoot "$Name\repo"
    New-Item -ItemType Directory -Force -Path $root | Out-Null
    New-TestSkill $root "claude" "client-claude"
    New-TestSkill $root "codex" "client-codex"
    New-TestSkill $root "zcode" "client-zcode"
    if (-not $NoShared) {
        New-TestSkill $root "shared" "shared-one"
        New-TestSkill $root "shared" "synology-sharesync-triage"
    }
    $templates = Join-Path $root "templates\system"
    New-Item -ItemType Directory -Force -Path $templates | Out-Null
    "# test Claude global" | Set-Content -LiteralPath (Join-Path $templates "CLAUDE-global.md")
    "# test Codex global" | Set-Content -LiteralPath (Join-Path $templates "AGENTS-global-codex.md")
    "# test ZCode global" | Set-Content -LiteralPath (Join-Path $templates "AGENTS-global-zcode.md")

    git -C $root init -b main | Out-Null
    git -C $root config user.name "AI DevOps Test"
    git -C $root config user.email "test@example.invalid"
    git -C $root add .
    git -C $root commit -m "test fixture" | Out-Null
    $remote = Join-Path $TempRoot "$Name\remote.git"
    git init --bare $remote | Out-Null
    git -C $root remote add origin $remote
    git -C $root push -u origin main | Out-Null
    return $root
}

function Invoke-Installer {
    param(
        [string]$Fixture,
        [string]$ClaudeHome,
        [string]$CodexHome,
        [string]$ZCodeHome = "",
        [switch]$SkillsDryRun,
        [switch]$MigrateObsolete,
        [switch]$AdoptGlobals
    )

    $parameters = @{
        RepoPath = $Fixture
        ClaudeHome = $ClaudeHome
        CodexHome = $CodexHome
        SkipGitInstall = $true
        ZCodeHome = $(if ($ZCodeHome) { $ZCodeHome } else { Join-Path $TempRoot "no-zcode-home" })
        SkillsDryRun = [bool]$SkillsDryRun
        MigrateObsolete = [bool]$MigrateObsolete
        AdoptGlobals = [bool]$AdoptGlobals
    }
    $oldMode = $env:AI_DEVOPS_INSTALL_TEST_MODE
    $oldRemote = $env:AI_DEVOPS_TEST_EXPECTED_REMOTE
    try {
        $env:AI_DEVOPS_INSTALL_TEST_MODE = '1'
        $env:AI_DEVOPS_TEST_EXPECTED_REMOTE = (git -C $Fixture remote get-url origin)
        if ($LASTEXITCODE -ne 0) { throw 'Could not read fixture remote.' }
        return (& $Installer @parameters *>&1 | Out-String)
    } finally {
        $env:AI_DEVOPS_INSTALL_TEST_MODE = $oldMode
        $env:AI_DEVOPS_TEST_EXPECTED_REMOTE = $oldRemote
    }
}

try {
    Write-Host "1/8 shared directory absent"
    $fixture = New-Fixture "absent" -NoShared
    $claude = Join-Path $TempRoot "absent\claude"
    $codex = Join-Path $TempRoot "absent\codex"
    $output = Invoke-Installer $fixture $claude $codex
    Assert-True (Test-Path (Join-Path $claude "skills\client-claude\SKILL.md")) "Claude client skill missing"
    Assert-True (Test-Path (Join-Path $codex "skills\client-codex\SKILL.md")) "Codex client skill missing"
    Assert-True ($output -match "0 shared skills installed for Claude") "absent-shared count missing"

    Write-Host "2/8 dual-client install and counts"
    $fixture = New-Fixture "dual"
    $claude = Join-Path $TempRoot "dual\claude"
    $codex = Join-Path $TempRoot "dual\codex"
    $output = Invoke-Installer $fixture $claude $codex
    Assert-True (Test-Path (Join-Path $claude "skills\shared-one\SKILL.md")) "shared Claude skill missing"
    Assert-True (Test-Path (Join-Path $codex "skills\shared-one\SKILL.md")) "shared Codex skill missing"
    Assert-True ($output -match "2 shared skills installed for Claude") "Claude shared count missing"
    Assert-True ($output -match "2 shared skills installed for Codex") "Codex shared count missing"

    Write-Host "3/8 skills dry-run makes no changes"
    $fixture = New-Fixture "dry"
    $claude = Join-Path $TempRoot "dry\claude"
    $codex = Join-Path $TempRoot "dry\codex"
    $output = Invoke-Installer $fixture $claude $codex -SkillsDryRun
    Assert-True (-not (Test-Path $claude)) "dry-run created Claude home"
    Assert-True (-not (Test-Path $codex)) "dry-run created Codex home"
    Assert-True ($output -match "No files were changed") "dry-run completion missing"

    Write-Host "4/8 collision fails before mutation"
    $fixture = New-Fixture "collision"
    New-TestSkill $fixture "shared" "client-claude"
    git -C $fixture add .
    git -C $fixture commit -m "add collision" | Out-Null
    git -C $fixture push | Out-Null
    $claude = Join-Path $TempRoot "collision\claude"
    $codex = Join-Path $TempRoot "collision\codex"
    $failed = $false
    try { Invoke-Installer $fixture $claude $codex | Out-Null } catch { $failed = $_.Exception.Message -match "refusing to overwrite" }
    Assert-True $failed "collision did not fail loudly"
    Assert-True (-not (Test-Path (Join-Path $claude "skills"))) "collision partially changed Claude home"
    Assert-True (-not (Test-Path (Join-Path $codex "skills"))) "collision partially changed Codex home"
    $fixture = New-Fixture "collision-codex"
    New-TestSkill $fixture "shared" "client-codex"
    git -C $fixture add .
    git -C $fixture commit -m "add Codex collision" | Out-Null
    git -C $fixture push | Out-Null
    $claude = Join-Path $TempRoot "collision-codex\claude"
    $codex = Join-Path $TempRoot "collision-codex\codex"
    $failed = $false
    try { Invoke-Installer $fixture $claude $codex | Out-Null } catch { $failed = $_.Exception.Message -match "skills/codex" }
    Assert-True $failed "Codex collision did not fail loudly"
    Assert-True (-not (Test-Path (Join-Path $claude "skills"))) "Codex collision partially changed Claude home"
    Assert-True (-not (Test-Path (Join-Path $codex "skills"))) "Codex collision partially changed Codex home"

    Write-Host "5/8 obsolete managed skill quarantines automatically"
    $fixture = New-Fixture "migrate"
    New-Item -ItemType Directory -Path (Join-Path $fixture "config") -Force | Out-Null
    "synology-sharesync-stuck-triage" | Set-Content -LiteralPath (Join-Path $fixture "config\retired-skills.txt")
    git -C $fixture add config/retired-skills.txt
    git -C $fixture commit -m "add retired skill fixture" | Out-Null
    git -C $fixture push | Out-Null
    $claude = Join-Path $TempRoot "migrate\claude"
    $codex = Join-Path $TempRoot "migrate\codex"
    New-TestSkill $claude "" "synology-sharesync-stuck-triage"
    New-TestSkill $codex "" "synology-sharesync-stuck-triage"
    $preview = Invoke-Installer $fixture $claude $codex -SkillsDryRun
    Assert-True (Test-Path (Join-Path $claude "skills\synology-sharesync-stuck-triage")) "preview moved Claude obsolete skill"
    Assert-True (Test-Path (Join-Path $codex "skills\synology-sharesync-stuck-triage")) "preview moved Codex obsolete skill"
    Assert-True ($preview -match "\[skills-dry-run\] retire") "automatic quarantine preview missing"
    Invoke-Installer $fixture $claude $codex | Out-Null
    Assert-True (-not (Test-Path (Join-Path $claude "skills\synology-sharesync-stuck-triage"))) "Claude obsolete skill remains active"
    Assert-True (-not (Test-Path (Join-Path $codex "skills\synology-sharesync-stuck-triage"))) "Codex obsolete skill remains active"
    Assert-True (Test-Path (Join-Path $claude "skills-quarantine\synology-sharesync-stuck-triage\SKILL.md")) "Claude quarantine missing"
    Assert-True (Test-Path (Join-Path $codex "skills-quarantine\synology-sharesync-stuck-triage\SKILL.md")) "Codex quarantine missing"

    # The old switch remains accepted as a no-op for older scripts.
    Invoke-Installer $fixture $claude $codex -MigrateObsolete | Out-Null

    Write-Host "6/8 reconciliation matrix: identical, extended, conflicting"
    $fixture = New-Fixture "matrix"
    $claude = Join-Path $TempRoot "matrix\claude"
    $codex = Join-Path $TempRoot "matrix\codex"
    $skill = Join-Path $fixture "skills\claude\client-claude\SKILL.md"
    $installed = Join-Path $claude "skills\client-claude"
    Invoke-Installer $fixture $claude $codex | Out-Null
    $marker = Join-Path $installed ".ai-devops-managed"
    $markerHashLines = @(Get-Content -LiteralPath $marker | Where-Object { $_ -match '^[0-9a-f]{64}  SKILL\.md$' })
    Assert-True ($markerHashLines.Count -eq 1) "marker does not record the installed file hash"

    # identical: a second apply changes nothing at all.
    $before = Get-ChildItem -LiteralPath (Join-Path $claude "skills") -Recurse -File -Force |
        ForEach-Object { "$($_.FullName) $((Get-FileHash -LiteralPath $_.FullName).Hash)" } | Sort-Object
    $output = Invoke-Installer $fixture $claude $codex
    Assert-True ($output -match "= client-claude \(Claude\) up to date") "identical not classified"
    $after = Get-ChildItem -LiteralPath (Join-Path $claude "skills") -Recurse -File -Force |
        ForEach-Object { "$($_.FullName) $((Get-FileHash -LiteralPath $_.FullName).Hash)" } | Sort-Object
    Assert-True (($before -join "|") -eq ($after -join "|")) "second apply changed files (not idempotent)"

    # locally extended: a file the repo does not ship survives an update.
    "local note" | Set-Content -LiteralPath (Join-Path $installed "LOCAL-NOTES.md")
    @("---", "name: client-claude", "description: test v2", "---") | Set-Content -LiteralPath $skill
    git -C $fixture add skills/claude/client-claude/SKILL.md
    git -C $fixture commit -m "update fixture to v2" | Out-Null
    git -C $fixture push | Out-Null
    $output = Invoke-Installer $fixture $claude $codex
    Assert-True ($output -match "~ client-claude \(Claude\) update") "source change not classified as update"
    Assert-True (Test-Path -LiteralPath (Join-Path $installed "LOCAL-NOTES.md")) "local extension deleted by update"
    Assert-True ((((Get-Content -LiteralPath (Join-Path $installed "SKILL.md")) -join "`n") -match "test v2")) "update did not land"
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $claude "skills-backup"))) "clean update made a backup"

    # locally conflicting: an edited installed file is backed up first.
    Add-Content -LiteralPath (Join-Path $installed "SKILL.md") -Value "hand edited"
    @("---", "name: client-claude", "description: test v3", "---") | Set-Content -LiteralPath $skill
    git -C $fixture add skills/claude/client-claude/SKILL.md
    git -C $fixture commit -m "update fixture to v3" | Out-Null
    git -C $fixture push | Out-Null
    $output = Invoke-Installer $fixture $claude $codex
    Assert-True ($output -match "LOCAL EDITS") "local edit not detected"
    Assert-True ((((Get-Content -LiteralPath (Join-Path $claude "skills-backup\client-claude\SKILL.md")) -join "`n") -match "hand edited")) `
        "local edit not backed up"
    Assert-True ((((Get-Content -LiteralPath (Join-Path $installed "SKILL.md")) -join "`n") -match "test v3")) "conflicting update did not land"

    Write-Host "7/8 unmanaged directory is backed up before adoption"
    $fixture = New-Fixture "unmanaged"
    $claude = Join-Path $TempRoot "unmanaged\claude"
    $codex = Join-Path $TempRoot "unmanaged\codex"
    New-Item -ItemType Directory -Force -Path (Join-Path $claude "skills\client-claude") | Out-Null
    "someone elses copy" | Set-Content -LiteralPath (Join-Path $claude "skills\client-claude\SKILL.md")
    $output = Invoke-Installer $fixture $claude $codex
    Assert-True ($output -match "never installed it") "unmanaged directory not reported"
    Assert-True ((((Get-Content -LiteralPath (Join-Path $claude "skills-backup\client-claude\SKILL.md")) -join "`n") -match "someone elses copy")) `
        "unmanaged copy not backed up"
    Assert-True ((((Get-Content -LiteralPath (Join-Path $claude "skills\client-claude\SKILL.md")) -join "`n") -match "description: test")) `
        "unmanaged directory not adopted"

    Write-Host "8/8 globals: never clobbered without -AdoptGlobals, backed up with it"
    $fixture = New-Fixture "globals"
    $claude = Join-Path $TempRoot "globals\claude"
    $codex = Join-Path $TempRoot "globals\codex"
    Invoke-Installer $fixture $claude $codex | Out-Null
    $global = Join-Path $claude "CLAUDE.md"
    Assert-True ((((Get-Content -LiteralPath $global) -join "`n") -match "test Claude global")) "global not seeded when absent"
    @("# test Claude global", "## machine-specific section") | Set-Content -LiteralPath $global
    $output = Invoke-Installer $fixture $claude $codex
    Assert-True ($output -match "not overwriting local edits") "differing global was not protected"
    Assert-True (((Get-Content -LiteralPath $global) -join "`n") -match "machine-specific") "global was clobbered by default"
    Invoke-Installer $fixture $claude $codex -AdoptGlobals -SkillsDryRun | Out-Null
    Assert-True (((Get-Content -LiteralPath $global) -join "`n") -match "machine-specific") "dry-run adopted the global"
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $claude "globals-backup"))) "dry-run wrote a backup"
    $output = Invoke-Installer $fixture $claude $codex -AdoptGlobals
    Assert-True (((Get-Content -LiteralPath (Join-Path $claude "globals-backup\CLAUDE.md")) -join "`n") -match "machine-specific") `
        "old global not backed up"
    Assert-True (-not (((Get-Content -LiteralPath $global) -join "`n") -match "machine-specific")) `
        "-AdoptGlobals did not replace the global"
    Assert-True ($output -match "restore with") "restore hint missing"

    Write-Host "9/9 ZCode: junction migration, install, and global seeding"
    $fixture = New-Fixture "zcode"
    $claude = Join-Path $TempRoot "zcode\claude"
    $codex = Join-Path $TempRoot "zcode\codex"
    $zcode = Join-Path $TempRoot "zcode\zcode-home"
    # Pre-seed the Claude home with skills and create the hand-made junction
    # ~/.zcode/skills -> ~/.claude/skills (the exact unmanaged baseline).
    Invoke-Installer $fixture $claude $codex | Out-Null
    $claudeSkillCount = @(Get-ChildItem -LiteralPath (Join-Path $claude "skills") -Directory).Count
    New-Item -ItemType Directory -Force -Path $zcode | Out-Null
    $junctionTarget = Join-Path $claude "skills"
    & cmd.exe /c mklink /J ("`"$zcode\skills`"") ("`"$junctionTarget`"") | Out-Null
    Assert-True ($LASTEXITCODE -eq 0) "test junction could not be created"

    $output = Invoke-Installer $fixture $claude $codex -ZCodeHome $zcode
    Assert-True ($output -match "Migrated ~/.zcode/skills") "junction migration not reported"
    $skillsItem = Get-Item -LiteralPath (Join-Path $zcode "skills") -Force
    Assert-True ($skillsItem.LinkType -ne 'Junction') "junction still present after install"
    Assert-True ($skillsItem.PSIsContainer) "managed skills dir is not a real directory"
    Assert-True (Test-Path (Join-Path $zcode "skills\client-zcode\SKILL.md")) "ZCode client skill missing"
    Assert-True (Test-Path (Join-Path $zcode "skills\shared-one\SKILL.md")) "shared skill missing for ZCode"
    Assert-True (Test-Path (Join-Path $zcode "skills\client-zcode\.ai-devops-managed")) "ZCode skill lacks managed marker"
    # THE critical safety property: the migration must not delete the Claude
    # skills the junction pointed at.
    Assert-True (@(Get-ChildItem -LiteralPath $junctionTarget -Directory).Count -eq $claudeSkillCount) `
        "junction target (Claude skills) was modified by the migration"
    Assert-True ($output -match "ZCode-specific skills installed") "ZCode install count missing"

    # ZCode global: seeded when absent, protected when locally edited.
    $zcodeGlobal = Join-Path $zcode "AGENTS.md"
    Assert-True ((((Get-Content -LiteralPath $zcodeGlobal) -join "`n") -match "test ZCode global")) "ZCode global not seeded when absent"
    @("# test ZCode global", "## zcode machine section") | Set-Content -LiteralPath $zcodeGlobal
    $output = Invoke-Installer $fixture $claude $codex -ZCodeHome $zcode
    Assert-True ($output -match "not overwriting local edits") "differing ZCode global was not protected"
    Assert-True (((Get-Content -LiteralPath $zcodeGlobal) -join "`n") -match "zcode machine section") "ZCode global was clobbered"
    $output = Invoke-Installer $fixture $claude $codex -ZCodeHome $zcode -AdoptGlobals
    Assert-True (-not (((Get-Content -LiteralPath $zcodeGlobal) -join "`n") -match "zcode machine section")) `
        "-AdoptGlobals did not replace the ZCode global"
    Assert-True (((Get-Content -LiteralPath (Join-Path $zcode "globals-backup\AGENTS.md")) -join "`n") -match "zcode machine section") `
        "old ZCode global not backed up"

    # Shared/ZCode tree collision must fail like the other clients.
    $fixture = New-Fixture "collision-zcode"
    New-TestSkill $fixture "shared" "client-zcode"
    git -C $fixture add .
    git -C $fixture commit -m "add zcode collision" | Out-Null
    git -C $fixture push | Out-Null
    $claude = Join-Path $TempRoot "collision-zcode\claude"
    $codex = Join-Path $TempRoot "collision-zcode\codex"
    $zcode = Join-Path $TempRoot "collision-zcode\zcode-home"
    $failed = $false
    try { Invoke-Installer $fixture $claude $codex -ZCodeHome $zcode | Out-Null } catch { $failed = $_.Exception.Message -match "skills/zcode" }
    Assert-True $failed "ZCode collision did not fail loudly"
    Assert-True (-not (Test-Path (Join-Path $zcode "skills"))) "ZCode collision partially changed the ZCode home"

    # Every machine must schedule the blocker watch, or its waiting sessions are
    # never woken. The test must not touch the real scheduler.
    $installerText = (Get-Content -LiteralPath $Installer) -join "`n"
    Assert-True ($installerText -match [regex]::Escape("bin\ai-blocker-watch") -and $installerText -match "'\`$bwTool' schedule") "installer no longer schedules the blocker watch"
    # A bare `bash` can be WSL bash, which cannot run the Windows checkout path
    # (seen on 916-alien): the schedule step must prefer Git's bundled bash.
    Assert-True ($installerText.Contains("'bin\bash.exe'")) "schedule step no longer prefers Git for Windows bash"
    Assert-True ($output -match "not touching this computer's scheduled tasks") "schedule step did not honour test mode"

    Write-Host "PASS: install-ai-devops-windows"
} finally {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
