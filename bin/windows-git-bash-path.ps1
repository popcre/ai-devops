function ConvertFrom-GitBashPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [string]$GitBashPath = 'C:\Program Files\Git\bin\bash.exe'
    )

    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        return (Resolve-Path -LiteralPath $Path).Path
    }
    if (-not (Test-Path -LiteralPath $GitBashPath -PathType Leaf)) {
        throw "Git Bash is unavailable at $GitBashPath."
    }

    # ai-private-config runs under Git Bash and therefore publishes /c/... paths.
    # Pass the value as argv[1], never interpolated shell text, then verify that
    # the native Windows path still names an existing regular file.
    $priorPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& $GitBashPath -c 'cygpath -w -- "$1"' -- $Path 2>$null)
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $priorPreference
    }
    if ($exitCode -ne 0 -or $output.Count -eq 0) {
        throw "Could not translate Git Bash path: $Path"
    }

    $translated = ([string]$output[-1]).Trim()
    if ([string]::IsNullOrWhiteSpace($translated) -or
        -not (Test-Path -LiteralPath $translated -PathType Leaf)) {
        throw "Translated Git Bash path is unavailable: $translated"
    }
    return (Resolve-Path -LiteralPath $translated).Path
}
