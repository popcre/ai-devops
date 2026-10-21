# Kill a Windows process and every descendant, then prove none survives.
# Prints "yes" only when the root (matched by PID AND creation time, so a reused
# PID is never touched) and all descendants are gone; anything else is a failure.
# Used by bin/ai-codex-review to stop its desktop relay (popcre/ai-devops#1891).
param([Parameter(Mandatory)][int]$RootPid, [Parameter(Mandatory)][string]$RootStart)

function Get-Tree([int[]]$Seed) {
  $all = @(Get-CimInstance Win32_Process)
  $tree = [System.Collections.Generic.List[int]]::new(); $Seed | ForEach-Object { $tree.Add($_) }
  for ($i = 0; $i -lt $tree.Count; $i++) {
    $all | Where-Object { $_.ParentProcessId -eq $tree[$i] -and -not $tree.Contains([int]$_.ProcessId) } |
      ForEach-Object { $tree.Add([int]$_.ProcessId) }
  }
  return ,$tree
}

$root = Get-Process -Id $RootPid -ErrorAction SilentlyContinue
if ($root -and $root.StartTime.ToUniversalTime().ToString('o') -ne $RootStart) { $root = $null }
$seed = @(); if ($root) { $seed = @($RootPid) }
$known = [System.Collections.Generic.HashSet[int]]::new()
# Repeat until a fresh snapshot finds nothing new, so late-spawned children are
# caught too; kill leaves first so no child is orphaned by its parent dying.
for ($round = 0; $round -lt 10 -and $seed.Count -gt 0; $round++) {
  $tree = Get-Tree $seed
  $tree | ForEach-Object { [void]$known.Add($_) }
  for ($i = $tree.Count - 1; $i -ge 0; $i--) { Stop-Process -Id $tree[$i] -Force -ErrorAction SilentlyContinue }
  Start-Sleep -Milliseconds 300
  $seed = @($known | Where-Object { Get-Process -Id $_ -ErrorAction SilentlyContinue })
}
$orphans = @(Get-CimInstance Win32_Process | Where-Object { $known.Contains([int]$_.ParentProcessId) -or $known.Contains([int]$_.ProcessId) })
if ($orphans.Count -eq 0) { 'yes' } else { 'alive' }
