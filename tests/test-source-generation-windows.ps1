# Focused native custody tests; writes only a newly-created private directory.
param([string]$Supervisor=(Join-Path $PSScriptRoot '..\tools\github-requests\source_generation_windows.ps1'))
$ErrorActionPreference='Stop'
if ($env:OS -ne 'Windows_NT') { throw 'Native Windows required' }
$text=[IO.File]::ReadAllText($Supervisor)
$source=[regex]::Match($text,"(?s)Add-Type -TypeDefinition @'\r?\n(.*?)\r?\n'@").Groups[1].Value
if (-not $source) { throw 'Supervisor native custody class missing' }
Add-Type -TypeDefinition $source
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseInput($text,[ref]$tokens,[ref]$errors)
$guard=$ast.Find({param($node)$node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Assert-ReadArguments'},$true)
. ([scriptblock]::Create($guard.Extent.Text))
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
    $injected=Join-Path $root 'unexpected_module.py'
    [IO.File]::WriteAllText($injected,'unexpected module')
    Refuses {[GenerationCustody]::AssertClosure($root,@('sealed.sh','canonical.sh'))} 'Pre-seal helper insertion refuses qualification'
    [IO.File]::Delete($injected)
    [GenerationCustody]::AssertClosure($root,@('sealed.sh','canonical.sh'))
    $attack=Join-Path $root 'attack.ps1'
    [IO.File]::WriteAllText($attack,@'
$ErrorActionPreference='Stop'
$root=$args[0]
if([Security.Principal.WindowsIdentity]::GetCurrent().User.Value -ne $args[1]){exit 10}
Add-Type -TypeDefinition 'using System;using System.Runtime.InteropServices;public static class ParentIsolationProbe{[DllImport("kernel32.dll")]public static extern IntPtr OpenProcess(uint access,bool inherit,int pid);[DllImport("kernel32.dll")]public static extern bool CloseHandle(IntPtr handle);}'
$parentHandle=[ParentIsolationProbe]::OpenProcess(0x68,$false,[int]$args[2])
if($parentHandle -ne [IntPtr]::Zero){[ParentIsolationProbe]::CloseHandle($parentHandle)|Out-Null;if($args[3] -eq '1'){exit 16}}
try{[IO.File]::WriteAllText((Join-Path $root 'unexpected_module.py'),'attack');exit 11}catch{}
try{[IO.Directory]::CreateDirectory((Join-Path $root 'newmodule'))|Out-Null;exit 12}catch{}
try{$a=Get-Acl -LiteralPath $root;Set-Acl -LiteralPath $root -AclObject $a;exit 13}catch{}
try{[IO.File]::WriteAllText((Join-Path $root 'sealed.sh'),'attack');exit 14}catch{}
if([IO.File]::ReadAllText((Join-Path $root 'sealed.sh')) -ne 'sealed bytes'){exit 15}
exit 0
'@)
    $attackHold=[GenerationCustody]::Hold($attack,$false,$true)
    $control=[GenerationCustody]::DirectoryControl($root)
    try {
        [GenerationCustody]::DirectoryAccess($control,$false)
        $beforePrivileges=[GenerationCustody]::PrivilegedContext()
        $beforePrivilegeState=[GenerationCustody]::PrivilegeState()
        Assert ([GenerationCustody]::DisabledBypassStillDetected()) 'Present disabled bypass privileges remain unqualified'
        $job=[GenerationCustody]::Job()
        $executable=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        $arguments='-NoProfile -File '+[GenerationCustody]::Quote($attack)+' '+[GenerationCustody]::Quote($root)+' '+$sid+' '+$PID+' '+[int]$beforePrivileges
        $process=[GenerationCustody]::Start($job,$executable,$arguments,$root,$true)
        try {$process.WaitForExit();Assert ($process.ExitCode -eq 0) ('Restricted child helper/ACL attacks denied; exit='+$process.ExitCode)} finally {$process.Dispose();$job.Dispose()}
        $job=[GenerationCustody]::Job()
        $process=[GenerationCustody]::Start($job,$executable,'-NoProfile -Command "Start-Sleep -Seconds 30"',$root,$true)
        try {$job.Dispose();Assert ($process.WaitForExit(10000)) 'Restricted cancellation returns to parent cleanup'} finally {$process.Dispose();$job.Dispose()}
        Assert ([GenerationCustody]::PrivilegedContext() -eq $beforePrivileges) 'Parent privileges remain unchanged'
        Assert ([GenerationCustody]::PrivilegeState() -eq $beforePrivilegeState) 'Parent privilege attributes remain unchanged'
        Assert (([IO.File]::ReadAllText($file)) -eq 'sealed bytes') 'Sealed directory remains readable'
    } finally {[GenerationCustody]::DirectoryAccess($control,$true);$control.Dispose();$attackHold.Dispose()}
    [IO.File]::WriteAllText($injected,'parent restoration works')
    Assert ([IO.File]::Exists($injected)) 'Retained parent control restores cleanup access'
    [IO.File]::Delete($injected)
    Assert-ReadArguments 'bin/ai-pr-wait' @('658','--repo','popcre/ai-devops','--timeout-minutes','1')
    Assert-ReadArguments 'bin/ai-gh' @('issue','view','658','--repo','popcre/ai-devops','--json','number,state,title')
    Assert $true 'Finite public read arguments accepted'
    Refuses {Assert-ReadArguments 'bin/ai-gh' @('issue','close','658','--repo','popcre/ai-devops','--json','number')} 'Write command denied by explicit read profile'
    Refuses {Assert-ReadArguments 'bin/ai-pr-wait' @('658','--repo','other/private')} 'Other repository denied by explicit read profile'
    Refuses {Assert-ReadArguments 'bin/ai-pr-wait' @('658','--repo','popcre/ai-devops','--reviewer-approval','unbound-file')} 'Unbound helper argument denied by read profile'
    $powershell=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
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
