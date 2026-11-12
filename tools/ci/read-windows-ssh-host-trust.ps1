# Fixed read-only host identity diagnostic; no paths or commands are accepted.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'

function Get-SshTrustDigest([string]$Text) {
    $hash = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-', '').ToLowerInvariant() }
    finally { $hash.Dispose() }
}

function Get-SshPeerBinding($Peer, [string]$ComputerName) {
    if ($null -eq $Peer -or $Peer.Online -ne $true -or
        [string]$Peer.HostName -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,62}$' -or
        [string]$Peer.HostName -ine $ComputerName -or
        [string]$Peer.ID -notmatch '^[A-Za-z0-9]{1,64}$' -or
        [string]$Peer.PublicKey -notmatch '^nodekey:[0-9a-f]{64}$') {
        throw 'Node identity is missing or inconsistent.'
    }
    return Get-SshTrustDigest ($ComputerName.ToLowerInvariant() + "`n" + $Peer.ID + "`n" + $Peer.PublicKey)
}

function Read-SshWireField([byte[]]$Bytes, [ref]$Offset) {
    if ($Offset.Value + 4 -gt $Bytes.Length) { throw 'Invalid public-key structure.' }
    $length = [uint64]0
    for ($i = 0; $i -lt 4; $i++) { $length = $length * 256 + $Bytes[$Offset.Value + $i] }
    $Offset.Value += 4
    if ($length -gt 16384 -or $Offset.Value + $length -gt $Bytes.Length) { throw 'Invalid public-key structure.' }
    $value = New-Object byte[] ([int]$length)
    [Array]::Copy($Bytes, $Offset.Value, $value, 0, [int]$length)
    $Offset.Value += [int]$length
    return ,$value
}

function Convert-SshPublicKeyToFingerprint([string]$Text, [string]$ExpectedKind) {
    $textLine = $Text.TrimEnd("`r", "`n")
    if ($textLine.Length -gt 65536 -or $textLine -match '[\r\n\x00]' -or
        $textLine -notmatch '^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521)) ([A-Za-z0-9+/]+={0,2})( [^\r\n]*)?$') {
        throw 'Invalid public-key content.'
    }
    $kind = $Matches[1]; $encoded = $Matches[3]
    if (($ExpectedKind -eq 'ed25519' -and $kind -ne 'ssh-ed25519') -or
        ($ExpectedKind -eq 'rsa' -and $kind -ne 'ssh-rsa') -or
        ($ExpectedKind -eq 'ecdsa' -and $kind -notmatch '^ecdsa-sha2-nistp(256|384|521)$') -or
        $ExpectedKind -notin @('ed25519', 'rsa', 'ecdsa')) { throw 'Unexpected public-key type.' }
    try { $bytes = [Convert]::FromBase64String($encoded) }
    catch { throw 'Invalid public-key encoding.' }
    $offset = 0
    $wireKind = [Text.Encoding]::ASCII.GetString((Read-SshWireField $bytes ([ref]$offset)))
    if ($wireKind -cne $kind) { throw 'Public-key type does not match its structure.' }
    if ($kind -eq 'ssh-ed25519') {
        if ((Read-SshWireField $bytes ([ref]$offset)).Length -ne 32) { throw 'Invalid public-key structure.' }
    } elseif ($kind -eq 'ssh-rsa') {
        foreach ($field in 1, 2) {
            $integer = Read-SshWireField $bytes ([ref]$offset)
            if ($integer.Length -eq 0 -or ($integer[0] -band 128) -ne 0 -or
                ($integer[0] -eq 0 -and ($integer.Length -eq 1 -or ($integer[1] -band 128) -eq 0))) {
                throw 'Invalid public-key integer.'
            }
        }
    } else {
        $curve = [Text.Encoding]::ASCII.GetString((Read-SshWireField $bytes ([ref]$offset)))
        $point = Read-SshWireField $bytes ([ref]$offset)
        $pointSizes = @{ nistp256 = 65; nistp384 = 97; nistp521 = 133 }
        if ($kind -cne ('ecdsa-sha2-' + $curve) -or -not $pointSizes.ContainsKey($curve) -or
            $point.Length -ne $pointSizes[$curve] -or $point[0] -ne 4) { throw 'Invalid public-key curve.' }
    }
    if ($offset -ne $bytes.Length) { throw 'Unexpected public-key trailing data.' }
    $hash = [Security.Cryptography.SHA256]::Create()
    try { $fingerprint = [Convert]::ToBase64String($hash.ComputeHash($bytes)).TrimEnd('=') }
    finally { $hash.Dispose() }
    return $kind + ' SHA256:' + $fingerprint
}

