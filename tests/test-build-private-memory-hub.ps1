$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$script = Join-Path $root 'tools/memory/build-private-hub.ps1'
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ("ai-memory-union-" + [guid]::NewGuid())
try {
    $public = Join-Path $temp 'public'
    $machineA = Join-Path $temp 'machine-a'
    $machineB = Join-Path $temp 'machine-b'
    $hub = Join-Path $temp 'hub'
    New-Item -ItemType Directory -Path (Join-Path $public 'sample'),
        (Join-Path $machineA 'C--repos-sample'),
        (Join-Path $machineB '-worksp-sample/memory'), $hub -Force | Out-Null
    '# old index' | Set-Content (Join-Path $public 'sample/MEMORY.md')
    'public' | Set-Content (Join-Path $public 'sample/public.md')
    'machine a' | Set-Content (Join-Path $machineA 'C--repos-sample/a.md')
    'machine b' | Set-Content (Join-Path $machineB '-worksp-sample/memory/b.md')
    "public.md`t2026-08-21`twritten tombstone" |
        Set-Content (Join-Path $machineA 'C--repos-sample/.forgotten')

    & $script -HubPath $hub -PublicMemoryPath $public -MachineSource @(
        "a|FlatSlugs|$machineA",
        "b|ProjectSlugs|$machineB"
    ) | Out-Null

    $project = Join-Path $hub 'memory/sample'
    if (Test-Path (Join-Path $project 'public.md')) { throw 'tombstoned fact survived' }
    if (-not (Test-Path (Join-Path $project 'a.md'))) { throw 'machine A fact missing' }
    if (-not (Test-Path (Join-Path $project 'b.md'))) { throw 'machine B fact missing' }
    $index = Get-Content (Join-Path $project 'MEMORY.md') -Raw
    if ($index -notmatch '\(a\.md\)' -or $index -notmatch '\(b\.md\)') { throw 'index did not cover union' }
    if ($index -match '\(public\.md\)') { throw 'index retained tombstoned fact' }

    $bash = 'C:\Program Files\Git\bin\bash.exe'
    if (Test-Path -LiteralPath $bash) {
        $hubUnix = (& 'C:\Program Files\Git\usr\bin\cygpath.exe' -u $hub).Trim()
        & $bash (Join-Path $root 'bin/ai-memory-health') --repo-root $hubUnix --hub-only --index-only | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'ai-memory-health rejected the rebuilt hub indexes' }
    }

    'ghp_abcdefghijklmnopqrstuvwxyz123456' | Set-Content (Join-Path $machineA 'C--repos-sample/leak.md')
    $blocked = $false
    try {
        & $script -HubPath $hub -PublicMemoryPath $public -MachineSource "a|FlatSlugs|$machineA" 2>$null | Out-Null
    } catch { $blocked = $true }
    if (-not $blocked) { throw 'secret-pattern fixture did not block publication' }
    Write-Output 'PASS: private memory union preserves facts, honors tombstones, indexes all facts, and blocks secret patterns'
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
