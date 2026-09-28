# Move bulk AI tool data from C: to D: (HDD) and leave directory junctions on C:
# so every tool keeps working without config changes. Reversible: delete the
# junction (not the target), then Move-Item the folder back.
#
# Policy (docs/disk-space.md): C: = speed (binaries, auth, config, live repos).
# D: = bulk/growth (worktrees, session logs, caches, archives, sandboxes).
#
# Safe to run while tools are open for caches/worktrees; locked folders are
# skipped and retried later. Live SQLite stores are never moved: they stay on
# C: as real files. Close coding tools only for a final retry pass.
#
# -DryRun prints every action and moves nothing.

param(
  [switch]$DryRun
)

$ErrorActionPreference = 'Continue'

function Move-LinkJunction {
  param([string]$Src, [string]$Dst)

  if (-not (Test-Path -LiteralPath $Src)) {
    Write-Output "SKIP missing $Src"
    return
  }
  $srcItem = Get-Item -LiteralPath $Src -Force
  if (-not $srcItem.PSIsContainer) {
    Write-Output "SKIP file (never junction files) $Src"
    return
  }
  if ($srcItem.LinkType) {
    Write-Output "SKIP already linked $Src -> $($srcItem.Target)"
    return
  }
  if (Test-Path -LiteralPath $Dst) {
    Write-Output "SKIP dest exists $Dst"
    return
  }
  if ($DryRun) {
    Write-Output "DRYRUN would move $Src -> $Dst (then junction)"
    return
  }

  $dstParent = Split-Path $Dst -Parent
  if (-not (Test-Path -LiteralPath $dstParent)) {
    New-Item -ItemType Directory -Path $dstParent -Force | Out-Null
  }

  Write-Output "MOVE $Src -> $Dst"
  try {
    Move-Item -LiteralPath $Src -Destination $Dst -Force -ErrorAction Stop
  } catch {
    Write-Output "LOCKED skip $Src ($($_.Exception.Message))"
    return
  }

  cmd /c "mklink /J `"$Src`" `"$Dst`"" | Out-Null
  if (-not (Test-Path -LiteralPath $Src)) {
    throw "junction failed for $Src"
  }
  Write-Output "LINK $Src => $Dst"
}

# Bulk/growth only (caches, worktrees, logs, session stores).
$map = @(
  # --- existing map (retry anything still unlinked) ---
  @{ Src = 'C:\Users\ahazan\.local\state\ai-devops\review-sandboxes'; Dst = 'D:\ai-data\local\state\ai-devops\review-sandboxes' },
  @{ Src = 'C:\Users\ahazan\.codex\worktrees';                        Dst = 'D:\ai-data\codex\worktrees' },
  @{ Src = 'C:\Users\ahazan\.codex\archived_sessions';                Dst = 'D:\ai-data\codex\archived_sessions' },
  @{ Src = 'C:\Users\ahazan\.codex\sessions';                         Dst = 'D:\ai-data\codex\sessions' },
  @{ Src = 'C:\Users\ahazan\.codex\attachments';                      Dst = 'D:\ai-data\codex\attachments' },
  @{ Src = 'C:\Users\ahazan\.local\share\ai-devops';                  Dst = 'D:\ai-data\local\share\ai-devops' },
  @{ Src = 'C:\Users\ahazan\.local\state\ai-devops\grok';             Dst = 'D:\ai-data\local\state\ai-devops\grok' },

  # NOTE: never junction individual files (SQLite, json, logs). mklink /J is
  # directory-only: Move-Item would relocate the file, the junction would fail,
  # and the script would throw with the store stranded on D: and no link at its
  # original path. Live SQLite stores stay as real files on C:. Only
  # directories go on this map. Tool packages and runtimes also stay on C:
  # (SSD speed, docs/disk-space.md policy).

  # --- download / browser caches ---
  @{ Src = 'C:\Users\ahazan\AppData\Local\npm-cache';                 Dst = 'D:\ai-data\caches\npm-cache' },
  @{ Src = 'C:\Users\ahazan\AppData\Local\pnpm';                      Dst = 'D:\ai-data\caches\pnpm' },
  @{ Src = 'C:\Users\ahazan\AppData\Local\pnpm-cache';                Dst = 'D:\ai-data\caches\pnpm-cache' },
  @{ Src = 'C:\Users\ahazan\AppData\Local\ms-playwright';             Dst = 'D:\ai-data\caches\ms-playwright' },
  @{ Src = 'C:\Users\ahazan\.cache\ai-devops-memory';                 Dst = 'D:\ai-data\caches\ai-devops-memory' },

  # --- harness growth dirs ---
  @{ Src = 'C:\Users\ahazan\.claude\projects';                        Dst = 'D:\ai-data\claude\projects' },
  @{ Src = 'C:\Users\ahazan\.local\share\claude';                     Dst = 'D:\ai-data\local\share\claude' },
  @{ Src = 'C:\Users\ahazan\.grok\worktrees';                         Dst = 'D:\ai-data\grok\worktrees' },
  @{ Src = 'C:\Users\ahazan\.grok\downloads';                         Dst = 'D:\ai-data\grok\downloads' },
  @{ Src = 'C:\Users\ahazan\.gemini';                                 Dst = 'D:\ai-data\gemini' },
  @{ Src = 'C:\Users\ahazan\.codex\plugins';                          Dst = 'D:\ai-data\codex\plugins' },
  @{ Src = 'C:\Users\ahazan\.codex\private-captures';                 Dst = 'D:\ai-data\codex\private-captures' },
  @{ Src = 'C:\Users\ahazan\.codex\cache';                            Dst = 'D:\ai-data\codex\cache' },
  @{ Src = 'C:\Users\ahazan\.codex\.tmp';                             Dst = 'D:\ai-data\codex\tmp' },
  @{ Src = 'C:\Users\ahazan\.ai-grok-review-isolated-home';           Dst = 'D:\ai-data\grok\isolated-home' },
  @{ Src = 'C:\Users\ahazan\.local\state\ai-devops\grok-c';           Dst = 'D:\ai-data\local\state\ai-devops\grok-c' },
  @{ Src = 'C:\Users\ahazan\.local\state\ai-devops\qwen';             Dst = 'D:\ai-data\local\state\ai-devops\qwen' },
  @{ Src = 'C:\Users\ahazan\.local\state\ai-devops\muse';             Dst = 'D:\ai-data\local\state\ai-devops\muse' },
  @{ Src = 'C:\Users\ahazan\.local\state\ai-devops\provider-cli';     Dst = 'D:\ai-data\local\state\ai-devops\provider-cli' }
)

