# Narrow installation primitives. Called only by the gated toolkit installer.
Set-StrictMode -Version Latest

function Assert-McpNarrowRegularPath {
    param([Parameter(Mandatory)][string]$Path)
    $current = [IO.Path]::GetFullPath($Path)
    while ($current) {
        if (Test-Path -LiteralPath $current) {
            $item = Get-Item -LiteralPath $current -Force
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'MCP installation refuses redirected paths.' }
        }
        $parent = Split-Path -Parent $current
        if ($parent -eq $current) { break }
        $current = $parent
    }
}

function Get-McpNarrowRemoteLauncher {
    param([Parameter(Mandatory)][string]$ScriptHash)
    if ($ScriptHash -cnotmatch '^[0-9a-f]{64}$') { throw 'MCP script hash is invalid.' }
    # The script path is fixed beside this launcher. PowerShell reads no secret
    # until both the protected installed bytes and this immutable hash agree.
    @"
@echo off
setlocal
set "AI_DEVOPS_MCP_SCRIPT=%~dp0mcp-secret-launch.ps1"
pwsh -NoProfile -Command "if ((Get-FileHash -LiteralPath `$env:AI_DEVOPS_MCP_SCRIPT -Algorithm SHA256).Hash.ToLowerInvariant() -cne '$ScriptHash') { exit 73 }"
if errorlevel 1 exit /b 73
pwsh -NoProfile -File "%~dp0mcp-secret-launch.ps1" -Mode Remote -Url %1 -SecretRef %2 %3 %4 %5 %6 %7 %8 %9
exit /b %errorlevel%
"@
}

function Copy-McpNarrowProtectedFile {
    param([Parameter(Mandatory)][string]$Source, [Parameter(Mandatory)][string]$Destination)
    Assert-McpNarrowRegularPath $Source
    Assert-McpNarrowRegularPath $Destination
    [IO.File]::WriteAllBytes($Destination, [IO.File]::ReadAllBytes($Source))
    Protect-AiDevOpsPrivatePath -Path $Destination
    if ((Get-FileHash -LiteralPath $Source).Hash -cne (Get-FileHash -LiteralPath $Destination).Hash) {
        throw 'MCP protected copy verification failed.'
    }
}

function Restore-McpNarrowInterruptedFiles {
    param([Parameter(Mandatory)][string]$ConfigurationRoot, [Parameter(Mandatory)][string]$TransactionRoot)
    $journalPath = Join-Path $TransactionRoot 'journal.json'
    if (-not (Test-Path -LiteralPath $journalPath)) { throw 'Interrupted MCP transaction has no recovery journal.' }
    Assert-McpNarrowRegularPath $journalPath
    Assert-AiDevOpsPrivateAcl $journalPath
    $journal = @(Get-Content -Raw -LiteralPath $journalPath | ConvertFrom-Json)
    $runtimeJournal = Join-Path $TransactionRoot 'runtime.json'
    if (Test-Path -LiteralPath $runtimeJournal) {
        Assert-AiDevOpsPrivateAcl $runtimeJournal
        $runtime = Join-Path $ConfigurationRoot 'mcp-runtime'
        if (Test-Path -LiteralPath $runtime) {
            if ((Get-McpNarrowTreeState $runtime) -cne [IO.File]::ReadAllText($runtimeJournal)) { throw 'Interrupted MCP runtime changed; refusing recovery.' }
        }
    }
    $fixed = @('mcp-remote-launch.cmd','mcp-session-guard.mjs','mcp-secret-launch.ps1')
    if ($journal.Count -ne 3 -or @($journal.leaf | Select-Object -Unique).Count -ne 3) { throw 'MCP recovery journal is incomplete.' }
    foreach ($entry in $journal) {
        if ($entry.leaf -cnotin $fixed) { throw 'MCP recovery path is outside fixed destinations.' }
        $destination = Join-Path $ConfigurationRoot $entry.leaf
        Assert-McpNarrowRegularPath $destination
        $current = if (Test-Path -LiteralPath $destination) { (Get-FileHash -LiteralPath $destination).Hash.ToLowerInvariant() } else { 'missing' }
        if ($current -cne $entry.before -and $current -cne $entry.after) { throw 'MCP destination changed after interruption; refusing recovery.' }
        if ($entry.before -cne 'missing') {
            $backup = Join-Path (Join-Path $TransactionRoot 'backup') $entry.leaf
            Assert-McpNarrowRegularPath $backup
            if ((Get-FileHash -LiteralPath $backup).Hash.ToLowerInvariant() -cne $entry.before) { throw 'MCP recovery backup changed.' }
        }
    }
    if ((Test-Path -LiteralPath $runtimeJournal) -and (Test-Path -LiteralPath (Join-Path $ConfigurationRoot 'mcp-runtime'))) {
        Remove-Item -LiteralPath (Join-Path $ConfigurationRoot 'mcp-runtime') -Recurse -Force
    }
    foreach ($entry in $journal) {
        $destination = Join-Path $ConfigurationRoot $entry.leaf
        if ($entry.before -ceq 'missing') {
            if (Test-Path -LiteralPath $destination) { Remove-Item -LiteralPath $destination -Force }
        } else {
            Copy-Item -LiteralPath (Join-Path (Join-Path $TransactionRoot 'backup') $entry.leaf) -Destination $destination -Force
            $acl = Get-Acl -LiteralPath $destination
            $acl.SetSecurityDescriptorSddlForm($entry.access_sddl, [Security.AccessControl.AccessControlSections]::Access)
            Set-Acl -LiteralPath $destination -AclObject $acl
        }
    }
    [IO.File]::WriteAllText((Join-Path $TransactionRoot 'rolled-back'), 'mcp-launchers-only')
}

