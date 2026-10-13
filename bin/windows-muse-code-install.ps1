# Muse Code on Windows: when the pinned binary is absent, run Meta's official
# Windows installer (Albert approved automatic install, 2026-09-25, as on
# Linux), then verify the pinned version and SHA-256. ai-muse runs only that
# hashed file; the auto-updating `muse` launcher is never run from here.
# Dot-source this file; Install-AiDevOpsMuseCode throws on any failure.

$script:AiDevOpsMuseInstallerUrl = 'https://dev.meta.ai/install.ps1'

function Install-AiDevOpsMuseCode {
    param(
        [Parameter(Mandatory)][string]$RepoPath,
        [string]$InstallDir = '',
        # Test seams: fetch the installer to a path, then run it.
        [scriptblock]$Fetch = { param($Uri, $Destination) Invoke-WebRequest -Uri $Uri -OutFile $Destination -UseBasicParsing },
        [scriptblock]$RunInstaller = {
            param($Script)
            # Windows PowerShell 5.1 turns native stderr into a terminating
            # error under 'Stop'; judge the installer by its exit code only.
            $ErrorActionPreference = 'Continue'
            $ps = (Get-Process -Id $PID).Path
            & $ps -NoProfile -ExecutionPolicy Bypass -File $Script *> $null
            if ($LASTEXITCODE -ne 0) { throw "installer exit code $LASTEXITCODE" }
        }
    )
    $pin = Join-Path $RepoPath 'config\muse-code'
    $versionFile = Join-Path $pin 'version'
    $shaFile = Join-Path $pin 'sha256'
    if (-not (Test-Path -LiteralPath $versionFile) -or -not (Test-Path -LiteralPath $shaFile)) {
        throw 'no Windows Muse Code pin in config\muse-code'
    }
    $version = ((Get-Content -Raw -LiteralPath $versionFile) -replace '\s', '')
    $want = ((Get-Content -Raw -LiteralPath $shaFile) -replace '\s', '').ToLowerInvariant()
    if (-not $InstallDir) {
        if (-not $env:LOCALAPPDATA) { throw 'LOCALAPPDATA is not set' }
        $InstallDir = Join-Path $env:LOCALAPPDATA 'Programs\muse'
    }
    $bin = Join-Path $InstallDir "muse-bin-$version.exe"
    $installed = $false
    if (-not (Test-Path -LiteralPath $bin -PathType Leaf)) {
        $temp = Join-Path ([IO.Path]::GetTempPath()) ('ai-devops-muse-install-' + [guid]::NewGuid() + '.ps1')
        try {
            try {
                & $Fetch $script:AiDevOpsMuseInstallerUrl $temp
                & $RunInstaller $temp
            } catch {
                throw "Meta's Muse Code installer failed: $($_.Exception.Message)"
            }
        } finally {
            Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
        }
        $installed = $true
    }
    if (-not (Test-Path -LiteralPath $bin -PathType Leaf)) {
        throw "Meta installed a different Muse Code than the pinned $version; re-pin config\muse-code"
    }
    $got = (Get-FileHash -Algorithm SHA256 -LiteralPath $bin).Hash.ToLowerInvariant()
    if ($got -ne $want) { throw "Muse Code $version does not match the pinned SHA-256" }
    if ($installed) { return "installed and verified Muse Code $version" }
    return "Muse Code $version already present and verified"
}
