$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$installer = Join-Path $root 'bin\install-windows-ai-provider-clis.ps1'
$bootstrap = Join-Path $root 'bin\bootstrap-windows-dev.ps1'
$qwenWrapper = Join-Path $root 'bin\ai-qwen'

function Assert([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw "TEST FAILED: $Message" }
}

Assert (Test-Path -LiteralPath $installer) 'Grok/Kimi/Qwen installer is missing'
foreach ($script in @($installer, $bootstrap)) {
  $tokens = $null; $errors = $null
  [void][Management.Automation.Language.Parser]::ParseFile($script, [ref]$tokens, [ref]$errors)
  Assert ($errors.Count -eq 0) "$script has PowerShell parse errors: $($errors.Message -join '; ')"
}

$installerText = Get-Content -Raw $installer
Assert ($installerText -match 'https://x\.ai/cli/install\.ps1') 'must use the official Grok installer'
Assert ($installerText -match 'https://code\.kimi\.com/kimi-code/install\.ps1') 'must use the official Kimi installer'
Assert ($installerText -match 'https://qwen-code-assets\.oss-cn-hangzhou\.aliyuncs\.com/installation/install-qwen-standalone\.ps1') 'must use the official Qwen standalone installer'
Assert ($installerText -match 'qwen-code\\bin\\qwen\.cmd') 'must verify the Qwen standalone shim'
Assert ($installerText -match 'TestOnly') 'must support a non-installing verification path'
Assert ($installerText -match 'Set-QwenChildEnvironmentHardening') 'installer must harden the Qwen child-process environment after installation'
Assert ($installerText -match 'BAILIAN_CODING_PLAN_API_KEY') 'Qwen hardening must remove the Coding Plan key from tool children'
Assert ($installerText -match 'declaration\.Value\.Contains') 'Qwen hardening must inspect the sanitizer declaration, not an unrelated bundle occurrence'
Assert ($installerText -match 'InstallerSha256') 'provider installers must carry repository-owned SHA-256 pins'
Assert ($installerText -match 'Get-FileHash -Algorithm SHA256') 'downloaded provider installers must be hash-verified before execution'
Assert ($installerText -notmatch 'Invoke-Expression') 'downloaded provider installers must never execute directly from text'