function Initialize-SshTrustReader {
    if ('FixedSshPublicReader' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;
public static class FixedSshPublicReader {
    [StructLayout(LayoutKind.Sequential)] struct Info {
        public uint Attr; public System.Runtime.InteropServices.ComTypes.FILETIME Created, Accessed, Written;
        public uint Volume, SizeHigh, SizeLow, Links, IndexHigh, IndexLow;
    }
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    static extern SafeFileHandle CreateFile(string path, uint access, uint share, IntPtr security, uint creation, uint flags, IntPtr template);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool GetFileInformationByHandle(SafeFileHandle handle, out Info info);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] static extern uint GetFileAttributes(string path);
    public static string Read(string kind) {
        if (kind != "ed25519" && kind != "rsa" && kind != "ecdsa") throw new IOException("Invalid public-key selection.");
        CheckParents(new[]{@"C:\", @"C:\ProgramData", @"C:\ProgramData\ssh"});
        return ReadPublicFile(@"C:\ProgramData\ssh\ssh_host_"+kind+"_key.pub");
    }
    static void CheckParents(string[] dirs) {
        foreach (string dir in dirs) {
            uint attrs=GetFileAttributes(dir);
            if(attrs==0xffffffff || (attrs & 0x400)!=0 || (attrs & 0x10)==0) throw new IOException("Invalid public-key parent.");
        }
    }
    static string ReadPublicFile(string path) {
        using (var h=CreateFile(path,0x80000000,1,IntPtr.Zero,3,0x08200000,IntPtr.Zero)) {
            Info info;
            if(h.IsInvalid || !GetFileInformationByHandle(h,out info) || (info.Attr & 0x410)!=0 || info.Links!=1 || info.SizeHigh!=0 || info.SizeLow==0 || info.SizeLow>65536)
                throw new IOException("Invalid public-key file.");
            using(var stream=new FileStream(h,FileAccess.Read))
            using(var reader=new StreamReader(stream,new UTF8Encoding(false,true))) return reader.ReadToEnd();
        }
    }
}
'@
}

function Invoke-SshHostTrustDiagnostic {
    if ($env:EXPECTED_PEER_DIGEST -cnotmatch '^[0-9a-f]{64}$') { throw 'Authenticated node binding is required.' }
    $tailscale = 'C:\Program Files\Tailscale\tailscale.exe'
    $binary = Get-Item -LiteralPath $tailscale -Force
    if ($binary.PSIsContainer -or ($binary.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Invalid identity reader.' }
    $process = New-Object Diagnostics.Process
    $process.StartInfo.FileName = $tailscale
    $process.StartInfo.Arguments = 'status --json'
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    try {
        if (-not $process.Start()) { throw 'Identity reader failed.' }
        $out = $process.StandardOutput.ReadToEndAsync(); $err = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(15000)) { $process.Kill(); throw 'Identity reader timed out.' }
        if ($process.ExitCode -ne 0 -or $out.Result.Length -gt 4194304) { throw 'Identity reader failed.' }
        $status = $out.Result | ConvertFrom-Json
        $digest = Get-SshPeerBinding $status.Self $env:COMPUTERNAME
        if ($digest -cne $env:EXPECTED_PEER_DIGEST) { throw 'Node identity does not match authenticated control evidence.' }
        Initialize-SshTrustReader
        $records = @()
        foreach ($kind in @('ed25519', 'rsa', 'ecdsa')) {
            $records += Convert-SshPublicKeyToFingerprint ([FixedSshPublicReader]::Read($kind)) $kind
        }
        # Publish only after every fixed file and identity check succeeds.
        Write-Output ('node SHA256:' + $digest)
        $records | ForEach-Object { Write-Output $_ }
    } finally { $process.Dispose() }
}

if ($MyInvocation.InvocationName -ne '.') {
    try { Invoke-SshHostTrustDiagnostic }
    catch { Write-Error 'SSH host trust diagnostic refused; no identity proof was published.'; exit 1 }
}
