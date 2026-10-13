# Retirement plan — UNPROVABLE HANDOFF.d batch 2

Tracking: popcre/ai-devops#1661 (comment will carry before/after counts).
Branch: `mimo/housekeeping-unprovable-batch2`. Owner ruling this session: open a
real issue for each still-relevant workstream; retire the rest under the
successor rule, **only with an AI reviewer APPROVE covering these exact files**.

Universe: the 18 UNPROVABLE rows from `bin/ai-housekeeping --details` on
origin/main `b7c8ec80` (before: 18 UNPROVABLE, 0 UNATTRIBUTED). The PR base
moved during the session (`1cc10b53`); UNPROVABLE is still 18 at both refs.

---

## A. Retargeted (file stays; `issue:` becomes a bare number)

Issues created in this batch (verified live before the retarget commit):

| Issue | Title | URL |
|---|---|---|
| #1676 | Finish DeepSeek/Grok/GLM reviewer repair-plan landing verifications | https://github.com/popcre/ai-devops/issues/1676 |
| #1677 | Cache-hit token reporting for DeepSeek and Muse wrappers | https://github.com/popcre/ai-devops/issues/1677 |
| #1678 | Reviewer incident repair: 2026-09-07 residuals and 2026-10-05 open incidents | https://github.com/popcre/ai-devops/issues/1678 |
| #1679 | Accept pop-ai-watchers statuses/PR write on both installations | https://github.com/popcre/ai-devops/issues/1679 |
| #1680 | Resume actions-minutes-reduction plan (parent #1464 closed, STATUS still open) | https://github.com/popcre/ai-devops/issues/1680 |
| #1681 | Disable broad OpenSSH-Server-In-TCP firewall rule on edge-dev | https://github.com/popcre/ai-devops/issues/1681 |

