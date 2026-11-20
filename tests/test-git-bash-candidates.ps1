# One Git Bash candidate list backs both the launcher generator and the
# Windows installer's source receipts (bin/git-bash-candidates.ps1). #2709
# host shape: ProgramFiles absent from the environment while Git for Windows
# lives under the standard root — the generator used to crash and the receipt
# check used to reject the launchers it had generated.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'bin\git-bash-candidates.ps1')

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
}

$savedProgramFiles = $env:ProgramFiles
$savedLocalAppData = $env:LOCALAPPDATA

# The standard root is always offered, even with the env roots gone.
Remove-Item Env:ProgramFiles -ErrorAction SilentlyContinue
Remove-Item Env:LOCALAPPDATA -ErrorAction SilentlyContinue
$candidates = @(Get-AiDevOpsGitBashCandidates)
Assert ($candidates -ccontains 'C:\Program Files\Git\bin\bash.exe') 'standard Git Bash root missing when ProgramFiles is absent'
if (Test-Path -LiteralPath 'C:\Program Files\Git\bin\bash.exe') {
    Assert ((Select-AiDevOpsGitBash) -ceq 'C:\Program Files\Git\bin\bash.exe') 'selector misses Git Bash under the standard root'
}

# Env roots keep their historical preference ahead of the standard fallback.
$env:ProgramFiles = 'C:\Program Files'
$env:LOCALAPPDATA = 'C:\Users\probe\AppData\Local'
$candidates = @(Get-AiDevOpsGitBashCandidates)
Assert ($candidates[0] -ceq 'C:\Program Files\Git\bin\bash.exe') 'env ProgramFiles root is not the preferred candidate'
Assert ($candidates -ccontains 'C:\Users\probe\AppData\Local\Programs\Git\bin\bash.exe') 'LOCALAPPDATA candidate missing'
$env:ProgramFiles = 'C:\Probe Only'
$candidates = @(Get-AiDevOpsGitBashCandidates)
Assert ($candidates[0] -ceq 'C:\Probe Only\Git\bin\bash.exe') 'env ProgramFiles root is not preferred when set'
Assert ($candidates -ccontains 'C:\Program Files\Git\bin\bash.exe') 'standard root dropped when ProgramFiles points elsewhere'

# The selector returns the first candidate that exists on disk.
$selected = Select-AiDevOpsGitBash
if ($selected) {
    Assert ((Get-AiDevOpsGitBashCandidates) -ccontains $selected) 'selector returned a path outside the candidate list'
    Assert (Test-Path -LiteralPath $selected) 'selector returned a missing Git Bash'
}

if ($null -ne $savedProgramFiles) { $env:ProgramFiles = $savedProgramFiles }
if ($null -ne $savedLocalAppData) { $env:LOCALAPPDATA = $savedLocalAppData }
Write-Host 'PASS: git-bash-candidates'
