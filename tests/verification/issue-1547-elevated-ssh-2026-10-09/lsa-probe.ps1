$ProgressPreference='SilentlyContinue'
foreach($dll in 'lsasrv.dll','samsrv.dll','samlib.dll','msv1_0.dll','kerberos.dll','wdigest.dll','tspkg.dll','cryptdll.dll','netlogon.dll'){
  $p="C:\Windows\System32\$dll"
  if(Test-Path $p){
    $f=Get-Item $p
    "{0} ver={1} created={2} written={3}" -f $dll, $f.VersionInfo.FileVersion, $f.CreationTimeUtc.ToString('yyyy-MM-dd HH:mmZ'), $f.LastWriteTimeUtc.ToString('yyyy-MM-dd HH:mmZ')
  } else { "$dll MISSING" }
}
