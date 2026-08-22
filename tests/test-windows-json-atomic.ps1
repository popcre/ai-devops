$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'bin\windows-json-file.ps1')
$temp = Join-Path ([IO.Path]::GetTempPath()) ('ai-devops-json-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $temp | Out-Null
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw "FAIL: $Message" } }

try {
  $path = Join-Path $temp 'config.json'
  '{broken' | Set-Content -LiteralPath $path -NoNewline
  $before = [IO.File]::ReadAllBytes($path)
  $failed=$false
  try { Update-AiDevOpsJsonFileAtomic -Path $path -Update { param($x) $x } | Out-Null } catch { $failed=$true }
  Assert $failed 'malformed live JSON did not fail'
  Assert (([Convert]::ToHexString($before)) -eq ([Convert]::ToHexString([IO.File]::ReadAllBytes($path)))) 'malformed live JSON changed'
  Assert (@(Get-ChildItem $temp -Filter '*.bak').Count -eq 0) 'malformed JSON created a false backup'

  '{"keep":1}' | Set-Content -LiteralPath $path -NoNewline
  $one = Update-AiDevOpsJsonFileAtomic -Path $path -Update { param($x) $x['added']=2; $x }
  Assert (Test-Path -LiteralPath $one.Backup) 'first known-good backup missing'
  $firstBackupHash=(Get-FileHash -LiteralPath $one.Backup).Hash
  $two = Update-AiDevOpsJsonFileAtomic -Path $path -Update { param($x) $x['added']=3; $x }
  Assert ($two.Backup -ne $one.Backup) 'second run overwrote the last backup name'
  Assert ((Get-FileHash -LiteralPath $one.Backup).Hash -eq $firstBackupHash) 'second run changed the prior backup'
  Assert ((Get-Content -Raw $path | ConvertFrom-Json).added -eq 3) 'atomic JSON publication failed'
  Write-Host 'PASS: malformed JSON stays byte-identical and every atomic update retains a unique known-good backup'
} finally {
  Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
