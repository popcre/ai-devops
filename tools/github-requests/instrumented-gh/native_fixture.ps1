# Qualification only. No installation, routing, trust changes, or named pipe.
param(
    [Parameter(Mandatory=$true)][string]$FixtureDirectory,
    [Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{64}$')][string]$ExpectedManifestSha256
)
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'Native Windows execution required' }
$root = [IO.Path]::GetFullPath($FixtureDirectory)
$temporaryRoot = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Temp'
$programFilesRoot = [Environment]::GetFolderPath('ProgramFiles')
$allowedParents = @([IO.Path]::GetFullPath($temporaryRoot), [IO.Path]::GetFullPath($programFilesRoot))
if ([IO.Path]::GetDirectoryName($root) -notin $allowedParents -or
    [IO.Path]::GetFileName($root) -notmatch '^ai-devops-gh-counter-[a-f0-9]{16,32}$' -or
    $root.StartsWith('\\') -or ([IO.DriveInfo]::new([IO.Path]::GetPathRoot($root))).DriveType -ne 'Fixed') {
    throw 'Fixed private local fixture namespace required'
}
$locks = [Collections.Generic.List[IDisposable]]::new()
$controlledKeys = @('TEMP','TMP','GH_CONFIG_DIR','GH_PATH','GH_TELEMETRY','GH_TELEMETRY_ENDPOINT_URL','GH_TELEMETRY_SAMPLE_RATE')
$savedEnvironment = @{}
function Clear-QualificationEnvironment {
    foreach ($key in @([Environment]::GetEnvironmentVariables().Keys)) {
        if ($key -like 'AI_GH_COUNTER_FIXTURE_*' -or $key -like 'AI_GH_HTTP_COUNTER_*' -or $key -in $controlledKeys) {
            [Environment]::SetEnvironmentVariable($key, $null, 'Process')
        }
    }
}
foreach ($key in @([Environment]::GetEnvironmentVariables().Keys)) {
    if ($key -like 'AI_GH_COUNTER_FIXTURE_*' -or $key -like 'AI_GH_HTTP_COUNTER_*' -or $key -in $controlledKeys) {
        $savedEnvironment[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
    }
}
function Assert-BootstrapPrivateDirectory([string]$Path) {
    # Existing protected staging parent excludes foreign replacement writers.
    # Reject links and unknown security before Add-Type writes any compiler temp.
    $item = Get-Item -LiteralPath $Path -Force
    if (-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Private compiler directory required' }
    $acl = Get-Acl -LiteralPath $Path
    $raw = [Security.AccessControl.RawSecurityDescriptor]::new($acl.GetSecurityDescriptorBinaryForm(), 0)
    $owner = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    if ($raw.Owner.Value -ne $owner -or -not ($raw.ControlFlags -band [Security.AccessControl.ControlFlags]::DiscretionaryAclPresent) -or
        -not ($raw.ControlFlags -band [Security.AccessControl.ControlFlags]::DiscretionaryAclProtected) -or
        $null -eq $raw.DiscretionaryAcl -or $raw.DiscretionaryAcl.Count -eq 0) { throw 'Private compiler DACL required' }
    $ownerRead = $false
    foreach ($ace in $raw.DiscretionaryAcl) {
        if ($ace -isnot [Security.AccessControl.CommonAce] -or $ace.IsCallback -or
            $ace.AceQualifier -ne 'AccessAllowed' -or ($ace.AceFlags -band [Security.AccessControl.AceFlags]::Inherited) -or
            $ace.SecurityIdentifier.Value -notin @($owner,'S-1-5-18','S-1-5-32-544') -or
            $ace.AccessMask -notin @(2032127,1179785,1179817)) { throw 'Unsafe compiler DACL refused' }
        if ($ace.SecurityIdentifier.Value -eq $owner -and ($ace.AccessMask -band 1179785) -eq 1179785) { $ownerRead = $true }
    }
    if (-not $ownerRead) { throw 'Compiler owner read contract unavailable' }
}
try {
    # Actual hostile environment sentinel cases use process-local values only.
    # They never open the supplied paths or send to the supplied URL.
    foreach ($key in @('AI_GH_COUNTER_FIXTURE_ROLE','AI_GH_COUNTER_FIXTURE_CONFIG','AI_GH_COUNTER_FIXTURE_TELEMETRY_URL',
        'AI_GH_COUNTER_FIXTURE_FUTURE_SENTINEL','AI_GH_HTTP_COUNTER_HANDLE','AI_GH_HTTP_COUNTER_FD','AI_GH_HTTP_COUNTER_HOST')) {
        [Environment]::SetEnvironmentVariable($key, 'hostile-ambient-sentinel', 'Process')
    }
    Clear-QualificationEnvironment
    foreach ($key in @([Environment]::GetEnvironmentVariables().Keys)) {
        if ($key -like 'AI_GH_COUNTER_FIXTURE_*' -or $key -like 'AI_GH_HTTP_COUNTER_*' -or $key -in $controlledKeys) { throw 'Ambient qualification control survived' }
    }
    [Console]::Out.WriteLine('{"schema":1,"native_environment_cases":7,"passed":true}')
    $privateTemp = Join-Path $root 'temp'
    Assert-BootstrapPrivateDirectory $root
    Assert-BootstrapPrivateDirectory $privateTemp
    $env:TEMP = $privateTemp
    $env:TMP = $privateTemp
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public static class CounterFixtureLocks {
 [DllImport("kernel32.dll", SetLastError=true)] internal static extern bool AllocConsole();
 [DllImport("kernel32.dll", SetLastError=true)] internal static extern bool GetConsoleMode(SafeFileHandle handle, out uint mode);
 [DllImport("kernel32.dll", SetLastError=true)] public static extern bool FreeConsole();
 public static bool EnsureFixtureConsole() {
  using (SafeFileHandle input = CreateFile("CONIN$", 0x80000000, 3, IntPtr.Zero, 3, 0, IntPtr.Zero)) {
   if (!input.IsInvalid) {
    uint mode;
    if (!GetConsoleMode(input, out mode)) throw new IOException("Existing console mode unavailable");
    return false;
   }
  }
  if (!AllocConsole()) throw new IOException("Fixture console allocation failed");
  try {
   using (SafeFileHandle input = CreateFile("CONIN$", 0x80000000, 3, IntPtr.Zero, 3, 0, IntPtr.Zero)) {
    uint mode;
    if (input.IsInvalid || !GetConsoleMode(input, out mode)) throw new IOException("Allocated fixture console unavailable");
   }
   return true;
  } catch { FreeConsole(); throw; }
 }
 [StructLayout(LayoutKind.Sequential)] public struct NativeTime { public uint Low, High; }
 [StructLayout(LayoutKind.Sequential)] public struct FileInfo {
  public uint Attributes; public NativeTime Creation, Access, Write;
  public uint Volume, SizeHigh, SizeLow, Links, IndexHigh, IndexLow;
 }
 [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true, EntryPoint="CreateFileW")]
 internal static extern SafeFileHandle CreateFile(string path, uint access, uint share, IntPtr security, uint disposition, uint flags, IntPtr template);
 [DllImport("kernel32.dll", SetLastError=true)] internal static extern bool GetFileInformationByHandle(SafeFileHandle file, out FileInfo info);
 [DllImport("kernel32.dll", SetLastError=true)] internal static extern uint GetFileType(SafeFileHandle file);
 [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true, EntryPoint="GetFinalPathNameByHandleW")]
 internal static extern uint GetFinalPathNameByHandle(SafeFileHandle file, StringBuilder path, uint length, uint flags);
 [DllImport("advapi32.dll", SetLastError=true)] internal static extern uint GetSecurityInfo(SafeFileHandle handle, uint type, uint flags, out IntPtr owner, out IntPtr group, out IntPtr dacl, out IntPtr sacl, out IntPtr descriptor);
 [DllImport("advapi32.dll", CharSet=CharSet.Unicode, SetLastError=true, EntryPoint="ConvertSecurityDescriptorToStringSecurityDescriptorW")]
 internal static extern bool DescriptorToString(IntPtr descriptor, uint revision, uint flags, out IntPtr text, out uint length);
 [DllImport("kernel32.dll")] internal static extern IntPtr LocalFree(IntPtr memory);
 [StructLayout(LayoutKind.Sequential)] internal struct SecurityAttributes {
  public uint Length; public IntPtr Descriptor; [MarshalAs(UnmanagedType.Bool)] public bool Inherit;
 }
 [DllImport("advapi32.dll", CharSet=CharSet.Unicode, SetLastError=true, EntryPoint="ConvertStringSecurityDescriptorToSecurityDescriptorW")]
 internal static extern bool StringToDescriptor(string text, uint revision, out IntPtr descriptor, out uint length);
 [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true, EntryPoint="CreateFileW")]
 internal static extern SafeFileHandle CreateOwnedFile(string path, uint access, uint share, ref SecurityAttributes attributes, uint disposition, uint flags, IntPtr template);
 [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true, EntryPoint="CreateDirectoryW")]
 internal static extern bool CreateOwnedDirectory(string path, ref SecurityAttributes attributes);
 [DllImport("advapi32.dll", SetLastError=true)] internal static extern uint SetSecurityInfo(SafeFileHandle file, uint type, uint flags, IntPtr owner, IntPtr group, IntPtr dacl, IntPtr sacl);
 [DllImport("advapi32.dll", SetLastError=true)] internal static extern bool GetSecurityDescriptorDacl(IntPtr descriptor, [MarshalAs(UnmanagedType.Bool)] out bool present, out IntPtr dacl, [MarshalAs(UnmanagedType.Bool)] out bool defaulted);
 [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true, EntryPoint="CreateHardLinkW")]
 internal static extern bool CreateHardLink(string path, string target, IntPtr security);
 [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true, EntryPoint="CreateSymbolicLinkW")]
 [return: MarshalAs(UnmanagedType.I1)] internal static extern bool CreateSymbolicLink(string path, string target, uint flags);
 [DllImport("kernel32.dll", SetLastError=true)] internal static extern bool DeviceIoControl(SafeFileHandle file, uint code, byte[] input, uint length, IntPtr output, uint outputLength, out uint returned, IntPtr overlapped);

 internal static string HandlePath(SafeFileHandle file) {
  StringBuilder text = new StringBuilder(32768);
  uint length = GetFinalPathNameByHandle(file, text, (uint)text.Capacity, 0);
  if (length == 0 || length >= text.Capacity) throw new IOException("Handle path unavailable");
  string path = text.ToString();
  if (path.StartsWith(@"\\?\UNC\", StringComparison.OrdinalIgnoreCase)) throw new IOException("Network path refused");
  if (path.StartsWith(@"\\?\", StringComparison.Ordinal)) path = path.Substring(4);
  return Path.GetFullPath(path);
 }
 internal static FileInfo Inspect(SafeFileHandle file, bool directory) {
  FileInfo info;
  if (GetFileType(file) != 1 || !GetFileInformationByHandle(file, out info)) throw new IOException("Disk handle metadata unavailable");
  if ((info.Attributes & 0x400) != 0) throw new IOException("Reparse handle refused");
  if (((info.Attributes & 0x10) != 0) != directory) throw new IOException("Handle type mismatch");
  if (!directory && info.Links != 1) throw new IOException("Hard-linked staged file refused");
  return info;
 }
 public static void AssertPrivate(SafeFileHandle file) {
  IntPtr owner, group, dacl, sacl, descriptor, text = IntPtr.Zero;
  if (GetSecurityInfo(file, 1, 5, out owner, out group, out dacl, out sacl, out descriptor) != 0) throw new IOException("Handle security unavailable");
  try {
   if (dacl == IntPtr.Zero) throw new IOException("Null or absent DACL refused");
   uint length;
   if (!DescriptorToString(descriptor, 1, 5, out text, out length)) throw new IOException("Security snapshot unavailable");
   RawSecurityDescriptor security = new RawSecurityDescriptor(Marshal.PtrToStringUni(text));
   string current = WindowsIdentity.GetCurrent().User.Value;
   if (security.Owner == null || security.Owner.Value != current) throw new IOException("Fixture owner mismatch");
   if ((security.ControlFlags & ControlFlags.DiscretionaryAclPresent) == 0 ||
       (security.ControlFlags & ControlFlags.DiscretionaryAclProtected) == 0 ||
       security.DiscretionaryAcl == null || security.DiscretionaryAcl.Count == 0 || dacl == IntPtr.Zero)
    throw new IOException("Present protected non-null DACL required");
   bool ownerRead = false;
   foreach (GenericAce ace in security.DiscretionaryAcl) {
    CommonAce allow = ace as CommonAce;
    if (allow == null || allow.IsCallback || allow.AceQualifier != AceQualifier.AccessAllowed ||
        (allow.AceFlags & AceFlags.Inherited) != 0) throw new IOException("Unsupported or deny ACE refused");
    string sid = allow.SecurityIdentifier.Value;
    if (sid != current && sid != "S-1-5-18" && sid != "S-1-5-32-544") throw new IOException("Untrusted ACL principal");
    uint mask = unchecked((uint)allow.AccessMask);
    if (mask != 0x1f01ff && mask != 0x120089 && mask != 0x1200a9) throw new IOException("Unsupported ACL rights");
    if (sid == current && (mask & 0x120089) == 0x120089) ownerRead = true;
   }
   if (!ownerRead) throw new IOException("Owner read contract unavailable");
  } finally { if (text != IntPtr.Zero) LocalFree(text); LocalFree(descriptor); }
 }
 public sealed class BoundEntry : IDisposable {
  public readonly SafeFileHandle Handle;
  public readonly string Path;
  internal readonly FileInfo Identity;
  internal readonly bool Directory;
  public FileStream Stream;
  internal BoundEntry(SafeFileHandle handle, string path, FileInfo identity, bool directory) {
   Handle = handle; Path = path; Identity = identity; Directory = directory;
   if (!directory) Stream = new FileStream(handle, FileAccess.Read, 4096, false);
  }
  public void AssertPathBinding() {
   FileInfo now = Inspect(Handle, Directory);
   if (now.Volume != Identity.Volume || now.IndexHigh != Identity.IndexHigh || now.IndexLow != Identity.IndexLow)
    throw new IOException("Held image identity changed");
   if (!String.Equals(HandlePath(Handle).TrimEnd('\\'), Path.TrimEnd('\\'), StringComparison.OrdinalIgnoreCase))
    throw new IOException("Held path identity changed");
   using (SafeFileHandle query = CreateFile(Path, 0x80000000, Directory ? 3u : 1u, IntPtr.Zero, 3, Directory ? 0x02200000u : 0x00200000u, IntPtr.Zero)) {
    if (query.IsInvalid) throw new IOException("Bound path unavailable");
    FileInfo pathInfo = Inspect(query, Directory);
    if (pathInfo.Volume != Identity.Volume || pathInfo.IndexHigh != Identity.IndexHigh || pathInfo.IndexLow != Identity.IndexLow)
     throw new IOException("Path identifies another image");
   }
  }
  public void Dispose() { if (Stream != null) Stream.Dispose(); Handle.Dispose(); }
 }
 public static BoundEntry Open(string path, bool directory, bool requirePrivate) {
  path = System.IO.Path.GetFullPath(path);
  // OPEN_REPARSE_POINT before any data read. Caller anchors directories
  // root-to-leaf and retains them with delete sharing denied.
  SafeFileHandle file = CreateFile(path, 0x80000000, directory ? 3u : 1u, IntPtr.Zero, 3, directory ? 0x02200000u : 0x00200000u, IntPtr.Zero);
  if (file.IsInvalid) { file.Dispose(); throw new IOException("No-follow lock unavailable"); }
  try {
   FileInfo identity = Inspect(file, directory);
   string actual = HandlePath(file);
   if (!String.Equals(actual.TrimEnd('\\'), path.TrimEnd('\\'), StringComparison.OrdinalIgnoreCase)) throw new IOException("Opened path identity mismatch");
   if (requirePrivate) AssertPrivate(file);
   return new BoundEntry(file, actual, identity, directory);
  } catch { file.Dispose(); throw; }
 }

 // Adversarial fixtures alter only newly created, fixed-name objects beneath
 // the already locked private fixture root. No staged image/manifest is changed.
 static string FixtureDescriptor(string dacl) {
  string sid = WindowsIdentity.GetCurrent().User.Value;
  return "O:" + sid + dacl.Replace("{owner}", sid);
 }
 static SecurityAttributes Attributes(string dacl) {
  IntPtr descriptor; uint length;
  if (!StringToDescriptor(FixtureDescriptor(dacl), 1, out descriptor, out length)) throw new IOException("Fixture descriptor unavailable");
  SecurityAttributes attributes = new SecurityAttributes();
  attributes.Length = (uint)Marshal.SizeOf(typeof(SecurityAttributes));
  attributes.Descriptor = descriptor;
  attributes.Inherit = false;
  return attributes;
 }
 static void FixtureDirectory(string path) {
  SecurityAttributes attributes = Attributes("D:P(A;;FA;;;{owner})(A;;FA;;;SY)(A;;FA;;;BA)");
  try { if (!CreateOwnedDirectory(path, ref attributes)) throw new IOException("Fresh private fixture directory required"); }
  finally { LocalFree(attributes.Descriptor); }
 }
 static void FixtureFile(string path, string dacl, bool nullDacl) {
  SecurityAttributes attributes = Attributes("D:P(A;;FA;;;{owner})(A;;FA;;;SY)(A;;FA;;;BA)");
  IntPtr requested = IntPtr.Zero;
  try {
   using (SafeFileHandle file = CreateOwnedFile(path, 0xc0040000, 1, ref attributes, 1, 0x00200000, IntPtr.Zero)) {
    if (file.IsInvalid) throw new IOException("Fresh fixture file unavailable");
    Inspect(file, false);
    using (FileStream stream = new FileStream(file, FileAccess.ReadWrite, 4096, false)) {
     byte[] bytes = Encoding.ASCII.GetBytes("verified fixture bytes");
     stream.Write(bytes, 0, bytes.Length); stream.Flush();
     uint length; bool present, defaulted; IntPtr acl;
     if (!StringToDescriptor(FixtureDescriptor(dacl), 1, out requested, out length) ||
         !GetSecurityDescriptorDacl(requested, out present, out acl, out defaulted) || !present)
      throw new IOException("Hostile ACL fixture unavailable");
     uint protection = dacl.StartsWith("D:P", StringComparison.Ordinal) ? 0x80000000u : 0x20000000u;
     if (SetSecurityInfo(file, 1, protection | 4u, IntPtr.Zero, IntPtr.Zero, nullDacl ? IntPtr.Zero : acl, IntPtr.Zero) != 0)
      throw new IOException("Hostile ACL application unavailable");
    }
   }
  } finally { if (requested != IntPtr.Zero) LocalFree(requested); LocalFree(attributes.Descriptor); }
 }
 static void RejectFixture(string path, bool directory) {
  bool rejected = false;
  try { using (BoundEntry unexpected = Open(path, directory, true)) {} }
  catch (IOException) { rejected = true; }
  if (!rejected) throw new IOException("Hostile boundary admitted");
 }
 static void Junction(string path, string target) {
  byte[] substitute = Encoding.Unicode.GetBytes(@"\??\" + System.IO.Path.GetFullPath(target));
  byte[] print = Encoding.Unicode.GetBytes(System.IO.Path.GetFullPath(target));
  byte[] buffer = new byte[16 + substitute.Length + 2 + print.Length + 2];
  Array.Copy(BitConverter.GetBytes(0xa0000003u), 0, buffer, 0, 4);
  Array.Copy(BitConverter.GetBytes((ushort)(buffer.Length - 8)), 0, buffer, 4, 2);
  Array.Copy(BitConverter.GetBytes((ushort)substitute.Length), 0, buffer, 10, 2);
  Array.Copy(BitConverter.GetBytes((ushort)(substitute.Length + 2)), 0, buffer, 12, 2);
  Array.Copy(BitConverter.GetBytes((ushort)print.Length), 0, buffer, 14, 2);
  Array.Copy(substitute, 0, buffer, 16, substitute.Length);
  Array.Copy(print, 0, buffer, 16 + substitute.Length + 2, print.Length);
  using (SafeFileHandle file = CreateFile(path, 0x40000000, 7, IntPtr.Zero, 3, 0x02200000, IntPtr.Zero)) {
   uint returned;
   if (file.IsInvalid || !DeviceIoControl(file, 0x000900a4, buffer, (uint)buffer.Length, IntPtr.Zero, 0, out returned, IntPtr.Zero))
    throw new IOException("Junction fixture unavailable");
  }
 }
 public static int RunBoundaryFixtures(string root) {
  const string valid = "D:P(A;;FA;;;{owner})(A;;FA;;;SY)(A;;FA;;;BA)";
  string cases = System.IO.Path.Combine(root, "boundary-cases");
  FixtureDirectory(cases);
  using (BoundEntry anchored = Open(cases, true, true)) {
   int count = 0;
   string nullFile = System.IO.Path.Combine(cases, "null-dacl");
   FixtureFile(nullFile, valid, true); RejectFixture(nullFile, false); count++;
   string worldFile = System.IO.Path.Combine(cases, "world-allow");
   FixtureFile(worldFile, "D:P(A;;FA;;;{owner})(A;;FA;;;WD)", false); RejectFixture(worldFile, false); count++;
   string inheritedFile = System.IO.Path.Combine(cases, "unprotected");
   FixtureFile(inheritedFile, "D:(A;;FA;;;{owner})(A;;FA;;;SY)", false); RejectFixture(inheritedFile, false); count++;
   string deniedFile = System.IO.Path.Combine(cases, "deny-ace");
   FixtureFile(deniedFile, "D:P(D;;0x2;;;WD)(A;;FA;;;{owner})(A;;FA;;;SY)", false); RejectFixture(deniedFile, false); count++;
   string target = System.IO.Path.Combine(cases, "valid-file");
   FixtureFile(target, valid, false);
   using (BoundEntry held = Open(target, false, true)) {
    byte[] before = new byte[held.Stream.Length]; held.Stream.Read(before, 0, before.Length); held.Stream.Position = 0;
    bool writeDenied = false, renameDenied = false;
    try { using (FileStream writer = File.Open(target, FileMode.Open, FileAccess.Write, FileShare.ReadWrite | FileShare.Delete)) {} }
    catch (IOException) { writeDenied = true; }
    try { File.Move(target, target + "-swapped"); } catch (IOException) { renameDenied = true; }
    if (!writeDenied || !renameDenied) throw new IOException("Verified fixture image replaceable");
    held.AssertPathBinding();
    byte[] after = new byte[before.Length]; held.Stream.Read(after, 0, after.Length);
    if (!String.Equals(Convert.ToBase64String(before), Convert.ToBase64String(after), StringComparison.Ordinal)) throw new IOException("Verified bytes changed");
    count++;
   }
   string hard = System.IO.Path.Combine(cases, "hard-link");
   if (!CreateHardLink(hard, target, IntPtr.Zero)) throw new IOException("Hard-link fixture unavailable");
   RejectFixture(hard, false); count++;
   string symbolic = System.IO.Path.Combine(cases, "symbolic-link");
   if (!CreateSymbolicLink(symbolic, target, 2)) throw new IOException("Symbolic-link capability unavailable: boundary qualification unknown");
   RejectFixture(symbolic, false); count++;
   string first = System.IO.Path.Combine(cases, "target-a"), second = System.IO.Path.Combine(cases, "target-b");
   FixtureDirectory(first); FixtureDirectory(second);
   string junction = System.IO.Path.Combine(cases, "junction");
   FixtureDirectory(junction);
   for (int i = 0; i < 20; i++) { Junction(junction, i % 2 == 0 ? first : second); RejectFixture(junction, true); }
   count++;
   string ancestor = System.IO.Path.Combine(cases, "ancestor");
   FixtureDirectory(ancestor);
   string child = System.IO.Path.Combine(ancestor, "held-child");
   FixtureFile(child, valid, false);
   using (BoundEntry held = Open(ancestor, true, true)) {
    using (BoundEntry heldChild = Open(child, false, true)) {
    bool denied = false;
    try { Directory.Move(ancestor, ancestor + "-swapped"); } catch (IOException) { denied = true; }
    if (!denied) throw new IOException("Locked ancestor replaceable");
    denied = false;
    try { Junction(ancestor, first); } catch (IOException) { denied = true; }
    if (!denied) throw new IOException("Held ancestor reparse mutation allowed");
    held.AssertPathBinding(); count++;
    }
   }
   anchored.AssertPathBinding();
   return count;
  }
 }
}
'@
function Lock-Directory([string]$Path, [bool]$Private = $false) {
    $entry = [CounterFixtureLocks]::Open($Path, $true, $Private)
    $locks.Add($entry)
    return $entry
}
function Lock-File([string]$Path) {
    $entry = [CounterFixtureLocks]::Open($Path, $false, $true)
    $locks.Add($entry)
    return $entry
}
function Digest([IO.Stream]$Stream) {
    $Stream.Position = 0
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { $value = [BitConverter]::ToString($algorithm.ComputeHash($Stream)).Replace('-','').ToLowerInvariant() }
    finally { $algorithm.Dispose(); $Stream.Position = 0 }
    return $value
}
    $ancestors = [Collections.Generic.List[string]]::new()
    $cursor = $root
    while ($cursor) {
        $ancestors.Add($cursor)
        $parent = [IO.Directory]::GetParent($cursor)
        if ($null -eq $parent) { break }
        $cursor = $parent.FullName
    }
    # Anchor from the volume root inward before inspecting any child path.
    for ($index = $ancestors.Count - 1; $index -ge 0; $index--) {
        [void](Lock-Directory $ancestors[$index] ($index -eq 0))
    }
    [void](Lock-Directory $privateTemp $true)
    $manifestEntry = Lock-File (Join-Path $root 'build.json')
    $manifestStream = $manifestEntry.Stream
    if ((Digest $manifestStream) -ne $ExpectedManifestSha256) { throw 'Reviewed manifest digest mismatch' }
    $reader = [IO.StreamReader]::new($manifestStream, [Text.Encoding]::UTF8, $true, 4096, $true)
    try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
    if ($manifest.target -ne 'windows-amd64' -or $manifest.installed -ne $false -or $manifest.counter_source_binding.schema -ne 1) { throw 'Wrong qualification manifest' }
    if ($manifest.pins.upstream_commit -ne '0cf1092493af067646fc5f3db9421c6a6ec9c938' -or
        $manifest.pins.source_sha256 -ne '057c1bfc07ecee96fcb0a121b482464a3f10063532bace358ee37d57214ea150' -or
        $manifest.pins.toolchain_sha256 -ne '63d339f0da5ab53635a56f2490a7984dfe12dfcff22ad749f63edaf590168445') { throw 'Official input pin mismatch' }
    $sources = @('httpcounter.go','httpcounter_test.go','channel.go','channel_linux.go','channel_windows.go','channel_unsupported.go','channel_windows_test.go','windows_cli_fixture_test.go','native_fixture.ps1')
    $keys = @($manifest.counter_source_binding.files.PSObject.Properties.Name | Sort-Object)
    if (($keys -join ',') -ne (($sources | Sort-Object) -join ',')) { throw 'Finite source closure mismatch' }
    $sourceRoot = Join-Path $root 'source'
    if ([IO.Path]::GetFullPath($PSCommandPath) -ne (Join-Path $sourceRoot 'native_fixture.ps1')) { throw 'Launch fixture must be staged with its source closure' }
    [void](Lock-Directory $sourceRoot $true)
    $actual = @(Get-ChildItem -LiteralPath $sourceRoot -File | Where-Object { $_.Extension -in @('.go','.ps1') } | ForEach-Object Name | Sort-Object)
    if (($actual -join ',') -ne ($keys -join ',')) { throw 'Extra or missing source file' }
    foreach ($name in $sources) {
        $path = Join-Path $sourceRoot $name
        $entry = Lock-File $path
        if ((Digest $entry.Stream) -ne $manifest.counter_source_binding.files.$name) { throw 'Source digest mismatch' }
    }
    $names = @{baseline='gh-baseline.exe'; instrumented='gh-instrumented.exe'; native_fixture='httpcounter-windows-fixture.exe'}
    $images = @{}
    foreach ($kind in @('baseline','instrumented','native_fixture')) {
        $path = Join-Path $root $names[$kind]
        $entry = Lock-File $path
        $images[$kind] = $entry
        $stream = $entry.Stream
        if ((Digest $stream) -ne $manifest.artifacts.$kind.sha256) { throw 'Image digest mismatch' }
        $binary = [IO.BinaryReader]::new($stream, [Text.Encoding]::UTF8, $true)
        try {
            if ($binary.ReadUInt16() -ne 0x5a4d) { throw 'Not a Windows image' }
            $stream.Position = 0x3c
            $offset = $binary.ReadUInt32()
            if ($offset -gt ($stream.Length - 6)) { throw 'Invalid Windows image header' }
            $stream.Position = $offset
            if ($binary.ReadUInt32() -ne 0x4550 -or $binary.ReadUInt16() -ne 0x8664) { throw 'Windows amd64 image required' }
        } finally { $binary.Dispose(); $stream.Position = 0 }
        # Actual verified handles stay held, denying writes/deletes until descendants finish.
    }
    foreach ($entry in $locks) { $entry.AssertPathBinding() }
    $boundaryCount = [CounterFixtureLocks]::RunBoundaryFixtures($root)
    if ($boundaryCount -ne 9) { throw 'Native hostile boundary qualification unknown' }
    [Console]::Out.WriteLine('{"schema":1,"native_boundary_cases":9,"passed":true}')
    foreach ($entry in $locks) { $entry.AssertPathBinding() }
    # The bound test image receives only its fixed fixture profile. Operator
    # credentials and executable/configuration selectors never reach it.
    $windowsRoot = [Environment]::GetFolderPath([Environment+SpecialFolder]::Windows)
    if ([string]::IsNullOrEmpty($windowsRoot) -or -not [IO.Path]::IsPathRooted($windowsRoot)) { throw 'Windows runtime directory unavailable' }
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $images.native_fixture.Path
    $start.Arguments = '-test.run=^TestWindows -test.timeout=5m'
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.EnvironmentVariables.Clear()
    foreach ($key in @('SYSTEMROOT','WINDIR')) { $start.EnvironmentVariables[$key] = $windowsRoot }
    foreach ($key in @('TEMP','TMP','HOME','USERPROFILE','XDG_CACHE_HOME')) { $start.EnvironmentVariables[$key] = $privateTemp }
    $start.EnvironmentVariables['PATH'] = ''
    $start.EnvironmentVariables['AI_GH_COUNTER_FIXTURE_BASELINE'] = $images.baseline.Path
    $start.EnvironmentVariables['AI_GH_COUNTER_FIXTURE_INSTRUMENTED'] = $images.instrumented.Path
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $ownedConsole = $false
    try {
        $ownedConsole = [CounterFixtureLocks]::EnsureFixtureConsole()
        if (-not $process.Start()) { throw 'Native fixture launch failed' }
        $outputTask = $process.StandardOutput.ReadToEndAsync()
        $errorTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(330000)) { $process.Kill(); $process.WaitForExit(); throw 'Native fixture timeout' }
        [Console]::Out.Write($outputTask.GetAwaiter().GetResult())
        [Console]::Error.Write($errorTask.GetAwaiter().GetResult())
        if ($process.ExitCode -ne 0) { throw 'Native qualification failed or unknown' }
    } finally {
        $process.Dispose()
        if ($ownedConsole -and -not [CounterFixtureLocks]::FreeConsole()) { throw 'Owned fixture console cleanup failed' }
    }
} finally {
    Clear-QualificationEnvironment
    foreach ($key in $savedEnvironment.Keys) { [Environment]::SetEnvironmentVariable($key, $savedEnvironment[$key], 'Process') }
    for ($index = $locks.Count - 1; $index -ge 0; $index--) { $locks[$index].Dispose() }
}
