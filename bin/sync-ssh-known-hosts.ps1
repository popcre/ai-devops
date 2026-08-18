[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$TemplatePath,
  [string]$KnownHostsPath = (Join-Path $env:USERPROFILE '.ssh\known_hosts')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $TemplatePath)) {
  throw "Managed SSH known-hosts template is missing: $TemplatePath"
}

$managedKeys = Get-Content -LiteralPath $TemplatePath | Where-Object {
  $_.Trim() -and -not $_.TrimStart().StartsWith('#')
}
$backupCreated = $false
foreach ($managedKey in $managedKeys) {
  $hostList = ($managedKey -split '\s+', 2)[0]
  $lookupHost = ($hostList -split ',')[0]
  $existing = if (Test-Path $KnownHostsPath) { & ssh-keygen -F $lookupHost -f $KnownHostsPath 2>$null } else { @() }
  if ($existing -contains $managedKey) {
    Write-Host "OK: Verified SSH server key already registered for $hostList"
    continue
  }

  if ((Test-Path $KnownHostsPath) -and -not $backupCreated) {
    $backup = "$KnownHostsPath.ai-devops-before-managed-update-$(Get-Date -Format 'yyyyMMddHHmmssfff')"
    Copy-Item -LiteralPath $KnownHostsPath -Destination $backup -ErrorAction Stop
    $backupCreated = $true
  } else {
    if (-not (Test-Path $KnownHostsPath)) {
      New-Item -ItemType File -Force -Path $KnownHostsPath | Out-Null
    }
  }
  foreach ($knownHost in ($hostList -split ',')) {
    & ssh-keygen -R $knownHost -f $KnownHostsPath | Out-Null
    if ($LASTEXITCODE -ne 0) {
      throw "Could not remove the prior SSH server key for $knownHost"
    }
  }
  Add-Content -LiteralPath $KnownHostsPath -Value $managedKey -Encoding ascii
  Write-Host "OK: Registered verified SSH server key for $hostList"
}
