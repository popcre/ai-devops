Set-StrictMode -Version Latest

function Update-AiDevOpsJsonFileAtomic {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][scriptblock]$Update,
    [int]$Depth = 20
  )
  $exists = Test-Path -LiteralPath $Path
  $originalBytes = $null
  if ($exists) {
    $originalBytes = [IO.File]::ReadAllBytes($Path)
    try { $document = ([Text.Encoding]::UTF8.GetString($originalBytes) | ConvertFrom-Json -AsHashtable) }
    catch { throw "Refusing to replace malformed JSON at $Path. Repair it first; the live file is unchanged." }
  } else { $document = @{} }

  $updated = & $Update $document
  if ($null -eq $updated) { $updated = $document }
  $json = $updated | ConvertTo-Json -Depth $Depth
  try { $null = $json | ConvertFrom-Json -AsHashtable }
  catch { throw "Generated JSON for $Path did not validate; the live file is unchanged." }
  $newBytes = [Text.UTF8Encoding]::new($false).GetBytes($json + [Environment]::NewLine)
  if ($exists -and ([Convert]::ToHexString($originalBytes) -eq [Convert]::ToHexString($newBytes))) {
    return [pscustomobject]@{ Changed=$false; Backup=$null; Value=$updated }
  }

  $parent = Split-Path -Parent $Path
  New-Item -ItemType Directory -Force -Path $parent | Out-Null
  $candidate = Join-Path $parent ('.ai-devops-json-' + [guid]::NewGuid().ToString('N') + '.tmp')
  $backup = $null
  try {
    [IO.File]::WriteAllBytes($candidate, $newBytes)
    try { $null = (Get-Content -Raw -LiteralPath $candidate | ConvertFrom-Json -AsHashtable) }
    catch { throw "Atomic JSON candidate for $Path did not parse; the live file is unchanged." }
    if ($exists) {
      $stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
      $backup = "$Path.aidevops.$stamp.bak"
      Copy-Item -LiteralPath $Path -Destination $backup
      if ((Get-FileHash -LiteralPath $Path).Hash -ne (Get-FileHash -LiteralPath $backup).Hash) {
        throw "Backup verification failed for $Path; the live file is unchanged."
      }
    }
    [IO.File]::Move($candidate, $Path, $true)
    $null = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -AsHashtable
    return [pscustomobject]@{ Changed=$true; Backup=$backup; Value=$updated }
  } finally {
    if (Test-Path -LiteralPath $candidate) { Remove-Item -LiteralPath $candidate -Force }
  }
}
