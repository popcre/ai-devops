$ErrorActionPreference = "Stop"

$repo = Split-Path -Parent $PSScriptRoot
$tool = Join-Path $repo "tools\context-audit\context-audit.py"
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ("context-audit-" + [guid]::NewGuid())

try {
    New-Item -ItemType Directory -Path $temp | Out-Null
    foreach ($path in @(
        "templates\system", "skills\shared\sample", "skills\claude",
        "skills\codex", "bin", ".ai", "transcripts", "node_modules")) {
        New-Item -ItemType Directory -Path (Join-Path $temp $path) -Force | Out-Null
    }

    $safety = @'
Production infrastructure is read-only. Never run terraform apply or mutating gcloud.
Shared database changes are authored in shared-db with a branch and PR.
Never expose a secret. Use the 1Password vault.
Destructive actions such as delete or overwrite must be recoverable.
Check GIT_COMMITTER_IDENT for Albert Hazan at users.noreply.github.com.
GPT-5.6 must use low or medium effort.
'@
    Set-Content -LiteralPath (Join-Path $temp "templates\system\CLAUDE-global.md") -Value $safety -Encoding utf8
    Set-Content -LiteralPath (Join-Path $temp "templates\system\AGENTS-global-codex.md") -Value $safety -Encoding utf8
    Set-Content -LiteralPath (Join-Path $temp "AGENTS.md") -Value "[Skill](skills/shared/sample/SKILL.md)" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $temp "CLAUDE.md") -Value "Read AGENTS.md." -Encoding utf8
    Set-Content -LiteralPath (Join-Path $temp "skills\shared\sample\SKILL.md") -Value @'
---
name: sample
description: Use for a small fixture.
---

This deliberately long paragraph exists to exercise paragraph handling without containing sensitive data. It continues beyond one hundred and eighty characters so the duplicate detector has a realistic input to normalize and hash safely.
'@ -Encoding utf8

    foreach ($installer in @("bin\ai-install-skills", "bin\install-ai-devops-windows.ps1")) {
        Set-Content -LiteralPath (Join-Path $temp $installer) -Value ".ai-devops-managed Shared skill also exists skills-quarantine not overwriting local edits dry-run" -Encoding utf8
    }

    $secret = "DO_NOT_READ_SECRET_FIXTURE_71c8"
    Set-Content -LiteralPath (Join-Path $temp ".env") -Value $secret -Encoding utf8
    Set-Content -LiteralPath (Join-Path $temp ".ai\hidden.md") -Value $secret -Encoding utf8
    Set-Content -LiteralPath (Join-Path $temp "transcripts\hidden.md") -Value $secret -Encoding utf8
    Set-Content -LiteralPath (Join-Path $temp "node_modules\hidden.md") -Value $secret -Encoding utf8

    $json1 = Join-Path $temp "report-1.json"
    $json2 = Join-Path $temp "report-2.json"
    $summary = Join-Path $temp "summary.txt"
    & python $tool --root $temp --json $json1 --summary $summary --generated-at "fixture-time"
    if ($LASTEXITCODE -ne 0) { throw "First audit failed." }
    & python $tool --root $temp --json $json2 --generated-at "fixture-time"
    if ($LASTEXITCODE -ne 0) { throw "Second audit failed." }

    $one = Get-Content -LiteralPath $json1 -Raw
    $two = Get-Content -LiteralPath $json2 -Raw
    if ($one -ne $two) { throw "Repeated reports are not stable." }
    if ($one.Contains($secret)) { throw "Secret-exclusion fixture content leaked into the report." }
    if ($one -match 'hidden\.md|\.env') { throw "Excluded paths appeared in the report." }

    $report = $one | ConvertFrom-Json
    if ($report.skills.Count -ne 1) { throw "Expected one tracked fixture skill." }
    if ($report.skillManifest.claude.skills -ne 1 -or $report.skillManifest.codex.skills -ne 1) {
        throw "Shared skill was not counted in both client manifests."
    }
    if (@($report.safetyMarkers.PSObject.Properties | Where-Object { -not $_.Value }).Count -ne 0) {
        throw "A required safety marker was not found in the positive fixture."
    }
    if (@($report.installerCapabilities.differences).Count -ne 0) {
        throw "Equivalent installer fixtures reported a parity difference."
    }
    if (-not (Test-Path -LiteralPath $summary)) { throw "Human summary was not written." }

    Write-Host "PASS: context audit classification, stable output, manifests, parity, safety markers, and secret exclusions"
} finally {
    if (Test-Path -LiteralPath $temp) {
        Remove-Item -LiteralPath $temp -Recurse -Force
    }
}
