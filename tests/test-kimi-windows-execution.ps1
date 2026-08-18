$ErrorActionPreference = "Stop"

# Offline Windows checks for ai-kimi's durable-worker boundary. These never
# inspect real Kimi OAuth data and never change ACLs.
$repo = Split-Path -Parent $PSScriptRoot
$script = Join-Path $repo "bin\ai-kimi"
$text = Get-Content -Raw $script

foreach ($required in @(
    'KIMI_CODE_HOME',
    'preflight_execution_context',
    'execution-context-denied',
    'Start-Process',
    '-WindowStyle Hidden',
    '__review-worker',
    'session.resume_hint',
    'hand_back_to_main_task'
)) {
    if (-not $text.Contains($required)) { throw "Missing Windows Kimi execution control: $required" }
}

$temp = Join-Path ([IO.Path]::GetTempPath()) ("ai-kimi-windows-" + [guid]::NewGuid().ToString("N"))
try {
    New-Item -ItemType Directory -Force -Path $temp | Out-Null
    $kimiHome = Join-Path $temp "Kimi Home With Spaces"
    New-Item -ItemType Directory -Force -Path $kimiHome | Out-Null
    $canary = Join-Path $kimiHome "sessions\.ai-kimi-canary"
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $canary) | Out-Null
    Set-Content -LiteralPath $canary -Value "ok" -NoNewline -Encoding ASCII
    if ((Get-Content -Raw -LiteralPath $canary) -ne "ok") { throw "Kimi-home write/read canary failed." }
    Remove-Item -LiteralPath $canary -Force
    if (Test-Path -LiteralPath $canary) { throw "Kimi-home canary did not clean up." }

    $acl = Get-Acl -LiteralPath $kimiHome
    if ($null -eq $acl.Owner) { throw "Kimi-home ACL inspection returned no owner." }

    $ps = [scriptblock]::Create('$p = Start-Process -FilePath cmd.exe -ArgumentList "/c exit 0" -WindowStyle Hidden -PassThru; $p.WaitForExit(); $p.ExitCode')
    if ((& $ps) -ne 0) { throw "Hidden detached-process primitive failed." }
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}

Write-Host "PASS: Windows Kimi execution controls are valid"
