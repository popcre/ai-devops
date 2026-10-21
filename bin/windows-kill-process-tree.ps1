# Kill every process of one review run and all their native descendants, then
# prove none survives (popcre/ai-devops#1891, used by bin/ai-codex-review).
#
# A run's roots are the processes whose command line contains -Marker (the
# run's unique review directory, which Codex receives via --cd). Git Bash
# processes do not expose real Windows parent links, so roots are found by
# marker, not by walking down from a shell. Descendants are processes whose
# parent is a known tree member AND that started after it, so a reused PID is
# never adopted; each kill re-checks PID plus creation time first.
# Prints "yes" when nothing from the run is left, otherwise "alive".
param([Parameter(Mandatory)][string]$Marker)

$norm = { param($s) if ($s) { $s.Replace('\', '/').ToLowerInvariant() } else { '' } }
$mark = & $norm $Marker
if ($mark.Length -lt 12) { 'alive'; exit 0 }   # refuse a marker too short to be unique
function Get-Key($p) { "$($p.ProcessId)@$($p.CreationDate.ToUniversalTime().Ticks)" }

for ($round = 0; $round -lt 10; $round++) {
  $live = @(Get-CimInstance Win32_Process | Where-Object { $_.CreationDate -and $_.ProcessId -ne $PID })
  $tree = [System.Collections.Generic.Dictionary[string,object]]::new()
  $live | Where-Object { (& $norm $_.CommandLine).Contains($mark) } | ForEach-Object { $tree[(Get-Key $_)] = $_ }
  $grew = $tree.Count -gt 0
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
  if ($tree.Count -eq 0) { 'yes'; exit 0 }
  # Leaves first, so no child is orphaned by its parent dying before it.
  $tree.Values | Sort-Object CreationDate -Descending | ForEach-Object {
    $cur = Get-CimInstance Win32_Process -Filter "ProcessId = $($_.ProcessId)" -ErrorAction SilentlyContinue
    if ($cur -and (Get-Key $cur) -eq (Get-Key $_)) { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
  }
  Start-Sleep -Milliseconds 300
}
'alive'
