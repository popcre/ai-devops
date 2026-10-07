$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'bin\windows-private-file.ps1')
. (Join-Path $root 'bin\mcp-launcher-install-windows.ps1')
$temp = Join-Path ([IO.Path]::GetTempPath()) ('mcp-narrow-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
try {
    $cfg = Join-Path $temp 'cfg'
    $source = Join-Path $temp 'source'
    New-Item -ItemType Directory -Path $cfg, (Join-Path $source 'bin') -Force | Out-Null
    foreach ($leaf in @('mcp-session-guard.mjs','mcp-secret-launch.ps1')) {
        [IO.File]::WriteAllText((Join-Path $source "bin\$leaf"), "fixture-$leaf")
    }
    [IO.File]::WriteAllText((Join-Path $cfg 'mcp-remote-launch.cmd'), 'prior-launcher')
    [IO.File]::WriteAllText((Join-Path $cfg 'unrelated'), 'keep')
    $failed = $false
    try {
        Invoke-McpNarrowFileTransaction $cfg $source (Join-Path $temp 'failed') { throw 'probe refused' }
    } catch { $failed = $true }
    if (-not $failed) { throw 'Failed probe was accepted.' }
    if ([IO.File]::ReadAllText((Join-Path $cfg 'mcp-remote-launch.cmd')) -cne 'prior-launcher') { throw 'Prior launcher was not restored.' }
    if (Test-Path (Join-Path $cfg 'mcp-secret-launch.ps1')) { throw 'Previously absent script was not rolled back.' }
    Invoke-McpNarrowFileTransaction $cfg $source (Join-Path $temp 'passed') {
        Assert-AiDevOpsPrivateAcl (Join-Path $cfg 'mcp-secret-launch.ps1')
    }
    $launcher = [IO.File]::ReadAllText((Join-Path $cfg 'mcp-remote-launch.cmd'))
    $hash = (Get-FileHash (Join-Path $cfg 'mcp-secret-launch.ps1')).Hash.ToLowerInvariant()
    if (-not $launcher.Contains($hash) -or -not $launcher.Contains('if errorlevel 1 exit /b 73')) { throw 'Launcher does not fail closed on hash mismatch.' }
    if ($launcher.Contains($source)) { throw 'Launcher depends on mutable source checkout.' }
    if ([IO.File]::ReadAllText((Join-Path $cfg 'unrelated')) -cne 'keep') { throw 'Unrelated configuration changed.' }
    $refused = $false
    try { Invoke-McpNarrowFileTransaction $cfg $source (Join-Path $temp 'passed') {} } catch { $refused = $true }
    if (-not $refused) { throw 'Existing transaction was reused.' }
    $refused = $false
    try { Get-McpNarrowRemoteLauncher 'invalid' | Out-Null } catch { $refused = $true }
    if (-not $refused) { throw 'Malformed source hash accepted.' }
    # Simulate process interruption after publication, before the receipt.
    [IO.File]::WriteAllText((Join-Path $cfg 'mcp-session-guard.mjs'), 'foreign-change')
    $refused = $false
    try { Restore-McpNarrowInterruptedFiles $cfg (Join-Path $temp 'passed') } catch { $refused = $true }
    if (-not $refused) { throw 'Crash recovery overwrote a later change.' }
    [IO.File]::WriteAllText((Join-Path $cfg 'mcp-session-guard.mjs'), 'fixture-mcp-session-guard.mjs')
    Restore-McpNarrowInterruptedFiles $cfg (Join-Path $temp 'passed')
    if ([IO.File]::ReadAllText((Join-Path $cfg 'mcp-remote-launch.cmd')) -cne 'prior-launcher') { throw 'Interrupted launcher was not recovered.' }
    if (Test-Path (Join-Path $cfg 'mcp-secret-launch.ps1')) { throw 'Interrupted absent script was not recovered.' }
    Write-Host 'PASS: narrow Windows fixed files, durable hash binding, rollback, private ACL, and refusal.'
} finally { Remove-Item -LiteralPath $temp -Recurse -Force }