# Directories only. Live app databases (mimocode.db, codex *.sqlite) stay on C:
# as real files while the apps run; do not move or junction them.

foreach ($item in $map) {
  Move-LinkJunction -Src $item.Src -Dst $item.Dst
}

# Worktree containers under C:\repos (worktrees, review clones, session sprawl).
$reposSrc = 'C:\repos'
$reposDstRoot = 'D:\repos'
$keepOnC = @(
  'ai-devops', 'ai-devops-transcripts', 'dflow_plm', 'licensor-source-data',
  'oracle', 'popcre.com_website', 'popcrm-web', 'popdam3', 'poppim-web',
  'shared-db', 'Users', 'worktrees', '.worktrees', '.wt', '.tmp-issues-8'
)

if (-not $DryRun -and -not (Test-Path -LiteralPath $reposDstRoot)) {
  New-Item -ItemType Directory -Path $reposDstRoot -Force | Out-Null
}

Get-ChildItem -LiteralPath $reposSrc -Directory -Force | ForEach-Object {
  $name = $_.Name
  if ($_.LinkType) {
    Write-Output "SKIP already linked $($_.FullName)"
    return
  }
  if ($keepOnC -contains $name) {
    # worktrees container is bulk — still move it below via explicit entry
    if ($name -ne 'worktrees') { return }
  }

  $src = $_.FullName
  $dst = Join-Path $reposDstRoot $name
  # Only relocate AI-session sprawl and *-worktrees containers, not live product repos
  $isWorktreeContainer = $name -match '-worktrees$'
  $isSprawl = $name -match '^(shared-db-(wt|work|audit|review|nonorch|issue|diagnose|inspect|plan|queue|codex|coldlion|artifacts|2491|2507|2662|2824|2998|3028|3345|3349|3380|3383|3397|3409|3411|3412)|ai-devops-(wt|issue|phase|task|gemini|glm)|oracle-(issue|review|dependency)|rev[0-9]|rf[0-9]|sdb-|scout-|product-reader-)'
  if (-not ($isWorktreeContainer -or $isSprawl)) { return }

  Move-LinkJunction -Src $src -Dst $dst
}

# Explicit bulk worktrees container
Move-LinkJunction -Src 'C:\repos\worktrees' -Dst 'D:\repos\worktrees'

if ($DryRun) {
  Write-Output "DRYRUN complete. Nothing was moved."
} else {
  Write-Output "DONE pass. Locked items can be retried after closing coding tools."
}
Write-Output "To reverse any one: delete the junction (not the target), then Move-Item back."
