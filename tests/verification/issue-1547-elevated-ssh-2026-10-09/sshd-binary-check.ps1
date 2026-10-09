$ProgressPreference='SilentlyContinue'
$pBase='C:\Windows\WinSxS\amd64_openssh-server-components-onecore_31bf3856ad364e35_10.0.26100.1_none_2414f81d8596f589\sshd.exe'
$pOld='C:\Windows\WinSxS\amd64_openssh-server-components-onecore_31bf3856ad364e35_10.0.26100.9168_none_c308f96dccf4131e\sshd.exe'
$pNew='C:\Windows\System32\OpenSSH\sshd.exe'
$paths=@($pBase,$pOld,$pNew)
foreach($p in $paths){
  if(Test-Path -LiteralPath $p){
    $f=Get-Item -LiteralPath $p
    $md5=(Get-FileHash -LiteralPath $p -Algorithm MD5).Hash
    "PATH=$p"
    "  SIZE=$($f.Length)"
    "  FILEVER=$($f.VersionInfo.FileVersion)  PRODVER=$($f.VersionInfo.ProductVersion)"
    "  MD5=$md5"
  } else {
    "PATH=$p"
    "  MISSING"
  }
}
function Get-StrSet([string]$path){
  $latin1=[Text.Encoding]::GetEncoding(28591)
  $text=$latin1.GetString([IO.File]::ReadAllBytes($path))
  $set=New-Object 'System.Collections.Generic.HashSet[string]'
  foreach($m in [regex]::Matches($text,'[\x20-\x7E]{5,}')){ [void]$set.Add($m.Value) }
  return ,$set
}
$setOld=Get-StrSet $pOld
$setNew=Get-StrSet $pNew
"STRINGS_ASCII_9168_TOTAL=$($setOld.Count)"
"STRINGS_ASCII_ACTIVE_TOTAL=$($setNew.Count)"
$onlyOld=@($setOld | Where-Object { -not $setNew.Contains($_) })
$onlyNew=@($setNew | Where-Object { -not $setOld.Contains($_) })
"ASCII_ONLY_IN_9168 count=$($onlyOld.Count)"
foreach($s in ($onlyOld | Sort-Object)){ "  OLD_ONLY: $s" }
"ASCII_ONLY_IN_ACTIVE count=$($onlyNew.Count)"
foreach($s in ($onlyNew | Sort-Object)){ "  NEW_ONLY: $s" }
$bytesOld=[IO.File]::ReadAllBytes($pOld)
$bytesNew=[IO.File]::ReadAllBytes($pNew)
$uniOld=New-Object 'System.Collections.Generic.HashSet[string]'
$uniNew=New-Object 'System.Collections.Generic.HashSet[string]'
$textUOld=[Text.Encoding]::Unicode.GetString($bytesOld)
$textUNew=[Text.Encoding]::Unicode.GetString($bytesNew)
foreach($m in [regex]::Matches($textUOld,'[\x20-\x7E]{5,}')){ [void]$uniOld.Add($m.Value) }
foreach($m in [regex]::Matches($textUNew,'[\x20-\x7E]{5,}')){ [void]$uniNew.Add($m.Value) }
"STRINGS_UTF16_9168_TOTAL=$($uniOld.Count)"
"STRINGS_UTF16_ACTIVE_TOTAL=$($uniNew.Count)"
$uOnlyOld=@($uniOld | Where-Object { -not $uniNew.Contains($_) })
$uOnlyNew=@($uniNew | Where-Object { -not $uniOld.Contains($_) })
"UTF16_ONLY_IN_9168 count=$($uOnlyOld.Count)"
foreach($s in ($uOnlyOld | Sort-Object)){ "  OLD_ONLY: $s" }
"UTF16_ONLY_IN_ACTIVE count=$($uOnlyNew.Count)"
foreach($s in ($uOnlyNew | Sort-Object)){ "  NEW_ONLY: $s" }
$latin1=[Text.Encoding]::GetEncoding(28591)
$tOld=$latin1.GetString($bytesOld)
$tNew=$latin1.GetString($bytesNew)
$idxOld=$tOld.IndexOf('RSDS')
$idxNew=$tNew.IndexOf('RSDS')
if($idxOld -ge 0){ $gOld=[BitConverter]::ToString($bytesOld[($idxOld+4)..($idxOld+19)]) } else { $gOld='RSDS-NOT-FOUND' }
if($idxNew -ge 0){ $gNew=[BitConverter]::ToString($bytesNew[($idxNew+4)..($idxNew+19)]) } else { $gNew='RSDS-NOT-FOUND' }
"PDBGUID_9168=$gOld"
"PDBGUID_ACTIVE=$gNew"
$block=65536
$ranges=New-Object System.Collections.Generic.List[string]
$md5c=[Security.Cryptography.MD5]::Create()
$nb=[Math]::Min($bytesOld.Length,$bytesNew.Length)
$i=0
while($i -lt $nb){
  $len=[Math]::Min($block,$nb-$i)
  $h1=[BitConverter]::ToString($md5c.ComputeHash($bytesOld,$i,$len))
  $h2=[BitConverter]::ToString($md5c.ComputeHash($bytesNew,$i,$len))
  if($h1 -ne $h2){
    $start=-1
    $end=-1
    for($j=$i;$j -lt ($i+$len);$j++){
      if($bytesOld[$j] -ne $bytesNew[$j]){ if($start -lt 0){ $start=$j }; $end=$j }
      else { if($start -ge 0){ $ranges.Add("$start-$end"); $start=-1 } }
    }
    if($start -ge 0){ $ranges.Add("$start-$end") }
  }
  $i+=$block
}
if($bytesOld.Length -ne $bytesNew.Length){ $ranges.Add("SIZE-MISMATCH $($bytesOld.Length) vs $($bytesNew.Length)") }
"DIFF_BYTE_RANGES count=$($ranges.Count)"
foreach($r in $ranges){ "  RANGE $r" }