# Reproduce the vendor layout that exposed the production bug: the protected
# name exists elsewhere in the bundle but is absent from the child sanitizer.
$ast = [Management.Automation.Language.Parser]::ParseFile($installer, [ref]$null, [ref]$null)
$hardenerAst = $ast.Find({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Set-QwenChildEnvironmentHardening'
}, $true)
Assert ($null -ne $hardenerAst) 'could not load the Qwen hardener for its behavioral fixture'
$fixtureFunction = $hardenerAst.Extent.Text.Replace('$PSScriptRoot', "'$($root.Replace("'", "''"))\bin'")
Invoke-Expression $fixtureFunction
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ("ai-devops-qwen-hardener-{0}" -f [Guid]::NewGuid().ToString('N'))
try {
  $chunkRoot = Join-Path $fixtureRoot 'lib\chunks'
  $nodeRoot = Join-Path $fixtureRoot 'node'
  [void](New-Item -ItemType Directory -Path $chunkRoot, $nodeRoot)
  $bundle = @'
var INTERNAL_SECRET_ENV_VARS = [
  "QWEN_SERVER_TOKEN",
  "QWEN_DAEMON_TOKEN",
  PRIVATE_ACP_CAPABILITY_ENV
];
const unrelatedCredentialLookup = "BAILIAN_CODING_PLAN_API_KEY";
function sanitizeChildEnv(env2 = process.env) {
  const sanitized = { ...env2 };
  for (const key of INTERNAL_SECRET_ENV_VARS) {
    delete sanitized[key];
  }
  return sanitized;
}
'@
  [IO.File]::WriteAllText((Join-Path $chunkRoot 'fixture.js'), $bundle, [Text.UTF8Encoding]::new($false))
  Copy-Item -LiteralPath (Get-Command node -ErrorAction Stop).Source -Destination (Join-Path $nodeRoot 'node.exe')
  $patchedPath = Set-QwenChildEnvironmentHardening -Root $fixtureRoot
  $patchedText = Get-Content -Raw -LiteralPath $patchedPath
  $patchedDeclaration = [regex]::Match($patchedText, 'var INTERNAL_SECRET_ENV_VARS\s*=\s*\[[\s\S]*?\];').Value
  Assert ($patchedDeclaration.Contains('"BAILIAN_CODING_PLAN_API_KEY"')) 'hardener was fooled by an unrelated bundle occurrence of the credential name'
} finally {
  if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
}

# --- exact version policy (issue #251) -------------------------------------
# "A provider that runs" is not the contract. Both Grok wrappers are qualified
# against one exact build, so the Windows installer must detect any other build
# as stale, bring it to exactly the pinned version, and roll back if it cannot.
$policyPath = Join-Path $root 'config\provider-cli-versions.json'
Assert (Test-Path -LiteralPath $policyPath) 'provider version policy is missing'
$policy = Get-Content -Raw -LiteralPath $policyPath | ConvertFrom-Json
Assert ($policy.schema_version -eq 1) 'provider version policy has an unexpected schema_version'
Assert ($policy.providers.grok.supported_version -match '^\d+\.\d+\.\d+$') 'grok must be pinned to one exact version'
foreach ($other in @('kimi', 'qwen')) {
  Assert ($null -eq $policy.providers.$other.supported_version) "$other must stay unpinned; Grok work must not force its upgrade"
}
$policyText = Get-Content -Raw -LiteralPath $policyPath
Assert ($policyText -notmatch '(?i)"(token|api[_-]?key|password|secret)"') 'the version policy must stay secret-free'

$pinned = $policy.providers.grok.supported_version

Assert ($installerText -match 'Get-RequiredProviderVersion') 'installer must read the repository version policy'
Assert ($installerText -match 'Update-ProviderToExactVersion') 'installer must have an exact-version upgrade path'
Assert ($installerText -match "update --version") 'installer must use the documented exact-version install command'
Assert ($installerText -match 'STALE') 'installer must report a wrong-version provider as stale, not as installed'
Assert ($installerText -match "contains 'MISSING' -or .*contains 'STALE'") 'a stale provider must fail the verification exit code, like a missing one'
Assert ($installerText -match 'Restored the previous') 'a failed upgrade must restore the previous binary'
Assert ($installerText -match 'reports .\$now., not \$Version') 'a wrong resulting version must be rejected'
Assert ($installerText -notmatch 'auth\.json') 'the installer must never touch provider credentials'
Assert ($installerText -notmatch [regex]::Escape($pinned)) 'the installer must read the pinned version from the policy, not hard-code it'

# Behavioural: load the two readers out of the installer and exercise them.
$policyFns = $ast.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
  $node.Name -in @('Get-RequiredProviderVersion', 'Get-ReportedProviderVersion')
}, $true)
Assert ($policyFns.Count -eq 2) 'could not load the version-policy readers for their fixture'
foreach ($fn in $policyFns) { Invoke-Expression $fn.Extent.Text }

