# Deliberately does not set StrictMode: this file is dot-sourced into scripts
# that were never written under it, and changing their strictness here would be
# an unrelated behavior change.

# Dot-source helper for the fail-closed repository identity guards.
# The allow-list itself lives in config/repo-identities.tsv; see that file for
# why widening it is a deliberate security decision. A missing, unreadable or
# empty table must reject every identity, never accept one.

# The ONE canonicaliser for both Windows callers. Previously bootstrap and the
# installer each inlined their own copy, and both were blind to ssh:// URLs --
# so a fresh clone taken with ssh://git@github.com/... would have been refused
# on Windows while the Bash reader accepted it. That is the post-transfer
# failure this whole change exists to prevent.
function Get-AiDevOpsCanonicalRemote {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Url)
    if (-not $Url) { return '' }
    $value = $Url.Trim()
    $value = $value -creplace '^git@github[.]com:', 'github.com/'
    $value = $value -creplace '^ssh://git@github[.]com/', 'github.com/'
    $value = $value -creplace '^https?://github[.]com/', 'github.com/'
    $value = $value.TrimEnd('/')
    $value = $value -creplace '[.]git$', ''
    return $value.TrimEnd('/')
}

function Get-AiDevOpsRepoIdentityTable {
    [CmdletBinding()]
    param([string]$Path)
    if (-not $Path) {
        if ($env:AI_REPO_IDENTITY_FILE) { $Path = $env:AI_REPO_IDENTITY_FILE }
        else { $Path = Join-Path (Split-Path -Parent $PSScriptRoot) 'config\repo-identities.tsv' }
    }
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Repository identity table not found: $Path"
    }
    return $Path
}

function Get-AiDevOpsAcceptedIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Key,
        [string]$Path
    )
    $table = Get-AiDevOpsRepoIdentityTable -Path $Path
    $accepted = New-Object 'System.Collections.Generic.List[string]'
    foreach ($line in [IO.File]::ReadAllLines($table)) {
        $row = $line.TrimEnd("`r")
        if (-not $row -or $row.StartsWith('#')) { continue }
        $parts = $row -split "`t"
        if ($parts.Count -lt 2) { continue }
        if ($parts[0] -cne $Key) { continue }
        $value = $parts[1].Trim()
        if ($value) { [void]$accepted.Add($value) }
    }
    return $accepted.ToArray()
}

function Assert-AiDevOpsRepoIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Identity,
        [Parameter(Mandatory)][string]$Message,
        [string]$Path
    )
    $accepted = @(Get-AiDevOpsAcceptedIdentity -Key $Key -Path $Path)
    if ($accepted.Count -eq 0) {
        throw "No accepted identity is configured for '$Key'; refusing to continue."
    }
    if ($accepted -cnotcontains $Identity) {
        throw "$Message (accepted: $($accepted -join ', '))"
    }
}

# --- clone-root resolution (project-scoped MCP, #705) ------------------------
# Mirrors find_repo_clone_roots in bin/ai-install-skills: a directory named
# after the identity key, at a scan root or one level nested
# (dflow_plm/designflow-frontend), whose origin matches an accepted identity,
# plus every worktree of that clone. Fail-closed: an origin that is not
# accepted is skipped, and a key with no accepted identity returns no roots
# (callers treat that as "not cloned here", which keeps servers global).

