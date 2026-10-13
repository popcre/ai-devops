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
  Assert (([Convert]::ToBase64String($before)) -eq ([Convert]::ToBase64String([IO.File]::ReadAllBytes($path)))) 'ACL failure changed existing file'

  # Replacement can inherit the old file's ACL. Seed an explicit extra grant
  # to prove old metadata cannot expose the newly published private bytes.
  & icacls.exe $path /grant 'BUILTIN\Users:(RX)' | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'FAIL: could not seed old destination ACL' }
  $oldAclRefused = $false
  try { Assert-AiDevOpsPrivateAcl $path } catch { $oldAclRefused = $true }
  Assert $oldAclRefused 'old destination ACL fixture is not broad'
  $backup = Set-AiDevOpsPrivateFileAtomic -Path $path -Bytes ([Text.Encoding]::ASCII.GetBytes('second-value'))
  Assert (([IO.File]::ReadAllText($path)) -eq 'second-value') 'replacement did not publish'
  Assert (Test-Path -LiteralPath $backup) 'unique protected backup missing'
  Assert (([IO.File]::ReadAllText($backup)) -eq 'first-value') 'backup is not the prior value'
  Assert-AiDevOpsPrivateAcl $path
  Assert-AiDevOpsPrivateAcl $backup
  function icacls.exe { Write-Error 'simulated native launch failure' }
  $ErrorActionPreference = 'Continue'
  $global:LASTEXITCODE = 0
  $launchFailed = $false
  try { Invoke-AiDevOpsIcacls -Path $path -Arguments @('/inheritance:r') } catch { $launchFailed = $true }
  $ErrorActionPreference = 'Stop'
  Remove-Item Function:\icacls.exe
  Assert $launchFailed 'native launch failure did not fail closed under Continue'
  if ($PSVersionTable.PSVersion.Major -ge 7 -and $env:OS -eq 'Windows_NT') {
    # CI normally uses PowerShell 7. Exercise the same real publication,
    # replacement, backup and refusal contract in native Windows PowerShell 5.
    $legacy = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $legacy
    $start.Arguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + $PSCommandPath + '"'
    $start.UseShellExecute = $false
    $start.EnvironmentVariables.Remove('PSModulePath')
    $child = [Diagnostics.Process]::Start($start)
    try {
      if (-not $child.WaitForExit(120000)) {
        $child.Kill()
        throw 'FAIL: native Windows PowerShell 5 private file checks exceeded deadline'
      }
      Assert ($child.ExitCode -eq 0) 'native Windows PowerShell 5 private file checks failed'
    } finally { $child.Dispose() }
  }
  Write-Host 'PASS: Windows private files stage, verify ACL, publish atomically, and preserve prior state'
} finally {
  $env:AI_DEVOPS_TEST_ICACLS_FAIL = $null
  Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
