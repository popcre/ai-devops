[CmdletBinding()]
param(
  [string]$GitHubConfigDir = (Join-Path $env:APPDATA "GitHub CLI"),
  [string]$CodexSandboxGroup = "$env:COMPUTERNAME\CodexSandboxUsers"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $GitHubConfigDir -PathType Container)) {
  Write-Host "GitHub CLI config folder is not present: $GitHubConfigDir"
  return
}

try {
  $group = [System.Security.Principal.NTAccount]::new($CodexSandboxGroup)
  $null = $group.Translate([System.Security.Principal.SecurityIdentifier])
} catch {
  Write-Host "Codex sandbox group is not present: $CodexSandboxGroup"
  return
}

$grant = "${CodexSandboxGroup}:(OI)(CI)(RX)"
& icacls.exe $GitHubConfigDir /grant:r $grant | Out-Null
if ($LASTEXITCODE -ne 0) {
  throw "Could not grant read-only Codex sandbox access to $GitHubConfigDir"
}

$acl = Get-Acl -LiteralPath $GitHubConfigDir
$rules = @($acl.Access | Where-Object {
  $_.IdentityReference.Value -ieq $CodexSandboxGroup -and
  $_.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Allow
})
$readRule = $rules | Where-Object {
  ($_.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::ReadAndExecute) -eq
    [System.Security.AccessControl.FileSystemRights]::ReadAndExecute
}
$writeMask = [System.Security.AccessControl.FileSystemRights]::CreateFiles -bor
  [System.Security.AccessControl.FileSystemRights]::CreateDirectories -bor
  [System.Security.AccessControl.FileSystemRights]::WriteAttributes -bor
  [System.Security.AccessControl.FileSystemRights]::WriteExtendedAttributes -bor
  [System.Security.AccessControl.FileSystemRights]::Delete -bor
  [System.Security.AccessControl.FileSystemRights]::ChangePermissions -bor
  [System.Security.AccessControl.FileSystemRights]::TakeOwnership
$writeRule = $rules | Where-Object { ($_.FileSystemRights -band $writeMask) -ne 0 }
if (-not $readRule -or $writeRule) {
  throw "GitHub CLI access repair did not produce an exact read-only sandbox grant."
}

Write-Host "Codex sandbox can read GitHub CLI settings; write access was not granted."