function Get-McpNarrowTreeState {
    param([Parameter(Mandatory)][string]$Root)
    Assert-McpNarrowRegularPath $Root
    $records = foreach ($item in Get-ChildItem -LiteralPath $Root -Recurse -Force | Sort-Object FullName) {
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'MCP runtime tree contains a redirected path.' }
        $relative = [IO.Path]::GetRelativePath($Root, $item.FullName).Replace('\','/')
        $hash = if ($item.PSIsContainer) { 'directory' } else { (Get-FileHash -LiteralPath $item.FullName).Hash.ToLowerInvariant() }
        [ordered]@{ path = $relative; hash = $hash }
    }
    ConvertTo-Json -InputObject @($records) -Compress
}

function Invoke-McpNarrowFileTransaction {
    param(
        [Parameter(Mandatory)][string]$ConfigurationRoot,
        [Parameter(Mandatory)][string]$SourceRoot,
        [Parameter(Mandatory)][string]$TransactionRoot,
        [Parameter(Mandatory)][scriptblock]$VerifyAndFinalize,
        [switch]$InstallRuntime,
        [scriptblock]$Committed
    )
    $fixed = @('mcp-remote-launch.cmd', 'mcp-session-guard.mjs', 'mcp-secret-launch.ps1')
    foreach ($path in @($ConfigurationRoot, $SourceRoot, $TransactionRoot)) { Assert-McpNarrowRegularPath $path }
    if (-not (Test-Path -LiteralPath $ConfigurationRoot -PathType Container)) { throw 'MCP configuration directory is missing.' }
    if (Test-Path -LiteralPath $TransactionRoot) { throw 'Unresolved MCP transaction exists; recovery is required.' }
    New-Item -ItemType Directory -Path $TransactionRoot | Out-Null
    Protect-AiDevOpsPrivatePath -Path $TransactionRoot -Directory
    $backup = Join-Path $TransactionRoot 'backup'
    $stage = Join-Path $TransactionRoot 'stage'
    New-Item -ItemType Directory -Path $backup, $stage | Out-Null
    $prior = @{}
    $priorAcl = @{}
    foreach ($leaf in $fixed) {
        $destination = Join-Path $ConfigurationRoot $leaf
        Assert-McpNarrowRegularPath $destination
        $prior[$leaf] = Test-Path -LiteralPath $destination
        if ($prior[$leaf]) {
            $priorAcl[$leaf] = (Get-Acl -LiteralPath $destination).GetSecurityDescriptorSddlForm([Security.AccessControl.AccessControlSections]::Access)
            Copy-Item -LiteralPath $destination -Destination (Join-Path $backup $leaf)
        } else { $priorAcl[$leaf] = '' }
    }
    $prior | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $TransactionRoot 'before.json') -Encoding utf8
    foreach ($leaf in @('mcp-session-guard.mjs', 'mcp-secret-launch.ps1')) {
        Copy-McpNarrowProtectedFile -Source (Join-Path (Join-Path $SourceRoot 'bin') $leaf) -Destination (Join-Path $stage $leaf)
    }
    $hash = (Get-FileHash -LiteralPath (Join-Path $stage 'mcp-secret-launch.ps1')).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText((Join-Path $stage 'mcp-remote-launch.cmd'), (Get-McpNarrowRemoteLauncher $hash), [Text.Encoding]::ASCII)
    Protect-AiDevOpsPrivatePath -Path (Join-Path $stage 'mcp-remote-launch.cmd')
    $journal = foreach ($leaf in $fixed) {
        $before = if ($prior[$leaf]) { (Get-FileHash -LiteralPath (Join-Path $backup $leaf)).Hash.ToLowerInvariant() } else { 'missing' }
        @{ leaf = $leaf; before = $before; after = (Get-FileHash -LiteralPath (Join-Path $stage $leaf)).Hash.ToLowerInvariant(); access_sddl = $priorAcl[$leaf] }
    }
    $journalPath = Join-Path $TransactionRoot 'journal.json'
    $journal | ConvertTo-Json | Set-Content -LiteralPath $journalPath -Encoding utf8
    Protect-AiDevOpsPrivatePath -Path $journalPath
    $written = @()
    $runtimeCreated = $false
    try {
        if ($InstallRuntime) { $runtimeCreated = Initialize-McpNarrowRuntime $ConfigurationRoot $SourceRoot $TransactionRoot }
        foreach ($leaf in $fixed) {
            $written += $leaf
            Copy-McpNarrowProtectedFile -Source (Join-Path $stage $leaf) -Destination (Join-Path $ConfigurationRoot $leaf)
        }
        & $VerifyAndFinalize
        # The gate receipt is the durable commit point. Keep backups as evidence.
    } catch {
        if ($Committed -and (& $Committed)) { throw }
        Restore-McpNarrowInterruptedFiles $ConfigurationRoot $TransactionRoot
        throw
    }
}

