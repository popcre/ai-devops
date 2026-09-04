$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$config = Join-Path $root '.config\configuration.winget'
$bootstrap = Join-Path $root 'bin\bootstrap-windows-dev.ps1'
$verify = Join-Path $root 'bin\verify-windows-dev.ps1'
$exceptions = Join-Path $root 'bin\reconcile-windows-package-exceptions.ps1'
$providerClis = Join-Path $root 'bin\install-windows-ai-provider-clis.ps1'
$remoteAccess = Join-Path $root 'bin\configure-windows-bootstrap-access.ps1'
$ansibleController = Join-Path $root 'bin\configure-wsl-ansible-controller.ps1'
$machineSetup = Join-Path $root 'bin\setup-machine.ps1'
$knownHostsTemplate = Join-Path $root 'config\ssh-known-hosts.template'
$knownHostsSync = Join-Path $root 'bin\sync-ssh-known-hosts.ps1'

function Assert([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw "TEST FAILED: $Message" }
}

Assert (Test-Path $config) 'configuration.winget is missing'
Assert (Test-Path $knownHostsTemplate) 'managed SSH known-hosts template is missing'
Assert (Test-Path $knownHostsSync) 'managed SSH known-hosts sync script is missing'
$knownHostsText = Get-Content -Raw $knownHostsTemplate
Assert ($knownHostsText -match 'ai-private-config path ssh_known_hosts') 'public known-hosts file must point to protected configuration'
Assert ($knownHostsText -notmatch 'ssh-(ed25519|rsa)') 'public known-hosts file must not contain host keys'
$sshConfigTemplate = Get-Content -Raw (Join-Path $root 'config\ssh-config.template')
Assert ($sshConfigTemplate -match 'ai-private-config path ssh_config') 'public SSH config must point to protected configuration'
$yaml = Get-Content -Raw $config
Assert ($yaml -match 'configurationVersion:\s+0\.2\.0') 'configuration must declare the supported WinGet DSC schema version'
Assert ($yaml -match 'Microsoft\.WinGet\.DSC/WinGetPackage') 'configuration must use WinGet DSC package resources'
Assert ($yaml -match 'Microsoft\.Windows\.Developer/EnableLongPathSupport') 'configuration must include a DSC Windows setting'
Assert ($yaml -match 'Anthropic\.ClaudeCode') 'configuration must include Claude Code'
Assert ($yaml -match '9PLM9XGG6VKS') 'configuration must include the Codex desktop Store app'
Assert ($yaml -notmatch '(?i)(ops_[A-Za-z0-9]|password\s*:|token\s*:)') 'configuration appears to contain a secret'

foreach ($script in @($bootstrap,$verify,$exceptions,$providerClis,$remoteAccess,$ansibleController)) {
  Assert (Test-Path $script) "$script is missing"
  $tokens=$null; $errors=$null
  [void][Management.Automation.Language.Parser]::ParseFile($script,[ref]$tokens,[ref]$errors)
  Assert ($errors.Count -eq 0) "$script has PowerShell parse errors: $($errors.Message -join '; ')"
}

