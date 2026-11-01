# Focused native custody tests; writes only a newly-created private directory.
param([string]$Supervisor=(Join-Path $PSScriptRoot '..\tools\github-requests\source_generation_windows.ps1'))
$ErrorActionPreference='Stop'
if ($env:OS -ne 'Windows_NT') { throw 'Native Windows required' }
$text=[IO.File]::ReadAllText($Supervisor)
$source=[regex]::Match($text,"(?s)Add-Type -TypeDefinition @'\r?\n(.*?)\r?\n'@").Groups[1].Value
if (-not $source) { throw 'Supervisor native custody class missing' }
Add-Type -TypeDefinition $source
$root=Join-Path ([IO.Path]::GetTempPath()) ('ai-gh-generation-test-'+[Guid]::NewGuid().ToString('N'))
$passed=0
function Assert([bool]$Condition,[string]$Name){if(-not $Condition){throw $Name};$script:passed++}
function Refuses([scriptblock]$Operation,[string]$Name){$refused=$false;try{& $Operation}catch{$refused=$true};Assert $refused $Name}
[GenerationCustody]::PrivateDirectory($root)
$file=Join-Path $root 'sealed.sh'
$ordinary=Join-Path $root 'canonical.sh'
[IO.File]::WriteAllText($file,'sealed bytes')
[IO.File]::WriteAllText($ordinary,'canonical bytes')
$directory=[GenerationCustody]::Hold($root,$true,$false)
$held=[GenerationCustody]::Hold($file,$false,$true)
try {
    Refuses { [IO.File]::WriteAllText($file,'altered') } 'Held source must reject writes'
    Refuses { [IO.File]::Move($file,(Join-Path $root 'renamed.sh')) } 'Held source must reject rename'
    Refuses { [IO.File]::Delete($file) } 'Held source must reject delete'
    Refuses { [IO.Directory]::Move($root,($root+'-renamed')) } 'Held ancestor must reject rename'
    [IO.File]::WriteAllText($ordinary,'canonical still writable')
    Assert (([IO.File]::ReadAllText($ordinary)) -eq 'canonical still writable') 'Canonical remains writable'
    Assert (([IO.File]::ReadAllText($file)) -eq 'sealed bytes') 'Held source remains readable'
    $again=[GenerationCustody]::Hold($file,$false,$true)
    try { Assert ([GenerationCustody]::Same($held,$again)) 'Identity binds same bytes' } finally { $again.Dispose() }
    $other=[GenerationCustody]::Hold($ordinary,$false,$true)
    try { Assert (-not [GenerationCustody]::Same($held,$other)) 'Different identity refuses' } finally { $other.Dispose() }
    Assert ([GenerationCustody]::Quote('') -eq '""') 'Empty argument preserved'
    Assert ([GenerationCustody]::Quote('plain') -eq 'plain') 'Plain argument preserved'
    Assert ([GenerationCustody]::Quote('two words') -eq '"two words"') 'Spaced argument preserved'
    Assert ([GenerationCustody]::Quote('a"b') -eq '"a\"b"') 'Quote argument preserved'
    $powershell=Join-Path $PSHOME 'powershell.exe'
    $job=[GenerationCustody]::Job()
    $process=[GenerationCustody]::Start($job,$powershell,'-NoProfile -Command "exit 17"',$root)
    try {$process.WaitForExit();Assert ($process.ExitCode -eq 17) 'Original child exit preserved'} finally {$process.Dispose();$job.Dispose()}
    $job=[GenerationCustody]::Job()
    $process=[GenerationCustody]::Start($job,$powershell,'-NoProfile -Command "Start-Sleep -Seconds 30"',$root)
    try {$job.Dispose();Assert ($process.WaitForExit(10000)) 'Cancellation closes child job'} finally {$process.Dispose();$job.Dispose()}
    $junction=Join-Path $root 'junction'
    New-Item -ItemType Junction -Path $junction -Target $root | Out-Null
    try { Refuses {$h=[GenerationCustody]::Hold($junction,$true,$false);$h.Dispose()} 'Reparse directory refuses' } finally {[IO.Directory]::Delete($junction)}
    $link=Join-Path $root 'hardlink.sh'
    & fsutil hardlink create $link $file | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Hardlink fixture unavailable' }
    Refuses { $h=[GenerationCustody]::Hold($link,$false,$true);$h.Dispose() } 'Hardlinked source refuses'
    Remove-Item -LiteralPath $link
} finally { $held.Dispose();$directory.Dispose();Remove-Item -LiteralPath $root -Recurse -Force }
Write-Output "PASS $passed native Windows source custody cases"
