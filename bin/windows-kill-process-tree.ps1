# Kill every process of one review run and all their native descendants, then
# prove none survives (popcre/ai-devops#1891, used by bin/ai-codex-review).
#
# A run's roots are the processes whose command line contains the marker (the
# run's unique review directory, which Codex receives via --cd). Git Bash
# processes do not expose real Windows parent links, so roots are found by
# marker, not by walking down from a shell. Descendants are processes whose
# parent is a known tree member AND that started after it, so a reused PID is
# never adopted; each kill re-checks PID plus creation time first. Tree members
# are remembered across rounds, so children of an already-dead member are still
# found. Any enumeration error is a failure, never an empty (clean) answer.
# The marker arrives in $env:AI_REVIEW_KILL_MARKER, never on a command line, so
# neither this helper nor the watchdog that launched it can match it.
# Prints "yes" when nothing from the run is left, otherwise "alive".
$ErrorActionPreference = 'Stop'
try {
  $norm = { param($s) if ($s) { $s.Replace('\', '/').ToLowerInvariant() } else { '' } }
  $mark = & $norm $env:AI_REVIEW_KILL_MARKER
  if ($mark.Length -lt 12) { 'alive'; exit 0 }   # refuse a marker too short to be unique
  function Get-Key($p) { "$($p.ProcessId)@$($p.CreationDate.ToUniversalTime().Ticks)" }
  $tree = [System.Collections.Generic.Dictionary[string,object]]::new()

  for ($round = 0; $round -lt 10; $round++) {
    $live = @(Get-CimInstance Win32_Process | Where-Object { $_.CreationDate -and $_.ProcessId -ne $PID })
    if ($live.Count -eq 0) { throw 'process enumeration returned nothing' }
    $live | Where-Object { (& $norm $_.CommandLine).Contains($mark) } | ForEach-Object { $tree[(Get-Key $_)] = $_ }
    $grew = $true
    while ($grew) {
      $grew = $false
      foreach ($p in $live) {
        $k = Get-Key $p
        if ($tree.ContainsKey($k)) { continue }
        foreach ($q in @($tree.Values)) {
          if ($q.ProcessId -eq $p.ParentProcessId -and $q.CreationDate -le $p.CreationDate) { $tree[$k] = $p; $grew = $true; break }
        }
      }
    }
    $liveKeys = [System.Collections.Generic.HashSet[string]]::new(); $live | ForEach-Object { [void]$liveKeys.Add((Get-Key $_)) }
    $alive = @($tree.Keys | Where-Object { $liveKeys.Contains($_) } | ForEach-Object { $tree[$_] })
    if ($alive.Count -eq 0) { 'yes'; exit 0 }
    # Leaves first, so no child is orphaned by its parent dying before it.
    $alive | Sort-Object CreationDate -Descending | ForEach-Object {
      $cur = @(Get-CimInstance Win32_Process -Filter "ProcessId = $($_.ProcessId)")
      if ($cur.Count -eq 1 -and (Get-Key $cur[0]) -eq (Get-Key $_)) {
        try { Stop-Process -Id $_.ProcessId -Force } catch { if (Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue) { throw } }
      }
    }
    Start-Sleep -Milliseconds 300
  }
  'alive'
} catch {
  'alive'
}
