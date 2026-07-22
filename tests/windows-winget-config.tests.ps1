$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$config = Join-Path $root '.config\configuration.winget'
$bootstrap = Join-Path $root 'bin\bootstrap-windows-dev.ps1'
$verify = Join-Path $root 'bin\verify-windows-dev.ps1'
$exceptions = Join-Path $root 'bin\reconcile-windows-package-exceptions.ps1'
$remoteAccess = Join-Path $root 'bin\configure-windows-bootstrap-access.ps1'
$ansibleController = Join-Path $root 'bin\configure-wsl-ansible-controller.ps1'

function Assert([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw "TEST FAILED: $Message" }
}

Assert (Test-Path $config) 'configuration.winget is missing'
$yaml = Get-Content -Raw $config
Assert ($yaml -match 'configurationVersion:\s+0\.2\.0') 'configuration must declare the supported WinGet DSC schema version'
Assert ($yaml -match 'Microsoft\.WinGet\.DSC/WinGetPackage') 'configuration must use WinGet DSC package resources'
Assert ($yaml -match 'Microsoft\.Windows\.Developer/EnableLongPathSupport') 'configuration must include a DSC Windows setting'
Assert ($yaml -match 'Anthropic\.ClaudeCode') 'configuration must include Claude Code'
Assert ($yaml -match '9PLM9XGG6VKS') 'configuration must include the Codex desktop Store app'
Assert ($yaml -notmatch '(?i)(ops_[A-Za-z0-9]|password\s*:|token\s*:)') 'configuration appears to contain a secret'

foreach ($script in @($bootstrap,$verify,$exceptions,$remoteAccess,$ansibleController)) {
  Assert (Test-Path $script) "$script is missing"
  $tokens=$null; $errors=$null
  [void][Management.Automation.Language.Parser]::ParseFile($script,[ref]$tokens,[ref]$errors)
  Assert ($errors.Count -eq 0) "$script has PowerShell parse errors: $($errors.Message -join '; ')"
}

$bootstrapText = Get-Content -Raw $bootstrap
Assert ($bootstrapText -match 'setup-machine\.ps1') 'bootstrap must delegate repo-specific configuration'
Assert ($bootstrapText -match 'TestOnly') 'bootstrap must expose a non-installing test path'
Assert ($bootstrapText -match 'pull --ff-only') 'bootstrap must update without rewriting local history'
Assert ($bootstrapText -match 'reconcile-windows-package-exceptions\.ps1') 'bootstrap must own non-WinGet package exceptions'
Assert ($bootstrapText -match 'configure-windows-bootstrap-access\.ps1') 'bootstrap must own first-connection Tailscale/OpenSSH setup'
Assert ($bootstrapText -match 'configure-wsl-ansible-controller\.ps1') 'bootstrap must own WSL Ansible controller setup'
$remoteText = Get-Content -Raw $remoteAccess
Assert ($remoteText -match 'OpenSSH\.Server~~~~0\.0\.1\.0') 'remote bootstrap must install Windows OpenSSH Server'
Assert ($remoteText -match '100\.64\.0\.0/10') 'remote bootstrap must restrict SSH sources to Tailscale IPv4'
Assert ($remoteText -match 'PasswordAuthentication no') 'remote bootstrap must enforce key-only SSH'
Assert ($remoteText -match 'Set-Service WinRM -StartupType Disabled') 'remote bootstrap must disable WinRM'
$controllerText = Get-Content -Raw $ansibleController
Assert ($controllerText -match 'apt-get install -y ansible ansible-lint') 'WSL controller setup must install Ansible and its linter'
Assert ($controllerText -match 'ansible-galaxy collection install') 'WSL controller setup must install required collections'
Write-Host 'PASS: WinGet/DSC configuration and scripts passed non-installing structural tests.'