function Get-AiDevOpsCloneScanRoots {
    # AI_REPO_CLONE_ROOTS (path-list, ';' separated) overrides the standard
    # locations for tests and non-standard layouts. No scheme or drive magic.
    if ($env:AI_REPO_CLONE_ROOTS) {
        return @($env:AI_REPO_CLONE_ROOTS -split ';' | Where-Object { $_ -and (Test-Path -LiteralPath $_) })
    }
    $candidates = New-Object 'System.Collections.Generic.List[string]'
    if ($env:SystemDrive) {
        [void]$candidates.Add((Join-Path $env:SystemDrive 'repos'))
        [void]$candidates.Add((Join-Path $env:SystemDrive 'worksp'))
    }
    foreach ($drive in ([IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' -and $_.IsReady })) {
        $driveRoot = $drive.RootDirectory.FullName
        [void]$candidates.Add((Join-Path $driveRoot 'repos'))
        [void]$candidates.Add((Join-Path $driveRoot 'worksp'))
    }
    if ($HOME) {
        [void]$candidates.Add((Join-Path $HOME 'repos'))
    }
    $roots = New-Object 'System.Collections.Generic.List[string]'
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($base in $candidates) {
        if ($base -and (Test-Path -LiteralPath $base)) {
            $full = ([IO.Path]::GetFullPath($base)).TrimEnd('\', '/')
            if ($seen.Add($full)) { [void]$roots.Add($full) }
        }
    }
    return $roots.ToArray()
}

function Get-AiDevOpsCloneRoots {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Key,
        [string]$Path
    )
    $accepted = @(Get-AiDevOpsAcceptedIdentity -Key $Key -Path $Path)
    if ($accepted.Count -eq 0) { return ,@() }
    $found = New-Object 'System.Collections.Generic.List[string]'
    foreach ($scanRoot in (Get-AiDevOpsCloneScanRoots)) {
        $candidates = @(Join-Path $scanRoot $Key)
        Get-ChildItem -LiteralPath $scanRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $nested = Join-Path $_.FullName $Key
            if (Test-Path -LiteralPath $nested) { $candidates += $nested }
        }
        foreach ($clone in ($candidates | Sort-Object -Unique)) {
            if (-not (Test-Path -LiteralPath (Join-Path $clone '.git'))) { continue }
            $url = git -C $clone remote get-url origin 2>$null
            if (-not $url) { continue }
            $identity = Get-AiDevOpsCanonicalRemote ([string]$url)
            if ($accepted -cnotcontains $identity) { continue }
            # git prints forward slashes; Join-Path yields backslashes. One
            # canonical form so a worktree's main entry is not added twice.
            if (-not $found.Contains(($clone -replace '/', '\'))) { [void]$found.Add($clone) }
            $listing = git -C $clone worktree list --porcelain 2>$null
            foreach ($line in @($listing)) {
                if ($line -like 'worktree *') {
                    $wt = $line.Substring(8).Trim()
                    if ($wt -and (Test-Path -LiteralPath $wt) -and -not $found.Contains(($wt -replace '/', '\'))) {
                        [void]$found.Add($wt)
                    }
                }
            }
        }
    }
    return $found
}

function Get-AiDevOpsProjectDeliveryRoots {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Key,
        [string]$Path
    )
    $result = New-Object 'System.Collections.Generic.List[string]'
    $clones = @(Get-AiDevOpsCloneRoots -Key $Key -Path $Path | Where-Object { $_ })
    if ($clones.Count -eq 0) { return $result }
    $scanSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($sr in (Get-AiDevOpsCloneScanRoots)) {
        [void]$scanSet.Add(([IO.Path]::GetFullPath($sr)).TrimEnd('\', '/'))
    }
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($root in $clones) {
        if (-not $root) { continue }
        $norm = ([IO.Path]::GetFullPath($root)).TrimEnd('\', '/')
        if ($seen.Add($norm)) { [void]$result.Add($norm) }
        # Only primary clones (where .git is a directory) propagate to a
        # multi-repo non-git parent folder (e.g. D:\repos\dflow_plm).
        if (-not (Test-Path -LiteralPath (Join-Path $norm '.git') -PathType Container)) { continue }
        $parent = Split-Path -Parent $norm
        if (-not $parent) { continue }
        $parentNorm = ([IO.Path]::GetFullPath($parent)).TrimEnd('\', '/')
        if ($scanSet.Contains($parentNorm)) { continue }
        if (Test-Path -LiteralPath (Join-Path $parentNorm '.git')) { continue }
        $leaf = Split-Path -Leaf $parentNorm
        if ($leaf -match '(^|[.-])worktrees$') { continue }
        if ($seen.Add($parentNorm)) { [void]$result.Add($parentNorm) }
    }
    return $result
}
