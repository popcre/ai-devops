---
summary: Plan for issue 2236 stale freeze-window and approval wording after PR 2234; small docs-only fixes remain.
kind: plan
status: open
read-when: Cleaning stale freeze-window text (issue 2236)
---

# Implementation plan — popcre/ai-devops#2236 (stale freeze-window and approval text after PR #2234)

## VERDICT (read first)

**Partly real, small, docs-only.** Checked on main `f2b4f5bd` (2026-11-04):

- Code part of finding 2 is **already fixed**: `tools/oracle_native_alternate_profile.py` no longer mentions `reviewer-approval` (grep is empty). In `bin/ai-task-gates:1632-1637` the reviewer report is now optional (`if [ -n "$reviewer_approval" ]`, labelled "advisory"). Parent issue #2041 is **CLOSED**. No gate left to remove.
- Doc parts are **still real**. `plan_skinny-review.md:214-217`, `:219`, `:305` and `:399` still say the freeze window is live and should be "extended". Inventory row 39 says it was deleted from all 5 hosts. A future agent could recreate the window file, which would undo #2073.
- Finding 3 (row 37 says `install.sh`/`update.sh` are class `code`) is still wrong. `.ai-devops/task-gates.json:27-28` classes them `installation`.
- Finding about `docs/owner-rulings.md:14-16` and `:23-25` is low-value. Those are dated historical entries, and `:150-154` already says "This supersedes earlier rulings that require an exact-head APPROVE." Fix it only with a one-line "Superseded 2026-10-29" marker. Do not rewrite history.

Under skinny this is worth one small docs PR, because it removes an instruction that could bring a removed gate back. It adds no new checks or tools.

## STATUS

| Step | State | Evidence |
|---|---|---|
| 1 Fix plan_skinny-review.md freeze/“59 rows live” text | ⬜ open | — |
| 2 Fix inventory row 37 wording | ⬜ open | — |
| 3 Add superseded markers in owner-rulings | ⬜ open | — |
| 4 PR, merge, close #2236 | ⬜ open | — |

A fresh session starts at step 1.

Handoff link: this plan is a scratch artifact for the stale-issues triage session and is not registered in `HANDOFF.d/`. The implementer creates `HANDOFF.d/` registration only if it leaves work unfinished.

## 1. Ultimate goal

No live document should tell an AI to bring back the review freeze window or approval gates that the owner removed on 2026-10-29/30. Future sessions must read the true current state. If a step conflicts with this goal, the goal wins. Stop and flag it.

## 2. What this application is

`popcre/ai-devops` is Albert's (POP Creations) shared AI toolkit. It holds instructions, skills, `bin/` wrappers such as `ai-task-gates`, installers and CI workflows. These are installed on 5 machines. It is a public repo with default branch `main`, and it is protected, so all changes go through a PR.

## 3. Trigger

The advisory AI review (DeepSeek, run 41262322771) of merged PR #2234 (head `6542fff8`) produced finding issue #2236. The auto-fixer deferred it because the source PR was already closed (label `fixer-deferred`).

## 4. Scope

In scope: text edits to `plan_skinny-review.md`, `docs/reviewer-enforcement-inventory-2026-10-29.md` row 37, and `docs/owner-rulings.md` (markers only).
NOT in scope:
- Any change to `bin/ai-task-gates`, `config/task-gates.json`, or the oracle tools. The `offline-private-capture-transform` → `oracle-native-alternate-descriptor-only-admission` binding is a theoracle opt-in, not a review gate, and it stays.
- Touching hosts. The window files are already gone (row 39).
- Reopening #2041.
- Rewriting the verbatim ruling text.

## 5. Current state

- `plan_skinny-review.md:11-22`: STATUS shows all stages ✅ and line 22 says "All stages are done".
- `:213-217`: "Freeze window" block written in the present tense.
- `:219`: "Everything else … (59 rows) is still live unless STATUS says otherwise". This is false now, because the resolution column marks the rows off.
- `:305`: "B deadline" paragraph with the extend-by-14-days procedure.
- `:399`: the risk "Stage B not merged by 2026-11-12. Extend the window file."
- `docs/reviewer-enforcement-inventory-2026-10-29.md:37`: the row 37 resolution text.
- `docs/owner-rulings.md:14-16`, `:23-25`: "Current rule" lines that mention APPROVE.

