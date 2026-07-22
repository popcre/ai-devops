$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
$launcher = Join-Path $repo "bin\ai-glm-agent.ps1"
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ("ai-glm-test-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $temp | Out-Null

try {
    $fakeClaude = Join-Path $temp "claude.cmd"
    @'
@echo off
echo %* > "%FAKE_CAPTURE%"
echo ANTHROPIC_API_KEY=%ANTHROPIC_API_KEY%>> "%FAKE_CAPTURE%"
echo ANTHROPIC_BASE_URL=%ANTHROPIC_BASE_URL%>> "%FAKE_CAPTURE%"
echo {"is_error":false,"result":"FAKE_OK","modelUsage":{"%FAKE_MODEL%":{}}}
'@ | Set-Content -LiteralPath $fakeClaude -Encoding ascii

    $oldPath = $env:Path
    $env:Path = "$temp;$oldPath"
    $env:ZAI_API_KEY = "test-only-not-a-secret"
    $env:ZAI_CLAUDE_CONFIG_DIR = Join-Path $temp "glm-config"
    $env:FAKE_CAPTURE = Join-Path $temp "args.txt"
    $env:FAKE_MODEL = "glm-5.2"
    $env:ANTHROPIC_API_KEY = "must-be-cleared"

    $result = & $launcher -Mode review "Inspect the repository"
    if ($result -ne "FAKE_OK") { throw "Positional prompt did not produce the expected result." }
    $capture = Get-Content -Raw -LiteralPath $env:FAKE_CAPTURE
    if ($capture -notmatch "--permission-mode plan") { throw "Review mode did not use plan permissions." }
    if ($capture -notmatch "ANTHROPIC_API_KEY=\s*(\r?\n|$)") { throw "Inherited Anthropic API key was not cleared." }
    if ($capture -notmatch "ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic") { throw "Z.ai endpoint was not isolated." }

    $null = & $launcher -Mode implement "Make the scoped change"
    $capture = Get-Content -Raw -LiteralPath $env:FAKE_CAPTURE
    if ($capture -notmatch "--permission-mode auto") { throw "Implement mode did not use auto permissions." }

    $env:FAKE_MODEL = "glm-5.1"
    $failed = $false
    try { $null = & $launcher "Reject fallback" } catch { $failed = $_.Exception.Message -match "No fallback accepted" }
    if (-not $failed) { throw "Returned-model mismatch was not rejected." }

    Write-Host "PASS: PowerShell GLM launcher isolation, modes, positional prompt, and fallback rejection"
} finally {
    $env:Path = $oldPath
    Remove-Item Env:ZAI_API_KEY, Env:ZAI_CLAUDE_CONFIG_DIR, Env:FAKE_CAPTURE, Env:FAKE_MODEL -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