$bootstrapText = Get-Content -Raw $bootstrap
$machineSetupText = Get-Content -Raw $machineSetup
$exceptionsText = Get-Content -Raw $exceptions
Assert ($bootstrapText -match 'setup-machine\.ps1') 'bootstrap must delegate repo-specific configuration'
Assert ($bootstrapText -match 'TestOnly') 'bootstrap must expose a non-installing test path'
Assert ($bootstrapText.Contains("'merge', '--ff-only', 'origin/main'")) 'bootstrap must update without rewriting local history'
Assert ($bootstrapText.Contains("'fetch', 'origin', 'main'")) 'bootstrap must fetch the canonical branch before machine changes'
Assert ($bootstrapText -match 'reconcile-windows-package-exceptions\.ps1') 'bootstrap must own non-WinGet package exceptions'
Assert ($bootstrapText -match 'setup.*-SkipPackageExceptionReconcile') 'bootstrap must not reconcile package exceptions twice'
Assert ($exceptionsText -match '@railway/cli@5\.43\.1') 'package exceptions must install the pinned official Railway CLI'
Assert ($exceptionsText -match '@ast-grep/cli@0\.45\.2') 'package exceptions must install the pinned official ast-grep CLI'
Assert ($exceptionsText -match 'Get-Command sg -All') 'ast-grep setup must preflight every existing sg command'
Assert ($exceptionsText -match 'Refusing to replace unrelated sg command') 'ast-grep setup must refuse an unrelated sg command'
Assert ($exceptionsText -match '(?s)Version=''0\.45\.2''.*ast-grep --version') 'ast-grep test-only verification must check the exact version'
Assert ($machineSetupText -match "https://mcp\.railway\.com") 'machine setup must configure Railway hosted MCP for Codex'
Assert ($machineSetupText -match "args = @\('mcp', 'proxy'\)") 'Codex must use Railway CLI authenticated proxy'
Assert ($machineSetupText -match '(?s)reconciling package-manager exceptions.*reconcile-windows-package-exceptions\.ps1') 'direct machine setup must use the canonical exception reconciler'
Assert ($machineSetupText -match '\$McpServers\["railway"\]') 'Railway MCP must be shared with Claude consumers'
Assert ($bootstrapText -match 'install-windows-ai-provider-clis\.ps1') 'bootstrap must install Grok, Kimi, and Qwen CLIs'
Assert ($bootstrapText -match 'configure-windows-bootstrap-access\.ps1') 'bootstrap must own first-connection Tailscale/OpenSSH setup'
Assert ($bootstrapText -match 'configure-wsl-ansible-controller\.ps1') 'bootstrap must own WSL Ansible controller setup'
Assert ($machineSetupText -match 'ai-private-config') 'machine setup must synchronize protected configuration'
Assert ($machineSetupText -match 'path ssh_known_hosts') 'machine setup must resolve protected SSH server keys'
$knownHostsSyncText = Get-Content -Raw $knownHostsSync
Assert ($knownHostsSyncText -match 'ssh-keygen -R') 'SSH known-hosts sync must safely replace a changed managed SSH key'
$syncTestRoot = Join-Path ([IO.Path]::GetTempPath()) ("ai-devops-known-hosts-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $syncTestRoot | Out-Null
try {
  $syncTemplate = Join-Path $syncTestRoot 'template'
  $syncKnownHosts = Join-Path $syncTestRoot 'known_hosts'
  $originalKnownHosts = 'unmanaged.example ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOldKeyForRecoveryTest'
  Set-Content -LiteralPath $syncKnownHosts -Value $originalKnownHosts -Encoding ascii
  Set-Content -LiteralPath $syncTemplate -Value @(
    'managed-one.example ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINewKeyForManagedOne',
    'managed-two.example ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINewKeyForManagedTwo'
  ) -Encoding ascii
  & $knownHostsSync -TemplatePath $syncTemplate -KnownHostsPath $syncKnownHosts | Out-Null
  $syncBackups = @(Get-ChildItem -LiteralPath $syncTestRoot -Filter 'known_hosts.ai-devops-before-managed-update-*')
  Assert ($syncBackups.Count -eq 1) 'SSH known-hosts sync must create exactly one pre-update backup per run'
  Assert ((Get-Content -Raw $syncBackups[0].FullName).Trim() -eq $originalKnownHosts) 'SSH known-hosts backup must preserve the original file before every managed update'
  Assert ((Get-Content $syncKnownHosts | Measure-Object).Count -eq 3) 'SSH known-hosts sync must preserve unmanaged keys and add both managed keys'
  & $knownHostsSync -TemplatePath $syncTemplate -KnownHostsPath $syncKnownHosts | Out-Null
  Assert (@(Get-ChildItem -LiteralPath $syncTestRoot -Filter 'known_hosts.ai-devops-before-managed-update-*').Count -eq 1) 'An unchanged second sync must not create another backup'
  Assert ((Get-Content $syncKnownHosts | Measure-Object).Count -eq 3) 'An unchanged second sync must not add duplicate keys'
} finally {
  Remove-Item -LiteralPath $syncTestRoot -Recurse -Force
}
$remoteText = Get-Content -Raw $remoteAccess
Assert ($remoteText -match 'OpenSSH\.Server~~~~0\.0\.1\.0') 'remote bootstrap must install Windows OpenSSH Server'
Assert ($remoteText -match '100\.64\.0\.0/10') 'remote bootstrap must restrict SSH sources to Tailscale IPv4'
Assert ($remoteText -match 'PasswordAuthentication no') 'remote bootstrap must enforce key-only SSH'
Assert ($remoteText -match 'Set-Service WinRM -StartupType Disabled') 'remote bootstrap must disable WinRM'
$controllerText = Get-Content -Raw $ansibleController
Assert ($controllerText -match 'apt-get install -y ansible ansible-lint') 'WSL controller setup must install Ansible and its linter'
Assert ($controllerText -match 'ansible-galaxy collection install') 'WSL controller setup must install required collections'
$providerText = Get-Content -Raw $providerClis
Assert ($providerText -match 'https://x\.ai/cli/install\.ps1') 'provider setup must use the official Grok installer'
Assert ($providerText -match 'https://code\.kimi\.com/kimi-code/install\.ps1') 'provider setup must use the official Kimi installer'
Assert ($providerText -match 'TestOnly') 'provider setup must support a non-installing verification path'
$verifyText = Get-Content -Raw $verify
Assert ($verifyText -match "Check-CommandVersion 'ast-grep'") 'machine verification must check ast-grep exact version'
Assert ($verifyText -match "tool-versions\.json") 'machine verification must read the canonical version catalog'

$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ("ai-devops-ast-grep-" + [guid]::NewGuid().ToString('N'))
$prefix = Join-Path $fixtureRoot 'npm-prefix'
$otherPrefix = Join-Path $fixtureRoot 'unrelated-prefix'
$packageRoot = Join-Path $prefix 'node_modules\@ast-grep\cli'
New-Item -ItemType Directory -Force -Path $packageRoot,$otherPrefix | Out-Null
$mutationMarker = Join-Path $fixtureRoot 'npm-was-called'
Set-Content -LiteralPath (Join-Path $prefix 'npm.cmd') -Encoding ascii -Value @("@echo called>`"$mutationMarker`"", '@exit /b 99')
Set-Content -LiteralPath (Join-Path $prefix 'sg.cmd') -Encoding ascii -Value '@exit /b 0'
Set-Content -LiteralPath (Join-Path $prefix 'ast-grep.cmd') -Encoding ascii -Value "@echo ast-grep 0.45.2`r`n@exit /b 0"
Set-Content -LiteralPath (Join-Path $prefix 'vercel.cmd') -Encoding ascii -Value '@exit /b 0'
Set-Content -LiteralPath (Join-Path $prefix 'trigger.dev.cmd') -Encoding ascii -Value '@exit /b 0'
Set-Content -LiteralPath (Join-Path $prefix 'railway.cmd') -Encoding ascii -Value '@exit /b 0'
Set-Content -LiteralPath (Join-Path $prefix 'supabase.cmd') -Encoding ascii -Value '@exit /b 0'
Set-Content -LiteralPath (Join-Path $packageRoot 'package.json') -Encoding ascii -Value '{"name":"@ast-grep/cli","version":"0.45.2"}'
$powershell = (Get-Command powershell.exe).Source
$savedTestMode = $env:AI_DEVOPS_TEST_MODE
$savedTestPath = $env:AI_DEVOPS_TEST_PATH
$savedTestPrefix = $env:AI_DEVOPS_TEST_NPM_PREFIX
try {
  $env:AI_DEVOPS_TEST_MODE = '1'
  $env:AI_DEVOPS_TEST_PATH = $prefix
  $env:AI_DEVOPS_TEST_NPM_PREFIX = $prefix
  & $powershell -NoProfile -ExecutionPolicy Bypass -File $exceptions -TestOnly | Out-Null
  Assert ($LASTEXITCODE -eq 0) 'test-only fixture must accept the package-owned sg shim and exact ast-grep version'
  Assert (-not (Test-Path -LiteralPath $mutationMarker)) 'test-only verification must never invoke npm or mutate packages'

  Set-Content -LiteralPath (Join-Path $prefix 'ast-grep.cmd') -Encoding ascii -Value "@echo ast-grep 0.44.0`r`n@exit /b 0"
  & $powershell -NoProfile -ExecutionPolicy Bypass -File $exceptions -TestOnly | Out-Null
  Assert ($LASTEXITCODE -eq 2) 'test-only fixture must report ast-grep version drift'
  Assert (-not (Test-Path -LiteralPath $mutationMarker)) 'version-drift verification must remain non-mutating'

  $env:AI_DEVOPS_TEST_NPM_PREFIX = $otherPrefix
  & $powershell -NoProfile -ExecutionPolicy Bypass -File $exceptions -TestOnly 2>$null | Out-Null
  Assert ($LASTEXITCODE -ne 0) 'test-only fixture must refuse an unrelated sg command'
} finally {
  $env:AI_DEVOPS_TEST_MODE = $savedTestMode
  $env:AI_DEVOPS_TEST_PATH = $savedTestPath
  $env:AI_DEVOPS_TEST_NPM_PREFIX = $savedTestPrefix
  Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
}
Write-Host 'PASS: WinGet/DSC configuration and scripts passed non-installing structural tests.'
