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
    if (-not $NoShared) {
        New-TestSkill $root "shared" "shared-one"
        New-TestSkill $root "shared" "synology-sharesync-triage"
    }
    $templates = Join-Path $root "templates\system"
    New-Item -ItemType Directory -Force -Path $templates | Out-Null
    "# test Claude global" | Set-Content -LiteralPath (Join-Path $templates "CLAUDE-global.md")
    "# test Codex global" | Set-Content -LiteralPath (Join-Path $templates "AGENTS-global-codex.md")

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
        [switch]$SkillsDryRun,
        [switch]$MigrateObsolete
    )

    $parameters = @{
        RepoPath = $Fixture
        ClaudeHome = $ClaudeHome
        CodexHome = $CodexHome
        SkipGitInstall = $true
        SkillsDryRun = [bool]$SkillsDryRun
        MigrateObsolete = [bool]$MigrateObsolete
    }
    return (& $Installer @parameters *>&1 | Out-String)
}

try {
    Write-Host "1/5 shared directory absent"
    $fixture = New-Fixture "absent" -NoShared
    $claude = Join-Path $TempRoot "absent\claude"
    $codex = Join-Path $TempRoot "absent\codex"
    $output = Invoke-Installer $fixture $claude $codex
    Assert-True (Test-Path (Join-Path $claude "skills\client-claude\SKILL.md")) "Claude client skill missing"
    Assert-True (Test-Path (Join-Path $codex "skills\client-codex\SKILL.md")) "Codex client skill missing"
    Assert-True ($output -match "0 shared skills installed for Claude") "absent-shared count missing"

    Write-Host "2/5 dual-client install and counts"
    $fixture = New-Fixture "dual"
    $claude = Join-Path $TempRoot "dual\claude"
    $codex = Join-Path $TempRoot "dual\codex"
    $output = Invoke-Installer $fixture $claude $codex
    Assert-True (Test-Path (Join-Path $claude "skills\shared-one\SKILL.md")) "shared Claude skill missing"
    Assert-True (Test-Path (Join-Path $codex "skills\shared-one\SKILL.md")) "shared Codex skill missing"
    Assert-True ($output -match "2 shared skills installed for Claude") "Claude shared count missing"
    Assert-True ($output -match "2 shared skills installed for Codex") "Codex shared count missing"

    Write-Host "3/5 skills dry-run makes no changes"
    $fixture = New-Fixture "dry"
    $claude = Join-Path $TempRoot "dry\claude"
    $codex = Join-Path $TempRoot "dry\codex"
    $output = Invoke-Installer $fixture $claude $codex -SkillsDryRun
    Assert-True (-not (Test-Path $claude)) "dry-run created Claude home"
    Assert-True (-not (Test-Path $codex)) "dry-run created Codex home"
    Assert-True ($output -match "No files were changed") "dry-run completion missing"

    Write-Host "4/5 collision fails before mutation"
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

    Write-Host "5/5 obsolete skill warns, then quarantines only by opt-in"
    $fixture = New-Fixture "migrate"
    $claude = Join-Path $TempRoot "migrate\claude"
    $codex = Join-Path $TempRoot "migrate\codex"
    New-TestSkill $claude "" "synology-sharesync-stuck-triage"
    New-TestSkill $codex "" "synology-sharesync-stuck-triage"
    $output = Invoke-Installer $fixture $claude $codex
    Assert-True (Test-Path (Join-Path $claude "skills\synology-sharesync-stuck-triage")) "default run moved Claude obsolete skill"
    Assert-True (Test-Path (Join-Path $codex "skills\synology-sharesync-stuck-triage")) "default run moved Codex obsolete skill"
    Assert-True ($output -match "Re-run with -MigrateObsolete") "migration warning missing"
    $preview = Invoke-Installer $fixture $claude $codex -SkillsDryRun -MigrateObsolete
    Assert-True (Test-Path (Join-Path $claude "skills\synology-sharesync-stuck-triage")) "preview moved Claude obsolete skill"
    Assert-True (Test-Path (Join-Path $codex "skills\synology-sharesync-stuck-triage")) "preview moved Codex obsolete skill"
    Assert-True ($preview -match "\[skills-dry-run\] move") "migration preview missing"
    Invoke-Installer $fixture $claude $codex -MigrateObsolete | Out-Null
    Assert-True (-not (Test-Path (Join-Path $claude "skills\synology-sharesync-stuck-triage"))) "Claude obsolete skill remains active"
    Assert-True (-not (Test-Path (Join-Path $codex "skills\synology-sharesync-stuck-triage"))) "Codex obsolete skill remains active"
    Assert-True (Test-Path (Join-Path $claude "skills-quarantine\synology-sharesync-stuck-triage\SKILL.md")) "Claude quarantine missing"
    Assert-True (Test-Path (Join-Path $codex "skills-quarantine\synology-sharesync-stuck-triage\SKILL.md")) "Codex quarantine missing"

    Write-Host "PASS: install-ai-devops-windows"
} finally {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