$versionFixture = Join-Path ([IO.Path]::GetTempPath()) ("ai-devops-version-{0}" -f [Guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $versionFixture)
$savedPolicyEnv = $env:AI_PROVIDER_VERSIONS_FILE
try {
  $env:AI_PROVIDER_VERSIONS_FILE = $policyPath
  Assert ((Get-RequiredProviderVersion -Provider 'grok') -eq $pinned) 'required version did not match the policy'
  Assert ($null -eq (Get-RequiredProviderVersion -Provider 'kimi')) 'an unpinned provider must report no required version'

  $threw = $false
  try { Get-RequiredProviderVersion -Provider 'not-a-provider' } catch { $threw = $true }
  Assert $threw 'an unknown provider must fail closed'

  $bad = Join-Path $versionFixture 'malformed.json'
  Set-Content -LiteralPath $bad -Value '{"schema_version":99}'
  $env:AI_PROVIDER_VERSIONS_FILE = $bad
  $threw = $false
  try { Get-RequiredProviderVersion -Provider 'grok' } catch { $threw = $true }
  Assert $threw 'a malformed policy must fail closed, never default to "any version"'

  $env:AI_PROVIDER_VERSIONS_FILE = Join-Path $versionFixture 'absent.json'
  $threw = $false
  try { Get-RequiredProviderVersion -Provider 'grok' } catch { $threw = $true }
  Assert $threw 'a missing policy must fail closed'

  # A provider that reports a version, and one that reports nothing at all.
  $fakeGrok = Join-Path $versionFixture 'grok.cmd'
  Set-Content -LiteralPath $fakeGrok -Value '@echo grok 1.0.5 (fake) [stable]'
  Assert ((Get-ReportedProviderVersion -Path $fakeGrok) -eq '1.0.5') 'could not read a version out of the provider banner'
  $mute = Join-Path $versionFixture 'mute.cmd'
  Set-Content -LiteralPath $mute -Value '@exit /b 0'
  Assert ($null -eq (Get-ReportedProviderVersion -Path $mute)) 'a provider that reports no version must not pass as qualified'

  # Behavioural rollback. Reading the installer's source only proves the restore
  # text exists; these run it. The third case is the one that matters: an
  # `update` that THROWS rather than exiting non-zero must still restore, or a
  # replaced or locked executable leaves the machine worse than it started.
  $upgradeFn = $ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    $node.Name -eq 'Update-ProviderToExactVersion'
  }, $true)
  Assert ($upgradeFn.Count -eq 1) 'could not load the exact-version upgrade path for its fixture'
  Invoke-Expression $upgradeFn[0].Extent.Text

  $fakeProvider = [pscustomobject]@{ Name = 'Fake Grok'; Command = 'grok' }
  # Keep fixture backups inside the fixture. A test must never write into the
  # operator's real provider-CLI backup directory.
  $savedHome = $HOME
  Set-Variable -Name HOME -Value $versionFixture -Scope Local -Force
  $reportsOld = '@echo off' + "`r`n" + 'if [%1]==[--version] (echo grok 1.0.5 ^(fake^) [stable] & exit /b 0)' + "`r`n"
  $cases = @(
    @{ name = 'a non-zero update';                        tail = 'exit /b 7' }
    @{ name = 'an update that reports the wrong version'; tail = 'exit /b 0'; rewriteTo = '9.9.9' }
    @{ name = 'an update that destroys the binary';       tail = 'del "%~f0" >nul 2>&1' + [Environment]::NewLine + 'exit /b 0' }
  )
  foreach ($case in $cases) {
    $live = Join-Path $versionFixture 'live-grok.cmd'
    if ($case.rewriteTo) {
      # Succeeds, but the resulting binary is not the pinned version.
      $body = '@echo off' + "`r`n" + 'if [%1]==[--version] (echo grok ' + $case.rewriteTo + ' & exit /b 0)' + "`r`n" + $case.tail
      Set-Content -LiteralPath $live -Value $body
    } else {
      Set-Content -LiteralPath $live -Value ($reportsOld + $case.tail)
    }

    $threw = $false
    try { Update-ProviderToExactVersion -Provider $fakeProvider -Path $live -Version '1.0.13' }
    catch { $threw = $true }

    Assert $threw ('{0} must fail loudly' -f $case.name)
    Assert (Test-Path -LiteralPath $live) ('{0} must leave a usable binary behind, not a hole' -f $case.name)
    # A .cmd cannot safely rewrite itself mid-execution, so the wrong-version
    # fake reports 9.9.9 both before and after; what it proves here is that a
    # resulting version other than the pin is rejected and restored rather than
    # accepted. Rollback that really reverts a mutated binary is proved on the
    # Unix side, where the fake rewrites its own version on update. The
    # destroying case is the one that needs the `finally`: it leaves no binary
    # at all, and only the backup can put one back.
    $expected = if ($case.rewriteTo) { $case.rewriteTo } else { '1.0.5' }
    Assert ((Get-ReportedProviderVersion -Path $live) -eq $expected) ('{0} must restore the previous binary' -f $case.name)
  }
} finally {
  if ($savedHome) { Set-Variable -Name HOME -Value $savedHome -Scope Local -Force }
  $env:AI_PROVIDER_VERSIONS_FILE = $savedPolicyEnv
  if (Test-Path -LiteralPath $versionFixture) { Remove-Item -LiteralPath $versionFixture -Recurse -Force }
}

$qwenWrapperText = Get-Content -Raw $qwenWrapper
Assert ($qwenWrapperText -match '\*\.cmd\|\*\.bat') 'Qwen wrapper must accept official Windows command shims that are not marked executable by Git Bash'

$bootstrapText = Get-Content -Raw $bootstrap
Assert ($bootstrapText -match 'install-windows-ai-provider-clis\.ps1') 'bootstrap must run the provider installer'
Write-Host 'PASS: Windows Grok, Kimi, and Qwen CLI setup wiring is valid.'
