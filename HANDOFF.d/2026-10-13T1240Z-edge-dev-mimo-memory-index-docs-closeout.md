---
issue: none
status: OPEN
owner: mimo/memory-index-decision
---
# Handoff — memory index merge-by-target: docs closeout

`issue: none` — the shipped fix is already tracked and merged as PR #1614; this file only carries the leftover wrap-up (docs PR #1665 in the merge queue and workspace cleanup). Do not open a second tracker for it.

## 0. ⚠️ BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

None — nothing in this workstream needs the owner.

Already settled — do NOT re-ask:
- 2026-10-12: merge MEMORY.md index entries by target file so consolidated indexes stop re-growing (Albert, session request). Shipped in PR #1614.

## 1. What this application is

`popcre/ai-devops` is Albert's public AI workflow toolkit (reviewer wrappers, task gates, memory sync tools). No app, no DB, no UI. GitHub `main` is protected and uses a merge queue.

Private memory hub: `github.com/u2giants/ai-devops-memory` (not this repo). Tools:
- https://github.com/popcre/ai-devops/blob/main/bin/ai-sync-memory
- https://github.com/popcre/ai-devops/blob/main/bin/ai-memory-sync
- https://github.com/popcre/ai-devops/blob/main/bin/ai-memory-health

## 2. What we set out to do this session, and why

**Goal:** stop consolidated `MEMORY.md` indexes from re-growing after hub consolidation.

**Trigger (proven 2026-10-12):** the outgoing union merged index lines by text. A machine with OLD wordings re-added every entry after the hub was consolidated. vps2 re-grew popdam 4KB→11KB; al8960ofc/edge-dev pushed 19–25KB ai-devops indexes until the 12KB health gate blocked sync. `forget --prune-index` only dedupes the hub copy.

**Technical objective:** merge by TARGET FILE. Hub wording wins for shared targets; genuinely new local memories still land; tombstoned/missing targets are never re-added; second sync converges.

## 3. Current state — what is true right now

**Done and on `main`:**
- Merge-by-target in `bin/ai-sync-memory` — PR #1614, merge commit https://github.com/popcre/ai-devops/commit/b217e53523da148be2febc151b8130f528c367a1 (merged 2026-10-13 8:20 AM EST).
- Four Bash cases in https://github.com/popcre/ai-devops/blob/main/tests/test-ai-sync-memory-index-target.sh and the main suite.
- Live proof on vps2 and edge-dev: popdam held 4004; second sync unchanged; popdam3/ai-devops shed stale extras then held.

**In flight (the only unfinished piece):**
- Docs-only PR #1665 records the decision in `docs/design-decisions.md`. URL: https://github.com/popcre/ai-devops/pull/1665
- Auto-merge is on. It is in the merge queue behind PRs #1664 and #1658 (as of 2026-10-13 12:40 PM EST). Branch `mimo/memory-index-decision` is kept until it lands.

**Workspace:**
- Worktree `C:\repos\ai-devops-wt-memory-index` (Windows, edge-dev) is on `mimo/memory-index-decision`, clean.
- Local branch `mimo/memory-index-target-merge` deleted (merged). Remote copy already gone (GitHub deleted on merge).

## 4. Everything we tried that did NOT work

