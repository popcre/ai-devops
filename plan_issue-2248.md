---
summary: Plan for issue 2248 Entire Gates check failing on popdam3 PRs - already fixed, close-out only.
kind: plan
status: open
read-when: Closing out issue 2248 popdam3 gates check
---

# Plan: popcre/ai-devops#2248 — Entire Gates check fails on popdam3 PRs

## VERDICT (read first): ALREADY FIXED — close-out only

Checked 2026-11-04 ~3:50 PM EST against live GitHub (`gh api repos/u2giants/popdam3/commits/<sha>/check-runs`):

- The reported failure `accepts 1 arg(s), received 2` no longer appears. Recent popdam3 PR heads show
  Entire Gates either **NEUTRAL** ("Entire gates do not apply to this pull request: no open trail tracks
  its head branch" — e.g. PR #701 head `f33ea9fafa7f0a01cb6e05c50f23135b623b41fc`, PR #700 head
  `105113264c01bab3d89614a7e317cc84af4e8c71`) or a **real gate evaluation** (PR #704 head
  `d800422db089a7ad7117efb71fb04534aa0dd6b9`: Checks passed, Findings passed, Up to date passed,
  Approvals failed "No reviewers have approved this trail", Trail #117).
- The invocation bug was on Entire's side (app slug `entire`) and was fixed there; nothing in ai-devops or
  popdam3 invokes it, so there is no code for us to change.
- Entire Gates is **not required** on popdam3: `gh api repos/u2giants/popdam3/rules/branches/main` lists
  no required status checks, and the only ruleset (`15652848 "no branches"`) is disabled. It cannot block a merge.
- `gh search issues "accepts 1 arg"` finds only #2248 — no duplicate to close.

Skinny assessment: the original symptom is gone; the residual red "Approvals" result appears only on PRs
with an open Entire trail, is advisory (not required), and matches owner rulings 2026-10-29/30 (reviews
advisory, only data-safety/secret-leak checks may block). Changing or removing the Entire integration is
forbidden during the trial (`docs/entire-trial.md` "Session workflow": no new or changed integrations,
billing, or required checks until 2026-11-12 5:58 AM EST). So: close the issue, no build.

## STATUS

| Step | State | Evidence |
|---|---|---|
| 1 Re-verify symptom absent | ⬜ open (pre-verified 2026-11-04 by planner, commands above) | re-run commands in step 1 |
| 2 Post close-out receipt and close #2248 | ⬜ open | issue comment URL |

Fresh session starts at step 1.

## 1. Ultimate goal
Albert should not see a misleading red CI mark on popdam3 caused by a broken tool. That is now true for
the broken-invocation case. If any step conflicts with this goal, the goal wins — stop and flag it.

## 2. What this application is
popdam3 (`u2giants/popdam3`, personal identity) is POP Creations' digital-asset app. "Entire" (entire.com)
is a third-party trails/review service on a bounded trial owned by popcre/ai-devops#2022; its GitHub App posts
an "Entire Gates" check run on PRs. ai-devops (`popcre/ai-devops`) holds the tooling and trial docs.

## 3. Trigger
ZCode on hetz filed #2248 on 2026-11-01 after Entire Gates failed on popdam3 PRs #623/#624 with
`accepts 1 arg(s), received 2`. No comments since.

## 4. Scope
In: re-verify, post a signed receipt, close #2248.
NOT in: changing/removing the Entire app, its registration, or any required check (trial rules); making the
"Approvals" gate pass (it is advisory and expected without a human trail approval); trial disposition (#2022).

## 5. Current state
No code involved. Live check data in VERDICT section. Nothing committed for this issue.

## 6. Key findings
See VERDICT. The failure was server-side in Entire; it now evaluates correctly.

## 7. Rejected approaches
- Uninstalling Entire / hiding the check: violates trial rules (no integration changes before 2026-11-12) and
  "preserve the capability".
- Opening a new issue for the "Approvals" red: it is the gate working as designed, non-blocking; under skinny
  rulings not worth a ticket. Handle at trial disposition (#2022) if anything.

## 8. Decisions
Locked: close as fixed; do not touch the integration during the trial. Open: none.

## 9. Steps
1. **Re-verify** (read-only). Run
   `gh pr list -R u2giants/popdam3 --state all -L 5 --json number,headRefOid` then for 2-3 head SHAs (one
   command each, no loops over PR reads — a local hook blocks PR-polling loops)
   `gh api repos/u2giants/popdam3/commits/<sha>/check-runs --jq '.check_runs[]|select(.name=="Entire Gates")|.conclusion+": "+.output.summary'`.
   Done when: no summary contains `accepts 1 arg`. If it does reappear, stop and reopen planning (report
   `Blocked —` to Entire vendor via #2022; do not change the integration).
2. **Close out.** `TZ=America/New_York date`, then
   `gh issue close 2248 -R popcre/ai-devops --reason completed --comment "<receipt>"`. Receipt: symptom gone
   (cite the SHAs/conclusions checked), fixed vendor-side, Entire Gates not required on popdam3 main, residual
   "Approvals" failure is advisory by design, no repo change; signed with `$AI_GH_SIGNATURE`.
   Done when: `gh issue view 2248 -R popcre/ai-devops --json state` shows CLOSED.

## 10. Tests
N/A — no code change. Verification is the live check-run read in step 1.

## 11. Constraints
Entire trial rules (`docs/entire-trial.md` "Session workflow"); public material only in comments; EST times;
signed GitHub posts; no new waiting tools; reviews never gate.

## 12. Access
`gh` authenticated as a user that can read `u2giants/popdam3` and write `popcre/ai-devops` issues.

## 13. Done / risks
Done: step 1 clean, #2248 closed with receipt. Risk: vendor regression — re-open if seen. No rollback needed.
Handoff: none created (planner ran read-only); the issue receipt is the record.

## Self-audit
1. Fresh session could execute without questions? Yes — VERDICT + §9 give exact commands and gates.
2. All background incl. rejected options? Yes — §6–7.
3. Goal clear enough for judgment? Yes — §1 plus the reappearance branch in step 1.
Gap acknowledged: no HANDOFF.d link, because this run was restricted to writing this one file.
