# Deliberately does not set StrictMode: this file is dot-sourced into scripts
# that were never written under it, and changing their strictness here would be
# an unrelated behavior change.

# Dot-source helper for the fail-closed repository identity guards.
# The allow-list itself lives in config/repo-identities.tsv; see that file for
# why widening it is a deliberate security decision. A missing, unreadable or
# empty table must reject every identity, never accept one.

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
