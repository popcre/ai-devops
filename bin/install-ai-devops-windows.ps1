<# 
Internal/advanced skill installer for Albert's AI DevOps toolkit on Windows.
The public restore entry point is bin\bootstrap-windows-dev.ps1.

What this does:
- Clones https://github.com/popcre/ai-devops.git if missing.
- Pulls the latest main branch if the repo already exists.
- Installs Claude skills to $HOME\.claude\skills.
- Installs Codex skills to $HOME\.codex\skills.
- Installs ZCode skills to $HOME\.zcode\skills (migrating the hand-made
  junction to ~/.claude/skills away first, non-recursively).
- Seeds $HOME\.claude\CLAUDE.md, $HOME\.codex\AGENTS.md, and
  $HOME\.zcode\AGENTS.md only if missing.
- Schedules the blocker watch so waiting sessions on this computer get woken.

Run in PowerShell:
  powershell -ExecutionPolicy Bypass -File .\bin\install-ai-devops-windows.ps1

For complete setup, run:
  pwsh -NoProfile -File C:\repos\ai-devops\bin\bootstrap-windows-dev.ps1
#>

[CmdletBinding()]
param(
    [string]$RepoUrl = "https://github.com/popcre/ai-devops.git",
    [string]$InstallRoot = "C:\repos",
    [string]$RepoPath = "",
    [switch]$SkipGitInstall,
    [string]$ClaudeHome = (Join-Path $HOME ".claude"),
    [string]$CodexHome = (Join-Path $HOME ".codex"),
    [string]$ZCodeHome = (Join-Path $HOME ".zcode"),
    [string]$MimoHome = (Join-Path $HOME ".config\mimocode"),
    [switch]$SkillsDryRun,
    # Replace an installed global that differs from the repo copy. Without this
    # switch a differing global is reported and left alone. The old file is
    # copied to <client>\globals-backup\ first.
    [switch]$AdoptGlobals,
    [switch]$SourceGateOnly,
    [switch]$LauncherGateOnly,
    [string]$ExpectedHead = '',
    # Deprecated: retiring skills is now automatic and needs no flag.
    # Accepted so older docs and scripts keep working.
    [switch]$MigrateObsolete
)

$ErrorActionPreference = "Stop"
if ($ExpectedHead -and $ExpectedHead -notmatch '^[0-9a-f]{40}$') {
    throw 'ExpectedHead must be a full lowercase Git commit SHA.'
}
if ($ExpectedHead -and $SkillsDryRun) {
    throw 'ExpectedHead requires a real source check; it cannot be combined with SkillsDryRun.'
}
if ($LauncherGateOnly -and ($SourceGateOnly -or $SkillsDryRun)) {
    throw 'LauncherGateOnly cannot be combined with source-only or dry-run modes.'
}

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Note {
    param([string]$Message)
    Write-Host "    $Message"
}

. (Join-Path $PSScriptRoot 'repo-identity.ps1')

function Get-CanonicalRemote([string]$Url) { return (Get-AiDevOpsCanonicalRemote -Url $Url) }

function Invoke-GitCommand {
    param([string[]]$Arguments)

    # Windows PowerShell 5.1 can promote ordinary native stderr (including
    # successful Git fetch/clone progress) to a terminating NativeCommandError
    # when the script's normal ErrorActionPreference is Stop. Git's exit code is
    # the authority; keep diagnostics visible without mistaking them for failure.
    $priorPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& git @Arguments)
        $script:LastGitExitCode = $LASTEXITCODE
        return $output
    } finally {
        $ErrorActionPreference = $priorPreference
    }
}

function Invoke-NativeProbe {
    param(
        [string]$Command,
        [string[]]$Arguments = @()
    )

    # Optional login/version probes are informational. Windows PowerShell 5.1
    # promotes native stderr to NativeCommandError when the script normally
    # uses ErrorActionPreference=Stop, even though the native exit code is the
    # result we need to inspect. Keep the probe isolated and return both facts
    # without letting an expected unauthenticated result abort installation.
    $priorPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& $Command @Arguments 2>$null)
        $exitCode = $LASTEXITCODE
        return [pscustomobject]@{
            ExitCode = $exitCode
            Output = $output
        }
    } finally {
        $ErrorActionPreference = $priorPreference
    }
}

function Get-TaskGateRulesAtRevision([string]$Path, [string]$Revision, [string]$RulesPath) {
    $raw = Invoke-GitCommand @('-C', $Path, 'show', "${Revision}:$RulesPath")
    if ($script:LastGitExitCode -ne 0) { throw "Could not read $RulesPath at $Revision." }
    try { return (($raw -join "`n") | ConvertFrom-Json) } catch { throw "Invalid $RulesPath at $Revision." }
}

function Get-ReviewerSafetyGlobs([string]$Path, [string]$Revision) {
    $localRules = Get-TaskGateRulesAtRevision -Path $Path -Revision $Revision -RulesPath '.ai-devops/task-gates.json'
    $centralRules = Get-TaskGateRulesAtRevision -Path $Path -Revision $Revision -RulesPath 'config/task-gates.json'
    $globs = @($localRules.paths | Where-Object { $_.class -eq 'reviewer-safety' } | ForEach-Object { $_.glob })
    foreach ($rule in @($centralRules.rules)) {
        if (-not $rule.match -or -not ([System.Management.Automation.WildcardPattern]::new($rule.match, 'IgnoreCase').IsMatch('popcre/ai-devops'))) { continue }
        $globs += @($rule.paths | Where-Object { $_.class -eq 'reviewer-safety' } | ForEach-Object { $_.glob })
    }
    if ($globs.Count -eq 0 -or @($globs | Where-Object { -not $_ -or $_ -isnot [string] }).Count -ne 0) {
        throw "Missing reviewer safety rules at $Revision."
    }
    return $globs
}

