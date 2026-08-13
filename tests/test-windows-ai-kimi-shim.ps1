$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
$installer = Join-Path $repo "bin\install-machine-tools.ps1"
$catalog = Join-Path $repo "config\machine-tools.tsv"
$text = Get-Content -Raw $installer
foreach ($required in @('bash+cmd', 'Set-Content -NoNewline -Encoding ASCII', 'SetEnvironmentVariable')) {
  if (-not $text.Contains($required)) { throw "Missing catalog installer control: $required" }
}
$rows = Get-Content $catalog | Where-Object { $_ -and -not $_.StartsWith('#') }
$names = $rows | ForEach-Object { ($_ -split "`t")[0] }
foreach ($name in @('ai-grok-review','ai-grok-implement','ai-kimi','ai-deepseek-agent','ai-glm')) {
  if ($names -notcontains $name) { throw "Catalog missing $name" }
}
$glm = $rows | Where-Object { $_.StartsWith("ai-glm`t") }
if (($glm -split "`t")[2] -ne 'cmd-only-external') { throw 'GLM must remain cmd-only-external' }
foreach ($file in @($installer)) {
  $bytes = [IO.File]::ReadAllBytes($file)
  if ($bytes | Where-Object { $_ -gt 127 }) { throw "PowerShell file is not ASCII: $file" }
  [void][scriptblock]::Create((Get-Content -Raw $file))
}
[void][scriptblock]::Create((Get-Content -Raw (Join-Path $repo 'bin\setup-machine.ps1')))
Write-Host "PASS: catalog-driven Windows launcher controls are valid"
