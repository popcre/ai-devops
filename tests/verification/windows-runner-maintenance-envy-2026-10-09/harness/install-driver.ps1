$ErrorActionPreference = 'Stop'
$head = '63e83b0772b5b8e7a071264829b163dd863c39f6'
if ($env:COMPUTERNAME -ne 'EDGE-RUNN-ENVY') { throw 'wrong host' }
# Runner idleness immediately before mutation
$w = Get-Process -Name 'Runner.Worker' -ErrorAction SilentlyContinue
if ($w) { throw 'runner busy locally (Runner.Worker present)' }
$svc = Get-CimInstance Win32_Service -Filter "Name='actions.runner.popcre-ai-devops.EDGE-RUNN-ENVY'"
if (-not $svc) { throw 'runner service missing' }
$pre = 'name=' + $svc.Name + '|state=' + $svc.State + '|startmode=' + $svc.StartMode + '|startname=' + $svc.StartName
Set-Content -LiteralPath (Join-Path $env:TEMP 'envy-service-preinstall.txt') -Value $pre
Write-Output "PREINSTALL_SERVICE=$pre"
# Task absence
& schtasks.exe /query /tn '\AiDevOps\WindowsRunnerMaintenance' 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) { throw 'maintenance task already present' }
Write-Output 'TASK_PRECONDITION=ABSENT'
# Exact reviewed checkout
$repo = 'C:\repos\ai-devops'
if (-not (Test-Path (Join-Path $repo '.git'))) {
  if (-not (Test-Path 'C:\repos')) { New-Item -ItemType Directory -Path 'C:\repos' | Out-Null }
  Write-Output 'CLONING'
  git clone https://github.com/popcre/ai-devops.git $repo 2>&1 | Select-Object -Last 2
  if ($LASTEXITCODE -ne 0) { throw 'clone failed' }
}
git -C $repo fetch origin main 2>&1 | Out-Null
git -C $repo checkout --detach $head 2>&1 | Select-Object -Last 1
if ($LASTEXITCODE -ne 0) { throw 'checkout of reviewed head failed' }
$actualHead = (git -C $repo rev-parse HEAD).Trim()
if ($actualHead -ne $head) { throw "head mismatch $actualHead" }
Write-Output "CHECKOUT_HEAD=$actualHead"
# Payload hash pinning
$expect = @{
  'bin/install-windows-runner-maintenance.ps1' = 'c2d2719570f05c82a9defbf9556263a167efc2a5d30f559240a3af985d824830'
  'bin/windows-runner-maintenance-worker.ps1' = 'c763a9aff60f92ecca16be07ae7e1d43fc57bb608490eec0a74b59fa912f10f4'
  'bin/launch-worker.bat' = '02cccf7873d2b01b27665434600b89e5aae3fa27d106215e3cc09e2bbac32d92'
  'config/windows-runner-maintenance-policy.json' = '255f91de23c6585ce9ac60444685fa1aa1ba777d99bb794a7c9c7d0b727453e7'
  'bin/qualify-windows-runner.ps1' = '172e1dac1d6de2407acef170b5f63332fb0bfa1e8db73e27b16d6ad2168ccaf7'
  'bin/invoke-windows-runner-maintenance.ps1' = 'c1ec759e3d9e7ae6c46c3325be41362715eb563a2da833e2c8781b791e6aeff4'
}
foreach ($k in $expect.Keys) {
  $h = (Get-FileHash -LiteralPath (Join-Path $repo $k) -Algorithm SHA256).Hash.ToLower()
  if ($h -ne $expect[$k]) { throw "payload hash mismatch: $k" }
}
Write-Output 'PAYLOAD_HASHES=6/6 MATCH'
# Elevated install
$installer = Join-Path $repo 'bin\install-windows-runner-maintenance.ps1'
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File $installer -Install -OperatorUser "$env:COMPUTERNAME\ahazan"
if ($LASTEXITCODE -ne 0) { throw "install failed rc=$LASTEXITCODE" }
Write-Output 'INSTALL_EXIT=0'
# Immediate post state (bounded)
$q = & schtasks.exe /query /tn '\AiDevOps\WindowsRunnerMaintenance' /fo LIST /v
$keep = $q | Select-String -Pattern 'TaskName:|Status:|Run As User:|Logon Mode:|Task To Run:|Schedule Type:|Repeat: Every|Run Level'
$keep | Select-Object -First 10 | ForEach-Object { Write-Output ('TASKPROP ' + $_.Line.Trim()) }
$svc2 = Get-CimInstance Win32_Service -Filter "Name='actions.runner.popcre-ai-devops.EDGE-RUNN-ENVY'"
$post = 'name=' + $svc2.Name + '|state=' + $svc2.State + '|startmode=' + $svc2.StartMode + '|startname=' + $svc2.StartName
Write-Output "POSTINSTALL_SERVICE=$post"
Write-Output ("SERVICE_UNCHANGED=" + ($post -eq $pre))
