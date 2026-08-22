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
$qwenWrapperText = Get-Content -Raw $qwenWrapper
Assert ($qwenWrapperText -match '\*\.cmd\|\*\.bat') 'Qwen wrapper must accept official Windows command shims that are not marked executable by Git Bash'

$bootstrapText = Get-Content -Raw $bootstrap
Assert ($bootstrapText -match 'install-windows-ai-provider-clis\.ps1') 'bootstrap must run the provider installer'
Write-Host 'PASS: Windows Grok, Kimi, and Qwen CLI setup wiring is valid.'