Existing issues reused: [#961](https://github.com/popcre/ai-devops/issues/961)
(WarpBuild Azure BYOC), [#1661](https://github.com/popcre/ai-devops/issues/1661)
(housekeeping leftover triage).

| File | New `issue:` | Why that issue |
|---|---|---|
| `2026-08-21T1122Z-edge-dev-codex-reviewer-repair-plans.md` | 1676 | 3 of 9 linked repair plans still have open STATUS rows (DeepSeek step 6, Grok step 7, GLM 4–5) |
| `2026-08-25T1600Z-edge-dev-claude-reviewer-cache-efficiency.md` | 1677 | `plan_reviewer-cache-efficiency.md` steps 2.1–2.3, 4.1 still open |
| `2026-09-07T1800Z-edge-dev-codex-reviewer-residual-failures.md` | 1678 | named local incident IDs still partially-resolved/OPEN |
| `2026-09-28T1125Z-edge-dev3-codex-warpbuild-azure-byoc.md` | 961 | #961 already owns WarpBuild Azure BYOC setup/canary/migration |
| `2026-09-28T2218Z-edge-dev-mimo-pop-ai-watchers-write-permissions.md` | 1679 | installations still on old read-only grant; handoff itself asked for this issue |
| `2026-10-05T2205Z-edge-dev-mimo-reviewer-issues-after-watchdog.md` | 1678 | same open `.ai/reviewer-issues/` repair need as the 2026-09-07 residuals (deliberate shared tracker; both flip to SUCCESSOR REVIEW when #1678 closes) |
| `2026-10-07T2335Z-edge-dev3-claude-actions-minutes-reduction.md` | 1680 | parent #1464 closed 2026-10-08 while plan STATUS is still all open |
| `2026-10-13T1126Z-edge-dev-mimo-housekeeping-leftover-triage.md` | 1661 | #1661 is the housekeeping leftover-triage tracking issue for this work |

None of these are deleted in this change.

---

## B. Retire (delete) — successor-rule evidence per file

Successor rule (must all be true; checked here for every file):
1. predecessor's own status line says its work was committed and pushed, and
   those commits are on `main`;
2. every still-open obligation it names is carried forward (plan STATUS, a
   still-open issue, or a successor file);
3. nothing in it is a decision or dead end that exists nowhere else.

### B1. `2026-08-14T2015Z-al8960ofc-claude-housekeeping-visibility.md`
- **(1)** Status says `Committed and pushed this session: 2db96bc` and
  `Corrected and pushed on 2026-08-15: commit 49c5627`. Those commits are on
  `main` (plan and this handoff landed together; later corrections in `49c5627`).
- **(2)** The only open obligation was "make the plan discoverable / approve
  implementation". `plan_repo-housekeeping-visibility.md` STATUS steps 1–8 are
  all ✅ done with artifacts (`bin/ai-housekeeping`, tests, schedule, first
  supervised run). Leftover triage lives in #1661 and `HANDOFF.d/2026-10-13T1126Z-edge-dev-mimo-housekeeping-leftover-triage.md` (retargeted to #1661).
- **(3)** Settled decisions (no `--apply`, no file-count cap, no `git branch
  --merged`, MERGED CANDIDATE rule) are locked in the plan §7/§8 and in
  `skills/shared/handoff-writer/SKILL.md`. Nothing unique remains.

### B2. `2026-08-16T0303Z-al8960ofc-codex-housekeeping-plan-corrections.md`
- **(1)** Status/§3 name `49c5627` on `origin/main` as the correction commit.
- **(2)** Same plan, now all steps done; implementation landed via parent #1585
  (closed). No separate obligation.
- **(3)** Corrections (closed-issue ≠ completion; MERGED CANDIDATE needs exact
  head) are in the plan and handoff-writer rules.

### B3. `2026-08-18T1404Z-edge-dev-codex-shared-db-finish-first-plan.md`
- **(1)** The plan it carried was committed (`plan_shared-db-finish-first-delivery.md` is on `main`).
- **(2)** The plan header itself says the premise is **superseded 2026-08-25**
  and directs execution of `plan_shared-db-complete-throughput-repair.md`
  instead. That successor programme is a closed #401 decision record with every
  in-scope row complete. Kimi reliability stays in
  `plan_kimi-windows-execution-reliability.md` (separate, still present).
- **(3)** Consensus document `docs/shared-db-finish-first-plan-consensus-2026-08-18.md`
  and the failure background remain on `main`. No unique decision.

### B4. `2026-09-18T1606Z-edge-dev-kimi-review-packet-race-plan.md`
- **(1)** Status line: `CLOSED — landed 2026-09-19 (PR-C #611 52b9f76f; PR-AB
  #639 918866b8)`. Both merges are on `main`.
- **(2)** Plan STATUS rows all ✅ with those SHAs; issue #608 (closed) carries
  the full record. Traps (re-scope don't delete packet test; #393 locked) are in
  the plan and `plan_review-packet-race-and-evidence-speed.md`.
- **(3)** Nothing unique. (`issue: 608 — ...` is non-bare; if kept it would be
  normalized to bare `608`. Retiring instead.)

### B5. `2026-09-18T1756Z-edge-dev-kimi-gemini-prepare-timeout.md`
- **(1)** Special case: deliberately `issue: none`; do **not** open a tracker.
  Status still says "fix written; ship phase remains" — **stale** (condition 1
  is met by *verified landing*, not by the stale line). **Must re-verify on
  full `origin/main` before delete:** `ca47a1fb fix(ai-gemini): bound
  prepare-phase steps with terminal timeouts (#626)` is merged and
  `bin/ai-gemini` has `PREPARE_TIMEOUT` / `bounded_inventory`. The ship
  happened; the deletion commit re-proves it.
- **(2)** Open obligation (batched hashing) is already issue **#633** (open).
  "Do not kill another session's reviews" is standing rule in the handoff and
  globals. Gemini requalification is owned by later Gemini work (#840/#676 lane).
- **(3)** Diagnosis details are in the handoff and #626/#633; no unique decision
  outside them. Reviewer: confirm the stale "ship remains" line is acceptable to
  retire given `ca47a1fb` is on `main`.

### B6. `2026-09-28T1513Z-edge-dev-mimo-edge-dev-ssh-916-alien-acl-fix.md`
- **(1)** Status/§3: SSH login "done and verified" with live `ssh ... whoami`
  proofs; private-config commit is in `u2giants/ai-devops-private-config`.
  Public repo was not modified except this handoff.
- **(2)** Named leftover (broad `OpenSSH-Server-In-TCP` rule) is now issue
  **#1681** (open). Related SSH fleet work is #1302/#1306.
- **(3)** Settled decisions (916-alien key is correct; do not swap keys) are in
  the handoff §0 and stay true; carried in #1681 body.

### B7. `2026-09-29T1635Z-edge-dev-mimo-c-by-deletion.md`
- **(1)** §3: plan "Merged on main (docs PRs #1078, #1083, #1097, #1101)".
  `plan_shared-db-coordination-deletion.md` STATUS steps 0–9 and 11 are ✅ done
  (row 10 residual is a 14d check on the plan, not this file).
- **(2)** Parent #1061 is closed. Remaining coordination residuals are already
  in still-open handoffs `2026-09-30T1226Z-...-coord-del-residuals.md` and
  `2026-10-04T...`-style residual closeout (issue: 1061) and in the plan.
  Parked-issue tidy is done (plan row 11).
- **(3)** LOCKED decision (C by deletion) is in the plan §8 and
  `docs/shared-db-delivery-failure-background-2026-09-29.md`. Contract block was
  non-standard (no `issue:`); retiring removes the UNPROVABLE/OWNER-UNKNOWN row.

### B8. `2026-10-01T2205Z-edge-dev-mimo-watchdog-local-timed-tasks.md`
- **(1)** Status table marks plan/docs/PR #1193 and plan landings as MERGED.
  `plan_watchdog-local-timed-tasks.md` STATUS P0–P5 are now all ✅ (this handoff's
  "P0–P5 not started" is stale; superseded by `2026-10-05T2205Z-...-reviewer-issues-after-watchdog.md` which records P0–P5 done via PRs #1286/#1313/#1316).
- **(2)** Live duty-pool claim is **#1288** (open). Plan owner issue **#1284**
  (open) carries the P0–P5 checklist. Runbook `docs/watchdog-duty-pool.md`.
- **(3)** Owner decisions (stop paying Blacksmith; free hosted only as backup)
  are in the plan §8 LOCKED and `docs/watchdog-duty-pool.md`.

### B9. `2026-10-12T1444Z-edge-dev-mimo-jev-review-waste-mining.md`
- **(1)** Handoff said "no implementation yet" — **stale**. `main` has
  `074902ed feat(jev): review-waste mining pipeline and waste report (#1620)`
  plus follow-ups `#1647`, `#1656`, `#1668`. Plan STATUS steps 0–6 (incl. 5b
  large sweep) are all done with artifacts under `tests/verification/jev/`.
- **(2)** Remaining items are **owner business decisions** (what to do about
  low-value review traffic; definition of negative value; keep bulk data?) —
  already recorded in the waste report / plan §8 open table. Not an
  implementation workstream. Jev advisory lane stays #643.
- **(3)** Locked design (five-level Score; Jev never opens gates; safety-gate
  bucket) is in the plan and AGENTS.md task-router row.

### B10. `2026-10-13T1240Z-edge-dev-mimo-memory-index-docs-closeout.md`
- **(1)** §3: merge-by-target landed as PR #1614 (commit `b217e535`) — on
  `main`. Docs PR **#1665 is MERGED** (2026-10-13).
- **(2)** Remaining named work is local workspace cleanup (branch
  `mimo/memory-index-decision`, worktree `C:\repos\ai-devops-wt-memory-index`).
  That is machine housekeeping, not a repo obligation; `cleanup-worktree` /
  `bin/ai-housekeeping` own it. Do-not-rewrite-handoff / health-gate constraints
  stay in the memory tools and AGENTS.md.
- **(3)** The merge-by-target decision is recorded in `docs/design-decisions.md`
  (via #1665). Nothing unique remains. (`issue: none` was deliberate: "do not
  open a second tracker".)

---

## C. Execution order (this PR)

1. **This commit (already on the branch):** retargets + this plan + reachability
   links. **No file is deleted yet.** The reviewer is approving the *plan* to
   delete B1–B10.
2. **After APPROVE, one follow-up commit in the same PR:**
   - re-verify on `origin/main` the landing commits cited above
     (`ca47a1fb`, `074902ed`, `2db96bc`, `49c5627`, `b217e535`, `52b9f76f`,
     `918866b8`, and the PR #1665 merge) before removing anything;
   - delete exactly B1–B10;
   - fix every inbound reference listed in section F in that same commit
     (handoff-writer skill: "when you delete a handoff, grep for references and
     fix/remove them in the same commit");
   - rerun `bin/ai-housekeeping --details` and paste before/after into #1661.
3. Then PR → merge queue → verify on `origin/main`.

What this change never does:
- Does not rewrite root `HANDOFF.md`.
- Does not delete any file not listed in section B.
- Does not close any GitHub issue.
- Does not reopen closed parents (#1464, #1061, #608, #1585, #1436).

## F. Inbound references to fix in the deletion commit

`skills/shared/handoff-writer/SKILL.md` requires grepping and fixing inbound
references when a handoff is deleted. Live references at the plan head
(`574ed798`) that must be updated in the same commit as the B1–B10 deletions:

| Target | Inbound reference | Fix |
|---|---|---|
| B1 `2026-08-14T2015Z-...housekeeping-visibility.md` | `plan_repo-housekeeping-visibility.md:7` | replace link with a short "retired 2026-10-13; plan STATUS is the record" note |
| B2 `2026-08-16T0303Z-...plan-corrections.md` | `plan_repo-housekeeping-visibility.md:10` | same |
| B3 `2026-08-18T1404Z-...shared-db-finish-first-plan.md` | `plan_shared-db-finish-first-delivery.md:9` | note supersession by `plan_shared-db-complete-throughput-repair.md` |
| B4 `2026-09-18T1606Z-...review-packet-race-plan.md` | `plan_review-packet-race-and-evidence-speed.md:15` | note landed via #611/#639 / issue #608 |
| B5 `2026-09-18T1756Z-...gemini-prepare-timeout.md` | (none outside this plan) | none |
| B6 `2026-09-28T1513Z-...ssh-916-alien-acl-fix.md` | (none outside this plan) | none; leftover is #1681 |
| B7 `2026-09-29T1635Z-...c-by-deletion.md` | `plan_shared-db-coordination-deletion.md:3`, `:17`; `tests/verification/shared-db-coordination-deletion/adopt-edge-dev3-20260930T051907Z.md:53` | replace with "decision record is this plan §8; session handoff retired 2026-10-13" |
| B8 `2026-10-01T2205Z-...watchdog-local-timed-tasks.md` | `plan_watchdog-local-timed-tasks.md:3`; `docs/watchdog-duty-pool.md:13` | note P0–P5 done / duty-pool runbook is the contract |
| B9 `2026-10-12T1444Z-...jev-review-waste-mining.md` | `plan_jev-review-waste-mining.md:4` | note implementation on `main` (#1620 etc.) |
| B10 `2026-10-13T1240Z-...memory-index-docs-closeout.md` | (none outside this plan) | none |

No gate catches these (`HANDOFF.d/**` is excluded from doc-reachability); the
handoff-writer rule is the control, and section C step 2 enforces it.

## D. Expected housekeeping delta

Before (origin/main `b7c8ec80`, first inventory): 70 OPEN, 0 SUCCESSOR REVIEW,
18 UNPROVABLE, 0 UNATTRIBUTED. On the later PR base `1cc10b53` the OPEN count
is 69 (one unrelated handoff removed upstream); UNPROVABLE is still 18.

After (if all B1–B10 approved): 8 UNPROVABLE files retargeted and stay as OPEN
(bare number + open issue) → 77 OPEN (69 + 8, matching `ai-housekeeping` at
head); 10 files deleted → 0 UNPROVABLE; 0 UNATTRIBUTED (unchanged).

## E. Review ask

APPROVE retirement of exactly B1–B10 (the ten filenames above), or name the
subset you approve. Do not approve deletion of any section-A file.
