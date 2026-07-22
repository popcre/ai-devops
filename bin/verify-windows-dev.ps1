[CmdletBinding()]
param(
  [string]$RepoPath = (Split-Path -Parent $PSScriptRoot),
  [string]$OutputPath = (Join-Path $env:TEMP 'ai-devops-windows-verification.json'),
  [switch]$SkipWingetStateTest
)
$ErrorActionPreference = 'Stop'
$checks = [Collections.Generic.List[object]]::new()
function Check-Command([string]$Name) {
  $command = Get-Command $Name -ErrorAction SilentlyContinue
  $checks.Add([pscustomobject]@{ Check="command:$Name"; Passed=[bool]$command; Detail=$(if($command){$command.Source}else{'not found'}) })
}
@('winget','git','pwsh','node','python','gh','op','gcloud','az','cloudflared','wsl','claude','vercel','trigger.dev','supabase') | ForEach-Object { Check-Command $_ }

$codexApp = Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object {
  $_.Name -like '*Codex*' -or $_.PackageFamilyName -like '*Codex*'
} | Select-Object -First 1
$checks.Add([pscustomobject]@{
  Check='app:CodexDesktop'; Passed=[bool]$codexApp
  Detail=$(if($codexApp){$codexApp.PackageFullName}else{'Microsoft Store app not found'})
})

$config = Join-Path $RepoPath '.config\configuration.winget'
$checks.Add([pscustomobject]@{ Check='configuration:file'; Passed=(Test-Path $config); Detail=$config })
$setup = Join-Path $RepoPath 'bin\setup-machine.ps1'
$checks.Add([pscustomobject]@{ Check='machine-setup:file'; Passed=(Test-Path $setup); Detail=$setup })

$sshd = Get-Service sshd -ErrorAction SilentlyContinue
$checks.Add([pscustomobject]@{ Check='remote:sshd'; Passed=($sshd -and $sshd.Status -eq 'Running'); Detail=$(if($sshd){$sshd.Status}else{'not installed'}) })
$winrm = Get-CimInstance Win32_Service -Filter "Name='WinRM'" -ErrorAction SilentlyContinue
$checks.Add([pscustomobject]@{ Check='remote:winrm-disabled'; Passed=($winrm -and $winrm.State -eq 'Stopped' -and $winrm.StartMode -eq 'Disabled'); Detail=$(if($winrm){"$($winrm.State)/$($winrm.StartMode)"}else{'not found'}) })
$sshRule = Get-NetFirewallRule -DisplayName 'OpenSSH Server — Tailscale only' -ErrorAction SilentlyContinue
$checks.Add([pscustomobject]@{ Check='remote:tailscale-firewall'; Passed=[bool]($sshRule -and $sshRule.Enabled); Detail=$(if($sshRule){$sshRule.DisplayName}else{'not found'}) })

$ubuntu = @(& wsl.exe --list --quiet 2>$null | ForEach-Object { ($_ -replace "`0", '').Trim() } | Where-Object { $_ -match '^Ubuntu' } | Select-Object -First 1)
if ($ubuntu.Count) {
  & wsl.exe -d $ubuntu[0] -u root -- bash -lc 'command -v ansible >/dev/null && command -v ansible-lint >/dev/null'
  $checks.Add([pscustomobject]@{ Check='controller:wsl-ansible'; Passed=($LASTEXITCODE -eq 0); Detail=$ubuntu[0] })
} else {
  $checks.Add([pscustomobject]@{ Check='controller:wsl-ansible'; Passed=$false; Detail='Ubuntu WSL not initialized' })
}

if (-not $SkipWingetStateTest -and (Get-Command winget -ErrorAction SilentlyContinue) -and (Test-Path $config)) {
  winget configure test -f $config --accept-configuration-agreements --disable-interactivity | Out-Host
  $checks.Add([pscustomobject]@{ Check='configuration:desired-state'; Passed=($LASTEXITCODE -eq 0); Detail="exit code $LASTEXITCODE" })
}

$parent = Split-Path -Parent $OutputPath
if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
$checks | ConvertTo-Json -Depth 3 | Set-Content -Encoding utf8 $OutputPath
$checks | Format-Table -AutoSize | Out-Host
Write-Host "Verification report: $OutputPath"
if ($checks.Passed -contains $false) { exit 1 }
exit 0
