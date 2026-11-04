# Implementation plan — popcre/ai-devops#2172 (lean required checks: finish stage C and close)

## Verdict (read first)

**Nearly complete; one stage open (checked 2026-11-04 9:42 PM EST).** The
programme plan is [`plan_lean-required-checks.md`](plan_lean-required-checks.md)
and its STATUS is authoritative. Stages A, B, D and E are done with evidence.
Stage C is partial: C1 and C2 landed in `popcre/shared-db` (promotion keys on
the merged PR and preview evidence; required contexts cut to three; guarded
merge, author-lease and agent-work-contract workflows deleted). Still open in
shared-db: move the preview/production exclusive locks out of
`manage-migration-author-lanes.mjs`, then delete the claim/lane code and
`refs/db-contracts`. Work issue: `popcre/shared-db#5228`. Nothing remains to do
in `ai-devops` itself except the STATUS update and closing #2172.

## STATUS

| Step | State | Evidence |
|---|---|---|
| 1 Confirm C3 state in shared-db (#5228) | ⬜ open (2026-11-04) | — |
| 2 Move the two exclusive locks out of `manage-migration-author-lanes.mjs` | ⬜ open | — |
| 3 Delete claim/lane code and `refs/db-contracts` | ⬜ open | — |
| 4 Live proof: a migration PR merges with no lane/claim artefacts | ⬜ open | — |
| 5 Update `plan_lean-required-checks.md` STATUS; close #2172 | ⬜ open | — |

A fresh session starts at Step 1. Handoff registration:
[HANDOFF.d/2026-11-04T2142Z-al8960ofc-claude-open-issue-plans-batch2.md](HANDOFF.d/2026-11-04T2142Z-al8960ofc-claude-open-issue-plans-batch2.md).

---

## 1. Ultimate goal

Albert's words (2026-10-30): "can we bypass/eliminate some or all of the
automatic checks?" then "yes. and do it in a permanent way in the ai-devops
repo so that it hits all apps/harnesses on all machines". A shared-db migration
PR had waited about fifteen hours on paperwork (collision checks, leases,
evidence pairs, queue order), not on data problems. The goal: **a database
change merges as soon as the checks that protect production data pass, and
nothing else can hold it**; every other check is advisory or gone, on every
repository and machine, permanently. **If a step conflicts with this goal, the
goal wins — stop and flag it on #2172.** In particular: never weaken the three
data-safety checks to make something merge faster.

## 2. What this application is

- `popcre/ai-devops`: the toolkit; carries the standing rule (globals,
  `docs/owner-rulings.md` 2026-10-30) and the model plan.
- `popcre/shared-db`: the shared Supabase database repository. Migrations
  under `supabase/migrations/`, promoted to production by
  `.github/workflows/shared-supabase-migrations.yml` after preview rehearsal.
  Required checks now: `SQL migration guards`, `Destructive SQL outside
  migrations`, `supabase/tests against an ephemeral database`.
- Tooling in shared-db touched by stage C: `tools/manage-migration-author-lanes.mjs`
  (author lanes, claims, and — still — the preview/production exclusive locks),
  the `.agent/work/<issue>/<gen>/` evidence-pair convention, and the
  `refs/db-contracts` ref family.

## 3. Trigger

Issue #2172 (owner request above). Model: #2041 / `plan_skinny-review.md`.
The last comment on #2172 (closeout of "Task F session") reports no structural
work; the issue stays open because stage C3 is not finished.

## 4. Scope

In scope: C3 in shared-db; STATUS update and closure in ai-devops.
**NOT in this plan:** touching the three core required checks; the production
promotion workflow's safety (preview rehearsal, tests, no open `review-finding`);
reviewer policy (that is #2041); other repositories (stage D already found none
with required checks).

## 5. Current state

From `plan_lean-required-checks.md` STATUS (2026-10-31 → 2026-11-01):
- A ✅ PR #2174. B ✅ shared-db #5171 (`8dd0e9b2`). D ✅ #2191 merged as
  `d1bc598a`; `verification-closure` is the single required ai-devops check
  (secret boundary). E ✅ shared-db #5233 merged on the three core checks;
  version `20261031232334` promoted to production (run 41265181704).
- C 🟡: C1+C2 done via shared-db #5221, #5226, #5234, #5240. Open: the locks
  and deletion, tracked as shared-db work issue #5228.

## 6. Key findings

- The preview and production exclusive locks are the one piece of the lane
  tool that still matters: two promotions must not rehearse against preview at
  once. They must move to a small standalone helper (or into the promotion
  workflow as a concurrency group) before the lane tool can be deleted.
- `refs/db-contracts` is written by the deleted guarded-merge workflow; nothing
  on `main` reads it after C2. Confirm with `git grep db-contracts` in shared-db
  before deleting the refs (`git push origin --delete refs/db-contracts/<x>`
  per ref; list with `git ls-remote origin 'refs/db-contracts/*'`).
- The ai-devops side is complete and live-proved; only the plan STATUS and the
  issue remain.

## 7. Rejected approaches

- Deleting the lane tool wholesale with the locks inside it: rejected; a race
  between two promotions could rehearse two migrations on preview at once.
- Re-adding any removed check as required "for safety": rejected by the owner
  ruling; it may run advisory only.
- Closing #2172 now with C3 as a follow-up issue: rejected; the issue is the
  programme card and stays open until the scope is complete.

## 8. Decisions

Locked: the rule (only data-safety and secret checks may block); the three
shared-db core checks; `verification-closure` as the only ai-devops required
check; promotion keyed on the merged PR plus preview evidence.
Open: where the exclusive locks live after the move (GitHub Actions
`concurrency:` group on the promotion workflow is the fewest-moving-parts
option; a separate lock helper only if the lock must span manual runs).

## 9. Steps

**Step 1 — Read shared-db #5228.** Read its latest comment and
`plan_shared-db-gate-trim.md` STATUS in ai-devops for any C3 progress since
2026-11-01. Gate: you can state which of "locks moved / lane code deleted /
refs deleted" is true today, with commit SHAs.

**Step 2 — Move the locks.** In shared-db, on a branch from `main`: add
`concurrency: { group: preview-rehearsal, cancel-in-progress: false }` to the
rehearsal job and `group: production-promotion` to the apply job in
`shared-supabase-migrations.yml` (or port the lock helper if a manual path
needs it); remove lock calls into `manage-migration-author-lanes.mjs`. Gate:
`grep -n "manage-migration-author-lanes" .github/workflows/*.yml` returns only
calls you intend to delete in Step 3; the workflow's offline tests pass.

**Step 3 — Delete claim/lane code and refs.** Remove
`tools/manage-migration-author-lanes.mjs`, its tests, the `.agent/work/`
convention docs, and every `refs/db-contracts/*` ref (list first, record the
list in the PR body). Update shared-db `AGENTS.md`/docs that mention lanes or
claims-for-merge (object claims on the issue remain; that is a different
mechanism). Gate: `git grep -n "author-lane\|db-contracts\|evidence-pair"` is
empty outside `archive/` and changelogs; CI green on the three core checks.

**Step 4 — Live proof.** The next real migration PR merges on the three core
checks with no lane, claim-for-merge or evidence-pair artefact, and promotion
applies to production. Record run id and version on #2172. Gate: production
ledger shows the version; the PR timeline shows no lane/lease workflow.

**Step 5 — Close.** Mark stage C ✅ in `plan_lean-required-checks.md` with the
SHAs and run id; post a signed closing comment on #2172; close it.

## 10. Tests required

- shared-db: existing offline workflow/policy tests must stay green; delete
  the lane tool's tests with the tool. New: none beyond a workflow-policy
  assertion that the two `concurrency` groups exist (if that test file already
  asserts workflow shape; otherwise skip — no new check).
- ai-devops: no code change; `bin/ai-doc-reachability` for the plan edit.

## 11. Constraints and gotchas

- Shared-db structural work is claim-first on the existing issue (#5228);
  load `shared-db-change` first; one stage = one PR.
- Production is read-only by default; promotion only via the automatic
  workflow; never a manual production command.
- Keep the three core checks required in both the ruleset and classic
  protection (both lists must match; see `plan_lean-required-checks.md`
  "Removed from required").
- `bin/ai-pr-wait` in the background for every PR; sign comments.

## 12. Access and environment

`gh` as `u2giants` with admin on `popcre/shared-db` (ruleset/protection edits
if any ref deletion is blocked); Supabase MCP read-only for ledger checks;
secrets only via 1Password `vibe_coding` through existing helpers (none should
be needed).

## 13. Definition of done, risks, open questions

Done: Steps 1–5 with evidence on #2172 and in the programme plan STATUS;
#2172 closed. Risk: deleting the lane tool breaks a manual promotion path
nobody documented — mitigate by grepping all workflows and `docs/` first and
by keeping the deletion as its own revertable PR. Open: lock location (§8).

## Self-audit

1. Executable without questions: yes — §5/§6 name the exact remaining items,
   §9 names files, commands and gates.
2. Background carried: yes — the whole programme history is in
   `plan_lean-required-checks.md`, summarised in §5, with §7 rejections.
3. Goal for judgment: yes — §1 with the "never weaken the three checks" rule.
