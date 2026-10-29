# ai-transcript-envcheck.ps1 - Python-free Windows pre-check for the transcript
# store (popcre/ai-devops#2050 section 12). Works in Windows PowerShell 5.1 and
# pwsh. Reports whether python3 / py -3 is >= 3.10 and whether the Dropbox
# folder and chat_transcripts\ exist. If Python is missing it says so and
# stops; run the toolkit installer, then re-run. When Python is present it
# then runs tools\transcript_store\envcheck.py with the remaining arguments.
param(
    [string]$Dropbox = '',
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Rest
)
$ErrorActionPreference = 'Stop'

function Test-Python([string]$Exe, [string[]]$PreArgs) {
    $cmd = Get-Command $Exe -ErrorAction SilentlyContinue
    if (-not $cmd) { return $null }
    try {
        $v = & $cmd.Source @PreArgs -c 'import sys; print("%d.%d.%d" % sys.version_info[:3])' 2>$null
    } catch { return $null }
    if ($LASTEXITCODE -ne 0 -or -not $v) { return $null }
    $parts = ($v.Trim()).Split('.')
    if ([int]$parts[0] -gt 3 -or ([int]$parts[0] -eq 3 -and [int]$parts[1] -ge 10)) {
        return @{ Path = $cmd.Source; PreArgs = $PreArgs; Version = $v.Trim() }
    }
    return $null
}

if (-not $Dropbox) {
    if ($env:AI_DROPBOX_ROOT) { $Dropbox = $env:AI_DROPBOX_ROOT }
    else { $Dropbox = Join-Path $env:USERPROFILE 'Dropbox' }
}
$failed = $false
$py = Test-Python 'python3' @()
if (-not $py) { $py = Test-Python 'py' @('-3') }
if (-not $py) { $py = Test-Python 'python' @() }
if ($py) { Write-Output ("PASS python>=3.10: {0} ({1})" -f $py.Version, $py.Path) }
else { Write-Output 'FAIL python>=3.10: no python3 or py -3 of 3.10 or newer; run the toolkit installer, then re-run'; $failed = $true }

if (Test-Path -LiteralPath $Dropbox -PathType Container) { Write-Output "PASS dropbox-folder: $Dropbox" }
else { Write-Output "FAIL dropbox-folder: $Dropbox"; $failed = $true }
$ct = Join-Path (Join-Path $Dropbox 'ai') 'chat_transcripts'
if (Test-Path -LiteralPath $ct -PathType Container) { Write-Output "PASS chat_transcripts: $ct" }
else { Write-Output "WARN chat_transcripts: $ct not present (needed by the writer only)" }

if (-not $py) { Write-Output 'RESULT FAIL'; exit 1 }
$script = Join-Path (Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'tools') 'transcript_store') 'envcheck.py'
$argsList = @($py.PreArgs) + @($script, '--dropbox', $Dropbox) + @($Rest | Where-Object { $_ })
& $py.Path @argsList
$code = $LASTEXITCODE
if ($failed -and $code -eq 0) { $code = 1 }
exit $code
