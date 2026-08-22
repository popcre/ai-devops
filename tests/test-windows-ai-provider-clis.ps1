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
Assert ($installerText -match 'InstallerSha256') 'provider installers must carry repository-owned SHA-256 pins'
Assert ($installerText -match 'Get-FileHash -Algorithm SHA256') 'downloaded provider installers must be hash-verified before execution'
Assert ($installerText -notmatch 'Invoke-Expression') 'downloaded provider installers must never execute directly from text'
$qwenWrapperText = Get-Content -Raw $qwenWrapper
Assert ($qwenWrapperText -match '\*\.cmd\|\*\.bat') 'Qwen wrapper must accept official Windows command shims that are not marked executable by Git Bash'

$bootstrapText = Get-Content -Raw $bootstrap
Assert ($bootstrapText -match 'install-windows-ai-provider-clis\.ps1') 'bootstrap must run the provider installer'
Write-Host 'PASS: Windows Grok, Kimi, and Qwen CLI setup wiring is valid.'
