# One Git Bash candidate list for every managed-launcher route decision.
# bin/install-machine-tools.ps1 writes the first existing candidate into the
# launchers it generates, and bin/install-ai-devops-windows.ps1 accepts
# exactly this set in its source receipts. ProgramFiles (and LOCALAPPDATA) can
# be absent in service and task environments (#1713) while Git for Windows is
# still installed under the standard root, so that root is always offered —
# the same probe bin/ai-task-gates windows_program_files() performs on the
# bash side. Keeping one list here stops the generator and the validator from
# drifting apart again.

function Get-AiDevOpsGitBashCandidates {
    @(
        if ($env:ProgramFiles) { Join-Path $env:ProgramFiles 'Git\bin\bash.exe' }
        'C:\Program Files\Git\bin\bash.exe'
        if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'Programs\Git\bin\bash.exe' }
    ) | Select-Object -Unique
}

function Select-AiDevOpsGitBash {
    Get-AiDevOpsGitBashCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
