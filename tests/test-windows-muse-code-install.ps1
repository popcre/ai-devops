# Offline tests for the optional Windows Muse Code install stage (#1650).
# Meta's installer download and run are mocked; nothing touches the network.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'bin\windows-muse-code-install.ps1')
$temp = Join-Path ([IO.Path]::GetTempPath()) ('ai-devops-muse-install-test-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $temp | Out-Null
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw "FAIL: $Message" } }

$payload = [Text.Encoding]::ASCII.GetBytes('pinned muse binary')
$sha = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($payload)).Replace('-', '').ToLowerInvariant()
$installerPayload = [Text.Encoding]::ASCII.GetBytes('pinned installer script')
$installerSha = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($installerPayload)).Replace('-', '').ToLowerInvariant()

function New-Case([string]$Name) {
    $repo = Join-Path $temp "$Name\repo"
    New-Item -ItemType Directory -Force -Path (Join-Path $repo 'config\muse-code') | Out-Null
    "9.9.9-R1.1`n" | Set-Content -NoNewline -LiteralPath (Join-Path $repo 'config\muse-code\version')
    "$sha`n" | Set-Content -NoNewline -LiteralPath (Join-Path $repo 'config\muse-code\sha256')
    "$installerSha`n" | Set-Content -NoNewline -LiteralPath (Join-Path $repo 'config\muse-code\windows-installer-sha256')
    $dir = Join-Path $temp "$Name\muse"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    return @{ Repo = $repo; Dir = $dir; Bin = (Join-Path $dir 'muse-bin-9.9.9-R1.1.exe') }
}

$script:fetched = @()
$fetch = { param($Uri, $Destination) $script:fetched += $Uri; [IO.File]::WriteAllBytes($Destination, [Text.Encoding]::ASCII.GetBytes('pinned installer script')) }

try {
    # Absent -> runs Meta's installer, then verifies.
    $c = New-Case 'absent'
    $script:fetched = @()
    $run = { param($Script) Assert (Test-Path -LiteralPath $Script) 'installer script was not fetched before running'; [IO.File]::WriteAllBytes($c.Bin, $payload) }.GetNewClosure()
    $msg = Install-AiDevOpsMuseCode -RepoPath $c.Repo -InstallDir $c.Dir -Fetch $fetch -RunInstaller $run
    Assert ($script:fetched.Count -eq 1 -and $script:fetched[0] -eq 'https://dev.meta.ai/install.ps1') "absent case did not fetch Meta's official installer: $($script:fetched -join ',')"
    Assert ($msg -like 'installed and verified*') "absent case message: $msg"

    # Downloaded installer mismatch -> fails before running any script.
    $c = New-Case 'installerhashmismatch'
    $badFetch = { param($Uri, $Destination) [IO.File]::WriteAllText($Destination, 'tampered') }
    $failed = $null
    try { Install-AiDevOpsMuseCode -RepoPath $c.Repo -InstallDir $c.Dir -Fetch $badFetch -RunInstaller { throw 'must not run' } | Out-Null } catch { $failed = $_.Exception.Message }
    Assert ($failed -like "Meta's Muse Code installer failed*does not match the pinned SHA-256*") "installer hash mismatch did not fail before execution: $failed"

    # Present and matching -> skips the installer.
    $c = New-Case 'present'
    [IO.File]::WriteAllBytes($c.Bin, $payload)
    $script:fetched = @()
    $msg = Install-AiDevOpsMuseCode -RepoPath $c.Repo -InstallDir $c.Dir -Fetch $fetch -RunInstaller { throw 'installer must not run' }
    Assert ($script:fetched.Count -eq 0) 'present case fetched the installer'
    Assert ($msg -like '*already present and verified') "present case message: $msg"

    # Hash mismatch -> fails closed.
    $c = New-Case 'mismatch'
    [IO.File]::WriteAllBytes($c.Bin, [Text.Encoding]::ASCII.GetBytes('tampered'))
    $failed = $null
    try { Install-AiDevOpsMuseCode -RepoPath $c.Repo -InstallDir $c.Dir -Fetch $fetch -RunInstaller { throw 'no' } | Out-Null } catch { $failed = $_.Exception.Message }
    Assert ($failed -like '*does not match the pinned SHA-256*') "hash mismatch did not fail closed: $failed"

    # Meta installs a different version -> fails.
    $c = New-Case 'otherversion'
    $run = { param($Script) [IO.File]::WriteAllBytes((Join-Path $c.Dir 'muse-bin-10.0.0-R2.1.exe'), $payload) }.GetNewClosure()
    $failed = $null
    try { Install-AiDevOpsMuseCode -RepoPath $c.Repo -InstallDir $c.Dir -Fetch $fetch -RunInstaller $run | Out-Null } catch { $failed = $_.Exception.Message }
    Assert ($failed -like '*different Muse Code than the pinned 9.9.9-R1.1*') "different version did not fail: $failed"

    # Installer failure -> fails, temp installer script removed.
    $c = New-Case 'installerfails'
    $script:tempSeen = ''
    $run = { param($Script) $script:tempSeen = $Script; throw 'boom' }
    $failed = $null
    try { Install-AiDevOpsMuseCode -RepoPath $c.Repo -InstallDir $c.Dir -Fetch $fetch -RunInstaller $run | Out-Null } catch { $failed = $_.Exception.Message }
    Assert ($failed -like "Meta's Muse Code installer failed*") "installer failure not reported: $failed"
    Assert (-not (Test-Path -LiteralPath $script:tempSeen)) 'temporary installer script was left behind'

    # Missing pin -> fails closed without fetching anything.
    $c = New-Case 'nopin'
    Remove-Item -LiteralPath (Join-Path $c.Repo 'config\muse-code\sha256')
    $script:fetched = @()
    $failed = $null
    try { Install-AiDevOpsMuseCode -RepoPath $c.Repo -InstallDir $c.Dir -Fetch $fetch -RunInstaller { throw 'no' } | Out-Null } catch { $failed = $_.Exception.Message }
    Assert ($failed -like 'no Windows Muse Code pin*' -and $script:fetched.Count -eq 0) "missing pin did not fail closed: $failed"

    # Default runner: native stderr from the installer must not fail the stage
    # when it exits 0 (Windows PowerShell 5.1 under 'Stop').
    $c = New-Case 'stderr'
    $installerText = "[Console]::Error.WriteLine('noise'); New-Item -ItemType File -Force -Path '$($c.Bin)' | Out-Null; [IO.File]::WriteAllBytes('$($c.Bin)', [Text.Encoding]::ASCII.GetBytes('pinned muse binary')); exit 0"
    $installerBytes = [Text.Encoding]::ASCII.GetBytes($installerText)
    $stderrPin = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($installerBytes)).Replace('-', '').ToLowerInvariant()
    "$stderrPin`n" | Set-Content -NoNewline -LiteralPath (Join-Path $c.Repo 'config\muse-code\windows-installer-sha256')
    $fetchNoisy = { param($Uri, $Destination) [IO.File]::WriteAllBytes($Destination, $installerBytes) }.GetNewClosure()
    $msg = Install-AiDevOpsMuseCode -RepoPath $c.Repo -InstallDir $c.Dir -Fetch $fetchNoisy
    Assert ($msg -like 'installed and verified*') "default runner with stderr noise: $msg"

    Write-Host 'PASS: windows Muse Code install stage'
} finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
