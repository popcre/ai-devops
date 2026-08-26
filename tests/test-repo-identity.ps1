# The PowerShell side of the fail-closed repository identity guard.
# Bash coverage lives in tests/test-ai-repo-identity.sh; this proves the
# dot-source helper the Windows bootstrap and installer actually call.
$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'bin\repo-identity.ps1')

$pass = 0
$fail = 0
function Check([string]$Name, [scriptblock]$Body) {
    try {
        if (& $Body) { Write-Host "  ok   $Name"; $script:pass++ }
        else { Write-Host "  FAIL $Name"; $script:fail++ }
    } catch { Write-Host "  FAIL $Name -- $($_.Exception.Message)"; $script:fail++ }
}
function Refused([string]$Name, [scriptblock]$Body) {
    try { & $Body; Write-Host "  FAIL $Name (it was accepted)"; $script:fail++ }
    catch { Write-Host "  ok   $Name"; $script:pass++ }
}

$accepted = @(Get-AiDevOpsAcceptedIdentity -Key 'ai-devops')
Check 'the old owner is listed' { $accepted -ccontains 'github.com/u2giants/ai-devops' }
Check 'the new owner is listed' { $accepted -ccontains 'github.com/popcre/ai-devops' }
Check 'exactly the two ai-devops owners are listed' { $accepted.Count -eq 2 }

Check 'the old owner passes the assertion' {
    Assert-AiDevOpsRepoIdentity -Key 'ai-devops' -Identity 'github.com/u2giants/ai-devops' -Message 'x'
    $true
}
Check 'the new owner passes the assertion' {
    Assert-AiDevOpsRepoIdentity -Key 'ai-devops' -Identity 'github.com/popcre/ai-devops' -Message 'x'
    $true
}
Refused 'an unknown owner still aborts' {
    Assert-AiDevOpsRepoIdentity -Key 'ai-devops' -Identity 'github.com/attacker/ai-devops' -Message 'x'
}
Refused 'a case-altered owner still aborts' {
    Assert-AiDevOpsRepoIdentity -Key 'ai-devops' -Identity 'github.com/PopCre/ai-devops' -Message 'x'
}
Refused 'an empty identity still aborts' {
    Assert-AiDevOpsRepoIdentity -Key 'ai-devops' -Identity '' -Message 'x'
}

# The private siblings are deliberately not moving.
Check 'the memory hub still accepts only u2giants' {
    $m = @(Get-AiDevOpsAcceptedIdentity -Key 'ai-devops-memory')
    $m.Count -eq 1 -and $m[0] -ceq 'github.com/u2giants/ai-devops-memory'
}
Check 'transcripts still accept only u2giants' {
    $t = @(Get-AiDevOpsAcceptedIdentity -Key 'ai-devops-transcripts')
    $t.Count -eq 1 -and $t[0] -ceq 'github.com/u2giants/ai-devops-transcripts'
}

# A broken table must reject, never wave a machine through.
$tmp = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
    $empty = Join-Path $tmp 'empty.tsv'
    Set-Content -LiteralPath $empty -Value '# nothing accepted'
    Refused 'an emptied table aborts' {
        Assert-AiDevOpsRepoIdentity -Key 'ai-devops' -Identity 'github.com/u2giants/ai-devops' -Message 'x' -Path $empty
    }
    Refused 'a missing table aborts' {
        Assert-AiDevOpsRepoIdentity -Key 'ai-devops' -Identity 'github.com/u2giants/ai-devops' -Message 'x' -Path (Join-Path $tmp 'absent.tsv')
    }
} finally { Remove-Item -LiteralPath $tmp -Recurse -Force }

Write-Host "`n$pass passed, $fail failed"
if ($fail -ne 0) { exit 1 }
exit 0
