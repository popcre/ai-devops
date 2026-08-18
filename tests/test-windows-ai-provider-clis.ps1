$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$installer = Join-Path $root 'bin\install-windows-ai-provider-clis.ps1'
$bootstrap = Join-Path $root 'bin\bootstrap-windows-dev.ps1'

function Assert([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw "TEST FAILED: $Message" }
}

Assert (Test-Path -LiteralPath $installer) 'Grok/Kimi installer is missing'
foreach ($script in @($installer, $bootstrap)) {
  $tokens = $null; $errors = $null
  [void][Management.Automation.Language.Parser]::ParseFile($script, [ref]$tokens, [ref]$errors)
  Assert ($errors.Count -eq 0) "$script has PowerShell parse errors: $($errors.Message -join '; ')"
}

$installerText = Get-Content -Raw $installer
Assert ($installerText -match 'https://x\.ai/cli/install\.ps1') 'must use the official Grok installer'
Assert ($installerText -match 'https://code\.kimi\.com/kimi-code/install\.ps1') 'must use the official Kimi installer'
Assert ($installerText -match 'TestOnly') 'must support a non-installing verification path'

$bootstrapText = Get-Content -Raw $bootstrap
Assert ($bootstrapText -match 'install-windows-ai-provider-clis\.ps1') 'bootstrap must run the provider installer'
Write-Host 'PASS: Windows Grok and Kimi CLI setup wiring is valid.'
