$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$repair = Join-Path $repoRoot "bin\repair-codex-github-cli-access.ps1"
$setup = Join-Path $repoRoot "bin\setup-machine.ps1"
$skill = Join-Path $repoRoot "skills\shared\shared-db-orchestrator\SKILL.md"
$manual = Join-Path $repoRoot "skills\shared\shared-db-orchestrator\references\operating-manual.md"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-gh-access-" + [guid]::NewGuid())
# A clean CI runner does not have Codex's machine-local sandbox group. The
# well-known Users group exercises the exact ACL grant and denial contract; the
# production default remains CodexSandboxUsers.
$group = ([Security.Principal.SecurityIdentifier]'S-1-5-32-545').Translate(
  [Security.Principal.NTAccount]).Value

try {
  New-Item -ItemType Directory -Path $tempRoot | Out-Null
  Set-Content -LiteralPath (Join-Path $tempRoot "config.yml") -Value "git_protocol: https" -Encoding utf8
  $currentSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
  & icacls.exe $tempRoot /inheritance:r /grant:r "*$currentSid`:(OI)(CI)(F)" | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Could not prepare the restricted test folder." }

  & $repair -GitHubConfigDir $tempRoot -CodexSandboxGroup $group
  if ($LASTEXITCODE -ne 0) { throw "Repair script failed." }

  $acl = Get-Acl -LiteralPath $tempRoot
  $rules = @($acl.Access | Where-Object {
    $_.IdentityReference.Value -ieq $group -and
    $_.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Allow
  })
  if (-not ($rules | Where-Object {
    ($_.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::ReadAndExecute) -eq
      [System.Security.AccessControl.FileSystemRights]::ReadAndExecute
  })) { throw "Expected read-and-execute grant was not created." }
  $writeMask = [System.Security.AccessControl.FileSystemRights]::CreateFiles -bor
    [System.Security.AccessControl.FileSystemRights]::CreateDirectories -bor
    [System.Security.AccessControl.FileSystemRights]::WriteAttributes -bor
    [System.Security.AccessControl.FileSystemRights]::WriteExtendedAttributes -bor
    [System.Security.AccessControl.FileSystemRights]::Delete -bor
    [System.Security.AccessControl.FileSystemRights]::ChangePermissions -bor
    [System.Security.AccessControl.FileSystemRights]::TakeOwnership
  if ($rules | Where-Object { ($_.FileSystemRights -band $writeMask) -ne 0 }) {
    throw "Repair granted write access."
  }

  $setupText = Get-Content -LiteralPath $setup -Raw
  if ($setupText -notmatch 'repair-codex-github-cli-access\.ps1') {
    throw "Machine setup does not install the repair."
  }
  $repairText = Get-Content -LiteralPath $repair -Raw
  if ($repairText -notmatch 'CodexSandboxUsers') {
    throw 'Production repair no longer defaults to the Codex sandbox group.'
  }
  foreach ($doc in @($skill, $manual)) {
    $text = Get-Content -LiteralPath $doc -Raw
    if ($text -notmatch 'Access is denied' -or $text -notmatch 'task.profile') {
      throw "Orchestrator guidance does not diagnose the Codex task-profile failure: $doc"
    }
  }

  Write-Host "PASS: exact read-only access, setup installation, and orchestrator diagnosis are covered."
} finally {
  if (Test-Path -LiteralPath $tempRoot) {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
  }
}
