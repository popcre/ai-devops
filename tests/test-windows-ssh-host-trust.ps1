$ErrorActionPreference = 'Stop'
$source = Join-Path (Split-Path -Parent $PSScriptRoot) 'tools\ci\read-windows-ssh-host-trust.ps1'
. $source
$script:passed = 0; $script:failed = 0
function Check([string]$Name, [scriptblock]$Body) {
    try { & $Body; $script:passed++; Write-Output "PASS $Name" }
    catch { $script:failed++; Write-Error "FAIL ${Name}: $($_.Exception.Message)" -ErrorAction Continue }
}
function Assert([bool]$Condition) { if (-not $Condition) { throw 'Assertion failed.' } }
function Refuses([scriptblock]$Body) {
    $refused = $false
    try { & $Body | Out-Null } catch { $refused = $true }
    Assert $refused
}
function Wire([byte[]]$Bytes) {
    $size = $Bytes.Length
    return ,[byte[]](@([byte](($size -shr 24) -band 255), [byte](($size -shr 16) -band 255), [byte](($size -shr 8) -band 255), [byte]($size -band 255)) + $Bytes)
}
$kind = [Text.Encoding]::ASCII.GetBytes('ssh-ed25519')
$blob = [byte[]]((Wire $kind) + (Wire ([byte[]](1..32))))
$public = 'ssh-ed25519 ' + [Convert]::ToBase64String($blob)
Check 'Ed25519 matches the standard SHA256 fingerprint without a comment leak' {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $expected = 'ssh-ed25519 SHA256:' + [Convert]::ToBase64String($sha.ComputeHash($blob)).TrimEnd('=') }
    finally { $sha.Dispose() }
    Assert ((Convert-SshPublicKeyToFingerprint ($public + ' COMMENT_CANARY') ed25519) -ceq $expected)
}
Check 'Private or multiline content is refused without publication' {
    $privateHeaderFixture = ('-----BEGIN ' + 'OPENSSH ' + 'PRIVATE KEY-----')
    foreach ($text in @($privateHeaderFixture, ($public + "`n" + $public), 'ssh-ed25519 invalid===')) {
        Refuses { Convert-SshPublicKeyToFingerprint $text ed25519 }
    }
}
Check 'Wrong key type, truncation and trailing bytes are refused' {
    Refuses { Convert-SshPublicKeyToFingerprint $public rsa }
    Refuses { Convert-SshPublicKeyToFingerprint ('ssh-ed25519 ' + [Convert]::ToBase64String([byte[]](0,0,0,80,1))) ed25519 }
    Refuses { Convert-SshPublicKeyToFingerprint ('ssh-ed25519 ' + [Convert]::ToBase64String([byte[]]($blob + 1))) ed25519 }
}
Check 'Fixed file and wire algorithm must agree' {
    Refuses { Convert-SshPublicKeyToFingerprint ($public.Replace('ssh-ed25519 ', 'ssh-rsa ')) rsa }
    Refuses { Convert-SshPublicKeyToFingerprint $public 'unknown' }
}
Check 'RSA and ECDSA wire keys are fingerprinted without arbitrary comments' {
    $rsaBlob = [byte[]]((Wire ([Text.Encoding]::ASCII.GetBytes('ssh-rsa'))) + (Wire ([byte[]](1,0,1))) + (Wire ([byte[]](0,128,1))))
    Assert ((Convert-SshPublicKeyToFingerprint ('ssh-rsa ' + [Convert]::ToBase64String($rsaBlob)) rsa) -match '^ssh-rsa SHA256:[A-Za-z0-9+/]{43}$')
    $curvePoint = [byte[]](@(4) + @(1..64))
    $ecBlob = [byte[]]((Wire ([Text.Encoding]::ASCII.GetBytes('ecdsa-sha2-nistp256'))) + (Wire ([Text.Encoding]::ASCII.GetBytes('nistp256'))) + (Wire $curvePoint))
    Assert ((Convert-SshPublicKeyToFingerprint ('ecdsa-sha2-nistp256 ' + [Convert]::ToBase64String($ecBlob)) ecdsa) -match '^ecdsa-sha2-nistp256 SHA256:[A-Za-z0-9+/]{43}$')
    Refuses { Convert-SshPublicKeyToFingerprint ('ecdsa-sha2-nistp384 ' + [Convert]::ToBase64String($ecBlob)) ecdsa }
}
$peer = [pscustomobject]@{ HostName='fixture-host'; ID='nFixture123'; PublicKey=('nodekey:' + ('a' * 64)); Online=$true }
Check 'Node identity binds OS hostname, node ID and node public key' {
    $expected = Get-SshTrustDigest ('fixture-host' + "`n" + $peer.ID + "`n" + $peer.PublicKey)
    Assert ((Get-SshPeerBinding $peer 'FIXTURE-HOST') -ceq $expected)
}
Check 'Unknown, offline and wrong-host node identity are refused' {
    Refuses { Get-SshPeerBinding $null 'fixture-host' }
    Refuses { Get-SshPeerBinding $peer 'another-host' }
    $peer.Online=$false; Refuses { Get-SshPeerBinding $peer 'fixture-host' }; $peer.Online=$true
    $peer.PublicKey='unexpected'; Refuses { Get-SshPeerBinding $peer 'fixture-host' }
}
$temp = Join-Path ([IO.Path]::GetTempPath()) ('ssh-trust-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
try {
    Initialize-SshTrustReader
    $flags = [Reflection.BindingFlags]'NonPublic,Static'
    $reader = [FixedSshPublicReader].GetMethod('ReadPublicFile', $flags)
    $parents = [FixedSshPublicReader].GetMethod('CheckParents', $flags)
    function Invoke-Reader([string]$Path) {
        $arguments = New-Object object[] 1
        $arguments[0] = $Path
        return $reader.Invoke($null, $arguments)
    }
    function Invoke-Parents([string[]]$Directories) {
        $arguments = New-Object object[] 1
        $arguments[0] = $Directories
        $parents.Invoke($null, $arguments)
    }
    $fixture = Join-Path $temp 'fixture.pub'
    [IO.File]::WriteAllText($fixture, $public)
    Check 'Native no-follow reader accepts a regular bounded public fixture' {
        Assert ((Invoke-Reader $fixture) -ceq $public)
    }
    Check 'Native reader refuses missing, empty, oversized and directory files' {
        Refuses { Invoke-Reader (Join-Path $temp 'absent.pub') }
        Refuses { Invoke-Reader $temp }
        [IO.File]::WriteAllText($fixture, ''); Refuses { Invoke-Reader $fixture }
        [IO.File]::WriteAllText($fixture, ('x' * 65537)); Refuses { Invoke-Reader $fixture }
    }
    Check 'Reparse-point parent is rejected before any key read' {
        $junction = Join-Path $temp 'junction'
        New-Item -ItemType Junction -Path $junction -Target $temp | Out-Null
        try { Refuses { Invoke-Parents @($junction) } }
        finally { [IO.Directory]::Delete($junction) }
    }
    Check 'Native reader rejects a multiply-linked file instead of reading another file through it' {
        $link = Join-Path $temp 'linked.pub'
        [IO.File]::WriteAllText($fixture, $public)
        New-Item -ItemType HardLink -Path $link -Target $fixture | Out-Null
        try { Refuses { Invoke-Reader $link } }
        finally { Remove-Item -LiteralPath $link -Force }
    }
    Check 'Production entrypoint accepts no caller paths or commands' {
        Refuses { & $source -Path $fixture }
        $text = [IO.File]::ReadAllText($source)
        Assert ($text.Contains('C:\ProgramData\ssh\ssh_host_'))
        Assert ($text.Contains('0x08200000'))
        Assert ($text.Contains('WaitForExit(15000)'))
    }
} finally { Remove-Item -LiteralPath $temp -Recurse -Force }
Write-Output "$script:passed passed, $script:failed failed"
if ($script:failed -gt 0) { exit 1 }
