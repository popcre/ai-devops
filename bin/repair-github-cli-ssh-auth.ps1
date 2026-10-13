[CmdletBinding()]
param(
  [string]$GitHubConfigDir = (Join-Path $env:APPDATA "GitHub CLI"),
  [string]$GhPath = "gh",
  [string]$GitHubHost = "github.com"
)

# SSH logons into Windows (OpenSSH key authentication) cannot open the user's
# Windows Credential Manager vault, so a GitHub CLI token stored in the keyring
# works in an interactive window but reads as "invalid" over SSH, and every
# remote ai-gh, git fetch (gh is git's credential helper) and ai-memory-sync
# fails. GitHub CLI's supported alternative is file storage (`--insecure-storage`):
# the token lives in hosts.yml, readable by both logon types. This script moves an
# interactive keyring login to file storage (the token travels only through a
# pipe) and restricts hosts.yml itself to the owner, SYSTEM and Administrators.
# The ACL work targets hosts.yml only: folder-level grants (such as the Codex
# sandbox's access, set by repair-codex-github-cli-access.ps1 so config.yml
# stays readable) are deliberately left in place. After /inheritance:r
# /grant:r the cleanup loop removes any remaining non-allowed ACE on hosts.yml,
# DENY rules included.

$ErrorActionPreference = "Stop"
$hosts = Join-Path $GitHubConfigDir "hosts.yml"

if (-not (Test-Path -LiteralPath $hosts -PathType Leaf)) {
  Write-Host "GitHub CLI is not logged in on this machine (no hosts.yml); nothing to repair."
  return
}

$status = (& $GhPath auth status --hostname $GitHubHost 2>&1 | Out-String)
if ($status -match '\(keyring\)') {
  if ($status -notmatch 'Logged in to') {
    Write-Warning "GitHub CLI token is in Windows Credential Manager and unreadable from this logon (an SSH session). Rerun this setup once from an interactive window to move it to file storage."
    return
  }
  $backup = "$hosts.bak-" + (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
  Copy-Item -LiteralPath $hosts -Destination $backup
  & $GhPath auth token --hostname $GitHubHost | & $GhPath auth login --hostname $GitHubHost --insecure-storage --with-token
  if ($LASTEXITCODE -ne 0) { throw "Moving the GitHub CLI token to file storage failed; backup at $backup" }
  $status = (& $GhPath auth status --hostname $GitHubHost 2>&1 | Out-String)
  if ($status -match '\(keyring\)') { throw "GitHub CLI still reports keyring storage after the move." }
  Write-Host "GitHub CLI token moved from Windows Credential Manager to protected file storage."
}

$owner = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$allowed = @($owner, "S-1-5-18", "S-1-5-32-544")
& icacls.exe $hosts /inheritance:r /grant:r "*${owner}:(F)" "*S-1-5-18:(F)" "*S-1-5-32-544:(F)" | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Could not restrict access to $hosts" }
foreach ($rule in (Get-Acl -LiteralPath $hosts).Access) {
  $sid = $rule.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value
  if ($allowed -notcontains $sid) {
    & icacls.exe $hosts /remove:g "*$sid" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Could not remove $sid from $hosts" }
  }
}

$extra = @((Get-Acl -LiteralPath $hosts).Access | Where-Object {
  $_.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Allow -and
  $allowed -notcontains $_.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value
})
if ($extra.Count -gt 0) {
  throw "hosts.yml is still readable by: $(($extra | ForEach-Object { $_.IdentityReference.Value }) -join ', ')"
}
Write-Host "GitHub CLI credentials file is readable only by its owner, SYSTEM and Administrators."
