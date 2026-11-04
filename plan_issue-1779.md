# Implementation plan — popcre/ai-devops#1779 (wrapped sessions keep idle shared-db reservations)

## VERDICT (read first) — core fix DONE; only fleet tail remains

Planned 2026-11-04 from `origin/main` at `f2b4f5bd`. The original problem is fixed and live:

- Checker exists on main: `bin/ai-shared-db-closeout-check` (353 lines) plus `bin/ai-shared-db-closeout-check.cmd`; tests `tests/test-ai-shared-db-closeout-check.py` and `tests/test-ai-shared-db-closeout-check.sh`.
- Shared skills already require it: `skills/shared/shared-db-handover/SKILL.md` ("Before declaring closeout complete, run `ai-shared-db-closeout-check` ... An expired, relinquished or handoff-ready claim still owns its objects and fails this check"); `skills/shared/wrap-up/SKILL.md:109` and `:248`.
- Source PRs merged: #1781 (checker + skills, `3dbba7a4`), #1789 (advisory-job prerequisite), #1802 (Windows UTF-8 fix, `2e0b9d35`), #1804 (handoff, `97b2435a`).
- All four original issue-body checkboxes are ticked; installed live proof in issue comment 6206762517.
- Fleet extension (Albert: "put it into the ai-devops tooling and install it on all computers"): 5 of 6 dev computers (edge-dev3, hetz, 4837, edge-dev, 916) have installed live proof. Only **T16** is missing — no authenticated route (no SSH; WinRM/RDP unreachable; ScreenConnect needs unavailable MFA; last attempt 2026-10-16 7:31 AM EDT).
- Second leftover: edge-dev's *optional* Muse Code pin mismatch. Not part of this need: its tracker #1783 is CLOSED, and Muse has nothing to do with shared-db reservations. Move it off #1779 (Step 4).

What is left is a two-item fleet tail: install on T16, then close. **No code change is planned.**

## STATUS

| Step | State | Evidence |
|---|---|---|
| 1 Re-verify that main still has the fix | ⬜ open | — |
| 2 Confirm T16 is still an approved dev computer and reachable | ⬜ open | — |
| 3 Install on T16 and run the installed live check | ⬜ open | — |
| 4 Move the Muse pin item off #1779 | ⬜ open | — |
| 5 Close #1779 | ⬜ open | — |

Start at Step 1. Handoff backlink: none yet. This is a scratch plan, not committed (the planning session was read-only). If you adopt it, copy it to `plan_1779-closeout-fleet-tail.md`, add a `HANDOFF.d/` entry linking to it, and link back here.

## 1. Ultimate goal

When an AI session ends, it must not leave shared-database objects reserved in its name. If it does, other sessions are blocked until Albert notices. Every dev computer's AI tools must refuse to say "wrapped up" while that session still owns a claim or stage. This is already true on 5 of 6 computers. **If a step conflicts with this goal, the goal wins — stop and flag it.**

## 2. What this application is

`popcre/ai-devops` is Albert's public AI toolkit: skills, `bin/` helpers, and an installer synced to every dev computer. `popcre/shared-db` is the shared Supabase schema repo. Its work is "claim-first": sessions reserve exact objects with claim issues and with preview/merge/production stage leases. The checker reads every open claim and stage on GitHub and fails if any of them is owned by the given session UUID.

## 3. Trigger

A wrapped Codex session released author capacity and published a handoff-ready receipt, but kept claim #4334 (licensing PR #4335). That blocked overlapping work until Albert spotted it. The fix, its review, and its install are done. Albert then widened the need to all computers.

## 4. Scope

