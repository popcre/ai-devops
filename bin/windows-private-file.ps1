Set-StrictMode -Version Latest

function Invoke-AiDevOpsIcacls {
  param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string[]]$Arguments)
  if ($env:AI_DEVOPS_TEST_ICACLS_FAIL -eq '1') { throw 'Simulated icacls failure.' }
  & icacls.exe $Path @Arguments | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "icacls failed for $Path with exit code $LASTEXITCODE." }
}

function Assert-AiDevOpsPrivateAcl {
  param([Parameter(Mandatory)][string]$Path)
  $userSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
  $allowed = @($userSid, 'S-1-5-18')
  $seenUser = $false
  $acl = Get-Acl -LiteralPath $Path
  foreach ($rule in $acl.Access) {
    if ($rule.AccessControlType -ne [Security.AccessControl.AccessControlType]::Allow) { continue }
    $sid = $rule.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value
    if ($allowed -notcontains $sid) { throw "Private path grants access to unexpected identity $sid." }
    if ($sid -eq $userSid) { $seenUser = $true }
  }
  if (-not $seenUser) { throw 'Private path does not grant the current user access.' }
}

function Protect-AiDevOpsPrivatePath {
  param([Parameter(Mandatory)][string]$Path, [switch]$Directory)
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
  Invoke-AiDevOpsIcacls -Path $Path -Arguments @('/inheritance:r')
  $grant = if ($Directory) { "$identity`:(OI)(CI)(F)" } else { "$identity`:(F)" }
  $systemGrant = if ($Directory) { 'SYSTEM:(OI)(CI)(F)' } else { 'SYSTEM:(F)' }
  Invoke-AiDevOpsIcacls -Path $Path -Arguments @('/grant:r', $grant, $systemGrant)
  Assert-AiDevOpsPrivateAcl -Path $Path
}

function Set-AiDevOpsPrivateFileAtomic {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][byte[]]$Bytes
  )
  $parent = Split-Path -Parent $Path
  New-Item -ItemType Directory -Force -Path $parent | Out-Null
  $staging = Join-Path $parent ('.ai-devops-private-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $staging | Out-Null
  try {
    Protect-AiDevOpsPrivatePath -Path $staging -Directory
    $candidate = Join-Path $staging 'candidate'
    [IO.File]::WriteAllBytes($candidate, $Bytes)
    Protect-AiDevOpsPrivatePath -Path $candidate
    Assert-AiDevOpsPrivateAcl -Path $candidate

    $backup = $null
    if (Test-Path -LiteralPath $Path) {
      $stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
      $backupCandidate = Join-Path $staging 'backup'
      Copy-Item -LiteralPath $Path -Destination $backupCandidate
      Protect-AiDevOpsPrivatePath -Path $backupCandidate
      $backup = "$Path.aidevops.$stamp.bak"
      [IO.File]::Move($backupCandidate, $backup)
      Assert-AiDevOpsPrivateAcl -Path $backup
    }

    [IO.File]::Move($candidate, $Path, $true)
    Assert-AiDevOpsPrivateAcl -Path $Path
    return $backup
  } finally {
    if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
  }
}