function Initialize-McpNarrowRuntime {
    param([Parameter(Mandatory)][string]$ConfigurationRoot, [Parameter(Mandatory)][string]$SourceRoot,
          [Parameter(Mandatory)][string]$TransactionRoot)
    $runtime = Join-Path $ConfigurationRoot 'mcp-runtime'
    Assert-McpNarrowRegularPath $runtime
    if (Test-Path -LiteralPath $runtime) {
        $package = Join-Path $runtime 'node_modules\mcp-remote\package.json'
        if (-not (Test-Path -LiteralPath $package)) { throw 'Existing MCP runtime is incomplete; repair requires its own reviewed inventory.' }
        if ((Get-Content -Raw -LiteralPath $package | ConvertFrom-Json).version -cne '0.1.38') { throw 'Existing MCP runtime is not pinned to the reviewed version.' }
        if (-not (Test-Path -LiteralPath (Join-Path $runtime 'node_modules\.bin\mcp-remote.cmd'))) { throw 'Pinned MCP command is absent.' }
        # Its complete tree is sealed by the authority's preflight inventory;
        # retain every existing stdio MCP package and its exact bytes.
        return $false
    }
    $staged = Join-Path $TransactionRoot 'runtime-stage'
    New-Item -ItemType Directory -Path $staged | Out-Null
    Protect-AiDevOpsPrivatePath -Path $staged -Directory
    foreach ($leaf in @('package.json','package-lock.json')) {
        Copy-Item -LiteralPath (Join-Path (Join-Path $SourceRoot 'config\mcp-remote-runtime') $leaf) -Destination $staged
    }
    $npm = Get-Command npm.cmd -ErrorAction Stop
    # npm is confined to protected staging. Disable scripts, audit, funding,
    # global configuration and user caches; no unrelated installation occurs.
    & $npm.Source ci --prefix $staged --cache (Join-Path $TransactionRoot 'npm-cache') --ignore-scripts --no-audit --no-fund --silent
    if ($LASTEXITCODE -ne 0) { throw 'Scoped pinned MCP runtime staging failed.' }
    foreach ($item in Get-ChildItem -LiteralPath $staged -Recurse -Force) {
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Scoped MCP runtime contains a redirected path.' }
    }
    $package = Get-Content -Raw -LiteralPath (Join-Path $staged 'node_modules\mcp-remote\package.json') | ConvertFrom-Json
    if ($package.version -cne '0.1.38' -or -not (Test-Path -LiteralPath (Join-Path $staged 'node_modules\.bin\mcp-remote.cmd'))) {
        throw 'Scoped MCP runtime did not produce the pinned remote command.'
    }
    $runtimeJournal = Join-Path $TransactionRoot 'runtime.json'
    [IO.File]::WriteAllText($runtimeJournal, (Get-McpNarrowTreeState $staged))
    Protect-AiDevOpsPrivatePath -Path $runtimeJournal
    Move-Item -LiteralPath $staged -Destination $runtime
    return $true
}
