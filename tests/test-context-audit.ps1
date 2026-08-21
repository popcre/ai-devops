$ErrorActionPreference = "Stop"

$repo = Split-Path -Parent $PSScriptRoot
$tool = Join-Path $repo "tools\context-audit\context-audit.py"
$codexRunner = Join-Path $repo "tools\skill-trigger-eval\codex-trigger-eval.py"
$root = Join-Path ([System.IO.Path]::GetTempPath()) ("context-audit-" + [guid]::NewGuid())

# Each locked safety category, and the one fixture line that carries it. The
# marker tests delete exactly one of these lines and require the audit to name
# that category in plain English.
$safetyLines = [ordered]@{
    "production mutation"     = "Production infrastructure is read-only. Never run terraform apply or mutating gcloud."
    "shared database routing" = "Shared database changes are authored in shared-db with a branch and PR."
    "secret handling"         = "Never expose a secret. Use the 1Password vault."
    "destructive actions"     = "Destructive actions such as delete or overwrite must be recoverable."
    "Git identity"            = "Check GIT_COMMITTER_IDENT for Albert Hazan at users.noreply.github.com."
    "GPT-5.6 effort"          = "GPT-5.6 must use low or medium effort."
}

# Rules that must appear in BOTH client globals, carried separately from the
# safety lines so a safety deletion does not accidentally decide parity.
$parityLines = @(
    "# Response Style",
    "Production infrastructure safety is absolute.",
    "Serialize every 1Password read.",
    "Synology long reads use the managed long-running skill.",
    "Write a HANDOFF file at session end."
)

$overlapSentence = "The quiet fixture sentence about pointer triggers exists only to prove overlap detection works correctly here."

function Write-Utf8 {
    param([string]$Path, [string]$Text)
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding $false))
}

function New-AuditFixture {
    param(
        [string]$Path,
        [string[]]$OmitSafety = @(),
        [string[]]$OmitSafetyFromCodexOnly = @(),
        [string]$ClaudeExtra = "",
        [string]$CodexExtra = "",
        [string]$SkillDescription = "Use for a small fixture."
    )

    if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Recurse -Force }
    foreach ($dir in @(
        "templates\system", "skills\shared\sample", "skills\claude",
        "skills\claude\folded", "skills\codex", "skills\codex\literal",
        "bin", ".ai", "transcripts", "node_modules")) {
        New-Item -ItemType Directory -Path (Join-Path $Path $dir) -Force | Out-Null
    }

    $claudeKeys = $safetyLines.Keys | Where-Object { $OmitSafety -notcontains $_ }
    $codexKeys = $claudeKeys | Where-Object { $OmitSafetyFromCodexOnly -notcontains $_ }
    $claudeBody = (@($parityLines) + @($claudeKeys | ForEach-Object { $safetyLines[$_] }) + @($ClaudeExtra)) -join "`n"
    # Genuinely Codex-only text, so the divergence allowlist has something real
    # to allow. A test that also puts this in the Claude global must be reported
    # as a stale allowlist entry.
    $codexBody = (@($parityLines) + @($codexKeys | ForEach-Object { $safetyLines[$_] }) +
        @("This file is the Codex edition of the standing rules.", $CodexExtra)) -join "`n"
    Write-Utf8 (Join-Path $Path "templates\system\CLAUDE-global.md") ($claudeBody + "`n")
    Write-Utf8 (Join-Path $Path "templates\system\AGENTS-global-codex.md") ($codexBody + "`n")

    Write-Utf8 (Join-Path $Path "AGENTS.md") "[Skill](skills/shared/sample/SKILL.md)`n"
    Write-Utf8 (Join-Path $Path "CLAUDE.md") "Read the router first.`n"

    $sample = @(
        "---",
        "name: sample",
        "description: $SkillDescription",
        "---",
        "",
        "This deliberately long paragraph exists to exercise paragraph handling without containing sensitive data. It continues beyond one hundred and eighty characters so the duplicate detector has a realistic input to normalize and hash safely."
    ) -join "`n"
    Write-Utf8 (Join-Path $Path "skills\shared\sample\SKILL.md") ($sample + "`n")

    # Folded frontmatter (LF endings). The parser must return the continuation
    # text, never the bare block-scalar marker.
    $foldedLines = @(
        "---",
        "name: folded",
        "description: >-",
        "  First folded line of the description.",
        "  Second folded line of the description.",
        "",
        "  Third folded paragraph.",
        "metadata:",
        "  type: reference",
        "---",
        "",
        "Body text for the folded fixture."
    )
    Write-Utf8 (Join-Path $Path "skills\claude\folded\SKILL.md") (($foldedLines -join "`n") + "`n")

    # Literal frontmatter written with CRLF endings, to prove Windows line
    # endings do not break block-scalar parsing.
    $literalLines = @(
        "---",
        "name: literal",
        "description: |-",
        "  First literal line of the description.",
        "  Second literal line of the description.",
        "---",
        "",
        "Body text for the literal fixture."
    )
    Write-Utf8 (Join-Path $Path "skills\codex\literal\SKILL.md") (($literalLines -join "`r`n") + "`r`n")

    foreach ($installer in @("bin\ai-install-skills", "bin\install-ai-devops-windows.ps1")) {
        Write-Utf8 (Join-Path $Path $installer) ".ai-devops-managed Shared skill also exists skills-quarantine not overwriting local edits dry-run`n"
    }

    $secret = "DO_NOT_READ_SECRET_FIXTURE_71c8"
    foreach ($leak in @(".env", ".ai\hidden.md", "transcripts\hidden.md", "node_modules\hidden.md")) {
        Write-Utf8 (Join-Path $Path $leak) $secret
    }
}

