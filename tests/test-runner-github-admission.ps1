$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$source = Join-Path $repo 'bin\runner-github-admission.ps1'
$promoter = Get-Content -Raw -LiteralPath (Join-Path $repo 'bin\promote-windows-runner-to-service.ps1')
$temp = Join-Path ([IO.Path]::GetTempPath()) ('runner-gh-admission-' + [guid]::NewGuid().ToString('N'))
$script:passed = 0
$script:failed = 0
function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Case([string]$Name, [scriptblock]$Body) {
  try { & $Body; $script:passed++; Write-Output "PASS $Name" }
  catch { $script:failed++; Write-Error "FAIL ${Name}: $($_.Exception.Message)" -ErrorAction Continue }
}

New-Item -ItemType Directory -Path $temp | Out-Null
try {
  $adapter = Join-Path $temp 'runner-github-admission.ps1'
  $fake = Join-Path $temp 'ai-gh.cmd'
  $log = Join-Path $temp 'calls.txt'
  Copy-Item -LiteralPath $source -Destination $adapter
  @'
@echo off
>> "%AI_RUNNER_FAKE_LOG%" echo %*
if "%AI_RUNNER_FAKE_EXIT%"=="1" exit /b 75
echo %AI_RUNNER_FAKE_RESPONSE%
'@ | Set-Content -LiteralPath $fake -Encoding ASCII
  $env:AI_RUNNER_FAKE_LOG = $log
  $env:AI_RUNNER_FAKE_EXIT = '0'
  $env:AI_RUNNER_FAKE_RESPONSE = '{"runners":[]}'

  Case 'List_UsesSharedAdmission' {
    $result = & $adapter -Operation list -Repository popcre/ai-devops | ConvertFrom-Json
    Assert-True ($result.runners.Count -eq 0) 'runner list changed'
    Assert-True ((Get-Content -LiteralPath $log -Tail 1) -eq 'api repos/popcre/ai-devops/actions/runners') 'wrong list route'
  }
  Case 'RemoveToken_UsesSharedAdmissionWithoutLoggingToken' {
    $env:AI_RUNNER_FAKE_RESPONSE = 'fixture-remove-token'
    $token = & $adapter -Operation remove-token -Repository popcre/ai-devops
    Assert-True ($token -eq 'fixture-remove-token') 'removal token changed'
    Assert-True ((Get-Content -LiteralPath $log -Tail 1) -eq 'api --method POST repos/popcre/ai-devops/actions/runners/remove-token --jq .token') 'wrong remove route'
    Assert-True (-not ((Get-Content -Raw -LiteralPath $log).Contains($token))) 'token leaked into call log'
  }
  Case 'Delete_UsesSharedAdmission' {
    $env:AI_RUNNER_FAKE_RESPONSE = ''
    & $adapter -Operation delete -Repository popcre/ai-devops -RunnerId 42 | Out-Null
    Assert-True ((Get-Content -LiteralPath $log -Tail 1) -eq 'api --method DELETE repos/popcre/ai-devops/actions/runners/42') 'wrong delete route'
  }
  Case 'RegistrationToken_UsesSharedAdmissionWithoutLoggingToken' {
    $env:AI_RUNNER_FAKE_RESPONSE = 'fixture-registration-token'
    $token = & $adapter -Operation registration-token -Repository popcre/ai-devops
    Assert-True ($token -eq 'fixture-registration-token') 'registration token changed'
    Assert-True ((Get-Content -LiteralPath $log -Tail 1) -eq 'api --method POST repos/popcre/ai-devops/actions/runners/registration-token --jq .token') 'wrong registration route'
    Assert-True (-not ((Get-Content -Raw -LiteralPath $log).Contains($token))) 'token leaked into call log'
  }
  Case 'InvalidInput_NeverCallsTransport' {
    $before = @(Get-Content -LiteralPath $log).Count
    foreach ($caseArgs in @(
      @{ Operation='list'; Repository='popcre/ai-devops -f token=bad' },
      @{ Operation='delete'; Repository='popcre/ai-devops'; RunnerId=0 }
    )) {
      try { & $adapter @caseArgs | Out-Null; throw 'invalid input accepted' }
      catch { Assert-True ($_.Exception.Message -ne 'invalid input accepted') 'invalid input accepted' }
    }
    Assert-True (@(Get-Content -LiteralPath $log).Count -eq $before) 'invalid input made a call'
  }
  Case 'AdmissionFailure_IsNonzeroAndSafe' {
    $env:AI_RUNNER_FAKE_EXIT = '1'
    try { & $adapter -Operation registration-token -Repository popcre/ai-devops | Out-Null; throw 'failure accepted' }
    catch { Assert-True ($_.Exception.Message -eq 'Shared GitHub admission failed for runner registration-token.') 'unsafe or missing failure' }
    $env:AI_RUNNER_FAKE_EXIT = '0'
  }
  Case 'MissingAdmission_RefusesWithoutFallback' {
    Rename-Item -LiteralPath $fake -NewName 'ai-gh.cmd.disabled'
    try { & $adapter -Operation list -Repository popcre/ai-devops | Out-Null; throw 'missing gate accepted' }
    catch { Assert-True ($_.Exception.Message -eq 'Shared GitHub admission is unavailable.') 'missing gate did not refuse' }
  }
  Case 'Promoter_RoutesAllFourCalls' {
    Assert-True ($promoter.Contains("-Operation list -Repository `$Repository")) 'list not routed'
    Assert-True ($promoter.Contains("-Operation remove-token -Repository `$Repository")) 'remove token not routed'
    Assert-True ($promoter.Contains("-Operation delete -Repository `$Repository")) 'delete not routed'
    Assert-True ($promoter.Contains("-Operation registration-token -Repository `$Repository")) 'registration token not routed'
    Assert-True ($promoter -notmatch '(?m)^\s*gh\s+api\b') 'direct gh api remains'
  }
} finally {
  Remove-Item Env:\AI_RUNNER_FAKE_LOG,Env:\AI_RUNNER_FAKE_EXIT,Env:\AI_RUNNER_FAKE_RESPONSE -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $temp -Recurse -Force
}

Write-Output "$script:passed passed, $script:failed failed"
if ($script:failed -ne 0) { exit 1 }