function Get-InstalledSourceReceipt([string]$Path) {
    $launcher = Join-Path $env:USERPROFILE '.local\bin\ai-task-gates'
    if ($env:AI_DEVOPS_INSTALL_TEST_MODE -eq '1' -and $env:AI_DEVOPS_TEST_EXPECTED_REMOTE -and
        (Get-CanonicalRemote $env:AI_DEVOPS_TEST_EXPECTED_REMOTE) -notmatch '^github[.]com/') {
        $launcher = if ($env:AI_DEVOPS_TEST_LAUNCHER) { $env:AI_DEVOPS_TEST_LAUNCHER } else { Join-Path $Path '.ai-devops-test-launchers\ai-task-gates' }
    }
    $cmdLauncher = "$launcher.cmd"
    if (-not (Test-Path -LiteralPath $launcher) -and -not (Test-Path -LiteralPath $cmdLauncher)) {
        $launcherDir = Split-Path -Parent $launcher
        foreach ($row in @(Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\config\machine-tools.tsv'))) {
            if (-not $row -or $row.StartsWith('#')) { continue }
            $name = ($row -split "`t")[0]
            if ((Test-Path -LiteralPath (Join-Path $launcherDir $name)) -or
                (Test-Path -LiteralPath (Join-Path $launcherDir "$name.cmd"))) {
                return 'partial'
            }
        }
        if (Test-Path -LiteralPath $launcherDir -PathType Container) {
            foreach ($file in @(Get-ChildItem -LiteralPath $launcherDir -File)) {
                $header = @(Get-Content -LiteralPath $file.FullName -TotalCount 2 -ErrorAction SilentlyContinue)
                if ($header | Where-Object { $_ -clike '*Managed by ai-devops install-machine-tools.ps1.*' }) {
                    return 'partial'
                }
            }
        }
        if ($env:AI_DEVOPS_INSTALL_TEST_MODE -eq '1' -and $env:AI_DEVOPS_SKIP_MACHINE_TOOLS_GATE -eq '1' -and
            $env:AI_DEVOPS_TEST_EXPECTED_REMOTE -and (Get-CanonicalRemote $env:AI_DEVOPS_TEST_EXPECTED_REMOTE) -notmatch '^github[.]com/') {
            return ''
        }
        return 'missing'
    }
    if (-not (Test-Path -LiteralPath $launcher) -or -not (Test-Path -LiteralPath $cmdLauncher)) { return 'partial' }
    $bash = @(Get-Content -LiteralPath $launcher)
    $cmd = @(Get-Content -LiteralPath $cmdLauncher)
    $offset = 4
    if ($bash.Count -eq 4 -and $cmd.Count -eq 4) { $offset = 2 }
    elseif ($bash.Count -ne 6 -or $cmd.Count -ne 6) { throw 'Managed ai-task-gates source receipt is malformed.' }
    if ($offset -eq 4) {
        $sha = [regex]::Match($bash[2], '^# source-sha=([0-9a-f]{40})$').Groups[1].Value
        $hash = [regex]::Match($bash[3], '^# source-hash=([0-9a-f]{64})$').Groups[1].Value
        if (-not $sha -or -not $hash -or $cmd[2] -cne "rem source-sha=$sha" -or $cmd[3] -cne "rem source-hash=$hash") {
            throw 'Managed ai-task-gates source receipt is inconsistent.'
        }
    }
    $source = Join-Path $Path 'bin\ai-task-gates'
    $sourceBash = '/' + (($source -replace '\\','/' -replace '^([A-Za-z]):','$1'))
    $homeBash = '/' + (($env:USERPROFILE -replace '\\','/' -replace '^([A-Za-z]):','$1'))
    $bashRoute = 'exec "' + $sourceBash + '" "$@"'
    $gitBash = @((Join-Path $env:ProgramFiles 'Git\bin\bash.exe'), (Join-Path $env:LOCALAPPDATA 'Programs\Git\bin\bash.exe'))
    $validCmdRoutes = @($gitBash | ForEach-Object { '"' + $_ + '" "' + $sourceBash + '" %*' })
    if ($bash[0] -cne '#!/usr/bin/env bash' -or $bash[1] -cne '# Managed by ai-devops install-machine-tools.ps1.' -or
        $cmd[0] -cne '@echo off' -or $cmd[1] -cne 'rem Managed by ai-devops install-machine-tools.ps1.' -or
        $bash[$offset] -cne ('export HOME="' + $homeBash + '"') -or $cmd[$offset] -cne ('set "HOME=' + $env:USERPROFILE + '"') -or
        $bash[$offset + 1] -cne $bashRoute -or $cmd[$offset + 1] -cnotin $validCmdRoutes) {
        throw 'Managed ai-task-gates launcher routes differ from the supported installation.'
    }
    if ($offset -eq 2) { return 'legacy' }
    $archive = Join-Path ([IO.Path]::GetTempPath()) ('ai-devops-receipt-' + [guid]::NewGuid() + '.zip')
    $extract = "$archive.extracted"
    try {
        Invoke-GitCommand @('-C', $Path, 'archive', '--format=zip', "--output=$archive", $sha, 'bin/ai-task-gates') | Out-Null
        if ($script:LastGitExitCode -ne 0) { throw 'Could not verify the installed source receipt commit.' }
        Expand-Archive -LiteralPath $archive -DestinationPath $extract
        $actualHash = (Get-FileHash -LiteralPath (Join-Path $extract 'bin\ai-task-gates') -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -cne $hash) { throw 'Managed ai-task-gates source receipt hash does not match its commit.' }
    } finally {
        Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $extract -Recurse -Force -ErrorAction SilentlyContinue
    }
    return $sha
}

function Get-ManagedLauncherInventory([string]$Launcher) {
    $directory = Split-Path -Parent $Launcher
    $names = @{}
    $catalog = Join-Path $PSScriptRoot '..\config\machine-tools.tsv'
    foreach ($row in @(Get-Content -LiteralPath $catalog)) {
        if (-not $row -or $row.StartsWith('#')) { continue }
        $name = ($row -split "`t")[0]
        foreach ($item in @($name, "$name.cmd")) {
            $path = Join-Path $directory $item
            if (Test-Path -LiteralPath $path) { $names[$item] = $path }
        }
    }
    if (Test-Path -LiteralPath $directory -PathType Container) {
        foreach ($file in @(Get-ChildItem -LiteralPath $directory -File)) {
            $header = @(Get-Content -LiteralPath $file.FullName -TotalCount 2 -ErrorAction SilentlyContinue)
            if ($header | Where-Object { $_ -clike '*Managed by ai-devops install-machine-tools.ps1.*' }) {
                $names[$file.Name] = $file.FullName
            }
        }
    }
    $result = @()
    foreach ($name in @($names.Keys | Sort-Object -CaseSensitive)) {
        $path = $names[$name]
        $file = Get-Item -LiteralPath $path
        if ($file.PSIsContainer -or ($file.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw 'Managed launcher inventory contains an unsafe path.'
        }
        $result += @{name=$name;sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()}
    }
    return $result
}

function Test-ProtectedUpdate([string]$Path, [string]$CurrentHead, [string]$TargetHead) {
    if ($CurrentHead -eq $TargetHead) { return $false }
    $changed = @(Invoke-GitCommand @('-C', $Path, 'diff', '--no-renames', '--name-only', $CurrentHead, $TargetHead))
    if ($script:LastGitExitCode -ne 0) { throw 'Could not classify incoming ai-devops source changes.' }
    # Use both declarations: an update may remove or narrow its own safety rule.
    $globs = @(Get-ReviewerSafetyGlobs -Path $Path -Revision $CurrentHead) + @(Get-ReviewerSafetyGlobs -Path $Path -Revision $TargetHead)
    foreach ($file in $changed) {
        foreach ($glob in $globs) {
            if ([System.Management.Automation.WildcardPattern]::new($glob, 'IgnoreCase').IsMatch($file)) {
                return $true
            }
        }
    }
    return $false
}

function Get-TargetPolicyDigest([string]$Path, [string]$TargetHead) {
    $blobs = @()
    foreach ($file in @('config/task-gates.json', '.ai-devops/task-gates.json')) {
        $blob = Invoke-GitCommand @('-C', $Path, 'rev-parse', ($TargetHead + ':' + $file))
        if ($script:LastGitExitCode -ne 0 -or $blob.Trim() -notmatch '^[0-9a-f]{40}$') { throw "Cannot verify target policy $file." }
        $blobs += $blob.Trim()
    }
    $bytes = [Text.Encoding]::UTF8.GetBytes(($blobs -join [char]10) + [char]10)
    return ([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
}

function Assert-PrivateInstallAuthority([string]$IssuedPath, [string]$ReadPath) {
    $profile = [IO.Path]::GetFullPath($env:USERPROFILE).TrimEnd('\')
    $dir = [IO.Path]::GetFullPath((Split-Path -Parent $ReadPath)).TrimEnd('\')
    if (-not ($dir.Equals($profile, [StringComparison]::OrdinalIgnoreCase) -or
        $dir.StartsWith($profile + '\', [StringComparison]::OrdinalIgnoreCase))) {
        throw 'Reviewed toolkit install authorization is outside the private user profile.'
    }
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $allow = @($sid, 'S-1-5-18', 'S-1-5-32-544')
    $sealPath = "$IssuedPath.seal"
    $keyDir = Join-Path $env:USERPROFILE '.local\state\.ai-task-gates-seal'
    $keyPath = Join-Path $keyDir 'key.bin'
    $privatePaths = @($ReadPath, $sealPath, $dir, (Split-Path -Parent $dir), $keyDir, $keyPath)
    $unsafe = [Security.AccessControl.FileSystemRights]::WriteData -bor
        [Security.AccessControl.FileSystemRights]::AppendData -bor
        [Security.AccessControl.FileSystemRights]::WriteExtendedAttributes -bor
        [Security.AccessControl.FileSystemRights]::WriteAttributes -bor
        [Security.AccessControl.FileSystemRights]::Delete -bor
        [Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles -bor
        [Security.AccessControl.FileSystemRights]::ChangePermissions -bor
        [Security.AccessControl.FileSystemRights]::TakeOwnership
    $objects = @($ReadPath, $sealPath)
    while ($true) {
        $objects += $dir
        if ($dir.Equals($profile, [StringComparison]::OrdinalIgnoreCase)) { break }
        $dir = Split-Path -Parent $dir
    }
    $objects += $keyPath
    $keyAncestor = $keyDir
    while ($true) {
        $objects += $keyAncestor
        if ($keyAncestor.Equals($profile, [StringComparison]::OrdinalIgnoreCase)) { break }
        $keyAncestor = Split-Path -Parent $keyAncestor
    }
    foreach ($path in $objects) {
        $mustBePrivate = $privatePaths -contains $path
        try {
            $item = Get-Item -LiteralPath $path -Force -ErrorAction Stop
            $acl = Get-Acl -LiteralPath $path -ErrorAction Stop
        } catch {
            throw 'Reviewed toolkit install authorization private path is missing or unreadable.'
        }
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw 'Reviewed toolkit install authorization has a reparse point.'
        }
        if ($acl.GetOwner([Security.Principal.SecurityIdentifier]).Value -notin $allow -or
            ($mustBePrivate -and $acl.GetOwner([Security.Principal.SecurityIdentifier]).Value -ne $sid)) {
            throw 'Reviewed toolkit install authorization has a foreign owner.'
        }
        $hasFull = $false
        foreach ($rule in $acl.Access) {
            $ruleSid = $rule.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value
            if ($rule.AccessControlType -ne [Security.AccessControl.AccessControlType]::Allow -or
                ($ruleSid -notin $allow -and ($mustBePrivate -or (($rule.FileSystemRights -band $unsafe) -ne 0)))) {
                throw 'Reviewed toolkit install authorization has broad access.'
            }
            if ($ruleSid -eq $sid -and (($rule.FileSystemRights -band [Security.AccessControl.FileSystemRights]::FullControl) -eq [Security.AccessControl.FileSystemRights]::FullControl)) {
                $hasFull = $true
            }
        }
        if (-not $hasFull) { throw 'Reviewed toolkit install authorization lacks owner control.' }
    }
    $digest = (Get-FileHash -LiteralPath $ReadPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $key = [IO.File]::ReadAllBytes($keyPath)
    if ($key.Length -ne 32) { throw 'Reviewed toolkit install authorization key is invalid.' }
    $bytes = [Text.Encoding]::UTF8.GetBytes(([IO.Path]::GetFullPath($IssuedPath) + "`n" + $digest))
    $hmac = [System.Security.Cryptography.HMACSHA256]::new($key)
    $expected = [Convert]::ToBase64String($hmac.ComputeHash($bytes))
    if ((Get-Content -Raw -LiteralPath $sealPath).Trim() -cne $expected) {
        throw 'Reviewed toolkit install authorization seal does not match its bytes.'
    }
}

function Assert-InstallAuthorization([string]$Path, [string]$TargetHead, [string]$InstalledHead, [bool]$LegacyMigration, [bool]$FirstInstall, [bool]$RecoverLaunchers) {
    $fixture = $env:AI_DEVOPS_INSTALL_TEST_MODE -eq '1' -and $env:AI_DEVOPS_TEST_EXPECTED_REMOTE -and
        (Get-CanonicalRemote $env:AI_DEVOPS_TEST_EXPECTED_REMOTE) -notmatch '^github[.]com/'
    $authDir = Join-Path $env:USERPROFILE '.local\state\ai-devops\task-gates\install-authorizations'
    if ($fixture -and $env:AI_DEVOPS_TEST_LAUNCHER) { $authDir = Join-Path (Split-Path -Parent $env:AI_DEVOPS_TEST_LAUNCHER) 'install-authorizations' }
    $authPath = Join-Path $authDir "$TargetHead.json"
    $consumingPath = "$authPath.consuming"
    if ((Test-Path -LiteralPath $authPath) -and (Test-Path -LiteralPath $consumingPath)) { throw 'Ambiguous toolkit install authorization state.' }
    if (-not (Test-Path -LiteralPath $authPath -PathType Leaf)) {
        if (-not (Test-Path -LiteralPath $consumingPath -PathType Leaf)) { throw 'Reviewed toolkit install authorization is missing.' }
        # A setup retry re-enters this source gate before the full installer.
        # Revalidate the exact pending grant below; do not reserve a second one.
        $authPath = $consumingPath
    }
    Assert-PrivateInstallAuthority -IssuedPath (Join-Path $authDir "$TargetHead.json") -ReadPath $authPath
    try { $auth = Get-Content -Raw -LiteralPath $authPath | ConvertFrom-Json } catch { throw 'Reviewed toolkit install authorization is malformed.' }
    $expectedCheckout = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    $recordedCheckout = [IO.Path]::GetFullPath([string]$auth.installed_checkout).TrimEnd('\')
    $expectedLauncher = Join-Path $env:USERPROFILE '.local\bin\ai-task-gates'
    if ($fixture -and $env:AI_DEVOPS_TEST_LAUNCHER) { $expectedLauncher = $env:AI_DEVOPS_TEST_LAUNCHER }
    if ($auth.schema_version -ne 1 -or $auth.target_head -cne $TargetHead -or
        $auth.installed_head -cne $InstalledHead -or $recordedCheckout -ine $expectedCheckout -or
        [IO.Path]::GetFullPath([string]$auth.installed_launcher) -ine [IO.Path]::GetFullPath($expectedLauncher) -or
        -not $auth.reviewer_approval -or $auth.policy_digest -cne (Get-TargetPolicyDigest -Path $Path -TargetHead $TargetHead) -or
        [bool]$auth.legacy_migration -ne $LegacyMigration -or [bool]$auth.first_install -ne $FirstInstall -or
        [bool]$auth.recover_launchers -ne $RecoverLaunchers) {
        throw 'Reviewed toolkit install authorization does not match installed source, target, or policy.'
    }
    if ($LegacyMigration) {
        $bashHash = (Get-FileHash -LiteralPath $expectedLauncher -Algorithm SHA256).Hash.ToLowerInvariant()
        $cmdHash = (Get-FileHash -LiteralPath "$expectedLauncher.cmd" -Algorithm SHA256).Hash.ToLowerInvariant()
        $sourceHash = (Get-FileHash -LiteralPath (Join-Path $Path 'bin\ai-task-gates') -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($auth.installed_launcher_sha256 -cne $bashHash -or $auth.installed_cmd_sha256 -cne $cmdHash -or
            $auth.installed_source_sha256 -cne $sourceHash) {
            throw 'Legacy migration launcher or installed source changed after approval.'
        }
    }
    if ($FirstInstall) {
        if ((Test-Path -LiteralPath $expectedLauncher) -or (Test-Path -LiteralPath "$expectedLauncher.cmd") -or
            $auth.installed_source_sha256 -cne (Get-FileHash -LiteralPath (Join-Path $Path 'bin\ai-task-gates') -Algorithm SHA256).Hash.ToLowerInvariant()) {
            throw 'First-install source or launcher state changed after approval.'
        }
    }
    if ($RecoverLaunchers) {
        $bashExists = Test-Path -LiteralPath $expectedLauncher -PathType Leaf
        $cmdExists = Test-Path -LiteralPath "$expectedLauncher.cmd" -PathType Leaf
        $bashHash = if ($bashExists) { (Get-FileHash -LiteralPath $expectedLauncher -Algorithm SHA256).Hash.ToLowerInvariant() } else { '' }
        $cmdHash = if ($cmdExists) { (Get-FileHash -LiteralPath "$expectedLauncher.cmd" -Algorithm SHA256).Hash.ToLowerInvariant() } else { '' }
        $sourceHash = (Get-FileHash -LiteralPath (Join-Path $Path 'bin\ai-task-gates') -Algorithm SHA256).Hash.ToLowerInvariant()
        $actualInventory = @(Get-ManagedLauncherInventory -Launcher $expectedLauncher)
        $approvedInventory = @($auth.managed_inventory)
        $inventoryMatches = $actualInventory.Count -eq $approvedInventory.Count
        if ($inventoryMatches) {
            foreach ($item in $actualInventory) {
                $matches = @($approvedInventory | Where-Object { $_.name -ceq $item.name -and $_.sha256 -ceq $item.sha256 })
                if ($matches.Count -ne 1) { $inventoryMatches=$false; break }
            }
        }
        if (($bashExists -and $cmdExists) -or (-not $inventoryMatches) -or $actualInventory.Count -eq 0 -or
            $auth.installed_launcher_sha256 -cne $bashHash -or
            $auth.installed_cmd_sha256 -cne $cmdHash -or $auth.installed_source_sha256 -cne $sourceHash) {
            throw 'Managed launcher inventory changed after reviewed recovery approval.'
        }
    }
    $report = [IO.Path]::GetFullPath([string]$auth.review_report)
    if (-not (Test-Path -LiteralPath $report -PathType Leaf) -or
        (Get-FileHash -LiteralPath $report -Algorithm SHA256).Hash.ToLowerInvariant() -cne $auth.review_report_sha256) {
        throw 'Reviewed toolkit install report is missing or changed.'
    }
    $lines = @(Get-Content -LiteralPath $report)
    if (($lines | Select-Object -Last 2) -join [char]10 -cne ('## Verdict' + [char]10 + 'APPROVE') -or
        -not ($lines | Where-Object { $_ -ceq ('| reviewed commit | ' + [char]96 + $TargetHead + [char]96 + ' |') }) -or
        -not ($lines | Where-Object { $_ -ceq ('| source digest | ' + [char]96 + $auth.source_digest + [char]96 + ' |') })) {
        throw 'Reviewed toolkit install report does not approve the exact target and source.'
    }
    if ($LegacyMigration -and -not ($lines | Where-Object { $_ -ceq 'Approved legacy-managed-launcher-refresh.' })) {
        throw 'Review report did not approve the legacy migration operation.'
    }
    if ($FirstInstall -and -not ($lines | Where-Object { $_ -ceq 'Approved first-managed-install.' })) {
        throw 'Review report did not approve the first managed installation operation.'
    }
    if ($RecoverLaunchers -and -not ($lines | Where-Object { $_ -ceq 'Approved partial-managed-launcher-recovery.' })) {
        throw 'Review report did not approve partial managed launcher recovery.'
    }
    $requestedOperation = if ($LegacyMigration) { 'legacy-managed-launcher-refresh' } elseif ($FirstInstall) { 'first-managed-install' } elseif ($RecoverLaunchers) { 'partial-managed-launcher-recovery' } else { '' }
    if ($requestedOperation) {
        $siblingApprovals = @('legacy-managed-launcher-refresh','first-managed-install','partial-managed-launcher-recovery','stale-linux-manifest-recovery') | Where-Object { $_ -cne $requestedOperation } | Where-Object { $sibling = 'Approved ' + $_ + '.'; $lines | Where-Object { $_ -ceq $sibling } }
        $resultIndex = [Array]::IndexOf([string[]]$lines, '## Result'); $headerLines = if ($resultIndex -gt 0) { @($lines[0..($resultIndex - 1)]) } else { @() }; $operationRows = @($headerLines | Where-Object { $_.StartsWith('| operation | ') })
        if ($siblingApprovals -or $operationRows.Count -ne 1 -or $operationRows[0] -cne ('| operation | ' + [char]96 + $requestedOperation + [char]96 + ' |')) {
            throw 'Review report does not bind exactly the requested installation operation.'
        }
    }
    $reviewRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $report))
    $expectedReportDir = Join-Path $reviewRoot '.ai\reviews'
    if (([IO.Path]::GetFullPath((Split-Path -Parent $report)).TrimEnd('\')) -ine ([IO.Path]::GetFullPath($expectedReportDir).TrimEnd('\'))) {
        throw 'Reviewed toolkit install report is outside its checkout.'
    }
    $reviewHead = Invoke-GitCommand @('-C', $reviewRoot, 'rev-parse', 'HEAD')
    if ($script:LastGitExitCode -ne 0 -or $reviewHead.Trim() -cne $TargetHead) { throw 'Reviewed checkout moved from exact target.' }
    $reviewStatus = Invoke-GitCommand @('-C', $reviewRoot, 'status', '--porcelain=v1', '--untracked-files=all')
    if ($script:LastGitExitCode -ne 0 -or $reviewStatus) { throw 'Reviewed checkout is dirty.' }
    $installedCommon = Invoke-GitCommand @('-C', $Path, 'rev-parse', '--path-format=absolute', '--git-common-dir')
    $reviewCommon = Invoke-GitCommand @('-C', $reviewRoot, 'rev-parse', '--path-format=absolute', '--git-common-dir')
    if ($script:LastGitExitCode -ne 0 -or
        [IO.Path]::GetFullPath($installedCommon.Trim()) -ine [IO.Path]::GetFullPath($reviewCommon.Trim())) {
        throw 'Reviewed checkout does not share installed Git ownership.'
    }
    $bash = Join-Path $env:ProgramFiles 'Git\bin\bash.exe'
    if (-not (Test-Path -LiteralPath $bash)) { throw 'Git Bash is required to verify reviewed source.' }
    $identity = Invoke-NativeProbe -Command $bash -Arguments @((Join-Path $PSScriptRoot 'ai-review-lifecycle'), 'identity', $reviewRoot)
    if ($identity.ExitCode -ne 0) { throw 'Could not independently verify review source identity.' }
    try { $source = ($identity.Output -join "`n") | ConvertFrom-Json } catch { throw 'Review source identity is malformed.' }
    if ($source.head -cne $TargetHead -or $source.source_digest -cne $auth.source_digest) {
        throw 'Reviewed source digest or commit differs from authorization.'
    }
    $lifecycleRoot = Join-Path $env:USERPROFILE '.local\state\ai-devops\review-lifecycle'
    if ($fixture) { $lifecycleRoot = Join-Path (Split-Path -Parent $env:AI_DEVOPS_TEST_LAUNCHER) 'review-lifecycle' }
    $runs = Join-Path $lifecycleRoot ('runs\' + $source.repository_key)
    $matched = $false
    if (Test-Path -LiteralPath $runs -PathType Container) {
        foreach ($item in @(Get-ChildItem -LiteralPath $runs -Filter '*.json' -File -Recurse)) {
            try { $state = Get-Content -Raw -LiteralPath $item.FullName | ConvertFrom-Json } catch { continue }
            if ($state.status -ceq 'completed' -and $state.verdict -ceq 'APPROVE' -and $state.stale -eq $false -and
                $state.head -ceq $TargetHead -and $state.source_digest -ceq $auth.source_digest -and
                $state.report_sha256 -ceq $auth.review_report_sha256 -and $state.report_path) {
                # Lifecycle is written by Git Bash, so its report path may be
                # /c/... while this installer receives C:\... from PowerShell.
                $converted = Invoke-NativeProbe -Command $bash -Arguments @('-c', 'cygpath -aw -- "$1"', 'ai-devops', [string]$state.report_path)
                if ($converted.ExitCode -eq 0 -and $converted.Output.Count -eq 1 -and
                    [IO.Path]::GetFullPath([string]$converted.Output[0]) -ieq $report) { $matched = $true; break }
            }
        }
    }
    if (-not $matched) { throw 'Review report has no matching completed lifecycle record.' }
    return $authPath
}

function Assert-ReadyRepository([string]$Path, [string]$ExpectedHead = '') {
    $dirty = Invoke-GitCommand @('-C', $Path, 'status', '--porcelain')
    if ($script:LastGitExitCode -ne 0) { throw 'Could not inspect the ai-devops checkout.' }
    if ($dirty) { throw 'The ai-devops checkout is dirty; refusing to install from mixed source.' }
    $origin = Invoke-GitCommand @('-C', $Path, 'remote', 'get-url', 'origin')
    if ($script:LastGitExitCode -ne 0) { throw 'Could not read the ai-devops origin.' }
    if ($env:AI_DEVOPS_INSTALL_TEST_MODE -eq '1' -and $env:AI_DEVOPS_TEST_EXPECTED_REMOTE) {
        $expectedIdentity = Get-CanonicalRemote $env:AI_DEVOPS_TEST_EXPECTED_REMOTE
        # The test override exists so a suite can point the installer at a local
        # bare-repo fixture. It must never be able to substitute a REAL GitHub
        # identity for the allow-list -- a stale pair of variables left in a
        # shell profile would otherwise be a complete bypass of the guard.
        # Every fixture in tests/ uses a filesystem path, so this costs nothing.
        if ($expectedIdentity -match '^github[.]com/') {
            throw "AI_DEVOPS_TEST_EXPECTED_REMOTE may not name a github.com identity ($expectedIdentity); the allow-list governs those."
        }
        if ((Get-CanonicalRemote $origin) -ne $expectedIdentity) { throw "Noncanonical ai-devops origin: $origin" }
    } else {
        Assert-AiDevOpsRepoIdentity -Key 'ai-devops' -Identity (Get-CanonicalRemote $origin) `
            -Message "Noncanonical ai-devops origin: $origin"
    }
    $branch = Invoke-GitCommand @('-C', $Path, 'branch', '--show-current')
    if ($script:LastGitExitCode -ne 0) { throw 'Could not read the ai-devops branch.' }
    if ($branch.Trim() -ne 'main') { throw "ai-devops must be on main; found '$branch'." }
    Invoke-GitCommand @('-C', $Path, 'fetch', 'origin', 'main') | Out-Host
    if ($script:LastGitExitCode -ne 0) { throw 'Fetching ai-devops origin/main failed.' }
    $head = Invoke-GitCommand @('-C', $Path, 'rev-parse', 'HEAD')
    if ($script:LastGitExitCode -ne 0) { throw 'Could not resolve ai-devops HEAD.' }
    $remoteHead = Invoke-GitCommand @('-C', $Path, 'rev-parse', 'origin/main')
    if ($script:LastGitExitCode -ne 0) { throw 'Could not resolve ai-devops origin/main.' }
    if ($ExpectedHead -and $remoteHead.Trim() -ne $ExpectedHead) {
        throw "Fetched origin/main $($remoteHead.Trim()) differs from the gate-approved install target $ExpectedHead."
    }
    if ($LauncherGateOnly -and $head.Trim() -ne $remoteHead.Trim()) {
        throw 'Launcher receipt cannot be stamped before the checkout reaches exact origin/main.'
    }
    # Restore a hard-crashed launcher transaction before reading its receipt.
    # The sub-installer validates the exact source, catalog and prior bytes.
    if (-not $LauncherGateOnly) {
        $transactionRoot = if ($env:AI_DEVOPS_INSTALL_TEST_MODE -eq '1' -and $env:AI_DEVOPS_TEST_LAUNCHER -and
            $env:AI_DEVOPS_TEST_EXPECTED_REMOTE -and (Get-CanonicalRemote $env:AI_DEVOPS_TEST_EXPECTED_REMOTE) -notmatch '^github[.]com/') {
            Join-Path (Split-Path -Parent $env:AI_DEVOPS_TEST_LAUNCHER) 'launcher-transactions'
        } else {
            Join-Path $env:USERPROFILE '.local\state\ai-devops\task-gates\launcher-transactions'
        }
        $transactionPath = Join-Path $transactionRoot ($head.Trim() + '.json')
        if (Test-Path -LiteralPath $transactionPath) {
            & (Join-Path $Path 'bin\install-machine-tools.ps1') -RepoPath $Path -RecoverPendingTransactionOnly
        }
    }
    $receiptHead = Get-InstalledSourceReceipt -Path $Path
    $installedBaseline = $head.Trim()
    if ($receiptHead -and $receiptHead -notin @('legacy','missing','partial')) {
        Invoke-GitCommand @('-C', $Path, 'merge-base', '--is-ancestor', $receiptHead, $remoteHead.Trim()) | Out-Null
        if ($script:LastGitExitCode -ne 0) { throw 'Installed source receipt is not an ancestor of the fetched release.' }
        $installedBaseline = $receiptHead
    }
    $protectedUpdate = Test-ProtectedUpdate -Path $Path -CurrentHead $installedBaseline -TargetHead $remoteHead.Trim()
    $authorityDir = Join-Path $env:USERPROFILE '.local\state\ai-devops\task-gates\install-authorizations'
    if ($env:AI_DEVOPS_INSTALL_TEST_MODE -eq '1' -and $env:AI_DEVOPS_TEST_LAUNCHER) {
        $authorityDir = Join-Path (Split-Path -Parent $env:AI_DEVOPS_TEST_LAUNCHER) 'install-authorizations'
    }
    $issuedAuthorization = Join-Path $authorityDir ($remoteHead.Trim() + '.json')
    $pendingAuthorization = "$issuedAuthorization.consuming"
    $hasAuthorization = (Test-Path -LiteralPath $issuedAuthorization -PathType Leaf) -or
        (Test-Path -LiteralPath $pendingAuthorization -PathType Leaf)
    if ($protectedUpdate -or $receiptHead -eq 'legacy' -or $receiptHead -eq 'missing' -or $receiptHead -eq 'partial' -or $hasAuthorization) {
        if (-not $ExpectedHead -and -not (Test-Path -LiteralPath $pendingAuthorization -PathType Leaf)) {
            throw 'Reviewer safety or legacy update needs a pinned target and one-use task gate authorization.'
        }
        $sameCommitLegacy = $receiptHead -eq 'legacy' -and $installedBaseline -eq $remoteHead.Trim()
        $firstInstall = $receiptHead -eq 'missing'
        $recoverLaunchers = $receiptHead -eq 'partial'
        $authorizationPath = Assert-InstallAuthorization -Path $Path -TargetHead $remoteHead.Trim() -InstalledHead $installedBaseline -LegacyMigration $sameCommitLegacy -FirstInstall $firstInstall -RecoverLaunchers $recoverLaunchers
        $consumingPath = if ($authorizationPath.EndsWith('.consuming')) { $authorizationPath } else { "$authorizationPath.consuming" }
        if ($authorizationPath -ne $consumingPath) { Move-Item -LiteralPath $authorizationPath -Destination $consumingPath }
        $script:ConsumingInstallAuthorization = $consumingPath
    }
    if ($head.Trim() -ne $remoteHead.Trim()) {
        $counts = Invoke-GitCommand @('-C', $Path, 'rev-list', '--left-right', '--count', 'HEAD...origin/main')
        if ($script:LastGitExitCode -ne 0) { throw 'Could not compare ai-devops source state.' }
        $parts = @($counts -split '\s+') | Where-Object { $_ }
        if ($parts.Count -ne 2 -or [int]$parts[0] -ne 0) { throw 'ai-devops is ahead of or diverged from origin/main.' }
        # Hooks stay disabled for this fast-forward on purpose: the post-merge
        # reviewer hook would requalify against the old checkout mid-install,
        # and a failed canary would read as a fast-forward failure before any
        # later stage ran. The explicit requalify near the end of this script
        # is the one gate for this update.
        $emptyHooks = Join-Path ([System.IO.Path]::GetTempPath()) ("ai-devops-no-hooks-" + [System.IO.Path]::GetRandomFileName())
        New-Item -ItemType Directory -Path $emptyHooks -Force | Out-Null
        try {
            # Merge the commit we just proved. A concurrent fetch must not
            # change the target between the comparison and this fast-forward.
            Invoke-GitCommand @('-C', $Path, '-c', "core.hooksPath=$emptyHooks", 'merge', '--ff-only', $remoteHead.Trim()) | Out-Host
            if ($script:LastGitExitCode -ne 0) { throw 'Fast-forwarding ai-devops failed.' }
        } finally {
            Remove-Item -LiteralPath $emptyHooks -Force -Recurse -ErrorAction SilentlyContinue
        }
        $head = Invoke-GitCommand @('-C', $Path, 'rev-parse', 'HEAD')
        if ($script:LastGitExitCode -ne 0 -or $head.Trim() -ne $remoteHead.Trim()) { throw 'ai-devops did not converge exactly to origin/main.' }
    }
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

# Runs a bash gate command with BOTH streams visible: unlike
# Invoke-NativeProbe (optional informational probes, stderr discarded), these
# gates must print their diagnostics: a failed requalification names the
# recorded reviewer issue on stderr and may not be swallowed.
function Invoke-BashGate {
    param([object]$Bash, [string]$CommandText)

    $priorPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& $Bash.Source -lc $CommandText 2>&1 | ForEach-Object { $_.ToString() })
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $priorPreference
    }
    if ($output) { $output | Write-Host }
    $script:LastBashGateOutput = $output
    return $exitCode
}

# Reviewer auto-requalification post-merge hook (#804). Pulling new reviewer
# wrapper code invalidates the affected reviewer's live qualification; the
# hook re-qualifies it automatically. bin/ai-install-post-merge-hook owns the
# marker rules (foreign hooks are never touched); this runs it through Git
# Bash so both installers share one implementation. Returns the located bash
# (or $null), because the later requalify step needs the same interpreter.
function Get-GitBash {
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCmd) {
        $gitRoot = Split-Path (Split-Path $gitCmd.Source -Parent) -Parent
        $gitBashPath = Join-Path $gitRoot 'bin\bash.exe'
        if (Test-Path $gitBashPath) { return Get-Command $gitBashPath -ErrorAction SilentlyContinue }
    }
    return Get-Command bash -ErrorAction SilentlyContinue
}

function Install-PostMergeHook {
    param([string]$Root, [object]$Bash)

    if (-not $Bash) {
        Write-Note "Git Bash not found; the post-merge reviewer hook was not installed. Install Git for Windows and rerun this script."
        return
    }
    $tool = (Join-Path $Root 'bin\ai-install-post-merge-hook') -replace '\\', '/'
    $exitCode = Invoke-BashGate -Bash $Bash -CommandText "'$tool'"
    if ($exitCode -eq 0 -and ($script:LastBashGateOutput -match 'leaving foreign post-merge hook untouched')) {
        Write-Note "A foreign post-merge hook was preserved; reviewer auto-requalification hook NOT installed."
    } elseif ($exitCode -eq 0) {
        Write-Note "Installed post-merge reviewer auto-requalification hook."
    } else {
        Write-Note "Installing the post-merge reviewer hook failed (exit $exitCode); see the output above."
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
    foreach ($client in @("claude", "codex", "zcode", "mimo")) {
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

function Get-Sha256 {
    param([string]$Path)

    # Do not depend on Get-FileHash module auto-loading. A documented
    # powershell.exe 5.1 install can inherit pwsh's PSModulePath and then fail to
    # discover that cmdlet even though the operating system supplies it.
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    $stream = $null
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        $bytes = $hasher.ComputeHash($stream)
        return ([System.BitConverter]::ToString($bytes) -replace '-', '').ToLowerInvariant()
    } finally {
        if ($null -ne $stream) { $stream.Dispose() }
        $hasher.Dispose()
    }
}

function Get-TreeHashes {
    param([string]$Dir)

    $map = @{}
    if (-not (Test-Path -LiteralPath $Dir)) { return $map }
    # Carry the relative path while walking instead of subtracting one absolute
    # path string from another. Git Bash can expose the same directory as both
    # RUNNER~1 and runneradmin on a hosted Windows runner; PowerShell 5.1 may
    # preserve the short spelling for the root but return long spellings for
    # children. Text subtraction across those aliases is never reliable.
    function Add-TreeHashes {
        param([string]$CurrentDir, [string]$Prefix)

        Get-ChildItem -LiteralPath $CurrentDir -Force | ForEach-Object {
            $relative = "$Prefix$($_.Name)"
            if ($_.PSIsContainer) {
                # Match the Bash installer's `find` without -L. PowerShell 5.1
                # can follow junctions during -Recurse, but installation must
                # never escape the governed source tree or enter a link loop.
                if (($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) {
                    Add-TreeHashes -CurrentDir $_.FullName -Prefix "$relative/"
                }
            } elseif ($_.Name -ne $script:ManagedMarker) {
                $map[$relative] = Get-Sha256 $_.FullName
            }
        }
    }
    Add-TreeHashes -CurrentDir $Dir -Prefix ""
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

# Migrate the hand-made ~/.zcode/skills junction (~/.claude/skills) away so the
# managed directory can exist. NON-RECURSIVE by necessity: a recursive delete
# would destroy the CLAUDE skills the junction points at. Only a reparse point
# is ever removed here; a real directory (already migrated) is left untouched.
function Remove-ZCodeSkillsJunction {
    param([string]$ClientHome)

    $skillsDir = Join-Path $ClientHome "skills"
    if (-not (Test-Path -LiteralPath $skillsDir)) { return }
    $item = Get-Item -LiteralPath $skillsDir -Force
    if ($item.LinkType -ne 'Junction') { return }

    $target = $item.Target
    if ($SkillsDryRun) {
        Write-Note "[skills-dry-run] remove junction $skillsDir -> $target (non-recursive)"
        return
    }
    # cmd's rmdir removes ONLY the junction itself, never its target's contents.
    & cmd.exe /c rmdir "$skillsDir" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Could not remove the ~/.zcode/skills junction (cmd /c rmdir exited $LASTEXITCODE). Nothing was deleted; resolve manually before re-running."
    }
    if (Test-Path -LiteralPath $skillsDir) {
        throw "~/.zcode/skills still exists after rmdir; refusing to continue into an unknown state."
    }
    Write-Note "Migrated ~/.zcode/skills: removed the hand-made junction to $target (its contents were untouched)."
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

    $srcHash = Get-Sha256 $Source
    $dstHash = Get-Sha256 $Dest
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

# A machine-wide mutex spans authority reservation, checkout advance, skill
# install, and final launcher receipt. Nested calls from install-machine-tools
# run on this PowerShell thread and re-enter the same mutex; other processes
# cannot reuse a pending one-use authority during the transaction.
$installMutex = [Threading.Mutex]::new($false, 'Global\AiDevOpsToolkitInstall')
$installMutexHeld = $false
try {
    try { $installMutexHeld = $installMutex.WaitOne(0) }
    catch [Threading.AbandonedMutexException] { $installMutexHeld = $true }
    if (-not $installMutexHeld) { throw 'Another toolkit installation holds the machine-wide install lock.' }
    if ($env:AI_DEVOPS_INSTALL_TEST_MODE -eq '1' -and $env:AI_DEVOPS_TEST_LOCK_READY -and
        $env:AI_DEVOPS_TEST_EXPECTED_REMOTE -and
        (Get-CanonicalRemote $env:AI_DEVOPS_TEST_EXPECTED_REMOTE) -notmatch '^github[.]com/') {
        $readyPath = [IO.Path]::GetFullPath($env:AI_DEVOPS_TEST_LOCK_READY)
        if (-not $readyPath.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()), [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Install lock fixture marker must be under the temporary directory.'
        }
        [IO.File]::WriteAllText($readyPath, [string]$PID)
        Start-Sleep -Milliseconds 4000
    }

if ([string]::IsNullOrWhiteSpace($RepoPath)) {
    $RepoPath = Join-Path $InstallRoot "ai-devops"
}

if ($LauncherGateOnly) {
    Ensure-Git
    Assert-ReadyRepository -Path $RepoPath -ExpectedHead $ExpectedHead
    Write-Note 'Launcher receipt source gate passed.'
    return
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
        Write-Note "Repo exists; proving canonical clean main and fast-forwarding only."
        Assert-ReadyRepository -Path $RepoPath -ExpectedHead $ExpectedHead
    } elseif (Test-Path -LiteralPath $RepoPath) {
        throw "$RepoPath exists but is not a git repo. Move it aside or pass -RepoPath to a different folder."
    } else {
        Write-Note "Repo missing; cloning from $RepoUrl."
        Assert-AiDevOpsRepoIdentity -Key 'ai-devops' -Identity (Get-CanonicalRemote $RepoUrl) `
            -Message "Noncanonical RepoUrl: $RepoUrl"
        Invoke-GitCommand @('clone', '--branch', 'main', '--single-branch', $RepoUrl, $RepoPath) | Out-Host
        if ($script:LastGitExitCode -ne 0) { throw 'Cloning ai-devops failed.' }
        Assert-ReadyRepository -Path $RepoPath -ExpectedHead $ExpectedHead
    }
}

if ($SourceGateOnly) {
    Write-Note 'Source gate passed; no skill or global files were changed.'
    return
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

Write-Step "Installing ZCode skills"
# The junction migration MUST precede the install: Install-SkillFolder's
# Ensure-Directory would otherwise see the junction as an existing directory
# and reconcile INTO ~/.claude/skills, stamping Claude's tree with ZCode state.
Remove-ZCodeSkillsJunction -ClientHome $ZCodeHome
$zcodeCount = Install-SkillFolder `
    -SourceRoot (Join-Path $RepoPath "skills\zcode") `
    -DestRoot (Join-Path $ZCodeHome "skills") `
    -Label "ZCode" `
    -ClientHome $ZCodeHome
Write-Note "$zcodeCount ZCode-specific skills installed."
$sharedZCodeCount = Install-SkillFolder `
    -SourceRoot (Join-Path $RepoPath "skills\shared") `
    -DestRoot (Join-Path $ZCodeHome "skills") `
    -Label "shared" `
    -ClientHome $ZCodeHome
Write-Note "$sharedZCodeCount shared skills installed for ZCode."
Invoke-OrphanSkillPruning -ClientHome $ZCodeHome -Label "ZCode" -Root $RepoPath -SourceRoots @(
    (Join-Path $RepoPath "skills\zcode"), (Join-Path $RepoPath "skills\shared"))

Write-Step "Installing MiMo skills"
# MiMoCode write root is ~/.config/mimocode/skills only (Desktop installs/imports
# here). Never install into ~/.agents/skills -- that is a read-only compat scan.
# Install only where MiMo has already created its home, so machines without
# MiMo stay untouched (same policy as the globals install below).
if (Test-Path -LiteralPath $MimoHome) {
    $mimoCount = Install-SkillFolder `
        -SourceRoot (Join-Path $RepoPath "skills\mimo") `
        -DestRoot (Join-Path $MimoHome "skills") `
        -Label "MiMo" `
        -ClientHome $MimoHome
    Write-Note "$mimoCount MiMo-specific skills installed."
    $sharedMimoCount = Install-SkillFolder `
        -SourceRoot (Join-Path $RepoPath "skills\shared") `
        -DestRoot (Join-Path $MimoHome "skills") `
        -Label "shared" `
        -ClientHome $MimoHome
    Write-Note "$sharedMimoCount shared skills installed for MiMo."
    Invoke-OrphanSkillPruning -ClientHome $MimoHome -Label "MiMo" -Root $RepoPath -SourceRoots @(
        (Join-Path $RepoPath "skills\mimo"), (Join-Path $RepoPath "skills\shared"))
} else {
    Write-Note "MiMo home not present - MiMo skills stage was skipped."
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
Install-GlobalFile `
    -Source (Join-Path $RepoPath "templates\system\AGENTS-global-zcode.md") `
    -Dest (Join-Path $ZCodeHome "AGENTS.md") `
    -Label "ZCode global instructions"
# Xiaomi MiMo reads its global AGENTS.md beside its config file. Install it only
# where MiMo has created that folder, so machines without MiMo stay untouched.
if (Test-Path -LiteralPath $MimoHome) {
    Install-GlobalFile `
        -Source (Join-Path $RepoPath "templates\system\AGENTS-global-mimo.md") `
        -Dest (Join-Path $MimoHome "AGENTS.md") `
        -Label "Xiaomi MiMo global instructions"
}

# A dry run is a preview of everything, globals included, and stops before the
# environment checks that would otherwise look like part of the plan.
if ($SkillsDryRun) {
    Write-Step "Skills dry-run complete"
    Write-Host "No files were changed."
    exit 0
}

# DeepSeek formal reviews must never ask 1Password for a key. Prepare the
# protected store before the installer's live qualification pass.
$deepseekBash = Get-GitBash
if ($deepseekBash) {
    $deepseekWrapper = (Join-Path $RepoPath 'bin\ai-deepseek-agent') -replace '\\', '/'
    $deepseekKeyProbe = Invoke-NativeProbe -Command $deepseekBash.Source -Arguments @('--noprofile', '--norc', $deepseekWrapper, 'store-key', '--if-missing')
    if ($deepseekKeyProbe.ExitCode -eq 0) {
        Write-Note 'DeepSeek protected per-user key store is ready.'
    } else {
        Write-Note 'DeepSeek key store setup failed; review qualification remains unavailable until ai-deepseek-agent store-key succeeds.'
    }
} else {
    Write-Note 'Git Bash is needed to prepare the DeepSeek key store.'
}

# Repo-level managed hook plus the update's one reviewer-requalification gate.
# Rerunning this script is the documented Windows update path, so every real
# run repairs or refreshes the hook and then requalifies any reviewer whose
# qualification the pulled code invalidated. The fast-forward above ran with
# hooks disabled, so this is the only requalify for this run.
$installBash = Get-GitBash

# A review turn may only read Muse's protected key store. Prepare it before
# requalification, outside any review, even if Muse Code is not yet installed.
$museWrapper = Join-Path $RepoPath 'bin\ai-muse'
if (Test-Path -LiteralPath $museWrapper) {
    if ($installBash) {
        $oldMuseCaller = $env:AI_MUSE_CALLER
        try {
            $env:AI_MUSE_CALLER = 'installer'
            $museProbe = Invoke-NativeProbe -Command $installBash.Source -Arguments @('--noprofile', '--norc', ($museWrapper -replace '\\', '/'), 'store-key', '--if-missing')
        } finally {
            $env:AI_MUSE_CALLER = $oldMuseCaller
        }
        if ($museProbe.ExitCode -eq 0) {
            Write-Note 'Muse protected per-user key store is ready.'
        } else {
            Write-Note 'Muse key store setup failed; review qualification remains unavailable until ai-muse store-key succeeds.'
        }
    } else {
        Write-Note 'Git Bash is needed to prepare the Muse key store.'
    }
}

Install-PostMergeHook -Root $RepoPath -Bash $installBash
if ($installBash) {
    $requalify = (Join-Path $RepoPath 'bin\ai-review-preflight') -replace '\\', '/'
    Write-Step "Re-qualifying reviewers whose qualification the update invalidated"
    if ($env:AI_DEVOPS_INSTALL_TEST_MODE -eq '1') {
        Write-Note "Test mode: not running live reviewer qualification."
    } else {
        $exitCode = Invoke-BashGate -Bash $installBash -CommandText "'$requalify' requalify"
        if ($exitCode -eq 0) {
            Write-Note "Reviewer requalification passed; any reviewer deferred for a provider capacity event stays quarantined (see the output above)."
        } else {
            Write-Note "Automatic reviewer requalification failed (exit $exitCode); it is recorded as a reviewer issue and the reviewer stays quarantined. See the output above."
        }
    }
}

# Blocker notices and session wake-ups only happen on a machine that runs the
# tick, so every machine installs the task. `schedule` uses schtasks /F, so
# rerunning the installer re-points an existing task instead of failing.
Write-Step "Scheduling the blocker watch"
# Prefer Git for Windows' bundled bash: on WSL-equipped machines (916-alien,
# 2026-09-17) a bare `bash` resolves to WSL bash, which cannot run the Windows
# checkout path and fails with no usable output.
$bwBash = $null
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if ($gitCmd) {
    $gitRoot = Split-Path (Split-Path $gitCmd.Source -Parent) -Parent
    $gitBashPath = Join-Path $gitRoot 'bin\bash.exe'
    if (Test-Path $gitBashPath) { $bwBash = Get-Command $gitBashPath -ErrorAction SilentlyContinue }
}
if (-not $bwBash) { $bwBash = Get-Command bash -ErrorAction SilentlyContinue }
if ($env:AI_DEVOPS_INSTALL_TEST_MODE -eq '1') {
    Write-Note "Test mode: not touching this computer's scheduled tasks."
} elseif ($bwBash) {
    $bwTool = (Join-Path $RepoPath 'bin\ai-blocker-watch') -replace '\\', '/'
    $bwProbe = Invoke-NativeProbe -Command $bwBash.Source -Arguments @('-lc', "'$bwTool' schedule")
    if ($bwProbe.ExitCode -eq 0) {
        Write-Note "Blocker watch scheduled. Waiting sessions on this computer now get woken when their blocker closes."
    } else {
        Write-Note "Could not schedule the blocker watch: $($bwProbe.Output -join ' ')"
    }
} else {
    Write-Note "Git Bash not found, so the blocker watch was not scheduled. Install Git for Windows and rerun this script."
}

# The shared-db reviewer start watch runs on ONE machine (run_on_host in
# config/reviewer-start-watch.json): the one with the reviewer wrappers, because
# drawing a replacement reviewer needs ai-review-preflight. Other machines skip it.
Write-Step "Scheduling the reviewer start watch"
$rswHost = $null
try { $rswHost = (Get-Content -Raw (Join-Path $RepoPath 'config\reviewer-start-watch.json') | ConvertFrom-Json).run_on_host } catch { }
if ($env:AI_DEVOPS_INSTALL_TEST_MODE -eq '1') {
    Write-Note "Test mode: not touching this computer's scheduled tasks."
} elseif (-not $rswHost -or $rswHost -ne $env:COMPUTERNAME) {
    Write-Note "Reviewer start watch runs on $rswHost, not this computer; skipped."
} elseif ($bwBash) {
    $rswTool = (Join-Path $RepoPath 'bin\ai-reviewer-start-watch') -replace '\\', '/'
    $rswProbe = Invoke-NativeProbe -Command $bwBash.Source -Arguments @('-lc', "'$rswTool' schedule")
    if ($rswProbe.ExitCode -eq 0) {
        Write-Note "Reviewer start watch scheduled. Shared-db reviewers that never start are now rerouted from this computer."
    } else {
        Write-Note "Could not schedule the reviewer start watch: $($rswProbe.Output -join ' ')"
    }
} else {
    Write-Note "Git Bash not found, so the reviewer start watch was not scheduled. Install Git for Windows and rerun this script."
}

# Scheduled retirement of merged shared-db worktrees (same shape as above).
if ($env:AI_DEVOPS_INSTALL_TEST_MODE -eq '1') {
    Write-Note "Test mode: not touching this computer's scheduled tasks (worktree reap)."
} elseif ($bwBash) {
    $reapTool = (Join-Path $RepoPath 'bin\ai-reap-shared-db-worktrees') -replace '\\', '/'
    $reapProbe = Invoke-NativeProbe -Command $bwBash.Source -Arguments @('-lc', "'$reapTool' schedule")
    if ($reapProbe.ExitCode -eq 0) {
        Write-Note "Worktree reap scheduled. Merged shared-db worktrees on this computer retire themselves daily."
    } else {
        Write-Note "Could not schedule the worktree reap: $($reapProbe.Output -join ' ')"
    }
} else {
    Write-Note "Git Bash not found, so the worktree reap was not scheduled. Install Git for Windows and rerun this script."
}

# Watchdog duty pool: local timed tasks for CI alarms (queue-slow, runner-pool,
# membership drift, merge-queue drift). Claim/lease rotation across
# watch_hosts; free Actions stay backup only. Never paid Blacksmith.
Write-Step "Scheduling the watchdog duty pool (local-watch)"
$lwInPool = $false
try {
    $lwConfig = Get-Content -Raw (Join-Path $RepoPath 'config\local-watch.json') | ConvertFrom-Json
    $lwHosts = @($lwConfig.watch_hosts | ForEach-Object { "$_".ToLowerInvariant() })
    $lwInPool = $lwHosts -contains $env:COMPUTERNAME.ToLowerInvariant()
} catch { }
if ($env:AI_DEVOPS_INSTALL_TEST_MODE -eq '1') {
    Write-Note "Test mode: not touching this computer's scheduled tasks (local-watch)."
} elseif (-not $lwInPool) {
    Write-Note "This computer is not in the watchdog duty pool (watch_hosts); local-watch not scheduled."
} elseif ($bwBash) {
    $lwTool = (Join-Path $RepoPath 'bin\ai-local-watch') -replace '\\', '/'
    $lwProbe = Invoke-NativeProbe -Command $bwBash.Source -Arguments @('-lc', "'$lwTool' schedule")
    if ($lwProbe.ExitCode -eq 0) {
        Write-Note "Watchdog duty pool timer scheduled. CI alarms now run as local timed tasks with claim/lease failover."
    } else {
        Write-Note "Could not schedule local-watch: $($lwProbe.Output -join ' ')"
    }
} else {
    Write-Note "Git Bash not found, so local-watch was not scheduled. Install Git for Windows and rerun this script."
}

Write-Step "Checking optional logins"
if (Get-Command gh -ErrorAction SilentlyContinue) {
    $ghGate = (Join-Path $PSScriptRoot 'ai-gh') -replace '\\', '/'
    if ($installBash -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'ai-gh'))) {
        $ghProbe = Invoke-NativeProbe -Command $installBash.Source -Arguments @('--noprofile', '--norc', '-c', 'AI_GH_NO_WAIT=1 AI_GH_CALLER=ai-devops-installer "$1" auth status', 'bash', $ghGate)
    } else {
        $ghProbe = [pscustomobject]@{ ExitCode = 75 }
    }
    if ($ghProbe.ExitCode -eq 75) {
        Write-Note "GitHub login check deferred because Git Bash or the shared GitHub gate is unavailable."
    } elseif ($ghProbe.ExitCode -ne 0) {
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
    $kimiProbe = Invoke-NativeProbe -Command 'kimi' -Arguments @('--version')
    $kimiVersion = $kimiProbe.Output -join " "
    if ([string]::IsNullOrWhiteSpace($kimiVersion)) {
        Write-Note "Kimi Code CLI found."
    } else {
        Write-Note "Kimi Code CLI found: $kimiVersion"
    }
    Write-Note "For delegation auth, test: kimi -p `"reply with OK`". If it fails, run kimi login once."
} else {
    Write-Note "Kimi Code CLI not found. Install/login separately if you want the kimi-code-delegation skill to run local Kimi jobs."
}

if (Get-Command qwen -ErrorAction SilentlyContinue) {
    $qwenProbe = Invoke-NativeProbe -Command 'qwen' -Arguments @('--version')
    $qwenVersion = $qwenProbe.Output -join " "
    if ([string]::IsNullOrWhiteSpace($qwenVersion)) {
        Write-Note "Qwen Code CLI found."
    } else {
        Write-Note "Qwen Code CLI found: $qwenVersion"
    }
    $qwenBash = Get-GitBash
    if ($qwenBash) {
        $qwenWrapper = (Join-Path $RepoPath 'bin\ai-qwen') -replace '\\', '/'
        $keyProbe = Invoke-NativeProbe -Command $qwenBash.Source -Arguments @('--noprofile', '--norc', $qwenWrapper, 'store-key', '--if-missing')
        if ($keyProbe.ExitCode -eq 0) {
            Write-Note 'Qwen protected per-user key store is ready.'
        } else {
            Write-Note 'Qwen key store setup failed; review qualification remains unavailable until ai-qwen store-key succeeds.'
        }
    } else {
        Write-Note 'Git Bash is needed to prepare the Qwen key store.'
    }
    $grokBash = Get-GitBash
    $grokWrapper = (Join-Path $RepoPath 'bin\ai-grok-review') -replace '\\', '/'
    if ($grokBash -and (Test-Path -LiteralPath (Join-Path $RepoPath 'bin\ai-grok-review'))) {
        # API-key fallback used only when no Grok OAuth session (auth.json) exists.
        $grokKeyProbe = Invoke-NativeProbe -Command $grokBash.Source -Arguments @('--noprofile', '--norc', $grokWrapper, 'store-key', '--if-missing')
        if ($grokKeyProbe.ExitCode -eq 0) { Write-Note 'Grok protected per-user key store is ready.' }
        else { Write-Note 'Grok key store setup failed; Grok reviews need an OAuth session until ai-grok-review store-key succeeds.' }
    }
    Write-Note "Verify model access and completion with: ai-qwen doctor --live"
} else {
    Write-Note "Qwen Code CLI not found. Install/login separately if you want the qwen-code skill to run local Qwen jobs."
}

# ZCode is a Windows-only client; $env:ProgramFiles is empty on non-Windows
# runners, and Join-Path with an empty path is a terminating parameter error.
$zcodeAppPresent = [bool]$env:ProgramFiles -and (Test-Path -LiteralPath (Join-Path $env:ProgramFiles "ZCode\ZCode.exe"))
if ($zcodeAppPresent) {
    if (Test-Path -LiteralPath (Join-Path $ZCodeHome "v2\credentials.json")) {
        Write-Note "ZCode desktop app found and signed in."
    } else {
        Write-Note "ZCode desktop app found but NOT signed in. Run once: zcode login --no-browser"
        Write-Note "  (the URL prints to the terminal because Windows auto-open truncates login URLs at '&')."
    }
    Write-Note "Verify the full integration when needed with: ai-zcode doctor"
} else {
    Write-Note "ZCode desktop app not found. Install when needed: winget install ZhipuAI.ZCode"
}

if (-not $SkillsDryRun -and -not ($env:AI_DEVOPS_INSTALL_TEST_MODE -eq '1' -and
    $env:AI_DEVOPS_SKIP_MACHINE_TOOLS_GATE -eq '1' -and $env:AI_DEVOPS_TEST_EXPECTED_REMOTE -and
    (Get-CanonicalRemote $env:AI_DEVOPS_TEST_EXPECTED_REMOTE) -notmatch '^github[.]com/')) {
    Write-Step 'Refreshing managed command launchers'
    # Every completed source update must refresh the durable receipt. Otherwise
    # a later protected release sees an older baseline than this checkout.
    # Keep one-use authority through this final step so failure can be retried.
    & (Join-Path $RepoPath 'bin\install-machine-tools.ps1') -RepoPath $RepoPath
    if ($LASTEXITCODE -ne 0) { throw 'Managed command launcher installation failed.' }
    $script:ConsumingInstallAuthorization = $null
}
Write-Step "Done"
Write-Host "AI DevOps repo: $RepoPath"
Write-Host "Codex skills:  $(Join-Path $CodexHome 'skills')"
Write-Host "Claude skills: $(Join-Path $ClaudeHome 'skills')"
Write-Host ""
Write-Host "Future updates on this computer: rerun this same script."
} finally {
    if ($installMutexHeld) { $installMutex.ReleaseMutex() }
    $installMutex.Dispose()
}
