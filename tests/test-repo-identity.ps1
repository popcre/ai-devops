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

# Canonicalisation is now shared. Both Windows callers previously inlined an
# ssh://-blind copy, so a fresh clone taken with ssh://git@github.com/... would
# have been refused on Windows while the Bash reader accepted it -- exactly the
# post-transfer failure this change exists to prevent.
$canonCases = @{
    'https://github.com/popcre/ai-devops.git'     = 'github.com/popcre/ai-devops'
    'https://github.com/popcre/ai-devops.git/'    = 'github.com/popcre/ai-devops'
    'git@github.com:popcre/ai-devops.git'         = 'github.com/popcre/ai-devops'
    'ssh://git@github.com/popcre/ai-devops.git'   = 'github.com/popcre/ai-devops'
    '  https://github.com/u2giants/ai-devops  '   = 'github.com/u2giants/ai-devops'
    'https://github.com/attacker/ai-devops.git'   = 'github.com/attacker/ai-devops'
}
foreach ($case in $canonCases.GetEnumerator()) {
    Check "canonicalises $($case.Key)" ([scriptblock]::Create(
        "(Get-AiDevOpsCanonicalRemote -Url '$($case.Key)') -ceq '$($case.Value)'"))
}

# Every URL form the Bash reader accepts must pass the PowerShell assertion too.
foreach ($u in @(
    'https://github.com/popcre/ai-devops.git',
    'ssh://git@github.com/popcre/ai-devops.git',
    'git@github.com:u2giants/ai-devops.git')) {
    Check "assertion accepts $u" ([scriptblock]::Create(@"
        Assert-AiDevOpsRepoIdentity -Key 'ai-devops' ``
            -Identity (Get-AiDevOpsCanonicalRemote -Url '$u') -Message 'x'
        `$true
"@))
}
Refused 'assertion still rejects an attacker URL' {
    Assert-AiDevOpsRepoIdentity -Key 'ai-devops' `
        -Identity (Get-AiDevOpsCanonicalRemote -Url 'https://github.com/attacker/ai-devops.git') -Message 'x'
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