In: T16 install plus live proof, cleanup of the Muse item, and closing the issue.
NOT in: any change to the checker or skills, any shared-db write, releasing claims (#4334 is already released; its version stays reserved), changes to shared-db PR #4357, repeating installs on the 5 accepted hosts, repairing Muse itself, and bypassing MFA or changing security on T16.

## 5. Current state of code

Everything above is merged on main and installed on 5 hosts. Nothing is half-done in source. The old handoff `HANDOFF.d/2026-10-16T1307Z-edge-dev3-codex-closeout-fleet-access.md` (merged in `97b2435a`) is now superseded by this plan for the T16 portion.

## 6. Key findings

- Capacity release or a handoff-ready receipt does **not** free a reservation. Only a native release, or a transfer the successor has accepted, frees it. That is the checker's whole reason to exist.
- A GitHub filtered-label query can return a false empty list. The checker cross-checks against an unfiltered listing.
- Windows legacy code pages broke the checker until #1802.
- On edge-dev, one API timeout failed closed as designed. A bounded retry then passed.

## 7. Rejected approaches

- Auto-expiring or auto-releasing claims: rejected. It would be a database write and could release another session's work.
- A second scheduler or claim writer: rejected. The checker is read-only.
- Reaching T16 by guessing credentials, resetting the account, harvesting cookies, or bypassing MFA: forbidden.
- Gating the T16 install on an exact-head AI review: **now obsolete**. Owner rulings 2026-10-15 and 2026-10-29 (night) in `docs/owner-rulings.md` say reviews are never required outside shared-db, including for install. Older issue comments that demand "fresh exact-target native AI review / one-use authorization" are superseded. Use the normal installer.

## 8. Decisions

Locked: the checker design, the skills wording, the 5 accepted hosts, and no-bypass on T16.
Open: whether T16 still belongs in the dev fleet. If the machine atlas no longer lists it as an approved dev computer, record that and treat the fleet as complete (5 of 5).

## 9. Steps

1. **Re-verify main.** Run `bash tests/test-ai-shared-db-closeout-check.sh` and `python3 tests/test-ai-shared-db-closeout-check.py` in a fresh worktree of `origin/main`. Gate: both pass. If either fails, fix it on #1779 before going on.
2. **T16 status.** Read the protected machine atlas (private; reached through the `machine-tool-sync-catalog` memory / `sync-dotfiles` route) and confirm T16 is an approved dev computer. Probe SSH, WinRM, RDP, and Tailscale presence read-only. Gate: one recorded answer per question, with the time in EST. If T16 has been retired from the atlas, skip to Step 4 and note the retirement on the issue. If it is listed but unreachable, report `Blocked —` with the owner (whoever controls T16's MFA/remote access), stop, and leave #1779 open with one checkbox. Do not loop.
3. **Install on T16** (only when a legitimate route exists). Use the normal Windows installer path that `sync-dotfiles` uses, with no review gate. Then verify that the installed `ai-shared-db-closeout-check.cmd` runs, its hash matches main's `bin/ai-shared-db-closeout-check`, and the wrap-up and shared-db-handover skills for Claude and Codex match main. Run the installed checker against real GitHub with a session UUID. Gate: `ok:true`, `blocking_claims:[]`, `blocking_stages:[]`.
4. **Muse item.** Check whether edge-dev's Muse pin still mismatches by running its native doctor. If it is still broken, put a one-line pointer on the active Muse/reviewer issue (#2041, or a successor found with `gh issue list --search muse`) and remove it from #1779. Gate: #1779 no longer lists Muse.
5. **Close #1779.** Tick the two fleet checkboxes, then post one signed comment (`$AI_GH_SIGNATURE`) with the T16 proof or T16-retired evidence. Gate: `gh issue view 1779 --json state` returns CLOSED.

## 10. Tests

Existing suites: `tests/test-ai-shared-db-closeout-check.{py,sh}` (27 cases). No new tests, because no code changes.

## 11. Constraints

- Read-only toward shared-db.
- Never release a claim this session does not own.
- Times in EST.
- Sign GitHub posts.
- Under the 30-minute no-progress rule, a T16 access failure is reported once as `Blocked —`, not polled.
- Keep private topology off the public issue.

## 12. Access

`gh` must be authenticated as `u2giants` with popcre access. T16 credentials, if they exist, are in 1Password `vibe_coding`. Reference them by item title only.

## 13. Done, risks, open

Done: T16 proved or retired, Muse moved off, and the issue closed with evidence.
Risk: none to production, because everything is read-only.
Open question for Albert (business meaning): **Is T16 still a computer you use for AI work, and if so, who can give it remote access?** If he says no, the fleet is complete at 5.

## Self-audit

1. Can a fresh session execute this without asking? Yes. The verdict, §5 and §9 give the paths and gates, and the only unknown, T16's status, has decision criteria in §8 and Step 2.
2. Is all the background carried? Yes. §6 covers the findings, §7 the rejected approaches, and the obsolete review gate is called out.
3. Is the goal clear enough for judgment calls? Yes. §1 lets the implementer close at 5/5 if T16 is retired.
Gap: no HANDOFF.d backlink, because writes were restricted to scratch. This is noted in STATUS for whoever adopts the plan.
