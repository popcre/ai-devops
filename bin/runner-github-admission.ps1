<#
.SYNOPSIS
Route the fixed Windows runner maintenance operations through ai-gh.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][ValidateSet('list','remove-token','delete','registration-token')][string]$Operation,
  [Parameter(Mandatory)][string]$Repository,
  [long]$RunnerId = 0
)

$ErrorActionPreference = 'Stop'
if ($Repository -cnotmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
  throw 'Invalid runner repository.'
}
if ($Operation -eq 'delete' -and $RunnerId -le 0) {
  throw 'Invalid runner ID.'
}

$admission = Join-Path $PSScriptRoot 'ai-gh.cmd'
if (-not (Test-Path -LiteralPath $admission -PathType Leaf)) {
  throw 'Shared GitHub admission is unavailable.'
}
$endpoint = "repos/$Repository/actions/runners"
$arguments = switch ($Operation) {
  'list'               { @('api', $endpoint) }
  'remove-token'       { @('api', '--method', 'POST', "$endpoint/remove-token", '--jq', '.token') }
  'delete'             { @('api', '--method', 'DELETE', "$endpoint/$RunnerId") }
  'registration-token' { @('api', '--method', 'POST', "$endpoint/registration-token", '--jq', '.token') }
}

$response = & $admission @arguments
if ($LASTEXITCODE -ne 0) {
  throw "Shared GitHub admission failed for runner $Operation."
}
$response
