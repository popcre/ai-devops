$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'bin\windows-private-file.ps1')
$temp = Join-Path ([IO.Path]::GetTempPath()) ('ai-devops-private-file-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $temp | Out-Null
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw "FAIL: $Message" } }

try {
  $explicitFixture = Join-Path $temp 'explicit-extra-grant'
  New-Item -ItemType Directory -Path $explicitFixture | Out-Null
  $currentSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
  & icacls.exe $explicitFixture /inheritance:r /grant:r "*$currentSid`:(OI)(CI)(F)" 'SYSTEM:(OI)(CI)(F)' 'BUILTIN\Users:(OI)(CI)(RX)' | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'FAIL: could not seed the unexpected explicit grant fixture' }
  Protect-AiDevOpsPrivatePath -Path $explicitFixture -Directory
  Assert-AiDevOpsPrivateAcl $explicitFixture

  $path = Join-Path $temp 'token'
  $first = [Text.Encoding]::ASCII.GetBytes('first-value')
  Set-AiDevOpsPrivateFileAtomic -Path $path -Bytes $first | Out-Null
  Assert (([IO.File]::ReadAllText($path)) -eq 'first-value') 'initial atomic publication failed'
  Assert-AiDevOpsPrivateAcl $path

  $before = [IO.File]::ReadAllBytes($path)
  $env:AI_DEVOPS_TEST_ICACLS_FAIL = '1'
  $failed = $false
  try { Set-AiDevOpsPrivateFileAtomic -Path $path -Bytes ([Text.Encoding]::ASCII.GetBytes('unsafe')) | Out-Null } catch { $failed=$true }
  $env:AI_DEVOPS_TEST_ICACLS_FAIL = $null
  Assert $failed 'simulated icacls failure did not fail closed'
  Assert (([Convert]::ToHexString($before)) -eq ([Convert]::ToHexString([IO.File]::ReadAllBytes($path)))) 'ACL failure changed existing file'

  $backup = Set-AiDevOpsPrivateFileAtomic -Path $path -Bytes ([Text.Encoding]::ASCII.GetBytes('second-value'))
  Assert (([IO.File]::ReadAllText($path)) -eq 'second-value') 'replacement did not publish'
  Assert (Test-Path -LiteralPath $backup) 'unique protected backup missing'
  Assert (([IO.File]::ReadAllText($backup)) -eq 'first-value') 'backup is not the prior value'
  Assert-AiDevOpsPrivateAcl $backup
  Write-Host 'PASS: Windows private files stage, verify ACL, publish atomically, and preserve prior state'
} finally {
  $env:AI_DEVOPS_TEST_ICACLS_FAIL = $null
  Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
