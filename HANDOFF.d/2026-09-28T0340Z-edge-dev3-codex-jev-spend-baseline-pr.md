---
issue: 643
status: OPEN
owner: codex/jev-spend-baseline
---

# HANDOFF — Jev spend baseline PR (2026-09-27 11:40 PM EDT, edge-dev3/Codex)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

Albert has no new decision to make. His request authorized a measured Jev spend-reduction attempt; the plan's locked selection rule makes **no-go** the required outcome when no candidate qualifies. Keep the separate advisory Jev work under issue #643 open.

The coordinator owns the merge decision. It approved the **pre-handoff** PR head `e2da9d8dda7c872f4a62e192a18be43f683c00ae` only after required CI passes. Adding this handoff changes the head and invalidates that approval. The coordinator must inspect the new exact head and explicitly approve it before merge; recommend approval only if the PR diff is this handoff plus the already reviewed eight task-owned files and required checks pass. If CI fails or the head changes again, stop for another decision. No production, shared database, secret, or external-data approval is needed.

## 1. What this application is

`popcre/ai-devops` is POP Creations' public recovery and operating toolkit for Claude, Codex, reviewers, skills, CI, and machine setup. GitHub `main` is protected and uses pull requests and a merge queue. Installation from this repository is its deployment mechanism. This work is in a dedicated worktree at `/home/ahazan/repos/ai-devops-jev-spend-baseline`; the canonical checkout is landing-only. TypeSafe Jev is a typed decision service already evaluated in separate advisory plans; this lane asks whether it can actually reduce paid frontier-model spend.

## 2. What we set out to do and why

Albert asked a subagent to measure one existing paid model decision Jev could replace, then to implement every plan step under coordinator oversight. The first open row of [`plan_typesafe-jev-spend-reduction.md`](../plan_typesafe-jev-spend-reduction.md) requires a structural transcript audit, real caller inspection, and at least 30 independent public ground-truth cases for any target. Its locked rule says to stop and close the later steps as N/A if none qualifies. The outcome is no-go, so no Jev caller, client, shadow evaluation, installation, or rollout is justified. This is separate from the still-open advisory issue-pair pilot.

## 3. Current state — verified facts and exact ownership

