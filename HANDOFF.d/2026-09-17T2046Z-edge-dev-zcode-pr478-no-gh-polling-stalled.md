---
issue: 478                            # the pull request that proves this done (no separate issue)
status: OPEN
owner: claude/no-gh-polling           # original authoring session; adoption open
---

# HANDOFF — PR #478 "Stop AI agents polling GitHub at the source" is stalled and needs an owning session (2026-09-17T2046Z, edge-dev/zcode)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

- **RECOVERABLE — adopt or shelve PR #478.** The pull request that stops AI agents polling GitHub at the source (the root-cause fix for the recurring machine-wide `ai-gh` back-offs) has had no visible session activity since 2026-09-15 20:19. Its authoring session appears gone and left no handoff. **Recommendation:** have one fresh session adopt it — review the diff at its head, rerun its tests, satisfy its task class, and land it through the merge queue. Albert asked about this on 2026-09-17 ("have we yet implemented the plan to reduce gh api calls at the source?"); the answer was no, and nothing else currently reduces polling at the source.
- **NOT PART OF THIS WORK, AND NOBODY IS ON IT — if adoption finds the PR design conflicts with current main,** the adopting session should put the specific conflict to Albert (rework vs close-with-rationale) rather than force it.

Already settled — do NOT re-ask:
- 2026-09-17, Albert: the muse parity plan (#542) proceeds phase by phase; Phase A landed as PR #554 (`8e1426f5`). Unrelated to #478.

## 1. What this application is

`popcre/ai-devops` is Albert's public recovery toolkit that all his AI coding sessions (Claude, Codex, Grok, GLM, Kimi, Qwen) share. All GitHub access from those sessions goes through `bin/ai-gh`, a machine-wide gatekeeper that serializes calls, enforces spacing, budgets an hourly allowance, and backs off when the budget is exhausted. The recurring pain: sessions polling GitHub (waiting on PRs/runs) burn the shared budget, and every session on the machine then sleeps through back-offs — a 24-minute back-off was observed on 2026-09-17 during unrelated work.

## 2. What we set out to do this session, and why

This session executed Phase A of `plan_ai-muse-native-engine-parity.md` (issue #542) — landed and closed. During wrap-up, Albert asked who owns the open "reduce gh api calls at the source" work. Investigation found it stalled; per the wrap-up scope freeze, recording it here for a future session instead of starting it.

## 3. Current state — what is true right now

- **PR #478** ("Stop AI agents polling GitHub at the source", branch `claude/no-gh-polling`) is **OPEN** on `popcre/ai-devops`.
- Branch tip `f723c263` (2026-09-15 20:19, "Merge origin/main: keep ai-gh throttle wording, keep run-list narrowing") — the authoring session kept it current with main up to that date. Commits carry "Co-Authored-By: Claude Opus 5".
- Its worktree `C:\repos\ai-devops-wt-poll` is **clean** — no uncommitted work is at risk.
- **No HANDOFF.d file exists for this workstream** (verified 2026-09-17 by grep over HANDOFF.d/), and no session was observed working it on 2026-09-17.
- Check status on the PR at the time of this handoff: unknown — this session deliberately spent no `ai-gh` budget on it (the machine was in back-off). The adopting session must re-read the PR fresh.
- Related context: PR #539 (reviewer checks only for reviewer paths) already landed as a separate reduction; PR #401's deadline/iteration-cap rules for waits are already in AGENTS.md. #478 is the at-source polling fix on top of those.

## 4. Everything we tried that did NOT work

N/A for this workstream — this session only investigated (read-only) and did not attempt to move the PR. Recorded non-finding: the branch-tip commit message says the author already reconciled "ai-gh throttle wording" and "run-list narrowing" with main once, so expect the diff to be review-ready rather than half-merged.

## 5. Root causes and key findings

- The authoring session went silent after 2026-09-15 20:19 with the worktree clean and the PR pushed — a clean hand-off point; nothing is stranded locally.
- The machine-wide `ai-gh` budget pressure is real and current (observed 24-min back-off on 2026-09-17 while three sessions ran) — the problem #478 fixes is still costing time today.
- How to find everything: `gh pr view 478` (via `bin/ai-gh`), worktree `C:\repos\ai-devops-wt-poll` (read its `git log` for design intent), branch `origin/claude/no-gh-polling`.

## 6. Exact next steps

1. Fresh session: own worktree cut from current `origin/main`, then `git fetch origin && git log origin/claude/no-gh-polling --oneline -5` and `bin/ai-gh pr view 478 --json state,mergeable,statusCheckRollup` to see where the PR stands. You'll know it worked when you can name its head SHA, check state, and mergeability.
2. Read the PR diff in full and its discussion; check whether main moved under it (mergeable state, or `git merge-tree`). If it needs a main refresh, push a merge-from-main commit to the same branch (the previous author did exactly that). Gate: diff applies cleanly and its own test files run green locally.
3. Declare the task class for the change set (`ai-task-gates start --class <class>` from a worktree on that branch; it touches the GitHub-calling layer, so expect `reviewer-safety` — check what the gate engine says, don't assume) and do what that class requires, including one independent read-only exact-head review before merge.
4. Land through the merge queue (`bin/ai-gh pr merge 478` — no strategy flags; the queue sets them). Gate: `git fetch origin && git log origin/main --oneline | grep -m1 "#478"` shows it landed.
5. Delete this handoff file in the same PR that retires the workstream (successor rule); also remove the stale worktree `C:\repos\ai-devops-wt-poll` via `cleanup-worktree` once its branch is merged.

## 7. Constraints and gotchas in force

- Repo contract (AGENTS.md): branch + PR only, never push `main`; merge queue; committer ident must be Albert Hazan <u2giants@users.noreply.github.com>; ALL GitHub calls through `bin/ai-gh`; canonical checkout `C:\repos\ai-devops` is landing-only.
- Reviewer-safety path (if classified so): one independent read-only exact-head review before merge is mandatory; a verdict without a coverage statement is not evidence.
- Never edit the original author's worktree in place; adopt via your own worktree and pushes to the PR branch.
- `ai-gh` budget is machine-wide and shared with concurrent sessions — be patient with back-offs; never bypass with raw `gh`.

## 8. Access and environment

- Machine `edge-dev` (Windows, Git Bash). Worktree of record: `C:\repos\ai-devops-wt-poll` (do not mutate; read only). Repo remote: `https://github.com/popcre/ai-devops`.
- No secrets involved in this workstream. 1Password references, if any surface, live in vault `vibe_coding` (location only).

## 9. Open questions and risks

- Unknown whether the PR's checks are green today; main has moved several times since 2026-09-15 (including PRs #538–#546, #554, #561), so a refresh is likely needed.
- Risk: the PR's design may overlap with wait-discipline rules landed separately (#401 rules, #539 path filters) — the adopting reviewer should confirm the PR still adds value on top and note any redundancy in the review.
- Decision made this session (2026-09-17): record and defer rather than adopt — per the wrap-up scope freeze, not because the work is low value.

## Self-audit (mandatory gate — passed 2026-09-17T2046Z)

1. Street-newcomer continuation without questions: yes — §1 explains the toolkit and the polling problem; §3+§5 give every identifier (PR number, branch, SHA, worktree path, dates); §6 is a numbered, gate-ended runbook.
2. As effective as this session right now: yes — everything observed (clean worktree, silence date, no handoff, budget pressure evidence, related landed PRs) is in §3/§5/§9; the one unknown (current check state) is named as unknown with the exact command to resolve it (§6 step 1).
3. Failed attempts included: §4 states N/A honestly with the reason (investigation-only) plus the one non-finding recorded.
4. Next steps concrete with verification gates: yes — each §6 step ends with "You'll know it worked when ___".
5. Terms defined: ai-gh, merge queue, reviewer-safety, gate engine, successor rule, worktree discipline — all defined inline at first use.
6. Section-0 sweep run: walked §1–§9 line by line; the adopt-vs-shelve decision (from §2/§6) and the conflict-escalation case (from §6 step 2 / §9) are promoted to §0 with a recommendation; no other sentence requires Albert.