function Invoke-Audit {
    param([string]$Path, [switch]$Strict, [string]$Budgets)

    $json = Join-Path $root ("report-" + [guid]::NewGuid() + ".json")
    $arguments = @($tool, "--root", $Path, "--json", $json, "--generated-at", "fixture-time")
    if ($Strict) { $arguments += "--strict" }
    if ($Budgets) { $arguments += @("--budgets", $Budgets) }
    $stderrFile = Join-Path $root ("stderr-" + [guid]::NewGuid() + ".txt")
    $out = & python @arguments 2> $stderrFile
    $code = $LASTEXITCODE
    return [pscustomobject]@{
        exit    = $code
        report  = (Get-Content -LiteralPath $json -Raw | ConvertFrom-Json)
        raw     = (Get-Content -LiteralPath $json -Raw)
        stderr  = (Get-Content -LiteralPath $stderrFile -Raw)
        stdout  = ($out -join "`n")
    }
}

try {
    New-Item -ItemType Directory -Path $root | Out-Null
    $fixture = Join-Path $root "repo"
    $secret = "DO_NOT_READ_SECRET_FIXTURE_71c8"

    # ---------------------------------------------------------------- baseline
    New-AuditFixture -Path $fixture
    $summary = Join-Path $root "summary.txt"
    $json1 = Join-Path $root "report-1.json"
    $json2 = Join-Path $root "report-2.json"
    & python $tool --root $fixture --json $json1 --summary $summary --generated-at "fixture-time"
    if ($LASTEXITCODE -ne 0) { throw "First audit failed." }
    & python $tool --root $fixture --json $json2 --generated-at "fixture-time"
    if ($LASTEXITCODE -ne 0) { throw "Second audit failed." }

    $one = Get-Content -LiteralPath $json1 -Raw
    $two = Get-Content -LiteralPath $json2 -Raw
    if ($one -ne $two) { throw "Repeated reports are not stable." }
    if ($one.Contains($secret)) { throw "Secret-exclusion fixture content leaked into the report." }
    if ($one -match 'hidden\.md|\.env') { throw "Excluded paths appeared in the report." }

    $report = $one | ConvertFrom-Json
    if ($report.skills.Count -ne 3) { throw "Expected three tracked fixture skills." }
    if ($report.skillManifest.claude.skills -ne 2 -or $report.skillManifest.codex.skills -ne 2) {
        throw "Shared and client skills were not counted in both client manifests."
    }

    foreach ($skill in $report.skills) {
        if ($skill.description -match '^\s*[>|][-+]?\s*$') {
            throw "Skill '$($skill.name)' recorded a block-scalar marker instead of its description."
        }
    }
    $folded = $report.skills | Where-Object { $_.name -eq "folded" }
    if ($folded.description -ne "First folded line of the description. Second folded line of the description.`nThird folded paragraph.") {
        throw "Folded description was not folded as documented: '$($folded.description)'"
    }
    $literal = $report.skills | Where-Object { $_.name -eq "literal" }
    if ($literal.description -ne "First literal line of the description.`nSecond literal line of the description.") {
        throw "Literal CRLF description was not preserved as documented: '$($literal.description)'"
    }
    foreach ($client in @("claude", "codex")) {
        # Marker-only parsing produced manifests under 60 bytes for these
        # fixtures. Real continuation text keeps both well above 100.
        if ($report.skillManifest.$client.bytes -lt 100) {
            throw "The $client manifest is too small; block-scalar continuation text is missing."
        }
    }
    if (@($report.safetyMarkers.PSObject.Properties | Where-Object { -not $_.Value }).Count -ne 0) {
        throw "A required safety marker was not found in the positive fixture."
    }
    if (@($report.safetyMarkerIssues).Count -ne 0) { throw "The positive fixture reported a safety issue." }
    if (@($report.installerCapabilities.differences).Count -ne 0) {
        throw "Equivalent installer fixtures reported a parity difference."
    }
    if (@($report.crossClientParity.mismatches).Count -ne 0) {
        throw "The positive fixture reported a cross-client parity mismatch: $($report.crossClientParity.mismatches -join ', ')"
    }
    if (@($report.crossClientParity.staleAllowlistEntries).Count -ne 0) {
        throw "The positive fixture reported a stale divergence-allowlist entry."
    }
    if (@($report.globalSkillOverlap).Count -ne 0) {
        throw "The positive fixture reported a global/skill-description overlap."
    }
    if ($report.budgets.warnings -ne 0) { throw "The tiny positive fixture exceeded a real warning budget." }
    if (-not (Test-Path -LiteralPath $summary)) { throw "Human summary was not written." }

    $strictBaseline = Invoke-Audit -Path $fixture -Strict
    if ($strictBaseline.exit -ne 0) { throw "Strict mode failed on a clean fixture: $($strictBaseline.stderr)" }
    Write-Host "PASS: baseline classification, stable output, manifests, parity, safety markers, secret exclusions"

    # ------------------------------------------------- safety marker removal
    foreach ($category in $safetyLines.Keys) {
        New-AuditFixture -Path $fixture -OmitSafety @($category)
        $result = Invoke-Audit -Path $fixture -Strict
        if ($result.report.safetyMarkers.$category) {
            throw "Removing the '$category' line did not clear its safety marker."
        }
        $issue = $result.report.safetyMarkerIssues | Where-Object { $_.category -eq $category }
        if (-not $issue) { throw "No safety issue was reported for the missing '$category' rule." }
        if ($issue.reason.Length -lt 40 -or $issue.reason -notmatch [regex]::Escape($category)) {
            throw "The '$category' failure reason is not a plain-English sentence naming the category: '$($issue.reason)'"
        }
        foreach ($other in $safetyLines.Keys) {
            if ($other -ne $category -and -not $result.report.safetyMarkers.$other) {
                throw "Removing '$category' also cleared the unrelated marker '$other'."
            }
        }
        if ($result.exit -eq 0) { throw "Strict mode passed with the '$category' safety rule missing." }
        if ($result.stderr -notmatch "FAIL: Missing safety marker") {
            throw "Strict mode did not print a plain reason for the missing '$category' rule."
        }
    }
    Write-Host "PASS: all six locked safety categories fail individually with a plain-English reason"

    # ------------------------------------------------------ cross-client parity
    New-AuditFixture -Path $fixture -OmitSafetyFromCodexOnly @("GPT-5.6 effort")
    $result = Invoke-Audit -Path $fixture -Strict
    if ($result.report.crossClientParity.mismatches -notcontains "GPT-5.6 low or medium only") {
        throw "A rule present only in the Claude global was not reported as a parity mismatch."
    }
    $rule = $result.report.crossClientParity.rules | Where-Object { $_.name -eq "GPT-5.6 low or medium only" }
    if ($rule.reason -notmatch "Codex") { throw "The parity reason does not name the client that is missing the rule." }
    if ($result.exit -eq 0) { throw "Strict mode passed with a cross-client parity mismatch." }
    if ($result.report.safetyMarkers."GPT-5.6 effort" -ne $true) {
        throw "Parity fixture unexpectedly cleared the safety marker; the two checks must be independent."
    }

    New-AuditFixture -Path $fixture -ClaudeExtra "This is the Codex edition framing sentence."
    $result = Invoke-Audit -Path $fixture -Strict
    if ($result.report.crossClientParity.staleAllowlistEntries -notcontains "Codex edition framing") {
        throw "Client-only text appearing in both globals was not reported as a stale allowlist entry."
    }
    if ($result.exit -eq 0) { throw "Strict mode passed with a stale divergence-allowlist entry." }
    Write-Host "PASS: cross-client parity mismatch and stale divergence-allowlist entry both fail with a reason"

    # -------------------------------------------------------- warning budgets
    New-AuditFixture -Path $fixture
    $budgetFile = Join-Path $root "tiny-budgets.json"
    Write-Utf8 $budgetFile (@{
        budgets = @{
            alwaysLoadedBytes        = @{ budget = 10; target = 5 }
            startupRoutedBytes       = @{ budget = 10; target = 5 }
            claudeSkillManifestBytes = @{ budget = 10; target = 5 }
            codexSkillManifestBytes  = @{ budget = 10; target = 5 }
        }
    } | ConvertTo-Json -Depth 5)
    $result = Invoke-Audit -Path $fixture -Strict -Budgets $budgetFile
    if ($result.report.budgets.warnings -ne 4) {
        throw "Expected four budget warnings, got $($result.report.budgets.warnings)."
    }
    foreach ($entry in $result.report.budgets.entries) {
        if ($entry.status -ne "warning") { throw "Budget '$($entry.name)' did not warn when it was exceeded." }
        if ($entry.reason -notmatch "warning, not a failure") {
            throw "Budget '$($entry.name)' did not say plainly that it is a warning: '$($entry.reason)'"
        }
    }
    if ($result.exit -ne 0) {
        throw "A budget overrun changed the exit status. Budgets must warn only, even in strict mode."
    }
    Write-Host "PASS: exceeded budgets warn with a plain reason and never fail the run"

    # ------------------------------------------------------- open handoff count
    # Every file in HANDOFF.d/ means an OPEN workstream. Retention used to depend
    # on someone remembering at the end of a long session, and it silently grew
    # past the threshold. Counting it here makes it mechanical - and a warning,
    # never a failure, because an audit that blocks a commit over paperwork is an
    # audit people learn to ignore.
    New-AuditFixture -Path $fixture
    $handoffDir = Join-Path $fixture "HANDOFF.d"
    $handoffSummary = Join-Path $root "handoff-summary.txt"
    New-Item -ItemType Directory -Force -Path $handoffDir | Out-Null
    $result = Invoke-Audit -Path $fixture -Strict
    if (@($result.report.openHandoffs).Count -ne 0) { throw "An empty HANDOFF.d was not reported as zero open handoffs." }
    # The 5-file cap was retired on 2026-08-14 (#658, commit 85887cf): a count is
    # not a finding, because a file's own session is what retires it. What the
    # audit warns about now is a handoff carrying NO contract block, since
    # without one nothing can ever tell whether that workstream is finished -
    # the failure that left 27 finished files behind in u2giants/shared-db.
    foreach ($n in 1..5) { Write-Utf8 (Join-Path $handoffDir "2026-01-0${n}Z-m-a-s.md") "# handoff $n" }
    $result = Invoke-Audit -Path $fixture -Strict
    if (@($result.report.openHandoffs).Count -ne 5) { throw "Five handoffs were not all counted." }
    & python $tool --root $fixture --summary $handoffSummary --generated-at "fixture-time" | Out-Null
    $handoffText = Get-Content -LiteralPath $handoffSummary -Raw
    if ($handoffText -notmatch "HANDOFF WARNING") {
        throw "Handoffs with no contract block did not warn."
    }
    if ($handoffText -notmatch "warning, not a failure") {
        throw "The handoff warning does not say plainly that it is a warning."
    }
    if ($result.exit -ne 0) { throw "An uncontracted handoff changed the exit status. It must warn only, even in strict mode." }

    # A file that carries the contract block is not a finding, however many
    # there are. Six contracted files must be counted and must NOT warn.
    Remove-Item -LiteralPath $handoffDir -Recurse -Force
    New-Item -ItemType Directory -Force -Path $handoffDir | Out-Null
    foreach ($n in 1..6) {
        Write-Utf8 (Join-Path $handoffDir "2026-02-0${n}Z-m-a-s.md") @"
---
issue: 92$n
status: OPEN
owner: claude/fixture-$n
---
# handoff $n
"@
    }
    $result = Invoke-Audit -Path $fixture -Strict
    if (@($result.report.openHandoffs).Count -ne 6) { throw "Six contracted handoffs were not all counted." }
    if (@($result.report.openHandoffs | Where-Object { -not $_.hasContract }).Count -ne 0) {
        throw "A handoff carrying issue/status/owner frontmatter was not recognised as contracted."
    }
    & python $tool --root $fixture --summary $handoffSummary --generated-at "fixture-time" | Out-Null
    if ((Get-Content -LiteralPath $handoffSummary -Raw) -match "HANDOFF WARNING") {
        throw "Contracted handoffs warned. The count alone is not a finding (#658)."
    }
    if ($result.exit -ne 0) { throw "Counting handoffs changed the exit status. It must warn only, even in strict mode." }
    Write-Host "PASS: open handoffs are counted, an uncontracted one warns, a contracted one does not, and neither ever fails the run"

    # -------------------------------- always-loaded global vs skill descriptions
    New-AuditFixture -Path $fixture -SkillDescription $overlapSentence `
        -ClaudeExtra $overlapSentence -CodexExtra $overlapSentence
    $result = Invoke-Audit -Path $fixture
    if (@($result.report.globalSkillOverlap).Count -lt 2) {
        throw "A sentence duplicated between both globals and a skill description was not reported as overlap."
    }
    $overlap = $result.report.globalSkillOverlap[0]
    if ($overlap.skill -ne "sample") { throw "The overlap report named the wrong skill." }
    if ($overlap.examplePhrase.Split(" ").Count -ne 10) {
        throw "The overlap example phrase is not the documented ten-word shingle."
    }
    if ($overlap.reason -notmatch "already startup") {
        throw "The overlap reason does not explain why duplicated startup text costs twice."
    }
    if ($result.exit -ne 0) { throw "An overlap warning changed the exit status." }
    Write-Host "PASS: global text repeating a skill description is reported as duplicated startup context"

    # --------------------------------------------- Codex autonomy guardrails
    # These assertions protect the behavior contract Albert corrected after the
    # old wording made Codex stop on harmless errors, ask for repeated approval,
    # and remove broken features instead of repairing them.
    $codexGlobal = Get-Content -LiteralPath (Join-Path $repo "templates\system\AGENTS-global-codex.md") -Raw
    foreach ($required in @(
        "Start immediately",
        "No approval loops",
        "recover first and finish",
        "Fix means preserve the intended capability",
        "Do not load unrelated handoffs",
        "permission to delete them"
    )) {
        if ($codexGlobal -notmatch [regex]::Escape($required)) {
            throw "The Codex global lost its autonomy rule: $required"
        }
    }
    foreach ($forbidden in @(
        "Tell him. Then stop.",
        "Access-first: before coding",
        "delete vestiges on sight",
        "More than 5 open files"
    )) {
        if ($codexGlobal -match [regex]::Escape($forbidden)) {
            throw "The Codex global restored a known behavior trap: $forbidden"
        }
    }
    Write-Host "PASS: Codex starts authorized work, recovers from routine errors, repairs broken capabilities, and ignores unrelated handoffs"

    # -------------------------------------------------- Codex trigger-eval runner
    $printed = & python $codexRunner --skill sample --eval-set $budgetFile --print-command
    if ($LASTEXITCODE -ne 0) { throw "The Codex trigger-eval runner failed to print its command." }
    $argv = $printed | ConvertFrom-Json
    if ($argv -notcontains "model_reasoning_effort=low") {
        throw "The Codex runner does not pass an explicit low reasoning effort."
    }
    if ($argv -notcontains "read-only") { throw "The Codex runner does not force a read-only sandbox." }
    & python $codexRunner --skill sample --eval-set $budgetFile --effort high --print-command 2>$null
    if ($LASTEXITCODE -eq 0) { throw "The Codex runner accepted a high reasoning effort." }
    Write-Host "PASS: Codex trigger-eval runner pins low/medium reasoning and a read-only sandbox"

    Write-Host "PASS: context audit enforcement suite"
} finally {
    if (Test-Path -LiteralPath $root) {
        Remove-Item -LiteralPath $root -Recurse -Force
    }
}
