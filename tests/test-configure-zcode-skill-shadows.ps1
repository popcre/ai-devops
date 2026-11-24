$ErrorActionPreference = "Stop"

# ZCode lists a skill twice when ~/.agents/skills holds a same-named copy of a
# toolkit skill, and every ZCode subagent then refuses the bare name
# (popcre/ai-devops #2795). The writer hides the second copy from ZCode through
# ZCode's own per-skill switch. These checks pin what it may write, what it must
# preserve, and what it must refuse.
#
# The writer runs inside the Windows installer, which the documented install
# commands start with Windows PowerShell 5.1, while this suite runs under
# PowerShell 7. So every scenario runs once per engine present on the machine.

$passed = 0
$failed = 0

function Assert-True([bool]$Condition, [string]$Message) {
  if ($Condition) { Write-Host "  ok   $Message"; $script:passed++ }
  else {
    # The last writer output is what a failed check is about to ask for.
    if ($script:lastOutput) { Write-Host "       writer said: $($script:lastOutput.Trim() -replace "\r?\n", " | ")" }
    Write-Host "  FAIL $Message"; $script:failed++
  }
}

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$scriptPath = Join-Path $repoRoot "bin\configure-zcode-skill-shadows.ps1"
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("zcode-skill-shadows-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $testRoot | Out-Null

$onWindows = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT

$engines = @()
if (Get-Command powershell.exe -ErrorAction SilentlyContinue) { $engines += "powershell.exe" }
if (Get-Command pwsh -ErrorAction SilentlyContinue) { $engines += "pwsh" }

function New-Skill([string]$Root, [string]$Name, [switch]$Managed) {
  $dir = Join-Path $Root "$Name"
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  @("---", "name: $Name", "description: test", "---") | Set-Content -LiteralPath (Join-Path $dir "SKILL.md")
  if ($Managed) { "# ai-devops managed skill." | Set-Content -LiteralPath (Join-Path $dir ".ai-devops-managed") }
}

function New-Fixture([string]$Name) {
  $root = Join-Path $testRoot $Name
  # Not $home: PowerShell variable names are case-insensitive and $HOME is read-only.
  $zhome = Join-Path $root "zcode-home"
  $agents = Join-Path $root "agents\skills"
  New-Item -ItemType Directory -Force -Path $zhome, $agents | Out-Null
  # Toolkit skills carry the managed marker; gamma is somebody else's skill.
  New-Skill (Join-Path $zhome "skills") "alpha" -Managed
  New-Skill (Join-Path $zhome "skills") "beta" -Managed
  New-Skill (Join-Path $zhome "skills") "gamma"
  New-Skill (Join-Path $zhome "skills-quarantine") "retired-one"
  New-Skill $agents "alpha"
  New-Skill $agents "gamma"
  New-Skill $agents "retired-one"
  New-Skill $agents "delta"
  # Folders ZCode's scanner never descends into are not skills.
  New-Skill (Join-Path $agents "node_modules") "nested"
  New-Skill (Join-Path $agents ".hidden") "dotted"
  return @{ Root = $root; Home = $zhome; Agents = $agents; Config = (Join-Path $zhome "cli\config.json") }
}

function Get-SkillEntryNames([string]$Path) {
  $config = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
  return @($config.skill.PSObject.Properties | ForEach-Object { $_.Name })
}

# Run the writer in a fresh process of the given engine, so the edition is the
# one under test. Output goes to files: Windows PowerShell 5.1 turns a child's
# stderr into a terminating error when this suite's preference is Stop.
function Invoke-Writer([string]$Engine, [string]$Label, [string[]]$WriterArguments) {
  $stdout = Join-Path $testRoot "$Label.out"
  $stderr = Join-Path $testRoot "$Label.err"
  $quoted = @($WriterArguments | ForEach-Object { '"' + $_ + '"' })
  $process = Start-Process -FilePath $Engine -ArgumentList (@("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $scriptPath) + $quoted) `
    -RedirectStandardOutput $stdout -RedirectStandardError $stderr -NoNewWindow -PassThru
  # Windows PowerShell 5.1 fills ExitCode only when the handle was held.
  $null = $process.Handle
  $process.WaitForExit()
  $text = (([IO.File]::ReadAllText($stdout)) + ([IO.File]::ReadAllText($stderr)))
  $script:lastOutput = $text
  return @{
    ExitCode = $process.ExitCode
    Output = $text
  }
}

$foreignKey = Join-Path $testRoot "elsewhere\someone-elses-skill\SKILL.md"
$fixturesWithJunction = @()

try {
  foreach ($engine in $engines) {
    $tag = $engine -replace "[^a-z0-9]", ""
    Write-Host "Engine: $engine"

    $f = New-Fixture $tag
    $alphaKey = [IO.Path]::GetFullPath((Join-Path $f.Agents "alpha\SKILL.md"))
    $retiredKey = [IO.Path]::GetFullPath((Join-Path $f.Agents "retired-one\SKILL.md"))
    $deltaKey = [IO.Path]::GetFullPath((Join-Path $f.Agents "delta\SKILL.md"))
    $gammaKey = [IO.Path]::GetFullPath((Join-Path $f.Agents "gamma\SKILL.md"))
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $f.Config) | Out-Null
    # A prior run hid retired-one; the toolkit has since retired it. delta was
    # disabled by a person, and so was a skill that lives somewhere else.
    @'
{
  "mcp": { "servers": { "mine": { "command": "my-exe", "args": ["--x"] } } },
  "plugins": { "enabledPlugins": { "computer-use@zcode-plugins-official": true } },
  "skill": {
    "RETIRED": { "enable": false },
    "DELTA": { "enable": false },
    "FOREIGN": { "enable": false }
  }
}
'@.Replace("RETIRED", $retiredKey.Replace("\", "\\")).Replace("DELTA", $deltaKey.Replace("\", "\\")).Replace("FOREIGN", $foreignKey.Replace("\", "\\")) |
      Set-Content -LiteralPath $f.Config -Encoding utf8

    # -- 1. Dry run reports the pending change and writes nothing --------------
    $before = [IO.File]::ReadAllText($f.Config)
    $r = Invoke-Writer $engine "$tag-dry" @("-ZCodeHome", $f.Home, "-AgentsSkillsRoot", $f.Agents, "-DryRun")
    Assert-True ($r.ExitCode -eq 0) "dry run exits 0"
    Assert-True ($r.Output -match [regex]::Escape("[skills-dry-run] + hide $alphaKey")) "dry run names the copy it would hide"
    Assert-True ($r.Output -match [regex]::Escape("[skills-dry-run] - stop hiding $retiredKey")) "dry run names the stale entry it would remove"
    Assert-True ([IO.File]::ReadAllText($f.Config) -ceq $before) "dry run left the config untouched"

    # -- 2. Real run: one entry added, one stale entry removed, rest kept ------
    $r = Invoke-Writer $engine "$tag-write" @("-ZCodeHome", $f.Home, "-AgentsSkillsRoot", $f.Agents)
    Assert-True ($r.ExitCode -eq 0) "write exits 0"
    Assert-True ($r.Output -match "skill shadows configured: \+1 -1; 1 hidden") "write reports +1 added, 1 removed, 1 hidden"
    $names = Get-SkillEntryNames $f.Config
    Assert-True ($names -ccontains $alphaKey) "shadowed toolkit skill alpha is hidden by its absolute SKILL.md path"
    Assert-True ($names -cnotcontains $retiredKey) "stale entry for the retired toolkit skill is removed"
    Assert-True ($names -ccontains $deltaKey) "a person's own disabled entry under the same root is kept"
    Assert-True ($names -ccontains $foreignKey) "an entry outside the second root is kept"
    Assert-True ($names -cnotcontains $gammaKey) "a doubled skill the toolkit did not install is left alone"
    $config = Get-Content -Raw -LiteralPath $f.Config | ConvertFrom-Json
    $alpha = $config.skill.PSObject.Properties[$alphaKey].Value
    Assert-True (($alpha.PSObject.Properties.Name -join ",") -ceq "enable" -and $alpha.enable -eq $false) "entry is exactly { enable: false }"
    Assert-True ($config.mcp.servers.mine.command -ceq "my-exe") "mcp block preserved"
    Assert-True ($config.plugins.enabledPlugins.'computer-use@zcode-plugins-official' -eq $true) "plugins block preserved"
    $backup = @(Get-ChildItem -LiteralPath (Split-Path -Parent $f.Config) -Filter "config.json.aidevops.*.bak")
    Assert-True ($backup.Count -eq 1) "timestamped backup made before the changed write"
    Assert-True ([IO.File]::ReadAllText($backup[0].FullName) -ceq $before) "backup is the exact prior config"

    # -- 3. Second run is a byte-identical no-op -------------------------------
    $written = [IO.File]::ReadAllText($f.Config)
    $r = Invoke-Writer $engine "$tag-again" @("-ZCodeHome", $f.Home, "-AgentsSkillsRoot", $f.Agents)
    Assert-True ($r.Output -match "already current: 1 hidden") "second run reports already current"
    Assert-True ([IO.File]::ReadAllText($f.Config) -ceq $written) "second run is a byte-identical no-op"
    Assert-True (@(Get-ChildItem -LiteralPath (Split-Path -Parent $f.Config) -Filter "*.bak").Count -eq 1) "second run made no extra backup"

    # Existing ZCode fields survive both a rewrite and a subsequent no-op.
    Add-Member -InputObject $alpha -NotePropertyName "metadata" -NotePropertyValue ([pscustomobject]@{ source = "user" })
    $alpha.enable = $true
    $config | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $f.Config -Encoding utf8
    $r = Invoke-Writer $engine "$tag-metadata" @("-ZCodeHome", $f.Home, "-AgentsSkillsRoot", $f.Agents)
    $withMetadata = [IO.File]::ReadAllText($f.Config)
    $entry = ($withMetadata | ConvertFrom-Json).skill.PSObject.Properties[$alphaKey].Value
    Assert-True ($r.ExitCode -eq 0 -and $entry.enable -eq $false -and $entry.metadata.source -ceq "user") "disabling the entry preserves its other fields"
    $r = Invoke-Writer $engine "$tag-metadata-again" @("-ZCodeHome", $f.Home, "-AgentsSkillsRoot", $f.Agents)
    Assert-True ($r.Output -match "already current: 1 hidden" -and [IO.File]::ReadAllText($f.Config) -ceq $withMetadata) "disabled entry with other fields is already current"

    # -- 4. The second copy disappears: our entry goes with it -----------------
    Remove-Item -LiteralPath (Join-Path $f.Agents "alpha") -Recurse -Force
    $r = Invoke-Writer $engine "$tag-unpaired" @("-ZCodeHome", $f.Home, "-AgentsSkillsRoot", $f.Agents)
    Assert-True ((Get-SkillEntryNames $f.Config) -cnotcontains $alphaKey) "entry removed once the pair is gone"
    Assert-True ((Get-SkillEntryNames $f.Config) -ccontains $deltaKey) "person's entry survives the removal sweep"

    # -- 5. Nothing doubled and no config yet: no file is created --------------
    $f5 = New-Fixture "$tag-none"
    Remove-Item -LiteralPath $f5.Agents -Recurse -Force
    $r = Invoke-Writer $engine "$tag-none" @("-ZCodeHome", $f5.Home, "-AgentsSkillsRoot", $f5.Agents)
    Assert-True ($r.ExitCode -eq 0 -and $r.Output -match "none to hide") "nothing doubled is reported as none to hide"
    Assert-True (-not (Test-Path -LiteralPath $f5.Config)) "no config file created when there is nothing to hide"
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $f5.Home "cli"))) "no cli folder created when there is nothing to hide"

    # -- 6. Malformed JSON is refused, live file unchanged ---------------------
    $f6 = New-Fixture "$tag-malformed"
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $f6.Config) | Out-Null
    '{ "mcp": {' | Set-Content -LiteralPath $f6.Config
    $r = Invoke-Writer $engine "$tag-malformed" @("-ZCodeHome", $f6.Home, "-AgentsSkillsRoot", $f6.Agents)
    Assert-True ($r.ExitCode -ne 0) "malformed config makes the writer exit nonzero"
    Assert-True ($r.Output -match "malformed JSON") "malformed config is named as the reason"
    Assert-True ([IO.File]::ReadAllText($f6.Config) -ceq ('{ "mcp": {' + [Environment]::NewLine)) "malformed config left byte-identical"

    # -- 7. A "skill" key that is not an object is refused ---------------------
    $f7 = New-Fixture "$tag-array"
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $f7.Config) | Out-Null
    '{ "skill": ["not", "an", "object"] }' | Set-Content -LiteralPath $f7.Config
    $r = Invoke-Writer $engine "$tag-array" @("-ZCodeHome", $f7.Home, "-AgentsSkillsRoot", $f7.Agents)
    Assert-True ($r.ExitCode -ne 0 -and $r.Output -match "is not an object") "non-object skill key refused"
    Assert-True (@(Get-ChildItem -LiteralPath (Split-Path -Parent $f7.Config) -Filter "*.bak").Count -eq 0) "refusal made no backup"

    # -- 8. Two roots that are the same folder: nothing is hidden --------------
    # Disabling a path disables its link target too, so an entry here would
    # switch every skill off in ZCode.
    $f8 = New-Fixture "$tag-same"
    $junctionRoot = Join-Path $f8.Root "linked\skills"
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $junctionRoot) | Out-Null
    $target = Join-Path $f8.Home "skills"
    if ($onWindows) {
      & cmd.exe /c mklink /J ("`"$junctionRoot`"") ("`"$target`"") | Out-Null
      $fixturesWithJunction += $junctionRoot
    } else {
      New-Item -ItemType SymbolicLink -Path $junctionRoot -Target $target | Out-Null
    }
    $r = Invoke-Writer $engine "$tag-same" @("-ZCodeHome", $f8.Home, "-AgentsSkillsRoot", $junctionRoot)
    Assert-True ($r.ExitCode -eq 0) "same-folder roots exit 0"
    Assert-True ($r.Output -match "same file in both skill roots") "same-folder roots are reported"
    Assert-True (-not (Test-Path -LiteralPath $f8.Config)) "same-folder roots wrote no config"
  }
}
finally {
  # A junction is removed non-recursively first, so the tree cleanup cannot
  # walk into what it points at.
  foreach ($junction in $fixturesWithJunction) {
    if (Test-Path -LiteralPath $junction) { & cmd.exe /c rmdir "$junction" | Out-Null }
  }
  Remove-Item -Recurse -Force $testRoot -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "$passed passed, $failed failed"
exit $(if ($failed -eq 0) { 0 } else { 1 })
