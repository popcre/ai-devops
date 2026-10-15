param([Parameter(Mandatory)][string]$Root)
$ErrorActionPreference = 'Stop'
$userSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$allowed = @($userSid, 'S-1-5-18')
$items = @(Get-Item -LiteralPath $Root -Force) + @(Get-ChildItem -LiteralPath $Root -Force -Recurse)
foreach ($item in $items) {
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw 'Credential tree contains a reparse point.'
    }
    $seenUser = $false
    foreach ($rule in (Get-Acl -LiteralPath $item.FullName).Access) {
        if ($rule.AccessControlType -ne [Security.AccessControl.AccessControlType]::Allow) { continue }
        $sid = $rule.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value
        if ($allowed -notcontains $sid) { throw 'Credential tree grants access to an unexpected identity.' }
        if ($sid -eq $userSid) { $seenUser = $true }
    }
    if (-not $seenUser) { throw 'Credential tree is not readable by the current user.' }
}
