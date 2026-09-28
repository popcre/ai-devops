$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$installer = Join-Path $root 'bin\install-ai-devops-windows.ps1'
$temp = Join-Path ([IO.Path]::GetTempPath()) ('ai-devops-source-gate-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $temp | Out-Null

function Assert([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw "FAIL: $Message" }
}
function Write-Receipt($Fixture) {
  $sha=(git -C $Fixture.Repo rev-parse HEAD).Trim()
  $source=Join-Path $Fixture.Repo 'bin/ai-task-gates'
  $hash=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
  $sourceBash='/' + (($source -replace '\\','/' -replace '^([A-Za-z]):','$1'))
  $homeBash='/' + (($env:USERPROFILE -replace '\\','/' -replace '^([A-Za-z]):','$1'))
  $gitBash=Join-Path $env:ProgramFiles 'Git\bin\bash.exe'
  @('#!/usr/bin/env bash','# Managed by ai-devops install-machine-tools.ps1.',"# source-sha=$sha","# source-hash=$hash",('export HOME="' + $homeBash + '"'),('exec "' + $sourceBash + '" "$@"')) | Set-Content -LiteralPath $Fixture.Launcher -Encoding ASCII
  @('@echo off','rem Managed by ai-devops install-machine-tools.ps1.',"rem source-sha=$sha","rem source-hash=$hash",('set "HOME=' + $env:USERPROFILE + '"'),('"' + $gitBash + '" "' + $sourceBash + '" %*')) | Set-Content -LiteralPath "$($Fixture.Launcher).cmd" -Encoding ASCII
}
function Write-TestAuthorization($Fixture, [string]$Target, [string]$Base, [bool]$LegacyMigration = $false, [bool]$FirstInstall = $false, [bool]$RecoverLaunchers = $false) {
  $blobs=@()
  foreach($file in @('config/task-gates.json','.ai-devops/task-gates.json')) { $blobs += (git -C $Fixture.Repo rev-parse ($Target + ':' + $file)).Trim() }
  $bytes=[Text.Encoding]::UTF8.GetBytes(($blobs -join [char]10) + [char]10)
  $policy=([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($bytes))).Replace('-','').ToLowerInvariant()
  $reviewRoot=Join-Path (Split-Path -Parent $Fixture.Launcher) 'reviewed'
  if (-not (Test-Path -LiteralPath $reviewRoot)) { git -C $Fixture.Repo worktree add --detach $reviewRoot $Target | Out-Null }
  $reviewDir=Join-Path $reviewRoot '.ai\reviews'
  New-Item -ItemType Directory -Path $reviewDir -Force | Out-Null
  Add-Content -LiteralPath (Join-Path $Fixture.Repo '.git\info\exclude') -Value '.ai/reviews/'
  $bash=Join-Path $env:ProgramFiles 'Git\bin\bash.exe'
  $sourceDigest=(& $bash (Join-Path $root 'bin\ai-review-sandbox') digest $reviewRoot).Trim()
  $identity=((& $bash (Join-Path $root 'bin\ai-review-lifecycle') identity $reviewRoot) -join "`n") | ConvertFrom-Json
  Assert ($identity.source_digest -ceq $sourceDigest) 'fixture review source identity differs'
  $report=Join-Path $reviewDir 'approved-review.md'
  $operation = if ($LegacyMigration) { 'Approved legacy-managed-launcher-refresh for this exact source and launcher.' } elseif ($FirstInstall) { 'Approved first-managed-install for this exact source.' } elseif ($RecoverLaunchers) { 'Approved partial-managed-launcher-recovery for exact present and absent launcher paths.' } else { 'Approved source update.' }
  @('# Review',('| reviewed commit | ' + [char]96 + $Target + [char]96 + ' |'),('| source digest | ' + [char]96 + $sourceDigest + [char]96 + ' |'),$operation,'## Verdict','APPROVE') | Set-Content -LiteralPath $report -Encoding ASCII
  $reportHash=(Get-FileHash -LiteralPath $report -Algorithm SHA256).Hash.ToLowerInvariant()
  $bashReport=(& $bash -c 'cygpath -u -- "$1"' 'ai-devops' $report).Trim()
  $stateDir=Join-Path (Split-Path -Parent $Fixture.Launcher) ('review-lifecycle\runs\' + $identity.repository_key + '\codex\codex')
  New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
  @{status='completed';verdict='APPROVE';stale=$false;head=$Target;source_digest=$sourceDigest;report_path=$bashReport;report_sha256=$reportHash} |
    ConvertTo-Json -Compress | Set-Content -LiteralPath (Join-Path $stateDir 'fixture.json') -Encoding ASCII
  $authDir=Join-Path (Split-Path -Parent $Fixture.Launcher) 'install-authorizations'
  New-Item -ItemType Directory -Path $authDir -Force | Out-Null
  $authPath=Join-Path $authDir "$Target.json"
  $launcherHash = if (($LegacyMigration -or $RecoverLaunchers) -and (Test-Path -LiteralPath $Fixture.Launcher)) { (Get-FileHash -LiteralPath $Fixture.Launcher -Algorithm SHA256).Hash.ToLowerInvariant() } else { '' }
  $cmdHash = if (($LegacyMigration -or $RecoverLaunchers) -and (Test-Path -LiteralPath "$($Fixture.Launcher).cmd")) { (Get-FileHash -LiteralPath "$($Fixture.Launcher).cmd" -Algorithm SHA256).Hash.ToLowerInvariant() } else { '' }
  $installedSourceHash = if ($LegacyMigration -or $FirstInstall -or $RecoverLaunchers) { (Get-FileHash -LiteralPath (Join-Path $Fixture.Repo 'bin/ai-task-gates') -Algorithm SHA256).Hash.ToLowerInvariant() } else { '' }
  $inventory=@()
  if ($RecoverLaunchers) {
    $directory=Split-Path -Parent $Fixture.Launcher
    foreach ($item in @(Get-ChildItem -LiteralPath $directory -File)) {
      $header=@(Get-Content -LiteralPath $item.FullName -TotalCount 2 -ErrorAction SilentlyContinue)
      if ($item.Name -in @('ai-task-gates','ai-task-gates.cmd') -or ($header | Where-Object { $_ -clike '*Managed by ai-devops install-machine-tools.ps1.*' })) {
        $inventory += @{name=$item.Name;sha256=(Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
      }
    }
  }
  @{schema_version=1;target_head=$Target;installed_head=$Base;installed_checkout=$Fixture.Repo;installed_launcher=$Fixture.Launcher;policy_digest=$policy;source_digest=$sourceDigest;review_report=$report;review_report_sha256=$reportHash;owner_request='Albert authorized fixture installation';legacy_migration=$LegacyMigration;first_install=$FirstInstall;recover_launchers=$RecoverLaunchers;managed_inventory=$inventory;installed_launcher_sha256=$launcherHash;installed_cmd_sha256=$cmdHash;installed_source_sha256=$installedSourceHash;issued_at='2026-09-28T00:00:00Z'} | ConvertTo-Json -Compress -Depth 4 | Set-Content -LiteralPath $authPath -Encoding ASCII
  return $authPath
}
function New-Fixture([string]$Name) {
  $remote = Join-Path $temp "$Name.git"
  $repo = Join-Path $temp $Name
  git init --bare $remote | Out-Null
  git init -b main $repo | Out-Null
  git -C $repo config user.name test
  git -C $repo config user.email test@example.invalid
  'fixture' | Set-Content (Join-Path $repo 'README.md')
  New-Item -ItemType Directory -Path (Join-Path $repo '.ai-devops') | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $repo 'bin') | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $repo 'config') | Out-Null
  'initial gate' | Set-Content (Join-Path $repo 'bin/ai-task-gates')
  '{"paths":[{"glob":"bin/ai-task-gates","class":"reviewer-safety"},{"glob":"bin/install-ai-devops-windows.ps1","class":"reviewer-safety"},{"glob":"bin/install-machine-tools.ps1","class":"reviewer-safety"},{"glob":"bin/bootstrap-windows-dev.ps1","class":"reviewer-safety"}]}' | Set-Content (Join-Path $repo '.ai-devops/task-gates.json')
  '{"rules":[{"match":"*/ai-devops","paths":[{"glob":"bin/ai-grok-review","class":"reviewer-safety"},{"glob":"config/task-gates.json","class":"reviewer-safety"}]}]}' | Set-Content (Join-Path $repo 'config/task-gates.json')
  git -C $repo add README.md .ai-devops/task-gates.json config/task-gates.json bin/ai-task-gates
  git -C $repo commit -m initial | Out-Null
  git -C $repo remote add origin $remote
  git -C $repo push -u origin main | Out-Null
  $launcherDir=Join-Path $temp "$Name-launchers"
  New-Item -ItemType Directory -Path $launcherDir | Out-Null
  $fixture=@{ Repo=$repo; Remote=$remote; Launcher=(Join-Path $launcherDir 'ai-task-gates') }
  Write-Receipt $fixture
  return $fixture
}
function Invoke-Gate($Fixture, [switch]$ExpectFailure, [string]$ExpectedHead = '', [string]$FailureContains = '') {
  $oldMode=$env:AI_DEVOPS_INSTALL_TEST_MODE; $oldRemote=$env:AI_DEVOPS_TEST_EXPECTED_REMOTE; $oldLauncher=$env:AI_DEVOPS_TEST_LAUNCHER
  try {
    $env:AI_DEVOPS_INSTALL_TEST_MODE='1'; $env:AI_DEVOPS_TEST_EXPECTED_REMOTE=$Fixture.Remote; $env:AI_DEVOPS_TEST_LAUNCHER=$Fixture.Launcher
    $failed=$false
    try { & $installer -RepoPath $Fixture.Repo -SkipGitInstall -SourceGateOnly -ExpectedHead $ExpectedHead *>$null } catch { $failed=$true; $failureText=$_.Exception.Message; if (-not $ExpectFailure) { Write-Host "Unexpected source-gate error: $failureText" } }
    if ($ExpectFailure) { Assert $failed 'hostile source state passed' } else { Assert (-not $failed) 'valid source state failed' }
    if ($FailureContains) { Assert ($failureText.Contains($FailureContains)) "unexpected refusal: $failureText" }
  } finally { $env:AI_DEVOPS_INSTALL_TEST_MODE=$oldMode; $env:AI_DEVOPS_TEST_EXPECTED_REMOTE=$oldRemote; $env:AI_DEVOPS_TEST_LAUNCHER=$oldLauncher }
}

try {
  $clean=New-Fixture clean; Invoke-Gate $clean

  $dirty=New-Fixture dirty; 'dirty' | Add-Content (Join-Path $dirty.Repo 'README.md'); Invoke-Gate $dirty -ExpectFailure

  $branch=New-Fixture branch; git -C $branch.Repo checkout -b feature | Out-Null; Invoke-Gate $branch -ExpectFailure

  $wrong=New-Fixture wrong; $env:AI_DEVOPS_INSTALL_TEST_MODE='1'; $env:AI_DEVOPS_TEST_EXPECTED_REMOTE=(Join-Path $temp 'different.git')
  $failed=$false; try { & $installer -RepoPath $wrong.Repo -SkipGitInstall -SourceGateOnly *>$null } catch { $failed=$true }
  Assert $failed 'wrong remote passed'

  $fetch=New-Fixture fetch; Move-Item -LiteralPath $fetch.Remote -Destination "$($fetch.Remote).offline"
  Invoke-Gate $fetch -ExpectFailure

  $ahead=New-Fixture ahead; 'ahead' | Add-Content (Join-Path $ahead.Repo 'README.md'); git -C $ahead.Repo add README.md; git -C $ahead.Repo commit -m ahead | Out-Null
  Invoke-Gate $ahead -ExpectFailure

  $race=New-Fixture race
  $approved=(git -C $race.Repo rev-parse HEAD).Trim()
  'later release' | Add-Content (Join-Path $race.Repo 'README.md')
  git -C $race.Repo add README.md
  git -C $race.Repo commit -m later | Out-Null
  git -C $race.Repo push origin main | Out-Null
  $later=(git -C $race.Repo rev-parse HEAD).Trim()
  git -C $race.Repo reset --hard $approved | Out-Null
  Invoke-Gate $race -ExpectedHead $approved -ExpectFailure
  Assert ((git -C $race.Repo rev-parse HEAD).Trim() -eq $approved) 'moved origin/main was installed despite expected-head guard'
  Invoke-Gate $race -ExpectedHead $later
  Assert ((git -C $race.Repo rev-parse HEAD).Trim() -eq $later) 'exact expected target did not install'

  $ordinary=New-Fixture ordinary
  $ordinaryBefore=(git -C $ordinary.Repo rev-parse HEAD).Trim()
  'ordinary release' | Add-Content (Join-Path $ordinary.Repo 'README.md')
  git -C $ordinary.Repo add README.md
  git -C $ordinary.Repo commit -m ordinary | Out-Null
  git -C $ordinary.Repo push origin main | Out-Null
  $ordinaryHead=(git -C $ordinary.Repo rev-parse HEAD).Trim()
  git -C $ordinary.Repo reset --hard $ordinaryBefore | Out-Null
  Invoke-Gate $ordinary
  Assert ((git -C $ordinary.Repo rev-parse HEAD).Trim() -eq $ordinaryHead) 'ordinary unpinned update failed'

  $installerOnly=New-Fixture installer-only
  'old installer' | Set-Content (Join-Path $installerOnly.Repo 'bin/install-ai-devops-windows.ps1')
  git -C $installerOnly.Repo add bin/install-ai-devops-windows.ps1
  git -C $installerOnly.Repo commit -m old-installer | Out-Null
  git -C $installerOnly.Repo push origin main | Out-Null
  $installerBase=(git -C $installerOnly.Repo rev-parse HEAD).Trim()
  Write-Receipt $installerOnly
  'changed installer gate' | Set-Content (Join-Path $installerOnly.Repo 'bin/install-ai-devops-windows.ps1')
  git -C $installerOnly.Repo add bin/install-ai-devops-windows.ps1
  git -C $installerOnly.Repo commit -m changed-installer | Out-Null
  git -C $installerOnly.Repo push origin main | Out-Null
  git -C $installerOnly.Repo reset --hard $installerBase | Out-Null
  Invoke-Gate $installerOnly -ExpectFailure -FailureContains 'Reviewer safety or legacy update'

  $sequence=New-Fixture ordinary-then-protected
  'ordinary release' | Add-Content (Join-Path $sequence.Repo 'README.md')
  git -C $sequence.Repo add README.md
  git -C $sequence.Repo commit -m ordinary | Out-Null
  git -C $sequence.Repo push origin main | Out-Null
  Invoke-Gate $sequence
  $sequenceBase=(git -C $sequence.Repo rev-parse HEAD).Trim()
  Write-Receipt $sequence # the completed full installer refreshes this receipt
  'protected release' | Set-Content (Join-Path $sequence.Repo 'bin/ai-task-gates')
  git -C $sequence.Repo add bin/ai-task-gates
  git -C $sequence.Repo commit -m protected | Out-Null
  git -C $sequence.Repo push origin main | Out-Null
  $sequenceTarget=(git -C $sequence.Repo rev-parse HEAD).Trim()
  git -C $sequence.Repo reset --hard $sequenceBase | Out-Null
  Write-TestAuthorization $sequence $sequenceTarget $sequenceBase | Out-Null
  Invoke-Gate $sequence -ExpectedHead $sequenceTarget
  Assert ((git -C $sequence.Repo rev-parse HEAD).Trim() -eq $sequenceTarget) 'ordinary then protected update failed'

  $protected=New-Fixture protected
  $before=(git -C $protected.Repo rev-parse HEAD).Trim()
  'changed gate' | Set-Content (Join-Path $protected.Repo 'bin/ai-task-gates')
  git -C $protected.Repo add bin/ai-task-gates
  git -C $protected.Repo commit -m protected | Out-Null
  git -C $protected.Repo push origin main | Out-Null
  $protectedHead=(git -C $protected.Repo rev-parse HEAD).Trim()
  git -C $protected.Repo reset --hard $before | Out-Null
  Invoke-Gate $protected -ExpectFailure
  Assert ((git -C $protected.Repo rev-parse HEAD).Trim() -eq $before) 'unpinned reviewer safety update changed installed source'
  Invoke-Gate $protected -ExpectedHead $protectedHead -ExpectFailure -FailureContains 'authorization is missing'
  Write-TestAuthorization $protected $protectedHead $before | Out-Null
  Invoke-Gate $protected -ExpectedHead $protectedHead
  Assert ((git -C $protected.Repo rev-parse HEAD).Trim() -eq $protectedHead) 'pinned reviewer safety update failed'
  $pending=Join-Path (Split-Path -Parent $protected.Launcher) ('install-authorizations\' + $protectedHead + '.json.consuming')
  Assert (Test-Path -LiteralPath $pending) 'source-only gate lost retryable authorization before full install'
  # Two independent installer processes cannot both enter the same pending
  # authority transaction. The first holds the real machine-wide mutex in a
  # local-origin fixture; the second must refuse before touching the receipt.
  $oldMode=$env:AI_DEVOPS_INSTALL_TEST_MODE; $oldRemote=$env:AI_DEVOPS_TEST_EXPECTED_REMOTE
  $oldLauncher=$env:AI_DEVOPS_TEST_LAUNCHER; $oldReady=$env:AI_DEVOPS_TEST_LOCK_READY
  $ready=Join-Path $temp 'first-installer-lock-ready'
  $firstOut=Join-Path $temp 'first-installer.out'; $firstErr=Join-Path $temp 'first-installer.err'
  $first=$null
  try {
    $env:AI_DEVOPS_INSTALL_TEST_MODE='1'; $env:AI_DEVOPS_TEST_EXPECTED_REMOTE=$protected.Remote
    $env:AI_DEVOPS_TEST_LAUNCHER=$protected.Launcher; $env:AI_DEVOPS_TEST_LOCK_READY=$ready
    $first=Start-Process pwsh -PassThru -RedirectStandardOutput $firstOut -RedirectStandardError $firstErr `
      -ArgumentList @('-NoProfile','-NonInteractive','-File',$installer,
        '-RepoPath',$protected.Repo,'-LauncherGateOnly','-ExpectedHead',$protectedHead)
    for ($attempt=0; $attempt -lt 80 -and -not (Test-Path -LiteralPath $ready); $attempt++) { Start-Sleep -Milliseconds 100 }
    Assert (Test-Path -LiteralPath $ready) 'first installer did not acquire the lock'
    Remove-Item Env:AI_DEVOPS_TEST_LOCK_READY
    $secondOutput=(& pwsh -NoProfile -NonInteractive -File $installer `
      -RepoPath $protected.Repo -LauncherGateOnly -ExpectedHead $protectedHead 2>&1 | Out-String)
    $secondCode=$LASTEXITCODE
    Assert ($secondCode -ne 0 -and $secondOutput.Contains('Another toolkit installation holds the machine-wide install lock')) `
      'second installer reused a pending authority during the first installer run'
    $first.WaitForExit()
    Assert ($first.ExitCode -eq 0) ('first installer failed: ' + (Get-Content -Raw -LiteralPath $firstErr))
    Assert (Test-Path -LiteralPath $pending) 'successful source gate lost retryable pending authorization'
  } finally {
    if ($first -and -not $first.HasExited) { $first.Kill(); $first.WaitForExit() }
    $env:AI_DEVOPS_INSTALL_TEST_MODE=$oldMode; $env:AI_DEVOPS_TEST_EXPECTED_REMOTE=$oldRemote
    $env:AI_DEVOPS_TEST_LAUNCHER=$oldLauncher; $env:AI_DEVOPS_TEST_LOCK_READY=$oldReady
  }
  Invoke-Gate $protected -ExpectedHead $protectedHead -ExpectFailure -FailureContains 'pending full installation'
  Remove-Item -LiteralPath $pending
  Invoke-Gate $protected -ExpectedHead $protectedHead -ExpectFailure -FailureContains 'authorization is missing'

  $preadvanced=New-Fixture preadvanced
  'pre-advanced gate' | Set-Content (Join-Path $preadvanced.Repo 'bin/ai-task-gates')
  git -C $preadvanced.Repo add bin/ai-task-gates
  git -C $preadvanced.Repo commit -m preadvanced | Out-Null
  git -C $preadvanced.Repo push origin main | Out-Null
  $preadvancedHead=(git -C $preadvanced.Repo rev-parse HEAD).Trim()
  Invoke-Gate $preadvanced -ExpectFailure
  Write-TestAuthorization $preadvanced $preadvancedHead (Get-Content -LiteralPath $preadvanced.Launcher)[2].Substring(13) | Out-Null
  Invoke-Gate $preadvanced -ExpectedHead $preadvancedHead

  $stale=New-Fixture stale-authorization
  $staleBase=(git -C $stale.Repo rev-parse HEAD).Trim()
  'stale target gate' | Set-Content (Join-Path $stale.Repo 'bin/ai-task-gates')
  git -C $stale.Repo add bin/ai-task-gates
  git -C $stale.Repo commit -m stale-target | Out-Null
  git -C $stale.Repo push origin main | Out-Null
  $staleTarget=(git -C $stale.Repo rev-parse HEAD).Trim()
  git -C $stale.Repo reset --hard $staleBase | Out-Null
  $staleAuth=Write-TestAuthorization $stale $staleTarget $staleBase
  $row=Get-Content -Raw -LiteralPath $staleAuth | ConvertFrom-Json
  $row.policy_digest='0' * 64
  $row | ConvertTo-Json -Compress | Set-Content -LiteralPath $staleAuth -Encoding ASCII
  Invoke-Gate $stale -ExpectedHead $staleTarget -ExpectFailure -FailureContains 'does not match installed source, target, or policy'
  Assert ((git -C $stale.Repo rev-parse HEAD).Trim() -eq $staleBase) 'stale authorization advanced checkout'
  $staleAuth=Write-TestAuthorization $stale $staleTarget $staleBase
  $staleRow=Get-Content -Raw -LiteralPath $staleAuth | ConvertFrom-Json
  Add-Content -LiteralPath $staleRow.review_report -Value 'tampered report'
  Invoke-Gate $stale -ExpectedHead $staleTarget -ExpectFailure -FailureContains 'report is missing or changed'

  $forged=New-Fixture forged-review
  $forgedBase=(git -C $forged.Repo rev-parse HEAD).Trim()
  'forged gate' | Set-Content (Join-Path $forged.Repo 'bin/ai-task-gates')
  git -C $forged.Repo add bin/ai-task-gates
  git -C $forged.Repo commit -m forged-target | Out-Null
  git -C $forged.Repo push origin main | Out-Null
  $forgedTarget=(git -C $forged.Repo rev-parse HEAD).Trim()
  git -C $forged.Repo reset --hard $forgedBase | Out-Null
  $forgedAuth=Write-TestAuthorization $forged $forgedTarget $forgedBase
  $forgedRow=Get-Content -Raw -LiteralPath $forgedAuth | ConvertFrom-Json
  $forgedRow.source_digest='b' * 64
  (Get-Content -LiteralPath $forgedRow.review_report) -replace 'source digest.*', ('source digest | ' + [char]96 + $forgedRow.source_digest + [char]96 + ' |') |
    Set-Content -LiteralPath $forgedRow.review_report -Encoding ASCII
  $forgedRow.review_report_sha256=(Get-FileHash -LiteralPath $forgedRow.review_report -Algorithm SHA256).Hash.ToLowerInvariant()
  $forgedRow | ConvertTo-Json -Compress | Set-Content -LiteralPath $forgedAuth -Encoding ASCII
  Invoke-Gate $forged -ExpectedHead $forgedTarget -ExpectFailure -FailureContains 'source digest or commit differs'
  $forgedAuth=Write-TestAuthorization $forged $forgedTarget $forgedBase
  $forgedLife=Get-ChildItem -LiteralPath (Join-Path (Split-Path -Parent $forged.Launcher) 'review-lifecycle') -Filter fixture.json -Recurse | Select-Object -First 1
  Remove-Item -LiteralPath $forgedLife.FullName
  Invoke-Gate $forged -ExpectedHead $forgedTarget -ExpectFailure -FailureContains 'no matching completed lifecycle'

  $provider=New-Fixture provider
  $providerBefore=(git -C $provider.Repo rev-parse HEAD).Trim()
  'changed provider' | Set-Content (Join-Path $provider.Repo 'bin/ai-grok-review')
  git -C $provider.Repo add bin/ai-grok-review
  git -C $provider.Repo commit -m provider | Out-Null
  git -C $provider.Repo push origin main | Out-Null
  git -C $provider.Repo reset --hard $providerBefore | Out-Null
  Invoke-Gate $provider -ExpectFailure -FailureContains 'Reviewer safety or legacy update'
  Assert ((git -C $provider.Repo rev-parse HEAD).Trim() -eq $providerBefore) 'central reviewer rule did not stop provider update'

  $declaration=New-Fixture declaration
  $declarationBefore=(git -C $declaration.Repo rev-parse HEAD).Trim()
  '{"rules":[]}' | Set-Content (Join-Path $declaration.Repo 'config/task-gates.json')
  git -C $declaration.Repo add config/task-gates.json
  git -C $declaration.Repo commit -m narrow-policy | Out-Null
  git -C $declaration.Repo push origin main | Out-Null
  git -C $declaration.Repo reset --hard $declarationBefore | Out-Null
  Invoke-Gate $declaration -ExpectFailure -FailureContains 'Reviewer safety or legacy update'
  Assert ((git -C $declaration.Repo rev-parse HEAD).Trim() -eq $declarationBefore) 'central reviewer declaration change advanced source'

  $tampered=New-Fixture tampered
  (Get-Content -LiteralPath $tampered.Launcher) -replace '^# source-hash=', '# source-hash=0' | Set-Content -LiteralPath $tampered.Launcher -Encoding ASCII
  Invoke-Gate $tampered -ExpectFailure

  $missing=New-Fixture missing
  Remove-Item -LiteralPath $missing.Launcher, "$($missing.Launcher).cmd"
  '# Managed by ai-devops install-machine-tools.ps1.' | Set-Content -LiteralPath (Join-Path (Split-Path -Parent $missing.Launcher) 'ai-review')
  Invoke-Gate $missing -ExpectFailure

  $retired=New-Fixture retired-managed
  Remove-Item -LiteralPath $retired.Launcher, "$($retired.Launcher).cmd"
  $retiredLauncher=Join-Path (Split-Path -Parent $retired.Launcher) 'retired-tool'
  '# Managed by ai-devops install-machine-tools.ps1.' | Set-Content -LiteralPath $retiredLauncher
  $retiredHead=(git -C $retired.Repo rev-parse HEAD).Trim()
  Invoke-Gate $retired -ExpectedHead $retiredHead -ExpectFailure -FailureContains 'authorization is missing'
  Write-TestAuthorization $retired $retiredHead $retiredHead $false $false $true | Out-Null
  Invoke-Gate $retired -ExpectedHead $retiredHead

  $changedSibling=New-Fixture changed-sibling
  Remove-Item -LiteralPath $changedSibling.Launcher, "$($changedSibling.Launcher).cmd"
  $sibling=Join-Path (Split-Path -Parent $changedSibling.Launcher) 'retired-tool'
  '# Managed by ai-devops install-machine-tools.ps1.' | Set-Content -LiteralPath $sibling
  $changedSiblingHead=(git -C $changedSibling.Repo rev-parse HEAD).Trim()
  Write-TestAuthorization $changedSibling $changedSiblingHead $changedSiblingHead $false $false $true | Out-Null
  Add-Content -LiteralPath $sibling -Value 'changed after review'
  Invoke-Gate $changedSibling -ExpectedHead $changedSiblingHead -ExpectFailure -FailureContains 'inventory changed after reviewed recovery'

  $first=New-Fixture first-install
  Remove-Item -LiteralPath $first.Launcher, "$($first.Launcher).cmd"
  $firstHead=(git -C $first.Repo rev-parse HEAD).Trim()
  Invoke-Gate $first -ExpectedHead $firstHead -ExpectFailure -FailureContains 'authorization is missing'
  Write-TestAuthorization $first $firstHead $firstHead $false $true | Out-Null
  Invoke-Gate $first -ExpectedHead $firstHead

  $preadvancedMissing=New-Fixture preadvanced-missing
  'reviewer change' | Set-Content (Join-Path $preadvancedMissing.Repo 'bin/ai-task-gates')
  git -C $preadvancedMissing.Repo add bin/ai-task-gates
  git -C $preadvancedMissing.Repo commit -m early-protected-pull | Out-Null
  git -C $preadvancedMissing.Repo push origin main | Out-Null
  Remove-Item -LiteralPath $preadvancedMissing.Launcher, "$($preadvancedMissing.Launcher).cmd"
  Invoke-Gate $preadvancedMissing -ExpectedHead (git -C $preadvancedMissing.Repo rev-parse HEAD).Trim() -ExpectFailure -FailureContains 'authorization is missing'

  $partial=New-Fixture partial
  Remove-Item -LiteralPath "$($partial.Launcher).cmd"
  $partialHead=(git -C $partial.Repo rev-parse HEAD).Trim()
  Invoke-Gate $partial -ExpectedHead $partialHead -ExpectFailure -FailureContains 'authorization is missing'
  Write-TestAuthorization $partial $partialHead $partialHead $false $false $true | Out-Null
  Invoke-Gate $partial -ExpectedHead $partialHead

  $cmdOnly=New-Fixture command-only
  Remove-Item -LiteralPath $cmdOnly.Launcher
  $cmdOnlyHead=(git -C $cmdOnly.Repo rev-parse HEAD).Trim()
  Write-TestAuthorization $cmdOnly $cmdOnlyHead $cmdOnlyHead $false $false $true | Out-Null
  Invoke-Gate $cmdOnly -ExpectedHead $cmdOnlyHead

  $changedPartial=New-Fixture changed-partial
  Remove-Item -LiteralPath "$($changedPartial.Launcher).cmd"
  $changedPartialHead=(git -C $changedPartial.Repo rev-parse HEAD).Trim()
  Write-TestAuthorization $changedPartial $changedPartialHead $changedPartialHead $false $false $true | Out-Null
  Add-Content -LiteralPath $changedPartial.Launcher -Value '# changed after approval'
  Invoke-Gate $changedPartial -ExpectedHead $changedPartialHead -ExpectFailure -FailureContains 'inventory changed after reviewed recovery'

  $filledPartial=New-Fixture filled-partial
  Remove-Item -LiteralPath "$($filledPartial.Launcher).cmd"
  $filledPartialHead=(git -C $filledPartial.Repo rev-parse HEAD).Trim()
  Write-TestAuthorization $filledPartial $filledPartialHead $filledPartialHead $false $false $true | Out-Null
  'unexpected' | Set-Content -LiteralPath "$($filledPartial.Launcher).cmd"
  Invoke-Gate $filledPartial -ExpectedHead $filledPartialHead -ExpectFailure

  $completedPair=New-Fixture completed-pair-after-approval
  Remove-Item -LiteralPath "$($completedPair.Launcher).cmd"
  $completedPairHead=(git -C $completedPair.Repo rev-parse HEAD).Trim()
  Write-TestAuthorization $completedPair $completedPairHead $completedPairHead $false $false $true | Out-Null
  Write-Receipt $completedPair
  Invoke-Gate $completedPair -ExpectedHead $completedPairHead -ExpectFailure -FailureContains 'does not match installed source, target, or policy'

  $legacy=New-Fixture legacy
  $bashLines=@(Get-Content -LiteralPath $legacy.Launcher)
  $cmdLines=@(Get-Content -LiteralPath "$($legacy.Launcher).cmd")
  @($bashLines[0],$bashLines[1],$bashLines[4],$bashLines[5]) | Set-Content -LiteralPath $legacy.Launcher -Encoding ASCII
  @($cmdLines[0],$cmdLines[1],$cmdLines[4],$cmdLines[5]) | Set-Content -LiteralPath "$($legacy.Launcher).cmd" -Encoding ASCII
  Invoke-Gate $legacy -ExpectFailure
  Write-TestAuthorization $legacy (git -C $legacy.Repo rev-parse HEAD).Trim() (git -C $legacy.Repo rev-parse HEAD).Trim() $true | Out-Null
  Invoke-Gate $legacy -ExpectedHead (git -C $legacy.Repo rev-parse HEAD).Trim()

  $stamp=New-Fixture direct-stamp
  Copy-Item -LiteralPath $installer -Destination (Join-Path $stamp.Repo 'bin\install-ai-devops-windows.ps1')
  Copy-Item -LiteralPath (Join-Path $root 'bin\install-machine-tools.ps1') -Destination (Join-Path $stamp.Repo 'bin\install-machine-tools.ps1')
  Copy-Item -LiteralPath (Join-Path $root 'bin\repo-identity.ps1') -Destination (Join-Path $stamp.Repo 'bin\repo-identity.ps1')
  Copy-Item -LiteralPath (Join-Path $root 'bin\ai-review-lifecycle') -Destination (Join-Path $stamp.Repo 'bin\ai-review-lifecycle')
  Copy-Item -LiteralPath (Join-Path $root 'bin\ai-review-sandbox') -Destination (Join-Path $stamp.Repo 'bin\ai-review-sandbox')
  New-Item -ItemType Directory -Force -Path (Join-Path $stamp.Repo 'tools\lib') | Out-Null
  Copy-Item -LiteralPath (Join-Path $root 'tools\lib\task-gates.sh') -Destination (Join-Path $stamp.Repo 'tools\lib\task-gates.sh')
  'fixture helper' | Set-Content (Join-Path $stamp.Repo 'bin\ai-helper') -Encoding ASCII
  @("ai-task-gates`tbin/ai-task-gates`tbash+cmd", "ai-helper`tbin/ai-helper`tbash+cmd") |
    Set-Content (Join-Path $stamp.Repo 'config\machine-tools.tsv') -Encoding ASCII
  git -C $stamp.Repo add bin config/machine-tools.tsv tools/lib/task-gates.sh
  git -C $stamp.Repo commit -m guarded-stamp-base | Out-Null
  git -C $stamp.Repo push origin main | Out-Null
  $stampBase=(git -C $stamp.Repo rev-parse HEAD).Trim()
  Write-Receipt $stamp
  $oldLauncherHash=(Get-FileHash -LiteralPath $stamp.Launcher -Algorithm SHA256).Hash
  $oldCmdHash=(Get-FileHash -LiteralPath "$($stamp.Launcher).cmd" -Algorithm SHA256).Hash
  'early pulled reviewer gate' | Set-Content (Join-Path $stamp.Repo 'bin\ai-task-gates')
  git -C $stamp.Repo add bin/ai-task-gates
  git -C $stamp.Repo commit -m early-pull | Out-Null
  git -C $stamp.Repo push origin main | Out-Null
  $oldMode=$env:AI_DEVOPS_INSTALL_TEST_MODE; $oldRemote=$env:AI_DEVOPS_TEST_EXPECTED_REMOTE; $oldLauncher=$env:AI_DEVOPS_TEST_LAUNCHER
  try {
    $env:AI_DEVOPS_INSTALL_TEST_MODE='1'; $env:AI_DEVOPS_TEST_EXPECTED_REMOTE=$stamp.Remote; $env:AI_DEVOPS_TEST_LAUNCHER=$stamp.Launcher
    $stampFailed=$false
    try { & (Join-Path $stamp.Repo 'bin\install-machine-tools.ps1') -RepoPath $stamp.Repo -CatalogPath (Join-Path $stamp.Repo 'config\machine-tools.tsv') -UserProfilePath (Split-Path -Parent $stamp.Launcher) *>$null } catch { $stampFailed=$true; $stampFailure=$_.Exception.Message }
    Assert $stampFailed 'direct machine-tools stamped an early-pulled protected checkout'
    Assert ($stampFailure -like '*source gate refused*') "direct stamp failed for another reason: $stampFailure"
    Assert ((Get-FileHash -LiteralPath $stamp.Launcher -Algorithm SHA256).Hash -eq $oldLauncherHash) 'direct stamp changed launcher before authorization'
    $stampTarget=(git -C $stamp.Repo rev-parse HEAD).Trim()
    $stampIssued=Write-TestAuthorization $stamp $stampTarget $stampBase
    $stampStatus=(@(git -C $stamp.Repo status --porcelain=v1 --untracked-files=all) -join '; ')
    Assert (-not $stampStatus) "direct-stamp fixture dirty before approved refresh: $stampStatus"
    $userPathBefore=[Environment]::GetEnvironmentVariable('PATH', 'User')
    $fixturePathStore=Join-Path (Split-Path -Parent $stamp.Launcher) '.user-path-fixture'
    $fixturePathBefore='C:\Existing;D:\Custom'
    [IO.File]::WriteAllText($fixturePathStore,$fixturePathBefore)
    $partialCatalog=Join-Path (Split-Path -Parent $stamp.Launcher) 'partial-catalog.tsv'
    "ai-task-gates`tbin/ai-task-gates`tbash+cmd" | Set-Content -LiteralPath $partialCatalog -Encoding ASCII
    $catalogFailed=$false
    try { & (Join-Path $stamp.Repo 'bin\install-machine-tools.ps1') -RepoPath $stamp.Repo `
      -CatalogPath $partialCatalog -UserProfilePath $env:USERPROFILE *>$null } catch { $catalogFailed=$true }
    Assert $catalogFailed 'direct stamper accepted a partial catalog'
    Assert ((Get-FileHash -LiteralPath $stamp.Launcher -Algorithm SHA256).Hash -eq $oldLauncherHash) `
      'partial catalog changed the gate launcher'
    $stampPending=Join-Path (Split-Path -Parent $stamp.Launcher) ('install-authorizations\' + $stampTarget + '.json.consuming')
    Assert (Test-Path -LiteralPath $stampIssued -PathType Leaf) 'partial catalog consumed authority'
    $env:AI_DEVOPS_TEST_FAIL_AFTER_GATE='1'
    $injectedFailed=$false
    try { & (Join-Path $stamp.Repo 'bin\install-machine-tools.ps1') -RepoPath $stamp.Repo `
      -CatalogPath (Join-Path $stamp.Repo 'config\machine-tools.tsv') -UserProfilePath $env:USERPROFILE *>$null } `
      catch { $injectedFailed=$true; $injectedMessage=$_.Exception.Message }
    $env:AI_DEVOPS_TEST_FAIL_AFTER_GATE=$null
    Assert $injectedFailed 'injected failure after gate launcher did not stop stamping'
    Assert ($injectedMessage -like '*exact prior launchers were restored*') "injected failure did not roll back: $injectedMessage"
    Assert ((Get-FileHash -LiteralPath $stamp.Launcher -Algorithm SHA256).Hash -eq $oldLauncherHash) `
      'injected failure changed gate launcher receipt'
    Assert ((Get-FileHash -LiteralPath "$($stamp.Launcher).cmd" -Algorithm SHA256).Hash -eq $oldCmdHash) `
      'injected failure changed gate command receipt'
    Assert (Test-Path -LiteralPath $stampPending -PathType Leaf) 'injected failure consumed pending authority'
    $stampTransaction=Join-Path (Split-Path -Parent $stamp.Launcher) ('launcher-transactions\' + $stampTarget + '.json')
    $env:AI_DEVOPS_TEST_HARD_CRASH_AFTER_GATE='1'
    $crashed=Start-Process -FilePath (Get-Command pwsh).Source -ArgumentList @('-NoProfile','-File',
      (Join-Path $stamp.Repo 'bin\install-machine-tools.ps1'),'-RepoPath',$stamp.Repo,
      '-CatalogPath',(Join-Path $stamp.Repo 'config\machine-tools.tsv'),'-UserProfilePath',$env:USERPROFILE) `
      -PassThru -Wait -WindowStyle Hidden
    $env:AI_DEVOPS_TEST_HARD_CRASH_AFTER_GATE=$null
    Assert ($crashed.ExitCode -ne 0) 'hard-crash launcher fixture exited successfully'
    Assert (Test-Path -LiteralPath $stampTransaction -PathType Leaf) 'hard crash did not leave recovery transaction'
    Assert (Test-Path -LiteralPath $stampPending -PathType Leaf) 'hard crash consumed pending authority'
    Assert ((Get-FileHash -LiteralPath $stamp.Launcher -Algorithm SHA256).Hash -ne $oldLauncherHash) `
      'hard crash did not publish the atomic gate launcher before termination'
    $env:AI_DEVOPS_TEST_FAIL_AFTER_RECOVERY='1'
    $recoveryStopped=$false
    try { & (Join-Path $stamp.Repo 'bin\install-machine-tools.ps1') -RepoPath $stamp.Repo `
      -CatalogPath (Join-Path $stamp.Repo 'config\machine-tools.tsv') -UserProfilePath $env:USERPROFILE *>$null } `
      catch { $recoveryStopped=$true }
    $env:AI_DEVOPS_TEST_FAIL_AFTER_RECOVERY=$null
    Assert $recoveryStopped 'fixture did not stop after interrupted launcher recovery'
    Assert ([IO.File]::ReadAllText($fixturePathStore) -ceq $fixturePathBefore) 'launcher recovery changed prior PATH'
    Assert ((Get-FileHash -LiteralPath $stamp.Launcher -Algorithm SHA256).Hash -eq $oldLauncherHash) `
      'hard-crash launcher recovery did not restore old gate bytes'
    $env:AI_DEVOPS_TEST_HARD_CRASH_AFTER_PATH='1'
    $pathCrashed=Start-Process -FilePath (Get-Command pwsh).Source -ArgumentList @('-NoProfile','-File',
      (Join-Path $stamp.Repo 'bin\install-machine-tools.ps1'),'-RepoPath',$stamp.Repo,
      '-CatalogPath',(Join-Path $stamp.Repo 'config\machine-tools.tsv'),'-UserProfilePath',$env:USERPROFILE) `
      -PassThru -Wait -WindowStyle Hidden
    $env:AI_DEVOPS_TEST_HARD_CRASH_AFTER_PATH=$null
    Assert ($pathCrashed.ExitCode -ne 0) 'hard-crash PATH fixture exited successfully'
    Assert (Test-Path -LiteralPath $stampTransaction -PathType Leaf) 'PATH crash lost recovery transaction'
    Assert (Test-Path -LiteralPath $stampPending -PathType Leaf) 'PATH crash consumed authority'
    $fixturePathAfter=[IO.File]::ReadAllText($fixturePathStore)
    Assert ($fixturePathAfter -cne $fixturePathBefore) 'PATH crash did not publish expected test PATH'
    [IO.File]::WriteAllText($fixturePathStore,'C:\ConcurrentUserEdit')
    $concurrentFailed=$false
    try { & (Join-Path $stamp.Repo 'bin\install-machine-tools.ps1') -RepoPath $stamp.Repo `
      -CatalogPath (Join-Path $stamp.Repo 'config\machine-tools.tsv') -UserProfilePath $env:USERPROFILE *>$null } `
      catch { $concurrentFailed=($_.Exception.Message -like '*PATH changed outside*') }
    Assert $concurrentFailed 'recovery overwrote an unrelated User PATH edit'
    [IO.File]::WriteAllText($fixturePathStore,$fixturePathAfter)
    $env:AI_DEVOPS_TEST_FAIL_AFTER_RECOVERY='1'
    $pathRecoveryStopped=$false
    try { & (Join-Path $stamp.Repo 'bin\install-machine-tools.ps1') -RepoPath $stamp.Repo `
      -CatalogPath (Join-Path $stamp.Repo 'config\machine-tools.tsv') -UserProfilePath $env:USERPROFILE *>$null } `
      catch { $pathRecoveryStopped=$true }
    $env:AI_DEVOPS_TEST_FAIL_AFTER_RECOVERY=$null
    Assert $pathRecoveryStopped 'PATH recovery fixture did not stop after rollback'
    Assert ([IO.File]::ReadAllText($fixturePathStore) -ceq $fixturePathBefore) 'PATH crash recovery did not restore exact prior value'
    Assert ((Get-FileHash -LiteralPath $stamp.Launcher -Algorithm SHA256).Hash -eq $oldLauncherHash) `
      'PATH crash recovery did not restore old gate launcher'
    & (Join-Path $stamp.Repo 'bin\install-machine-tools.ps1') -RepoPath $stamp.Repo `
      -CatalogPath (Join-Path $stamp.Repo 'config\machine-tools.tsv') -UserProfilePath $env:USERPROFILE *>$null
    Assert ([Environment]::GetEnvironmentVariable('PATH', 'User') -ceq $userPathBefore) `
      'disposable launcher fixture changed the real User PATH'
    Assert ((Get-Content -LiteralPath $stamp.Launcher)[2] -ceq "# source-sha=$stampTarget") `
      'locked direct launcher refresh did not stamp the approved source'
    Assert (-not (Test-Path -LiteralPath $stampPending)) 'successful locked launcher refresh did not consume authority'
    Assert (-not (Test-Path -LiteralPath $stampTransaction)) `
      'successful retry left a pending launcher transaction'
    Assert ([IO.File]::ReadAllText($fixturePathStore) -ceq $fixturePathAfter) `
      'same-target retry did not publish intended test User PATH'
    Remove-Item -LiteralPath $fixturePathStore -Force
    & (Join-Path $stamp.Repo 'bin\install-machine-tools.ps1') -RepoPath $stamp.Repo `
      -CatalogPath (Join-Path $stamp.Repo 'config\machine-tools.tsv') -UserProfilePath $env:USERPROFILE *>$null
    Assert ([IO.File]::ReadAllText($fixturePathStore).StartsWith((Split-Path -Parent $stamp.Launcher))) `
      'empty or absent User PATH could not be installed from trusted same-source receipt'
  } finally { $env:AI_DEVOPS_TEST_FAIL_AFTER_GATE=$null; $env:AI_DEVOPS_TEST_FAIL_AFTER_RECOVERY=$null; $env:AI_DEVOPS_TEST_HARD_CRASH_AFTER_GATE=$null; $env:AI_DEVOPS_TEST_HARD_CRASH_AFTER_PATH=$null; $env:AI_DEVOPS_INSTALL_TEST_MODE=$oldMode; $env:AI_DEVOPS_TEST_EXPECTED_REMOTE=$oldRemote; $env:AI_DEVOPS_TEST_LAUNCHER=$oldLauncher }

  $removed=New-Fixture removed
  $removedBefore=(git -C $removed.Repo rev-parse HEAD).Trim()
  git -C $removed.Repo rm .ai-devops/task-gates.json | Out-Null
  git -C $removed.Repo commit -m remove-policy | Out-Null
  git -C $removed.Repo push origin main | Out-Null
  git -C $removed.Repo reset --hard $removedBefore | Out-Null
  Invoke-Gate $removed -ExpectFailure
  Assert ((git -C $removed.Repo rev-parse HEAD).Trim() -eq $removedBefore) 'removed safety policy advanced installed source'

  $source = Get-Content -Raw $installer
  Assert ($source -match 'function Invoke-GitCommand') 'native Git stderr guard missing'
  Assert ($source -match "Invoke-GitCommand @\('-C', \`$Path, 'fetch', 'origin', 'main'\)\s+\| Out-Host\s+if \(\`$script:LastGitExitCode -ne 0\)") 'fetch exit code is not checked immediately'
  Assert ($source.Contains("'branch', '--show-current'")) 'main branch gate missing'
  Assert ($source.Contains("'rev-parse', 'origin/main'")) 'exact origin/main proof missing'
  Assert ($source.Contains("'merge', '--ff-only', `$remoteHead.Trim()")) 'fast-forward must use the proved commit, not a mutable ref'
  $bootstrap = Get-Content -Raw (Join-Path $root 'bin\bootstrap-windows-dev.ps1')
  Assert ($bootstrap.Contains("[string]`$RepoPath = 'C:\repos\ai-devops'")) 'bootstrap default is not C:\repos\ai-devops'
  Assert ($bootstrap -match 'function Invoke-GitCommand') 'bootstrap native Git stderr guard missing'
  Assert ($bootstrap -match "Invoke-GitCommand @\('-C', \`$Path, 'fetch', 'origin', 'main'\)\s+\| Out-Host\s+if \(\`$script:LastGitExitCode -ne 0\)") 'bootstrap fetch does not check the real Git exit code'
  Assert (-not $bootstrap.Contains("'merge', '--ff-only', 'origin/main'")) 'bootstrap must not pre-advance source before the installer checks its receipt'
  Assert ($bootstrap.Contains('-RepoPath $RepoPath -SourceGateOnly -ExpectedHead $sourceSha')) `
    'bootstrap must delegate every non-test source update to the pinned installer gate'
  $sourceGateAt=$bootstrap.IndexOf('-RepoPath $RepoPath -SourceGateOnly -ExpectedHead $sourceSha')
  $runnerAt=$bootstrap.IndexOf('if ($GitHubRunnerHost) {')
  $wingetConfigAt=$bootstrap.IndexOf('winget configure -f $configuration')
  Assert ($sourceGateAt -gt $bootstrap.IndexOf('Clone failed.') -and $sourceGateAt -lt $runnerAt -and $sourceGateAt -lt $wingetConfigAt) `
    'bootstrap source gate must precede runner and WinGet configuration mutations on clone and existing checkout'
  Assert (($bootstrap.Split('-SourceGateOnly').Count - 1) -eq 1) 'bootstrap must always use one source gate, even at equal HEAD'
  Assert ($bootstrap.IndexOf('if (-not $SkipMachineSetup -and -not $TestOnly)') -gt $sourceGateAt) `
    'SkipMachineSetup may not bypass bootstrap source authorization'
  $setup = Get-Content -Raw (Join-Path $root 'bin\setup-machine.ps1')
  $setupGateAt=$setup.IndexOf('-RepoPath $RepoPath -SourceGateOnly -ExpectedHead $sourceTarget')
  Assert ($setupGateAt -gt 0 -and $setupGateAt -lt $setup.IndexOf('Copy-Item -LiteralPath $codexPortableTemplate') -and
    $setupGateAt -lt $setup.IndexOf('Ensure-Winget "GitHub.cli"')) `
    'direct setup must authorize source before copying configuration or installing non-Git packages'
  Assert ($setup.Contains('Guarded ai-devops installation failed; machine setup cannot continue.')) `
    'direct setup must stop when its full guarded installer fails'
  $legacySetup = Get-Content -Raw (Join-Path $root 'bin\setup_dev_computer_internal.ps1')
  $legacyGateAt=$legacySetup.IndexOf('-RepoPath $sourceRepo -SourceGateOnly -ExpectedHead $sourceTarget')
  Assert ($legacyGateAt -gt 0 -and $legacyGateAt -lt $legacySetup.IndexOf('Start-Transcript -Path $logFile') -and
    $legacyGateAt -lt $legacySetup.IndexOf('Ensure-Winget "OpenJS.NodeJS.LTS"')) `
    'legacy direct setup must authorize source before transcript and package writes'
  Assert ($legacySetup.Contains('AI DevOps guarded machine setup failed; legacy setup cannot report completion.')) `
    'legacy setup must stop when delegated guarded setup fails'
  Write-Host 'PASS: Windows source gate rejects hostile source, moved targets, unpinned protected updates, stale receipts, and pre-advanced checkout'
} finally {
  Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
