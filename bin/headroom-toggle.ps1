<#
.SYNOPSIS
  Turn the Headroom token-compression proxy ON or OFF for THIS Windows machine.

.DESCRIPTION
  Headroom is a single point of failure. When Claude is pointed at it, Claude
  cannot reach Anthropic at all if the hetz VPS is down, the proxy is stopped,
  or this machine's Tailscale link drops. There is NO automatic fallback --
  Claude Code has no "try the proxy, then go direct" behaviour.

  This script is the escape hatch. Run:

      pwsh bin/headroom-toggle.ps1 off      # go straight to Anthropic
      pwsh bin/headroom-toggle.ps1 on       # route through the proxy
      pwsh bin/headroom-toggle.ps1 status   # show current setting + reachability

  Either way, fully quit Claude (tray icon -> Quit) and reopen it afterwards.
  The setting is only read at startup.

  See docs/headroom.md for the full picture.
#>
[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [ValidateSet('on', 'off', 'status')]
  [string]$Action = 'status'
)

$ErrorActionPreference = 'Stop'

$ProxyUrl    = 'http://<removed-protected-address>:8787'
$SettingsDir = Join-Path $env:USERPROFILE '.claude'
$Settings    = Join-Path $SettingsDir 'settings.json'

function Test-Proxy {
  try {
    $r = Invoke-RestMethod -Uri "$ProxyUrl/health" -TimeoutSec 6
    return [pscustomobject]@{ Reachable = $true; Status = $r.status }
  } catch {
    return [pscustomobject]@{ Reachable = $false; Status = $_.Exception.Message }
  }
}

if (-not (Test-Path $Settings)) { throw "Not found: $Settings" }

$json = Get-Content $Settings -Raw | ConvertFrom-Json
$current = $null
if ($json.PSObject.Properties.Name -contains 'env' -and $json.env) {
  if ($json.env.PSObject.Properties.Name -contains 'ANTHROPIC_BASE_URL') {
    $current = $json.env.ANTHROPIC_BASE_URL
  }
}

if ($Action -eq 'status') {
  $health = Test-Proxy
  if ($current) {
    Write-Host "Claude on this machine routes through: $current" -ForegroundColor Cyan
  } else {
    Write-Host 'Claude on this machine goes DIRECT to Anthropic (proxy off).' -ForegroundColor Cyan
  }
  if ($health.Reachable) {
    Write-Host "Proxy health: reachable ($($health.Status))" -ForegroundColor Green
  } else {
    Write-Host "Proxy health: NOT REACHABLE -- $($health.Status)" -ForegroundColor Red
    if ($current) {
      Write-Host 'Claude WILL FAIL to connect. Run:  pwsh bin/headroom-toggle.ps1 off' -ForegroundColor Yellow
    }
  }
  return
}

# Back up before every change -- never overwrite without a way back.
$backup = "$Settings.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item $Settings $backup -Force

if ($Action -eq 'on') {
  $health = Test-Proxy
  if (-not $health.Reachable) {
    Write-Host "Refusing to enable: proxy is not reachable -- $($health.Status)" -ForegroundColor Red
    Write-Host 'Turning it on now would leave Claude unable to connect at all.' -ForegroundColor Red
    Remove-Item $backup -Force
    exit 1
  }
  if (-not ($json.PSObject.Properties.Name -contains 'env') -or -not $json.env) {
    $json | Add-Member -NotePropertyName env -NotePropertyValue ([pscustomobject]@{}) -Force
  }
  $json.env | Add-Member -NotePropertyName ANTHROPIC_BASE_URL -NotePropertyValue $ProxyUrl -Force
  $msg = "Proxy ON  -> $ProxyUrl"
} else {
  if ($json.env -and ($json.env.PSObject.Properties.Name -contains 'ANTHROPIC_BASE_URL')) {
    $json.env.PSObject.Properties.Remove('ANTHROPIC_BASE_URL')
  }
  $msg = 'Proxy OFF -> Claude goes straight to Anthropic'
}

$json | ConvertTo-Json -Depth 100 | Set-Content $Settings -Encoding utf8
Write-Host $msg -ForegroundColor Green
Write-Host "Backup: $backup" -ForegroundColor DarkGray
Write-Host 'Now fully quit Claude (tray icon -> Quit) and reopen it.' -ForegroundColor Yellow
