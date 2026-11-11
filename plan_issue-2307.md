---
summary: Plan for issue 2307 doc drift in the closeout-checker architecture note; a docs-only reword remains.
kind: plan
status: open
read-when: Fixing closeout-checker architecture doc drift (issue 2307)
---

# Implementation plan — popcre/ai-devops#2307 (doc drift in closeout-checker architecture note)

Verdict (checked 2026-11-04 against main f2b4f5bd): **STILL REAL, docs-only, small.** Both findings reproduce on main. The code is safe (fails closed); only `docs/architecture.md` is wrong. Fix = reword two sentences. No code change.

## STATUS
| Step | State | Evidence |
|---|---|---|
| 1 Reword docs/architecture.md:65 and :67 | ⬜ open | — |
| 2 PR, merge, close #2307 | ⬜ open | — |

Fresh session starts at Step 1.

## 1. Ultimate goal
The written description of the shared-database "closeout" safety checker must match what the checker actually does, so a future maintainer does not "fix" the checker back into an older, wrong behaviour. If a step conflicts with this goal, the goal wins — stop and flag it.

## 2. What this application is
`popcre/ai-devops` (public) is Albert's AI tooling repo: scripts, skills, CI. `bin/ai-shared-db-closeout-check` is a read-only Python checker that, before an AI session closes out shared-db work, reads claim issues in `popcre/shared-db` and decides which session owns each claim. `docs/architecture.md` documents it. Branch: `main` (protected; PR + merge queue).

## 3. Trigger
Advisory AI review (deepseek, run 41491963305) of PR #2306 (merged 2026-11-02, commit f96739b5) filed #2307. Auto-fixer deferred because the source PR was closed. Findings:
1. `docs/architecture.md:67` still says closeout "reads exactly one posting signature outside fenced examples" — false since #2306 (it now accepts several identical ones).
2. `docs/architecture.md:65` says repeats are accepted "when every signature identifies the same session", but the code compares raw strings (`len(set(signatures)) != 1`, `bin/ai-shared-db-closeout-check:158`), so a full UUID plus its eight-hex prefix, or differing case, for the same session is rejected (fails closed).

## 4. Scope
In: reword `docs/architecture.md` lines 65 and 67–68.
NOT in: any change to `bin/ai-shared-db-closeout-check`; normalising signatures before comparison; new tests; editing the "Superseded 2026-11-02 (PR #2309)" paragraph (~line 76).

## 5. Current state (main f2b4f5bd)
- `bin/ai-shared-db-closeout-check:155-161`: findall all `OWNER_SIGNATURE` matches in prose outside fences; require exactly one distinct literal string AND the count of `^Posted by` lines equal to matches; else `CheckError` (fail closed).
- `OWNER_SIGNATURE` (line 54) accepts full UUID, `ses_…` MiMo id, or eight-hex prefix; comparison is on the raw captured text.
- Later commits fba1f18e (#2309) and d392d2ee (#2311) touched this area but did not change these two sentences.

## 6. Key findings
Code behaviour is correct and conservative; only documentation overstates/contradicts it. Mixed representations failing closed is safe (blocks, never releases).

## 7. Rejected approaches
- Normalising signatures in code (`normalize_session`) so mixed forms pass: adds logic and test surface to a safety checker for a case nobody has hit; skinny rulings (docs/owner-rulings.md 2026-10-29/30) favour fewest moving parts. Rejected.
- Closing #2307 as won't-fix: line 67 is a direct contradiction that invites a harmful "fix"; cheap to correct. Rejected.

## 8. Decisions
Locked: docs-only; wording says "the same literal signature". Open: exact phrasing.

## 9. Steps
**Step 1.** In `docs/architecture.md`:
- Line 65: replace "when every signature identifies the same session" with "when every signature is the same literal text (the same session written the same way; a full UUID and its eight-hex prefix, or differing case, count as different and fail closed)".
- Lines 67–68: replace "closeout reads exactly one posting signature outside fenced examples." with "closeout reads every posting signature outside fenced examples and requires them all to be one identical signature, with no unreadable `Posted by` line."
Verify: `grep -n "exactly one posting signature" docs/architecture.md` returns nothing; `git diff --stat` shows only docs/architecture.md.

**Step 2.** Branch `docs/2307-closeout-signature-wording`, commit as Albert (`git var GIT_COMMITTER_IDENT`) with the repo co-author trailer, PR body `Closes #2307` signed with `$AI_GH_SIGNATURE`, wait with `bin/ai-pr-wait <pr>` in background, merge via queue. Verify: PR merged, #2307 closed, line text on origin/main matches.

## 10. Tests
None new (docs only). Existing CI (incl. `tests/test-ai-shared-db-closeout-check.py`/`.sh`, docs/link checks) must stay green.

## 11. Constraints
Never push to main directly. Reviews advisory, never wait on them. Do not touch checker code. Sign GitHub posts. Times in EST.

## 12. Access
`gh` authenticated as u2giants with popcre access. No secrets needed.

## 13. Done / risks
Done: step 1 grep clean, PR merged, CI green, #2307 closed by the merge. Risk: none functional; rollback = revert doc commit. Open questions: none.

Handoff link: N/A — this plan was requested as a read-only scratch deliverable; the implementing session registers it in HANDOFF.d/ if it is not completed in one sitting.

## Self-audit
1. Fresh session can execute without asking? Yes — exact lines and replacement text in §9, verification gates, scope §4.
2. All background incl. rejected options? Yes — §3, §5–§7.
3. Goal clear for judgment calls? Yes — §1; phrasing left open in §8.
