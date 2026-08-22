$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$helper = Join-Path $root 'bin\windows-git-bash-path.ps1'
$gitBash = 'C:\Program Files\Git\bin\bash.exe'

if (-not (Test-Path -LiteralPath $gitBash -PathType Leaf)) {
    Write-Host 'SKIP: Git Bash is unavailable.'
    exit 0
}

. $helper
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ("ai-devops-path-bridge-" + [guid]::NewGuid())
try {
    New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
    $fixture = Join-Path $fixtureRoot 'protected-ssh-config'
    [IO.File]::WriteAllText($fixture, "Host test`n")
    $posixPath = (& $gitBash -c 'cygpath -u -- "$1"' -- $fixture | Select-Object -Last 1).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($posixPath)) {
        throw 'Could not build the Git Bash path fixture.'
    }

    $expected = (Resolve-Path -LiteralPath $fixture).Path
    $translated = ConvertFrom-GitBashPath -Path $posixPath -GitBashPath $gitBash
    if ($translated -ne $expected) { throw "Git Bash path translated incorrectly: $translated" }
    $native = ConvertFrom-GitBashPath -Path $fixture -GitBashPath $gitBash
    if ($native -ne $expected) { throw "Native Windows path changed unexpectedly: $native" }

    $missingFailed = $false
    try {
        ConvertFrom-GitBashPath -Path "$posixPath-missing" -GitBashPath $gitBash | Out-Null
    } catch {
        $missingFailed = $true
    }
    if (-not $missingFailed) { throw 'Missing translated path did not fail closed.' }

    Write-Host 'PASS: Git Bash paths are translated to verified native Windows files'
} finally {
    if (Test-Path -LiteralPath $fixtureRoot) {
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
    }
}
