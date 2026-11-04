# Plan — popcre/ai-devops#1998: finish #1881 step 6.1 (live transcript re-audit)

**Not obsolete (checked 2026-11-04).** The freeze #1998 waited on ended
2026-10-29 night (`docs/owner-rulings.md` "freeze off"). Step 6.1 of
[`plan_ruleset-trim-and-enforce.md`](../../plan_ruleset-trim-and-enforce.md) ran once on
2026-10-28 and **did not pass** (3 of 4 criteria; #1881 comment 6471560403). Two
of the gaps it named are still live on main at `f2b4f5bd`:
- `bin/ai-pr-poll-guard-hook:72` block message still tells agents to use
  `--timeout-minutes N` / `--fit-tool-call` (the superseded foreground form)
  instead of the 2026-10-21 ruling "run `bin/ai-pr-wait <pr>` in the background".
  This message is a likely source of the "acting on a superseded rule" failure.
- No re-run has happened since. #1881 and #1998 are both OPEN.
The 2026-10-28 drift finding is resolved on edge-dev3: `bin/ai-adopt-globals
--check` printed CLEAN for all four globals on 2026-11-04.

## STATUS (read first)

| Step | State | Date | Evidence |
|---|---|---|---|
| 1 Fix poll-guard hook message to the current wait form | ⬜ open | | |
| 2 Confirm installs are current (edge-dev3, edge-dev) | ⬜ open (edge-dev3 CLEAN 2026-11-04 pre-check) | | |
| 3 Re-run the audit from the transcript store | ⬜ open | | |
| 4 Post counts on #1881, close #1998 | ⬜ open | | |
| 5 Mark STATUS 6.1 in the parent plan | ⬜ open | | |

**Start here:** step 1. Handoff backlink: the implementer creates
`HANDOFF.d/<UTC>-<machine>-<agent>-1998-audit.md` linking this plan (this plan
was written read-only in a scratchpad; copy it into the repo as
`plan_1998-ruleset-audit-rerun.md` only if the work spans sessions — otherwise
the issue is the card).

## Part 1 — Why

### 1. Ultimate goal
Albert wants proof that the October rule trim (#1881) actually made AI sessions
obey the rules that matter. "Done" means: a fresh sample of real sessions shows
agents no longer hand-poll pull requests, never get task-class rejections, do
not act on retired rules, and are corrected by Albert no more often than before.
Then #1881 can close. **If a step conflicts with this goal, the goal wins — stop
and note it on #1998.** Never weaken a rule or a criterion to make the audit pass.

### 2. The application
`popcre/ai-devops` — Albert's AI toolkit (global rule templates, skills, hooks,
installer). Not a web app; "deploy" = the protected install per
`docs/deployment.md`. Machines in scope: edge-dev3 (Ubuntu, main box) and
edge-dev (Windows, `ssh edge-dev`, Git Bash `-l -s`). al8960ofc is excluded —
Albert, 2026-10-21: "forget about al8960ofc. just proceed with the rest".

### 3. Trigger
#1998 parked step 6.1 behind the reviewer observation freeze (#1996). The
freeze is off. The 2026-10-28 run failed one criterion; this is the re-run.

### 4. Scope
In: the one-line hook-message fix and its test, the install check, the
re-audit, posting counts, the STATUS row.
NOT in: extending the poll guard to catch `gh run` CI polling (7/41 sessions on
2026-10-28) — owner ruling 2026-10-21 "add NO new tooling"; report the count
only. No further globals trimming. No al8960ofc. No new audit script. No reviewer
gating (reviews are advice only, 2026-10-29).

## Part 2 — What we know

### 5. Current state
- Phases 1–5 of #1881 done (parent STATUS table, rows 1.1–5.1, 2.3).
- 6.1 ❌ 2026-10-28: polling loops 0/41 ✅, class rejections 0 ✅,
  superseded-rule sessions 2/41 ❌ (`timeout 5xx bin/ai-pr-wait` foreground
  wrapper), corrections 19/41 ✅ (baseline 23/44). Private report
  `~/Dropbox/ai/chat_transcripts/_audit/ruleset-audit-2026-10-28.md`.
- Transcript store (`bin/ai-transcript-query --stats`, 2026-11-04): edge-dev3
  current (last session 2026-11-04 4:07 AM EST); **edge-dev STALE, last
  session 2026-10-20 7:53 PM EDT**; hetz current.

### 6. Key findings
- The superseded behaviour matches the hook's own advice text
  (`bin/ai-pr-poll-guard-hook:72`), so agents blocked by the hook are told to
  use the old form. Fix the message, not the agents.
- edge-dev produces no new sessions in the store, so the sample will again be
  edge-dev3 (plus optionally hetz). That is acceptable; say so in the count post.

### 7. Rejected approaches
- Bulk-reading raw transcripts from `~/Dropbox/ai/chat_transcripts/` (the
  2026-10-28 method) — rejected: the `transcript-query` skill now requires the
  topic-cut store first; raw only by `--raw <segment>` drill-down.
- New hook rule for `gh run watch/view` loops — rejected by the "no new
  tooling" ruling.
- Waiting another 7 days after the hook fix — rejected as gold-plating; but see
  step 3 date window (sessions after the fix's install are the clean sample if
  any exist; otherwise sample 2026-10-30 onward and attribute any
  superseded-form hits to the pre-fix message).

### 8. Decisions
Locked: the four criteria and thresholds (parent plan Phase 6); counts-only on
GitHub; al8960ofc excluded; reviews advisory.
Open (implementer): include hetz sessions or not — include them as a separate
line, not in the pass/fail totals, since hetz was never in the install gate.

## Part 3 — Build

### 9. Steps
1. **Hook message.** Task class `code` (`ai-task-gates start --class code`),
   own worktree off `origin/main`. Edit `bin/ai-pr-poll-guard-hook:72` so the
   advice reads: run `bin/ai-pr-wait <pr>` in the background and rerun on exit 2;
   drop the `--timeout-minutes N` / `--fit-tool-call` advice. Update any
   assertion on that text in `tests/test-ai-pr-poll-guard-hook.sh`.
   Gate: `bash tests/test-ai-pr-poll-guard-hook.sh` all pass and
   `grep -n "fit-tool-call\|timeout-minutes" bin/ai-pr-poll-guard-hook` is empty.
   PR, merge on green (lean checks, 2026-10-30), then install per
   `docs/deployment.md` on edge-dev3 and edge-dev.
2. **Install check.** On both machines: `bin/ai-adopt-globals --check` → CLEAN
   ×4, and the installed hook prints the new message (pipe a fake
   `gh pr view` loop payload as in the test). Record drift if any; reinstall,
   don't hand-edit.
3. **Re-audit** (task class `private-evidence`). Use
   `bin/ai-transcript-query`: `--since 2026-10-30` with `--topic ci`,
   `--text "ai-pr-wait"`, `--text "timeout"`, `--text "ai-task-gates"`,
   `--topic ai-mistakes`, raising `--limit` as needed. Pick ≥40 interactive
   sessions (drop forks/subagent copies) at random from the matching session
   list; count per criterion: (a) hand-written PR polling loops, (b) task-gate
   class rejections, (c) any use of retired forms (`timeout NNN bin/ai-pr-wait`,
   required `--timeout-minutes`, `--admin` merges, exact-head APPROVE waits),
   (d) Albert corrections. Use `--raw` + ScaleDown only for ambiguous segments.
   Also count `gh run` polling loops (info only). Write
   `~/Dropbox/ai/chat_transcripts/_audit/ruleset-audit-<YYYY-MM-DD>.md`.
   Gate: report file exists with the session id list and four counts.
4. **Post** counts only (no quotes, no segment text) on #1881, signed with
   `$AI_GH_SIGNATURE`; times in EST. Comment on #1998 linking it and close it.
5. **Parent STATUS.** Prose PR updating row 6.1 of
   `plan_ruleset-trim-and-enforce.md` (✅ with the comment id and private report
   path, or ❌ with the failing count and next fix). If ✅, tick `live proof` on
   #1881 and close it. Gate: row on main.

### 10. Tests
`tests/test-ai-pr-poll-guard-hook.sh` (updated message assertion); must stay
green: `tests/test-ai-claude-permissions.sh`, `tests/test-ai-pr-wait.sh`.

### 11. Constraints
Never paste transcript text into GitHub (public repo). Never edit installed
checkouts (`/worksp/ai-devops`) or `git pull` there. Stage only owned files.
Windows: keep the `.cmd` shim and LF endings. Wait on CI with
`bin/ai-pr-wait <pr>` in the background.

### 12. Access
`gh` authenticated as the repo's AI identity; `ssh edge-dev`; transcript store
via Dropbox `ai/transcript-store/` (offline-available). No secrets needed.

## Part 4 — Landing

### 13. Done + risks
Done: hook fix merged and installed on both machines; audit report written;
counts on #1881; #1998 closed; parent row 6.1 updated on main.
Risks: the store may not mark interactive vs. forked sessions — dedupe by
session id. If (c) still fails after the fix, record ❌ with the source of the
retired form; do not loosen the criterion. Rollback for step 1: revert the PR.

## Self-audit (2026-11-04)
1. Fresh session can execute? Yes — §§5, 9, 12 give files, commands, gates.
2. Background and rejected paths carried? Yes — §§5–7 (old method, no-tooling
   ruling, edge-dev staleness).
3. Goal clear for judgment calls? Yes — §1, plus the "never loosen" rule in §13.
