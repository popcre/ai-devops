$ErrorActionPreference = 'Stop'
$failures = 0
function Assert([bool]$Condition, [string]$Message) {
  if ($Condition) { Write-Host "  ok   $Message" }
  else { Write-Host "  FAIL $Message"; $script:failures++ }
}

$scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'bin\reconcile-smart-app-control.ps1'
$id = [Guid]::NewGuid().ToString('N')
$registryPath = "HKCU:\Software\ai-devops-tests\$id"
$nativeKey = "HKCU\Software\ai-devops-tests\$id"
$root = Join-Path $env:TEMP "smart-app-control-test-$id"
$backup = Join-Path $root 'backups'
$policies = Join-Path $root 'Active'
$refresh = Join-Path $root 'citool.cmd'
$refreshMarker = Join-Path $root 'refresh-called.txt'
$stateMarker = Join-Path $root 'state-refreshed.json'
try {
  New-Item -ItemType Directory -Force -Path $policies | Out-Null
  Set-Content -LiteralPath (Join-Path $policies 'policy.cip') -Value 'fixture'
  Set-Content -LiteralPath $refresh -Encoding ascii -Value @('@echo off', 'exit /b 7')
  New-Item -Path $registryPath -Force | Out-Null
  New-ItemProperty -Path $registryPath -Name VerifiedAndReputablePolicyState -PropertyType DWord -Value 1 -Force | Out-Null

  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath -TestOnly -RegistryPath $registryPath -RegistryNativeKey $nativeKey -BackupRoot $backup -ActivePolicyPaths $policies -RefreshMarkerPath $stateMarker
  Assert ($LASTEXITCODE -eq 2) 'TestOnly reports drift with exit code 2'
  Assert ((Get-ItemPropertyValue $registryPath VerifiedAndReputablePolicyState) -eq 1) 'TestOnly never changes policy state'
  Assert (-not (Test-Path $backup)) 'TestOnly creates no backup'

  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath -RegistryPath $registryPath -RegistryNativeKey $nativeKey -BackupRoot $backup -ActivePolicyPaths $policies -CiToolPath $refresh -RefreshMarkerPath $stateMarker
  Assert ($LASTEXITCODE -ne 0) 'a failed Code Integrity refresh is never reported as success'
  Assert ((Get-ItemPropertyValue $registryPath VerifiedAndReputablePolicyState) -eq 0) 'policy state is exactly Off'
  $firstBackups = @(Get-ChildItem -LiteralPath $backup -Directory)
  Assert ($firstBackups.Count -eq 1) 'pre-change state has one recoverable backup'
  Assert (Test-Path (Join-Path $firstBackups[0].FullName 'ci-policy.reg')) 'registry backup exists'
  Assert (Test-Path (Join-Path $firstBackups[0].FullName 'active-policies\Active\policy.cip')) 'active policy file backup exists'
  Assert (-not (Test-Path $refreshMarker)) 'failed refresh has no success marker'
  Assert (-not (Test-Path $stateMarker)) 'failed refresh has no durable compliance marker'

  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath -TestOnly -RegistryPath $registryPath -RegistryNativeKey $nativeKey -BackupRoot $backup -ActivePolicyPaths $policies -CiToolPath $refresh -RefreshMarkerPath $stateMarker
  Assert ($LASTEXITCODE -eq 2) 'TestOnly rejects registry-Off state after a failed refresh'

  Set-Content -LiteralPath $refresh -Encoding ascii -Value @('@echo off', ('echo refreshed>"{0}"' -f $refreshMarker), 'exit /b 0')
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath -RegistryPath $registryPath -RegistryNativeKey $nativeKey -BackupRoot $backup -ActivePolicyPaths $policies -CiToolPath $refresh -RefreshMarkerPath $stateMarker
  Assert ($LASTEXITCODE -eq 0) 'retry from registry-Off refresh failure succeeds'
  Assert (@(Get-ChildItem -LiteralPath $backup -Directory).Count -eq 1) 'retry creates no new backup'
  Assert (Test-Path $refreshMarker) 'retry refreshes active policy before reporting compliant'
  Assert (Test-Path $stateMarker) 'successful refresh writes durable compliance evidence'

  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath -TestOnly -RegistryPath $registryPath -RegistryNativeKey $nativeKey -BackupRoot $backup -ActivePolicyPaths $policies -CiToolPath $refresh -RefreshMarkerPath $stateMarker
  Assert ($LASTEXITCODE -eq 0) 'TestOnly accepts registry Off only with refresh evidence'

  Remove-Item -LiteralPath $refreshMarker
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath -RegistryPath $registryPath -RegistryNativeKey $nativeKey -BackupRoot $backup -ActivePolicyPaths $policies -CiToolPath $refresh -RefreshMarkerPath $stateMarker
  Assert ($LASTEXITCODE -eq 0) 'compliant second run succeeds'
  Assert (@(Get-ChildItem -LiteralPath $backup -Directory).Count -eq 1) 'compliant second run creates no new backup'
  Assert (Test-Path $refreshMarker) 'compliant apply run keeps active policy refreshed'
} finally {
  Remove-Item -LiteralPath $registryPath -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

if ($failures) { exit 1 }
Write-Host 'ALL TESTS PASSED'
