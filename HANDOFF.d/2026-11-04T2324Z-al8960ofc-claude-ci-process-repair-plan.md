---
issue: 2367
status: OPEN
owner: claude/ci-process-improvement-plan-1082ae
---

# HANDOFF — CI process repair plan (2026-11-04 23:24 UTC, al8960ofc/Claude)

## 0. ⚠️ BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

One question was put to Albert and not answered when this session closed: start building the plan now, or hold? His original request was for a plan only, so building has not started.

No other decision is his. If [plan step 3.3](https://github.com/popcre/ai-devops/blob/main/plan_ci-process-repair.md) finds a payment setting only he can change, that becomes one plain request.

## 1. What this application is

[`popcre/ai-devops`](https://github.com/popcre/ai-devops) is Albert's public toolkit for AI coding sessions. The plan also touches [`popcre/shared-db`](https://github.com/popcre/shared-db), the shared database structure, and the CI and deploy workflows of the application repos. Albert owns POP Creations and is not a programmer.

## 2. What we set out to do this session, and why

Albert asked for all transcripts about CI to be reviewed, and for an implementation plan solving every problem in the CI process. CI has caused most of the delivery delays since August.

## 3. Current state — what is true right now

- **Done and merged:** [the plan](https://github.com/popcre/ai-devops/blob/main/plan_ci-process-repair.md) and [the measured baseline](https://github.com/popcre/ai-devops/blob/main/tests/verification/ci-process/baseline-2026-11-04.md), through [PR #2368](https://github.com/popcre/ai-devops/pull/2368), commit `76f979c5`. Linked from [the task router](https://github.com/popcre/ai-devops/blob/main/docs/task-router.md) and [pending work](https://github.com/popcre/ai-devops/blob/main/docs/pending-work.md).
- **Owner issue:** [#2367](https://github.com/popcre/ai-devops/issues/2367), open, with phase checklist.
- **Not started:** all 29 plan steps. No workflow, script or test was changed. Nothing in `popcre/shared-db` was changed, and this session held no claims there.
- **Private catalogue:** 16 findings files with segment ids, in Albert's Dropbox at `ai/transcript-store/reports/ci-findings-2026-11-04/`. Never paste them into GitHub.

## 4. Everything we tried that did NOT work

- `ai-transcript-query` reported the store unavailable. Dropbox is on `D:` on al8960ofc. Setting `AI_TRANSCRIPT_STORE_ROOT` to the `D:` location worked.
- The first reading of the shared-db queue was wrong. Logs said #5541 caused REFUSED on three pull requests, so it looked like a block. All three had merged, because that gate is advisory. Albert was briefly told it was blocking, and this was corrected in the same session.
- A ruleset read returned 404 because the id belonged to the other repo. It is not a finding.
- Counting by the "billing lock" subject gave about 900 segments, which is false. See section 5.
- A very long shell command failed on Windows with a name-too-long error. Write long files with the file tool.

## 5. Root causes and key findings

Full list in [plan section 6](https://github.com/popcre/ai-devops/blob/main/plan_ci-process-repair.md). The main ones:

- ai-devops `verify` failed 66 of 72 merge-queue runs, mainly because [the evidence command](https://github.com/popcre/ai-devops/blob/main/bin/ai-merge-group-evidence#L256) treats an unfinished run as failure.
- 13 of the last 20 merged pull requests had a failed check that nobody owned. Tests became advisory on 2026-10-30, and nothing replaced the pressure to fix them.
- [`review-fixer.yml`](https://github.com/popcre/ai-devops/blob/main/.github/workflows/review-fixer.yml#L17-L18) runs on every push and delete: 675 of 1,000 runs.
- shared-db has 19 open automatic-fix pull requests, 11 in conflict.
- Production promotion has failed in a new form after each fix.
- The "billing lock" subject comes from [the summariser's example header](https://github.com/popcre/ai-devops/blob/main/tools/transcript_store/prompt_v5.txt#L53). Real locks did occur on 2026-07-27 and 2026-10-28 to 10-29, with no recorded cause.

## 6. Exact next steps

1. If Albert says to build, or a session is told to continue, open the plan's STATUS and start at step 0.1.
2. After step 0.1, phases 1 to 5 can run in parallel, one session per phase.
3. Step 5.3 includes the transcript store issue found here: readers saw two unredacted credentials in store text, a deploy-platform token and an ERP key. Their values were not copied. Segment ids are in `findings_00.md` in the private catalogue. Decide handling under the standing secrets rule, and fix the redaction patterns.

## 7. Constraints and gotchas in force

See [plan section 11](https://github.com/popcre/ai-devops/blob/main/plan_ci-process-repair.md). Do not add a required check or review gate. Do not use the `review-finding` label for CI failures, because in shared-db it holds production. Do not redo work listed under existing owners in plan section 5. `TZ=America/New_York date` printed GMT in Git Bash on al8960ofc.

## 8. Access and environment

`gh` through `bin/ai-gh`. The store is read-only through `ai-transcript-query`. No secrets were needed. Secrets stay in 1Password vault `vibe_coding`.

## 9. Open questions and risks

- Why the October billing lock happened (step 3.3).
- Whether out-of-order migrations apply safely (step 2.7).
- Whether today's Linux test failures are environment or code (step 1.2).
- Highest risk: steps 2.1 and 2.7 change what reaches production. Follow the adversarial table.
- The baseline windows differ because the GitHub API caps at 1,000 runs: four days for ai-devops, under 20 hours for shared-db.

## Self-audit

A stranger can continue from sections 0, 3 and 6 plus the plan's STATUS. Failed attempts are in section 4, and the reasoning is in section 5 and the plan's sections 6 to 8. Evidence: every section above is filled, and files are named by GitHub URL except the private Dropbox catalogue, which has no URL.
