$ErrorActionPreference = 'Stop'

# Load the setup probe without running machine setup.
$setup = Join-Path (Split-Path -Parent $PSScriptRoot) 'bin/setup-machine.ps1'
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($setup, [ref]$null, [ref]$parseErrors)
if ($parseErrors) { throw "Could not parse Windows setup: ${parseErrors}" }
$probe = $ast.Find({
  param($node)
  $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
    $node.Name -eq 'Test-CodexSandboxWrite'
}, $true)
. ([scriptblock]::Create($probe.Extent.Text))

function Invoke-FakeCodex {
  $script:ProbeRan = $true
  if ($args -contains '--skip-git-repo-check') { throw 'The probe bypassed the Git requirement.' }
  if ($env:GIT_DIR -or $env:GIT_CONFIG_NOSYSTEM -ne '1') { throw 'The probe inherited caller Git state.' }
  & git rev-parse --verify HEAD | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'The probe was missing its committed baseline.' }
  Set-Content -LiteralPath 'probe.txt' -Value 'OK'
}

$originalGitDir = $env:GIT_DIR
$env:GIT_DIR = 'caller-git-dir-for-test'
try {
  if (-not (Test-CodexSandboxWrite Invoke-FakeCodex)) { throw 'Codex write was not detected.' }
  if ($env:GIT_DIR -ne 'caller-git-dir-for-test') { throw 'The probe changed the caller Git environment.' }

  function git { $global:LASTEXITCODE = 1 }
  $script:ProbeRan = $false
  $fixtureFailure = $null
  try {
    Test-CodexSandboxWrite Invoke-FakeCodex | Out-Null
  } catch {
    $fixtureFailure = $_.Exception.Message
  }
  if ($fixtureFailure -notlike '*Codex was not tested*' -or $script:ProbeRan) {
    throw 'Invalid scratch setup must stop before the Codex call and explain what was skipped.'
  }
} finally {
  [Environment]::SetEnvironmentVariable('GIT_DIR', ($originalGitDir ?? [NullString]::Value), 'Process')
}
Write-Host 'PASS: Windows Codex probe uses an isolated committed baseline and skips invalid setup.'
