[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [int]$TargetProcessId,
    [string]$TaskkillPath = "taskkill.exe",
    [int]$WaitMilliseconds = 10000
)

$ErrorActionPreference = "Stop"

$tree = [System.Collections.Generic.HashSet[int]]::new()
$frontier = [System.Collections.Generic.List[int]]::new()
$null = $tree.Add($TargetProcessId)
$frontier.Add($TargetProcessId)
while ($frontier.Count -gt 0) {
    $parents = @($frontier)
    $frontier.Clear()
    foreach ($child in Get-CimInstance Win32_Process | Where-Object { $parents -contains [int]$_.ParentProcessId }) {
        $childId = [int]$child.ProcessId
        if ($tree.Add($childId)) {
            $frontier.Add($childId)
        }
    }
}

& $TaskkillPath /PID $TargetProcessId /T /F | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "taskkill failed for process $TargetProcessId with exit code $LASTEXITCODE." -ErrorAction Continue
    exit 20
}

$deadline = [DateTime]::UtcNow.AddMilliseconds($WaitMilliseconds)
do {
    $survivors = @($tree | Where-Object { Get-Process -Id $_ -ErrorAction SilentlyContinue })
    if ($survivors.Count -eq 0) {
        exit 0
    }
    Start-Sleep -Milliseconds 100
} while ([DateTime]::UtcNow -lt $deadline)

Write-Error "Process tree still has live PIDs after checked termination: $($survivors -join ',')." -ErrorAction Continue
exit 21
