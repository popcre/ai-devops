[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $HubPath,
    [Parameter(Mandatory)] [string] $PublicMemoryPath,
    [Parameter(Mandatory)] [string[]] $MachineSource
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-CanonicalProject([string] $Slug) {
    $known = @{
        'C--repos-temp-1Password-MCP' = '1password-mcp'
        'C--PopDAM-popdam3' = 'popdam3'
        'D--openclaw' = 'openclaw'
        'D--popdam-claude-supabase-mcp' = 'claude-supabase-mcp'
        'D--synology-monitor' = 'synology-monitor'
        '-' = 'hetz-root'
        '-worksp' = 'worksp-root'
    }
    if ($known.ContainsKey($Slug)) { return $known[$Slug] }
    if ($Slug.StartsWith('-worksp-')) { return $Slug.Substring(8) }
    $marker = $Slug.LastIndexOf('repos-')
    if ($marker -ge 0) { return $Slug.Substring($marker + 6) }
    return $Slug
}

function Copy-UnionFile([System.IO.FileInfo] $Source, [string] $DestinationDirectory, [string] $Label) {
    New-Item -ItemType Directory -Path $DestinationDirectory -Force | Out-Null
    $target = Join-Path $DestinationDirectory $Source.Name

    if ($Source.Name -eq '.forgotten') {
        $lines = @()
        if (Test-Path -LiteralPath $target) { $lines += Get-Content -LiteralPath $target }
        $lines += Get-Content -LiteralPath $Source.FullName
        $lines | Where-Object { $_.Trim() } | Select-Object -Unique |
            Set-Content -LiteralPath $target -Encoding utf8NoBOM
        return
    }

    if ($Source.Name -eq 'MEMORY.md') { return }
    if (-not (Test-Path -LiteralPath $target)) {
        Copy-Item -LiteralPath $Source.FullName -Destination $target
        return
    }

    $sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Source.FullName).Hash
    $targetHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $target).Hash
    if ($sourceHash -eq $targetHash) { return }

    $base = [System.IO.Path]::GetFileNameWithoutExtension($Source.Name)
    $extension = [System.IO.Path]::GetExtension($Source.Name)
    $safeLabel = $Label -replace '[^A-Za-z0-9._-]', '-'
    $candidate = Join-Path $DestinationDirectory "$base--$safeLabel$extension"
    $suffix = 2
    while (Test-Path -LiteralPath $candidate) {
        if ((Get-FileHash -Algorithm SHA256 -LiteralPath $candidate).Hash -eq $sourceHash) { return }
        $candidate = Join-Path $DestinationDirectory "$base--$safeLabel-$suffix$extension"
        $suffix++
    }
    Copy-Item -LiteralPath $Source.FullName -Destination $candidate
}

$resolvedHub = [System.IO.Path]::GetFullPath($HubPath)
$resolvedPublic = [System.IO.Path]::GetFullPath($PublicMemoryPath)
if ($resolvedHub.StartsWith($resolvedPublic, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'The private hub cannot live inside the public memory tree.'
}

$memoryRoot = Join-Path $resolvedHub 'memory'
New-Item -ItemType Directory -Path $memoryRoot -Force | Out-Null

# Public memory is already arranged by canonical project name.
Get-ChildItem -LiteralPath $resolvedPublic -Directory | ForEach-Object {
    $destination = Join-Path $memoryRoot $_.Name
    Get-ChildItem -LiteralPath $_.FullName -File | ForEach-Object {
        Copy-UnionFile $_ $destination 'public'
    }
}

# Each source is label|layout|path. FlatSlugs means files live directly under
# each slug; ProjectSlugs means each slug contains a memory directory.
foreach ($sourceSpec in $MachineSource) {
    $parts = $sourceSpec.Split('|', 3)
    if ($parts.Count -ne 3) { throw "Invalid machine source: $sourceSpec" }
    $label, $layout, $sourcePath = $parts
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Container)) {
        throw "Machine source does not exist: $label"
    }
    Get-ChildItem -LiteralPath $sourcePath -Directory | ForEach-Object {
        $factPath = if ($layout -eq 'ProjectSlugs') { Join-Path $_.FullName 'memory' } else { $_.FullName }
        if (-not (Test-Path -LiteralPath $factPath -PathType Container)) { return }
        $project = Get-CanonicalProject $_.Name
        $destination = Join-Path $memoryRoot $project
        Get-ChildItem -LiteralPath $factPath -File | ForEach-Object {
            Copy-UnionFile $_ $destination $label
        }
    }
}

# Tombstones are the only deletion authority. Rebuild every index from the
# surviving fact files so an orphan cannot become unreachable.
$factCount = 0
Get-ChildItem -LiteralPath $memoryRoot -Directory | Sort-Object Name | ForEach-Object {
    $projectDirectory = $_
    $forgotten = Join-Path $projectDirectory.FullName '.forgotten'
    if (Test-Path -LiteralPath $forgotten) {
        foreach ($line in Get-Content -LiteralPath $forgotten) {
            if (-not $line.Trim() -or $line.StartsWith('#')) { continue }
            $name = $line.Split("`t", 2)[0]
            $forgottenPath = Join-Path $projectDirectory.FullName $name
            if (Test-Path -LiteralPath $forgottenPath -PathType Leaf) {
                Remove-Item -LiteralPath $forgottenPath
            }
        }
    }
    $facts = @(Get-ChildItem -LiteralPath $projectDirectory.FullName -File -Filter '*.md' |
        Where-Object Name -ne 'MEMORY.md' | Sort-Object Name)
    $index = @("# Memory index - $($projectDirectory.Name)", '')
    foreach ($fact in $facts) {
        $title = [System.IO.Path]::GetFileNameWithoutExtension($fact.Name) -replace '[-_]+', ' '
        $index += "- [$title]($($fact.Name)) - Portable fact."
        $factCount++
    }
    $index | Set-Content -LiteralPath (Join-Path $projectDirectory.FullName 'MEMORY.md') -Encoding utf8NoBOM
}

$secretPattern = '(ops_[A-Za-z0-9]{20}|gh[pousr]_[A-Za-z0-9]{20}|github_pat_[A-Za-z0-9_]{20}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY|xox[baprs]-[A-Za-z0-9-]{10}|sk-[A-Za-z0-9]{20}|eyJ[A-Za-z0-9_-]{18,}\.[A-Za-z0-9_-]{18,}\.)'
$hits = @(Get-ChildItem -LiteralPath $memoryRoot -File -Recurse | Where-Object {
    (Get-Content -LiteralPath $_.FullName -Raw) -match $secretPattern
})
if ($hits.Count -gt 0) {
    Write-Error ("Secret-pattern scan blocked publication in {0} file(s): {1}" -f
        $hits.Count, (($hits | ForEach-Object { $_.FullName.Substring($resolvedHub.Length + 1) }) -join ', '))
}

$projects = @(Get-ChildItem -LiteralPath $memoryRoot -Directory).Count
Write-Output "PRIVATE_MEMORY_UNION projects=$projects facts=$factCount secret_hits=0"
