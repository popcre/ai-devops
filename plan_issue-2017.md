# Plan — popcre/ai-devops#2017: retire the verified DesignFlow HTS multi-classify handoff

## VERDICT (checked 2026-11-04, 3:51 PM EST) — STILL NEEDED, NOW UNBLOCKED

- The blocker is gone. Owner ruling "2026-10-29 (night) — freeze off" in
  `docs/owner-rulings.md` (ai-devops, line ~167) quotes Albert: "take off the
  freeze and make reviewers preferred but not required". #1948 (freeze tracker) is CLOSED.
- Prerequisites still hold: frontend PR #375 and backend PR #227 are both MERGED
  (`gh pr view 375 -R popcre/designflow-frontend`, `gh pr view 227 -R popcre/designflow-backend`).
  Successful develop builds are recorded in the #2017 body (Cloud Build ids
  dc79f0cd-… and 4e15160f-…, project lithe-breaker-323913, region us-east4).
- The work is NOT done: `HANDOFF.d/2026-10-22T2341Z-edge-dev3-claude-hts-multi-classify.md`
  still exists in popcre/designflow-backend on both `sandbox-albert` and `develop`,
  same blob `84fceec9999eb1fc42a1a47461ee71e01593dec8` (the blob #2017 recorded, so nobody edited it).
  Its only commit is `2e2cdfd9ad` (2026-10-22).
- Bookkeeping drift: parent #1996 is CLOSED while its line `- [ ] #2017` is still unticked.
- Open PR popcre/designflow-backend#311 (sandbox-albert → develop) exists; a deletion
  pushed to sandbox-albert will ride into develop through it (or the next such PR).

## STATUS

| Step | State | Evidence |
|---|---|---|
| 1 Recheck | ⬜ open | — |
| 2 Delete file on sandbox-albert | ⬜ open | — |
| 3 Verify + close | ⬜ open | — |

Fresh session starts at Step 1.

## 1. Ultimate goal
DesignFlow's backend repo keeps a folder of "handoff" notes for unfinished AI work.
One note describes work that is finished, merged and built. Leaving it makes future
AI sessions think the work is still open and redo it. Goal: that note is gone from
the working branch (and, after Uma's normal merge, from develop), and the tracking
issue is closed with proof. If a step conflicts with this goal, the goal wins — stop and flag it.

## 2. What this application is
DesignFlow PLM: POP Creations' product lifecycle app. Repos `popcre/designflow-*`
(this task touches only `popcre/designflow-backend`). Albert's working branch
`sandbox-albert`; delivery target `develop`; Uma/devopswithkube merges to develop;
AI never self-merges DesignFlow PRs. Pushes to sandbox-albert trigger a sandbox Cloud Build
(project lithe-breaker-323913, us-east4). GitHub identity for DesignFlow: `popcre`.

## 3. Trigger
Albert asked on 2026-10-25 to delete the handoff once #375/#227 merged and built.
The ship gate refused because of the reviewer observation freeze (ended 2026-10-29).
The work was parked in #2017 under #1996.

## 4. Scope
In: delete that one file on `sandbox-albert`; fix a stale link to it only if one exists; close #2017.
NOT in: any app code; the other ~49 handoffs in `HANDOFF.d/`; sandbox-sync build
verification from 2026-10-25 (stale, superseded by later pushes — record as "not rechecked, superseded");
merging #311 or any develop PR; reopening #1996; toolkit/gate changes; incident-record rework.

## 5. Current state
File present on sandbox-albert and develop (blob above). No deletion commit or PR exists.
`.ai-devops/task-gates.json` on sandbox-albert maps `HANDOFF.d/**` to class `reviewer-safety`.

## 6. Key findings
The 2026-10-25 refusal was solely the freeze window ("STOP before ship. Reviewer observation week…").
That window file was removed on every host per the 2026-10-29 night ruling. The handoff
header says `status: OPEN` and `issue: none`; its open-risks section (§9) concerns
product follow-ups, not this deletion — Albert's authorization covered deleting it once merged+built.

## 7. Rejected approaches
- Editing the handoff to "status: done" instead of deleting — Albert asked for deletion; Git history preserves it.
- Pushing straight to develop / self-merging — forbidden for DesignFlow.
- Opening a new PR for this alone — unnecessary; sandbox-albert already flows through #311.
- Bypassing the gate if it still refuses — forbidden; report Blocked with exact output.
- Re-verifying the 2026-10-25 sandbox sync builds — obsolete; later pushes superseded them.

## 8. Decisions
Locked: delete (not edit); sandbox-albert only; no self-merge; commit as Albert's verified identity.
Open: whether a reference fix is needed (only if grep finds a link to the filename).

## 9. Steps
1. **Recheck (read-only).** Run `dflow-session-start` skill or at least
   `gh api repos/popcre/designflow-backend/contents/HANDOFF.d/2026-10-22T2341Z-edge-dev3-claude-hts-multi-classify.md?ref=sandbox-albert -q .sha`.
   If 404 → someone already deleted it: skip to Step 3. If the blob differs from
   `84fceec…` → read the new content; if it records new open work, stop and flag.
   Done when: blob confirmed and #375/#227 still MERGED.
2. **Delete.** In a fresh worktree of designflow-backend on `origin/sandbox-albert`:
   `ai-task-gates start --class reviewer-safety --base origin/sandbox-albert`;
   `git grep -n 2026-10-22T2341Z-edge-dev3-claude-hts-multi-classify` and fix any link
   (drop the line); `git rm` the file; check `git var GIT_COMMITTER_IDENT` is Albert Hazan;
   commit `docs(handoff): retire completed HTS multi-classify handoff (#227, frontend #375)`;
   `ai-task-gates check --before ship`; push via `dflow-ship` (race-protected push to sandbox-albert).
   Done when: the contents API on sandbox-albert returns 404 and the commit SHA is on the remote.
3. **Verify and close.** Confirm the sandbox Cloud Build for the new head succeeded
   (`gcloud builds list --project lithe-breaker-323913 --region us-east4 --filter="substitutions.COMMIT_SHA=<sha>"`) —
   docs-only, so a failure there unrelated to this file is reported, not fixed here.
   Confirm the commit appears in open PR #311 (or whichever sandbox-albert→develop PR is open).
   Comment on #2017 (signed with `$AI_GH_SIGNATURE`): deletion SHA, 404 readback, build id,
   develop delivery pending Uma via that PR. Close #2017; tick `#2017` line on #1996 (leave #1996 closed).
   Done when: #2017 closed with those links.

## 10. Tests
No code; no new tests. Gate: `ai-task-gates check --before ship` passes; repo's existing CI on the PR stays green.

## 11. Constraints / gotchas
- Canonical checkouts are landing-only: use a worktree.
- Never `git checkout -b` in a live worktree; never bare `git stash`.
- If the gate still refuses, quote it and report Blocked; no bypass.
- Develop absence is not required to close: it lands when Uma merges; say so explicitly.

## 12. Access
`gh` authenticated as `popcre` for designflow repos; `gcloud` read-only for builds. No secrets needed.

## 13. Done / risks
Done: file absent on sandbox-albert (readback), commit pushed, sandbox build checked,
commit visible in the open develop PR, #2017 closed with evidence, #1996 line ticked.
Risk: negligible (docs deletion; recoverable from `2e2cdfd9ad`). Rollback: `git revert`.
Open question for Albert: none.

Handoff link: this plan lives in a scratchpad by request (read-only planning); the
implementer records progress on #2017 itself, which is the durable handoff.

## Self-audit
1. Fresh session can execute without asking: yes — Verdict, §2, §9 give exact file, branch, commands, gates.
2. Background and rejected routes carried: yes — §3, §6, §7.
3. Goal clear for judgment calls: yes — §1, plus Step 1 stop conditions.
