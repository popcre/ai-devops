# Host gate shared by every job in windows-runner-qualification.yml: Windows 11,
# fresh Administrator security evidence, service-visible runtimes and exactly
# one automatic runner service. Run by the runner service itself.
$ErrorActionPreference = 'Stop'
$build = [int](Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuildNumber
if ($build -lt 22000) { throw "Windows 11 is required; build is $build." }
$evidencePath = 'C:\ProgramData\ai-devops\windows-runner-security.json'
if (-not (Test-Path -LiteralPath $evidencePath -PathType Leaf)) {
  throw 'Administrator security preflight evidence is missing.'
}
$evidence = Get-Content -Raw -LiteralPath $evidencePath | ConvertFrom-Json
if ($evidence.schema_version -ne 1) { throw 'Administrator security preflight schema is unsupported.' }
if ($evidence.windows_build -ne $build) { throw 'Administrator security preflight is for a different Windows build.' }
if (-not $evidence.tpm_present -or -not $evidence.tpm_ready -or -not $evidence.secure_boot) {
  throw 'Administrator security preflight did not prove TPM and Secure Boot.'
}
$evidenceAge = [DateTime]::UtcNow - [DateTime]::Parse($evidence.recorded_at_utc).ToUniversalTime()
if ([math]::Abs($evidenceAge.TotalHours) -gt 24) {
  throw 'Administrator security preflight evidence is not fresh.'
}
foreach ($tool in @('git', 'gh', 'jq', 'pwsh', 'node', 'python')) {
  if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
    throw "$tool is not visible to the runner service account."
  }
}
if (-not (Test-Path 'C:\Program Files\Git\bin\bash.exe')) {
  throw 'Git Bash is not installed at the supported machine-wide path.'
}
$runnerService = Get-Service | Where-Object Name -Like 'actions.runner.*'
if (@($runnerService).Count -ne 1) { throw "Exactly one GitHub Actions runner service is required; found $(@($runnerService).Count)." }
if ($runnerService.Status -ne 'Running') { throw 'GitHub Actions runner service is not running.' }
$serviceConfig = $runnerService | ForEach-Object { Get-CimInstance Win32_Service -Filter "Name='$($_.Name)'" }
if ($serviceConfig.StartMode -ne 'Auto') { throw 'GitHub Actions runner service is not automatic.' }
"Qualified host build=$build runner=$env:RUNNER_NAME security_evidence_age_minutes=$([math]::Round($evidenceAge.TotalMinutes))"
