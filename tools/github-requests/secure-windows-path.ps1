# S2-owned ACL check for the Bash identity reader and Python PR snapshot helper.
# One verifier keeps their Windows privacy rule identical; consolidate it into
# a future shared ai-gh state validator when that validator exists.
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('VerifyIdentity', 'EnsureCache', 'VerifyCache')]
  [string]$Mode,
  [string]$Path,
  [string]$Identities,
  [string]$IdentityFile,
  [string]$SaltFile
)

$ErrorActionPreference = 'Stop'
$current = [Security.Principal.WindowsIdentity]::GetCurrent().User
# OWNER RIGHTS follows the already verified owner; it is not a separate user.
$trusted = @($current.Value, 'S-1-5-18', 'S-1-5-32-544', 'S-1-3-4')
$full = [Security.AccessControl.FileSystemRights]::FullControl
$write = [Security.AccessControl.FileSystemRights]::Write -bor
  [Security.AccessControl.FileSystemRights]::Delete -bor
  [Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles -bor
  [Security.AccessControl.FileSystemRights]::ChangePermissions -bor
  [Security.AccessControl.FileSystemRights]::TakeOwnership

function Get-PathAcl([string]$LiteralPath) {
  # Get-Acl lives in Microsoft.PowerShell.Security and can fail to import when
  # Windows PowerShell type data is already registered. The .NET accessors
  # always work and return the same descriptor.
  if ([IO.Directory]::Exists($LiteralPath)) {
    return [IO.Directory]::GetAccessControl($LiteralPath)
  }
  return [IO.File]::GetAccessControl($LiteralPath)
}

function Assert-PathAcl([string]$LiteralPath, [bool]$Private, [bool]$Directory) {
  $item = Get-Item -LiteralPath $LiteralPath -Force
  if ([bool]($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
      $item.PSIsContainer -ne $Directory) { throw 'invalid path type' }
  $acl = Get-PathAcl $LiteralPath
  $owner = $acl.GetOwner([Security.Principal.SecurityIdentifier]).Value
  if (($Private -and $Directory -and $owner -ne $current.Value) -or
      ($owner -notin $trusted)) {
    throw 'path owner is not trusted'
  }
  if ($Private -and $Directory -and -not $acl.AreAccessRulesProtected) {
    throw 'cache inherits access rules'
  }
  $currentHasFull = $false
  foreach ($rule in $acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])) {
    if ($rule.AccessControlType -ne [Security.AccessControl.AccessControlType]::Allow) { continue }
    $sid = $rule.IdentityReference.Value
    if ($sid -eq $current.Value) {
      if (($rule.FileSystemRights -band $full) -eq $full) { $currentHasFull = $true }
      continue
    }
    if ($sid -in @('S-1-5-18', 'S-1-5-32-544', 'S-1-3-4')) { continue }
    if ($Private -or ($rule.FileSystemRights -band $write)) {
      throw 'another principal has access to protected state'
    }
  }
  if ($Private -and -not $currentHasFull) { throw 'current user lacks full access' }
}

try {
  switch ($Mode) {
    VerifyIdentity {
      # Identity metadata contains a token-derived hash and public principal,
      # never the token. Other sandbox readers may see it, but they must not
      # alter the verified identity used to partition private PR snapshots.
      Assert-PathAcl (Split-Path -Parent $Path) $false $true
      Assert-PathAcl $Path $false $true
      Assert-PathAcl $Identities $false $true
      Assert-PathAcl $IdentityFile $false $false
      Assert-PathAcl $SaltFile $false $false
    }
    EnsureCache {
      $ancestor = Split-Path -Parent $Path
      while (-not (Test-Path -LiteralPath $ancestor)) {
        $next = Split-Path -Parent $ancestor
        if (-not $next -or $next -eq $ancestor) { throw 'cache parent is unavailable' }
        $ancestor = $next
      }
      Assert-PathAcl $ancestor $false $true
      if (-not (Test-Path -LiteralPath $Path)) {
        [void][IO.Directory]::CreateDirectory($Path)
        $acl = New-Object Security.AccessControl.DirectorySecurity
        $acl.SetOwner($current)
        $acl.SetAccessRuleProtection($true, $false)
        $rule = New-Object Security.AccessControl.FileSystemAccessRule(
          $current, $full,
          ([Security.AccessControl.InheritanceFlags]::ContainerInherit -bor
           [Security.AccessControl.InheritanceFlags]::ObjectInherit),
          [Security.AccessControl.PropagationFlags]::None,
          [Security.AccessControl.AccessControlType]::Allow)
        $acl.AddAccessRule($rule)
        [IO.Directory]::SetAccessControl($Path, $acl)
      }
      Assert-PathAcl (Split-Path -Parent $Path) $false $true
      # A second waiter can observe the newly created directory before the
      # creator finishes applying its ACL. No cache read occurs until verified.
      $verified = $false
      for ($attempt = 0; $attempt -lt 20; $attempt++) {
        try {
          Assert-PathAcl $Path $true $true
          $verified = $true
          break
        } catch {
          Start-Sleep -Milliseconds 50
        }
      }
      if (-not $verified) { throw 'cache ACL is not private' }
    }
    VerifyCache { Assert-PathAcl $Path $true $false }
  }
  exit 0
} catch {
  Write-Error 'protected GitHub snapshot path failed Windows ACL verification'
  exit 1
}
