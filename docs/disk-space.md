# Disk space on C: — detect, recover, prevent

**Open this when** C: is nearly full, a tool says there is no room to write, or
someone asks where the free space went. This is the runbook
([issue #768](https://github.com/popcre/ai-devops/issues/768)). The incident
narrative lives in [`critical-incidents.md`](critical-incidents.md) (2026-09-23).
Prevention code is [`plan_agent-self-cleanup.md`](../plan_agent-self-cleanup.md)
and [`scripts/ai-housekeeping/`](../scripts/ai-housekeeping/).

Albert is not a programmer. Report in plain English. Every claim needs a
command result, a path on GitHub, or an issue number.

---

## 1. What actually ate the disk (2026-09-23, EDGE-DEV)

| Where | What it was | Size seen |
|-------|-------------|-----------|
| `C:\Users\<user>\.local\state\ai-devops\review-sandboxes\` | Full Git clones of repos made for AI reviews (history included) | **~192 GB / 3,950 folders** |
| `C:\Users\<user>\.codex\worktrees\` | Codex task working copies | **~34 GB / 160 folders** |
| `C:\Users\<user>\.codex\` root | Chat/thread SQLite logs + `.bak` leftovers | several GB |
| `C:\Users\<user>\.codex\archived_sessions\` | Old chat archives | several GB |

C: dropped to **5 GB free**. Cleanup of disposable review snapshots and clean
worktrees recovered **~229 GB**. Live code under `C:\repos\` was left alone.

**Root cause:** every review copied a whole repository including `.git` history.
A review only needs the files at the review revision plus the patch under
review. Cleanup was described in prose ("delete when the session ends") and
never enforced in code.

---

## 2. First 10 minutes on a full C:

Do these in order. Stop when you have enough free space to work.

1. **Measure — do not guess.**
   ```powershell
   Get-PSDrive C | Select-Object @{n='FreeGB';e={[math]::Round($_.Free/1GB,1)}},@{n='UsedGB';e={[math]::Round($_.Used/1GB,1)}}
   ```
2. **Size the known debris roots** (fast size via `robocopy /L`, not recursive `Get-ChildItem` — those time out):
   ```powershell
   function Get-FastSize($path) {
     if (-not (Test-Path -LiteralPath $path)) { return 0 }
     $out = robocopy $path NULL /L /S /NJH /R:0 /W:0 /XJ /BYTES /NFL /NDL /NP 2>$null
     foreach ($line in $out) {
       if ($line -match '^\s+Bytes\s*:\s*(\d+)') { return [math]::Round([int64]$Matches[1]/1GB,2) }
     }
     return 0
   }
   Get-FastSize "$env:USERPROFILE\.local\state\ai-devops\review-sandboxes"
   Get-FastSize "$env:USERPROFILE\.codex\worktrees"
   Get-FastSize "$env:USERPROFILE\.codex\archived_sessions"
   Get-FastSize "$env:USERPROFILE\.codex"
   Get-FastSize "$env:USERPROFILE\.local"
   Get-FastSize 'C:\repos'
   ```
3. **Free space with the backup sweeper** (already installed on EDGE-DEV as task
   `AI-Debris-Housekeeping`, 03:30 daily):
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File C:\repos\ai-devops\scripts\ai-housekeeping\cleanup-ai-debris.ps1
   ```
   Or run the task: `schtasks /Run /TN AI-Debris-Housekeeping` then read `D:\ai-data\logs\housekeeping.log` (or `C:\ai-data\logs\housekeeping.log` if D: is absent — edit the script's `$log` first).
4. **If still tight, delete review sandboxes older than 24 hours by hand** (they
   are documented disposable snapshots — see `AI-REVIEW-SANDBOX.md` inside each
   one). Keep anything younger than 24 hours until you know no review is live.

---

## 3. Never destroy this

| Keep | Why |
|------|-----|
| `C:\repos\*` | Live, landing-only code. Source of truth is GitHub; local uncommitted work is unique until proven otherwise. |
| Any folder with `git status` dirty or uncommitted commits | Unique work. Load `cleanup-worktree` and preserve/ship first. |
| `*.sqlite` while Codex/Claude/opencode is running | Live databases. Close the tool first. |
| Auth/config: `auth.json`, `config.toml`, 1Password material, `.env` | Secrets and identity. |
| Another session's `HANDOFF.d/*` or untracked work | Concurrent-session hazard. |

**Age is not proof of safety.** Clean and incorporated is proof. Dirty-but-duplicated
needs a patch comparison. Unclear → keep it.

---

## 4. Move bulk off C: (when a second drive exists)

Policy: **SSD (usually C:) holds speed** — live repos, tool binaries, packages,
auth. **HDD (often D:) holds bulk/growth** — review sandboxes, worktrees, session
logs, archives, thread history.

On EDGE-DEV (2026-09-23) growth paths already junction to `D:\ai-data\...`.
On another machine:

```powershell
# Close Codex, opencode, Claude, and other coding tools first.
pwsh -NoProfile -ExecutionPolicy Bypass -File C:\repos\ai-devops\scripts\ai-housekeeping\move-bulk-to-d.ps1
```

The script moves folders to `D:\ai-data\...` and leaves **directory junctions**
at the old paths so every existing config keeps working. To reverse one path:
delete the junction (not the target), then move the folder back.

If tools are running and a folder will not move, leave it. Finish after tools
are closed. Do not kill processes just to free a rename.

---

## 5. Prevention (do not skip after the emergency)

1. **Self-cleanup at create time** is the real fix — issue
   [#711](https://github.com/popcre/ai-devops/issues/711),
   [`plan_agent-self-cleanup.md`](../plan_agent-self-cleanup.md). Reviews must
   not copy full Git history. The run that creates a snapshot deletes it before
   returning.
2. **Daily sweep is backup only** — `scripts/ai-housekeeping/cleanup-ai-debris.ps1`.
   Do not retire it until self-cleanup has been live-proven for 14 days
   (owner ruling 2026-09-23).
3. **Prompts for related cleanup:**
   - [`prompt_fix-review-full-history.md`](../prompt_fix-review-full-history.md) — stop full-history snapshots
   - [`prompt_six-dirty-codex-worktrees.md`](../prompt_six-dirty-codex-worktrees.md) — ship or discard dirty work folders (issue [#713](https://github.com/popcre/ai-devops/issues/713))

---

## 6. Reporting to Albert

One short plain-English note: what was eating the disk, how much you freed,
what you refused to delete and why, and which GitHub issue owns prevention.
No jargon, no command dumps, no local paths he cannot open — link GitHub
files and issue numbers instead.
