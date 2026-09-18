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
@('winget','git','pwsh','node','python','gh','op','gcloud','az','cloudflared','wsl','claude','grok','kimi','vercel','trigger.dev','railway','supabase') | ForEach-Object { Check-Command $_ }

$codexApp = Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object {
  $_.Name -like '*Codex*' -or $_.PackageFamilyName -like '*Codex*'
} | Select-Object -First 1
$checks.Add([pscustomobject]@{
  Check='app:CodexDesktop'; Passed=[bool]$codexApp
  Detail=$(if($codexApp){$codexApp.PackageFullName}else{'Microsoft Store app not found'})
})

# ZCode desktop app (Windows-only client; machine-wide install). Presence only --
# the app self-updates, so no version is pinned or asserted here.
$zcodeAppExe = Join-Path $env:ProgramFiles 'ZCode\ZCode.exe'
$zcodeCliCore = Join-Path $env:ProgramFiles 'ZCode\resources\glm\zcode.cjs'
$zcodePassed = (Test-Path -LiteralPath $zcodeAppExe) -and (Test-Path -LiteralPath $zcodeCliCore)
$checks.Add([pscustomobject]@{
  Check='app:ZCode'; Passed=$zcodePassed
  Detail=$(if($zcodePassed){
    $v = (Get-Item -LiteralPath $zcodeAppExe).VersionInfo.ProductVersion
    "desktop $v; cli core present"
  }else{
    "not found at $zcodeAppExe (winget install ZhipuAI.ZCode)"
  })
})

$config = Join-Path $RepoPath '.config\configuration.winget'
$checks.Add([pscustomobject]@{ Check='configuration:file'; Passed=(Test-Path $config); Detail=$config })
$setup = Join-Path $RepoPath 'bin\setup-machine.ps1'
$checks.Add([pscustomobject]@{ Check='machine-setup:file'; Passed=(Test-Path $setup); Detail=$setup })

$runnerServices = @(Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object {
  $_.Name -like 'actions.runner.*' -or $_.PathName -match 'Runner\.Listener\.exe'
})
$runnerPassed = ($runnerServices.Count -eq 0) -or -not ($runnerServices | Where-Object { $_.State -ne 'Running' })
$runnerDetail = if ($runnerServices.Count -eq 0) {
  'official runner not installed; compatibility policy verified separately'
} else {
  ($runnerServices | ForEach-Object { "$($_.Name)=$($_.State)" }) -join '; '
}
$checks.Add([pscustomobject]@{ Check='compatibility:github-runner-listener'; Passed=$runnerPassed; Detail=$runnerDetail })

$smartAppPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy'
$smartAppState = try { [int](Get-ItemPropertyValue -LiteralPath $smartAppPath -Name 'VerifiedAndReputablePolicyState' -ErrorAction Stop) } catch { $null }
$smartAppRequired = $runnerServices.Count -gt 0
$smartAppRefreshMarker = Join-Path $env:ProgramData 'ai-devops\smart-app-control-off-refreshed.json'
$checks.Add([pscustomobject]@{
  Check='compatibility:smart-app-control-off'; Passed=(-not $smartAppRequired -or ($smartAppState -eq 0 -and (Test-Path -LiteralPath $smartAppRefreshMarker)))
  Detail=$(if (-not $smartAppRequired) { 'not required: official GitHub runner is not installed' } elseif ($null -eq $smartAppState) { 'state missing; runner host requires 0 (Off)' } elseif (-not (Test-Path -LiteralPath $smartAppRefreshMarker)) { 'registry is Off but active-policy refresh is unproven' } else { "state=$smartAppState; active-policy refresh marker present" })
})

$sshd = Get-Service sshd -ErrorAction SilentlyContinue
$checks.Add([pscustomobject]@{ Check='remote:sshd'; Passed=($sshd -and $sshd.Status -eq 'Running'); Detail=$(if($sshd){$sshd.Status}else{'not installed'}) })
$winrm = Get-CimInstance Win32_Service -Filter "Name='WinRM'" -ErrorAction SilentlyContinue
$checks.Add([pscustomobject]@{ Check='remote:winrm-disabled'; Passed=($winrm -and $winrm.State -eq 'Stopped' -and $winrm.StartMode -eq 'Disabled'); Detail=$(if($winrm){"$($winrm.State)/$($winrm.StartMode)"}else{'not found'}) })
$sshRule = Get-NetFirewallRule -DisplayName 'OpenSSH Server - Tailscale only' -ErrorAction SilentlyContinue
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
