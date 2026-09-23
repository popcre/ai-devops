# Move bulk AI tool data from C: to D: (HDD) and leave directory junctions on C:
# so every tool keeps working without config changes. Run when Codex/Claude/MiMo
# and other coding tools are CLOSED. Reversible: move the folder back and delete
# the junction.
#
# What moves (bulk/growth): review sandboxes, worktrees, archived sessions,
# logs, thread history, sessions cache.
# What stays on C: (speed): binaries, packages, plugins, live repos, auth, config.

$ErrorActionPreference = 'Stop'
$map = @(
  @{ Src = 'C:\Users\ahazan\.local\state\ai-devops\review-sandboxes'; Dst = 'D:\ai-data\local\state\ai-devops\review-sandboxes' },
  @{ Src = 'C:\Users\ahazan\.codex\worktrees';                        Dst = 'D:\ai-data\codex\worktrees' },
  @{ Src = 'C:\Users\ahazan\.codex\archived_sessions';                Dst = 'D:\ai-data\codex\archived_sessions' },
  @{ Src = 'C:\Users\ahazan\.codex\sessions';                         Dst = 'D:\ai-data\codex\sessions' },
  @{ Src = 'C:\Users\ahazan\.codex\attachments';                      Dst = 'D:\ai-data\codex\attachments' },
  @{ Src = 'C:\Users\ahazan\.codex\logs_2.sqlite';                    Dst = 'D:\ai-data\codex\logs_2.sqlite' },
  @{ Src = 'C:\Users\ahazan\.codex\thread_history_1.sqlite';          Dst = 'D:\ai-data\codex\thread_history_1.sqlite' },
  @{ Src = 'C:\Users\ahazan\.codex\thread_history_1.sqlite-wal';      Dst = 'D:\ai-data\codex\thread_history_1.sqlite-wal' },
  @{ Src = 'C:\Users\ahazan\.codex\thread_history_1.sqlite-shm';      Dst = 'D:\ai-data\codex\thread_history_1.sqlite-shm' },
  @{ Src = 'C:\Users\ahazan\.codex\logs_2.sqlite-wal';                Dst = 'D:\ai-data\codex\logs_2.sqlite-wal' },
  @{ Src = 'C:\Users\ahazan\.codex\logs_2.sqlite-shm';                Dst = 'D:\ai-data\codex\logs_2.sqlite-shm' },
  @{ Src = 'C:\Users\ahazan\.local\share\ai-devops';                  Dst = 'D:\ai-data\local\share\ai-devops' },
  @{ Src = 'C:\Users\ahazan\.local\state\ai-devops\grok';             Dst = 'D:\ai-data\local\state\ai-devops\grok' }
)

foreach ($item in $map) {
  $src = $item.Src
  $dst = $item.Dst
  if (-not (Test-Path -LiteralPath $src)) { Write-Output "SKIP missing $src"; continue }
  $srcItem = Get-Item -LiteralPath $src -Force
  if ($srcItem.LinkType) { Write-Output "SKIP already linked $src"; continue }

  $dstParent = Split-Path $dst -Parent
  if (-not (Test-Path -LiteralPath $dstParent)) { New-Item -ItemType Directory -Path $dstParent -Force | Out-Null }

  Write-Output "MOVE $src -> $dst"
  # Move (same volume would be rename; cross-volume copies then deletes)
  Move-Item -LiteralPath $src -Destination $dst -Force

  # Junction at the old path so every existing config keeps working
  cmd /c "mklink /J `"$src`" `"$dst`"" | Out-Null
  if (-not (Test-Path -LiteralPath $src)) { throw "junction failed for $src" }
  Write-Output "LINK $src => $dst"
}

Write-Output "DONE. Bulk AI data now lives under D:\ai-data with junctions on C:."
Write-Output "To reverse any one: delete the junction (not the target), then Move-Item back."