## 6. Key findings

These are listed in the VERDICT. The class resolution uses the strongest class (`bin/ai-task-gates` ~423-432), so `install.sh`/`update.sh` resolve to `installation`. The reviewer gate is off for every class (stage B, PR #2057).

## 7. Rejected approaches

- Deleting `plan_skinny-review.md` outright. Memory entries and AGENTS routing point to it, so deleting it creates broken links. Rejected for this tiny fix. (Archiving it is a separate housekeeping call.)
- Adding a CI check that greps for "observation-week". This adds a moving part that is neither data-safety nor secret-leak, so the owner ruling of 2026-10-30 rules it out.
- Changing the `install.sh` classes to `code`. That would weaken the installation protections. The doc is what is wrong, not the config.

## 8. Decisions

Locked:
- The edits are docs only.
- Verbatim rulings are never edited, only annotated.
- Historical sections are kept but marked historical.

Open: the exact wording, as long as it is plain English and in the past tense.

## 9. Steps

1. **`plan_skinny-review.md`.**
   - Replace `:213-217` with: "Freeze window (historical): removed from all 5 hosts by #2073 (inventory row 39). Do not recreate it."
   - Replace `:219` with: "Every inventory row now carries a resolution; see the resolution column."
   - At `:305`, prefix the B-deadline paragraph with "Historical — stage B merged 2026-10-29 (PR #2057); do not act on this." Alternatively, delete the extend procedure.
   - Delete the `:399` risk bullet.
   - Leave §13 "Done when" as is, but add "(met; #2041 closed)".
   Gate: `grep -nE "Extend the window|extended on all 5 hosts|still live unless" plan_skinny-review.md` returns nothing outside a line marked historical.
2. **Inventory row 37.** Change the resolution to: "off — reviewer gate removed for all classes (stage B, PR #2057); reviewer bins are class `code`; `install.sh`/`update.sh` remain `installation` (`.ai-devops/task-gates.json`)". Gate: the row matches `.ai-devops/task-gates.json:27-28`.
3. **`docs/owner-rulings.md`.** After each of the "Current rule" lines at `:14-16` and `:23-25`, add one line: "Superseded in part 2026-10-29 (afternoon): review is advisory; no APPROVE gate." Do not change the verbatim quotes. Gate: `git diff` shows only added lines in that file.
4. **Land it.** Branch `docs/2236-stale-freeze-text`. Commit as Albert's verified identity with the Claude co-author trailer. Open a PR with "Fixes #2236", signed with `$AI_GH_SIGNATURE`. Wait with `bin/ai-pr-wait <pr>` in the background. Merge yourself once required checks pass, since review is advisory. Gate: #2236 shows closed by the merged PR. If auto-close fails, close it with a signed comment that links the merge SHA.

## 10. Tests

No code changes, so no new tests. The existing PR CI (docs lint and link checks) must stay green.

## 11. Constraints and gotchas

- Never push to `main`.
- Work in its own worktree.
- Stage only these three files.
- Do not wait on or request a review.
- Quote times in EST.
- Line numbers may drift, so find the lines by text.

## 12. Access

You need `gh` authenticated with push to popcre/ai-devops. No secrets are needed.

## 13. Done / risks

Done when steps 1-4 are ✅ with the PR merge SHA in STATUS and #2236 is closed. The risk is negligible because the change is docs only; roll back by reverting the PR. No open questions.

## Self-audit

1. Could a fresh session execute this without questions? Yes. The VERDICT and §5 give the exact lines, §9 gives the replacement text and the gates, and §4 bounds the scope.
2. Does it carry every reason? Yes. §7 gives the rejected options and the VERDICT gives the already-fixed evidence.
3. Is the goal clear enough for a judgment call? Yes. §1 sets one goal: no doc revives a removed gate.

Gap noted: the plan is not registered in `HANDOFF.d/` because the task runs read-only (see STATUS note).