1. **Line-text union (the old algorithm).** Re-added stale wordings after consolidation. This is the bug, not a failed fix.
2. **`forget --prune-index` only.** Dedupes the hub copy; the next machine sync re-adds lines. Insufficient alone.
3. **First implementation used `dirname` of the temp index copy for existence checks.** Pull/push pass a `mktemp` copy of the other side's index, so every genuinely new local memory was dropped (bodies live next to OUTPUT, not next to the temp file). Fixed by using `dirname "$output"`.
4. **GitHub user auth on edge-dev is broken** (keyring `gho_` token invalid;1Password PAT "u2giants repo push access" also 401; GCM token expired). App token (`ai-gh-app-auth token popcre`) can create/read PRs but cannot merge or rerun. **SSH `git@github.com` works as `u2giants`.** Merge/queue must run from **vps2** (`gh` there is logged in as `u2giants` with `repo` scope).
5. **First merge-queue attempts failed** because the branch was 12 hours stale. Main updated `bin/ai-public-boundary-check` to allow published `.ai/reviewer-issues/*` (PR #1626). Our old copy still rejected them; the grouped landing tree failed `doc-safety` and `test-public-boundary`. **Fix: rebase onto latest `origin/main`**, then re-queue. After rebase, doc-safety and all Linux shards passed on the merge-queue commit.
6. **Empty "retrigger" commit** was pushed to retry a flaky `test-ai-gh.sh` spacing test. Harmless; it rode along in PR #1614.
7. **`ai-test-local --check-collision` hung** on this Windows box (HOME/USERPROFILE quirks). Not pursued; CI is the authority.

## 5. Root causes and key findings

- **Index merge must key on the link target (`](file.md)`), not line text.** One line per memory file. Hub wording wins for any target the hub lists. See the new section in `docs/design-decisions.md` (in PR #1665).
- **Push call argument order was inverted** relative to the function's documented "hub wins" contract. Fixed when implementing target merge: `merge_memory_index LOCAL HUB OUTPUT [FORGET]`.
- **Merge queue tests a grouped landing tree.** A stale PR can fail because another queued PR brought bad files. Rebase often clears it.
- **vps2 is the working GitHub-auth machine.** Use it for `gh pr merge --auto`, merge-queue GraphQL, and `gh run` log pulls.

## 6. Exact next steps

1. Confirm PR #1665 merged:
   - `gh pr view 1665 --repo popcre/ai-devops --json state,mergedAt`
   - You'll know it worked when `state` is `MERGED` and `docs/design-decisions.md` on `main` contains "MEMORY.md index entries merge by target file".
2. Delete branch `mimo/memory-index-decision` (local + remote) after it merges.
3. Remove worktree `C:\repos\ai-devops-wt-memory-index` only after (1)+(2): tree is clean AND the docs branch is merged. Use `cleanup-worktree` skill. Never delete if unmerged.
4. Optionally delete this handoff file after (1)–(3) (successor rule: PR landed, obligations carried, nothing unique left).

## 7. Constraints and gotchas in force

- Never push to protected `main`. Branch + PR + merge queue only.
- Docs-only PRs may merge immediately via the normal queue (never `--admin`).
- Do not weaken the memory health gate (12KB / 200 lines) or secret-pattern/privacy checks.
- Do not rewrite root `HANDOFF.md` (static pointer). Do not edit other sessions' `HANDOFF.d/` files.
- Windows PowerShell eats `$()` and `<` in `bash -lc` strings — put long commands in a script file and scp/ssh it.
- Quote every time in EST.

## 8. Access and environment

- **GitHub:** SSH works as `u2giants`. `gh` on **vps2** is authenticated (repo scope). edge-dev `gh`/GCM tokens are invalid.
- **1Password:** vault `vibe_coding` (service account / `op`). No new secrets stored this session.
- **Machines:** edge-dev (this box), vps2 (Linux, `ssh vps2`).
- **Memory hub clone (edge-dev):** `~/.cache/ai-devops-memory-private`.
- **Claude memory (edge-dev):** `~/.claude/projects/*/memory/`.

## 9. Open questions and risks

- **PR #1665 still queued** behind #1664/#1658 as of 12:40 PM EST 2026-10-13. If those keep failing, the docs PR waits. Not a code risk — documentation only.
- **Flaky test:** `test-ai-gh.sh` "concurrent processes space their GitHub call starts" can fail under load. Unrelated to memory sync. Do not "fix" by weakening it without a separate issue.
- **Installed toolkits on other machines** pick up the merge fix when their `ai-devops` checkout next updates `main`. Live proof used the worktree's copy of `bin/ai-sync-memory`. Scheduled syncs will use the new merge after that pull.
- **Decisions dated 2026-10-13:** target-file merge is the standing rule; do not revert to line-text union.