- [PR #904](https://github.com/popcre/ai-devops/pull/904) is **OPEN**, unmerged, and pushed. Immediately before this handoff, its exact head was `e2da9d8dda7c872f4a62e192a18be43f683c00ae`; after committing this file, use `git rev-parse HEAD` and the PR's `headRefOid` to record the new exact head. Do not assume the pre-handoff approval carries forward.
- [`tests/verification/jev/spend-baseline-20260928T0243Z.md`](../tests/verification/jev/spend-baseline-20260928T0243Z.md) contains the reproducible no-go baseline. [`spend_baseline_audit.py`](../tests/verification/jev/spend_baseline_audit.py) prints aggregate usage without transcript content; [`test-jev-spend-baseline.sh`](../tests/test-jev-spend-baseline.sh) checks deduplication and content exclusion. [`config/ci-suite-manifest.json`](../config/ci-suite-manifest.json) registers the new test.
- The spend plan STATUS has row 1 no-go complete and rows 2–5 N/A. [`plan_typesafe-jev-decision-layer.md`](../plan_typesafe-jev-decision-layer.md) holds the durable conclusion. The predecessor handoff for this spend lane was retired in the PR; this new file exists only because the PR has not landed.
- The first current-head CI run failed Windows offline section 3 at `test-mcp-skill-drift.ps1`: `FAIL skills carrying disable-model-invocation match the documented list typesafe-ai (<=)`. The TypeSafe skill had landed on `main` as manual-only, but [`docs/context-engineering.md`](../docs/context-engineering.md) still listed fifteen instead of sixteen. The PR now lists `typesafe-ai`; local structural verification reported `manual-only match: True flagged: 16 listed: 16 difference: []`.
- At the last live [PR #904](https://github.com/popcre/ai-devops/pull/904) check at **11:40 PM EDT on 2026-09-27**, head `e2da9d8...` had fast classifier, all four Linux shards, Linux aggregate, Windows sections 4 and 5, and reviewer availability green. Windows sections 1, 2, 3, 6 and reviewer fallback were still running. This snapshot will be superseded by checks on the new handoff commit. No installed Jev spend substitution exists.
- The worktree was clean before this file. `origin/main` has moved during this session; do not merge it into the PR merely to keep up. Compare the actual PR diff and use the task gate against the correct upstream base. Issue #643 remains open for separate advisory work. A signed final no-go comment there and merged-main verification have **not** been done.

## 4. What did not work

1. A keyword scan of transcripts could not establish billable savings because system prompts, copied policy, tool output, and ordinary conversation contaminate mentions. The audit instead parsed structural JSONL records and provider usage fields, excluded subagents and duplicate sessions, and printed no private text.
2. Reviewer-maintenance commands appeared inside paid agent sessions, but `bin/ai-reviewer-issue` and `tools/reviewer_maintenance.py` classify structured events deterministically. There is no separate paid category-suggestion call to skip. Public issue sorting has no existing paid sorting caller; the advisory pilot would initially replace human time. Skill reads occur, but there are no observed labels proving which full reads were unnecessary across 30 independent public cases. Do not rebrand any of these as a token-saving substitution.
3. The local full test series ran 101 Bash suites. Seven initially failed; four passed on a targeted rerun using a temporary project-scoped `python` compatibility path because this host has `python3` but no `python` command. Three unrelated failures remained in GLM interrupted-prune, GitHub timing, and StepFun wrong-binary tests. Do not change system binaries or suppress those tests to make this PR appear green. The new audit test and workflow-policy test passed; the required CI is the landing gate.
4. The first Windows CI run found a real cross-plan documentation drift after the new TypeSafe skill landed on upstream. Updating the documented manual-only list fixed the local structural mismatch; the current-head Windows rerun remains the decisive proof. A bounded check briefly reported green for an older head, so every later check must pair `headRefOid` with check conclusions.

## 5. Root causes and key findings

- The plan's §8 selection rule requires **all four** properties: a concrete existing frontier call or avoidable full skill read, 30 independent public cases, observable ground truth, and a reversible caller. The measured candidates each lack at least one; details and bounded counts are in the baseline artifact. Aggregate token totals cannot be priced as one provider/model rate and cannot be attributed to a replaceable call. Estimated replaceable spend is **unavailable**, not zero.
- Claude skill loading already follows a model choice from the available-skills list. Codex reads the matching skill/router file when task instructions require it. The paid `claude -p` calls in `docs/skill-trigger-eval.md` test trigger behavior; they are not a recurring production decision Jev could displace.
- Windows `test-mcp-skill-drift.ps1` requires the documented manual-only skill list to equal the skills carrying `disable-model-invocation: true`. The new `skills/shared/typesafe-ai/SKILL.md` brought the flagged count to sixteen. The documentation-only correction preserves the skill and the check.

## 6. Exact next steps

1. Verify this handoff commit is pushed and read the PR's **new** `headRefOid`; send it and the eight-plus-one file diff to the coordinator for a fresh merge decision. You'll know it worked when the coordinator explicitly approves that exact SHA and the PR diff contains no other task-owned changes.
2. Recheck required CI for that exact head through `bin/ai-gh`. Inspect any failure's exact job log and stop for a new decision if a check fails or the head moves. You'll know it worked when every required check is SUCCESS or an expected SKIPPED result at the approved head.
3. Run `ai-task-gates check --before ship`; merge through GitHub's protected-branch/merge-queue route using `bin/ai-gh`, then wait with `bin/ai-pr-wait 904 --repo popcre/ai-devops` within its bounded deadline. You'll know it worked when PR #904 reports MERGED and the merge queue's required checks pass. Register `ai-blocker-watch wait` before ending a turn on a wait that may exceed ten minutes; use the existing issue #643 as owner and a fresh brief.
4. Fetch `origin/main`, verify the merged change and no-go record are present, and post a concise signed no-go outcome on issue #643 using `bin/ai-gh`. Do not close #643: it owns the separate advisory Jev pilot. You'll know it worked when the intended commit is on `origin/main` and the issue comment links the merged PR and says no runtime integration was added.
5. Retire **this** handoff only when the PR, issue comment, and merged-main proof are complete. Git history preserves it. You'll know it worked when no open Jev spend-reduction handoff remains and the plan STATUS still has no open row.

## 7. Constraints and gotchas

Use `AGENTS.md` and the repository task router. GitHub calls go through `bin/ai-gh`; no direct push to protected `main`. Stage only task-owned files. Before any ship or PR wait, run the task gate against the actual current base; an older base can misclassify unrelated merged reviewer-safety changes as part of this PR. Never force-push, replace OS binaries, expose private transcript text or identifiers, send it to TypeSafe, or treat a Jev call as a gate-opening verdict. The advisory plan stays separately open. Any time shown to Albert, in issue comments, or in status notes must be named EDT/EST. Sign GitHub posts `Posted by Codex chat <thread id> on <machine>`; this chat's ID is `01a0e5da-65b8-7fa3-b355-af7a7b43bd58` on `edge-dev3`. The PR may change head when this handoff is committed; prior exact-head approval is then void.

## 8. Access and environment

- Worktree: `/home/ahazan/repos/ai-devops-jev-spend-baseline`, branch `codex/jev-spend-baseline`, remote `popcre/ai-devops`, PR #904, tracking issue #643. The public repo holds only aggregate audit output and synthetic test content.
- The private transcript archive was read locally at `/home/ahazan/Dropbox/ai/chat_transcripts/`; never commit, quote, or upload its raw JSONL. Recompute with `python3 tests/verification/jev/spend_baseline_audit.py /home/ahazan/Dropbox/ai/chat_transcripts` from the worktree.
- No Jev secret was read or used. If a future independent plan needs the key, the standing reference is 1Password vault `vibe_coding`, item `typesafe.ai API`, resolved through `op run`; this no-go lane needs no key.
- A BlockerWatch wait for PR #904 was registered as `20260928T032810-codex-01a0e5da-popcre_ai-devops_904` with an earlier head in its brief. Check `ai-blocker-watch list`; after this commit, refresh or replace the wait's brief so a resumed session sees the new SHA. Do not leave competing waits or depend on a stale exact-head approval.

## 9. Open questions, risks, and self-audit

The only live uncertainty is whether required CI passes the **new** exact head and whether the coordinator renews merge approval. A fresh upstream commit may appear; reconcile only if necessary and get another exact-head decision if it changes the PR. The main substantive conclusion is settled no-go by the plan's locked rule; future newly instrumented callers require a new baseline, not an unsupported continuation of this one. No shared-db change or handover occurred.

**Self-audit:** (1) A newcomer can continue from §§1–3, 6–8 with repo, PR, head, tests, commands, and gates stated. (2) §§2, 4–5 preserve purpose and failed approaches. (3) §§0–9 cover background, current state, evidence, constraints, risks, and verification. (4) The §0 sweep found no Albert decision; its only approval item is the coordinator's new exact-head merge decision, also stated in §§3, 6–7, and 9. All ten required sections are present; no raw private content or secret value is included.
