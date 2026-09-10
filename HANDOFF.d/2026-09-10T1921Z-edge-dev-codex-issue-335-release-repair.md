---
issue: 335
status: OPEN
owner: codex/issue-335-phase4-resolve
---

# HANDOFF — Issue #335 Phase 4 release repair after authorized merges

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

**Blocking — production repair authority is required before either failed release may be changed or retried.** Authorize two exact actions in one message: (1) repair POP PIM's deployment workflow so it uses the documented POST restart route, then merge and release that new repair head; and (2) replace Backrest Wiz's production GHCR pull credential from 1Password `vibe_coding`, then redeploy the already-built image for merge `daf86a69`. Recommendation: authorize both repairs, but keep them separate so each release has its own exact-head and live proof.

The next session must ask for this whole list once before the first production-changing action. Do not treat the 2026-09-10 authorization for the four original PR heads as authority for either new repair or credential change.

Already settled — do not re-ask:

- Albert authorized merging the original current heads of POP CRM #8, POP PIM #6, PopDAM #122, and Backrest Wiz #7, including their existing automatic releases (2026-09-10).
- Keep Issue #335 open and do not start Phase 5 until all 17 coverage rows are landed and the mixed/missing guard passes.
- Do not weaken Backrest's exact-head qualified-review requirement or repeat an unchanged failed production release.

## 1. What this application is

Issue #335 distributes the public `ai-devops` task-gate policy across 17 POP Creations repositories. The four final application rows protect ordinary work from silently reaching production, database, infrastructure, UI, reviewer, or private-data paths. Their main branches run existing production automation; the policy rollout must prove each real release, not merely a merged pull request.

## 2. What we set out to do this session, and why

From fresh `origin/main` at `e42018b5`, this session refreshed the remaining four candidates, restored Backrest's missing independent exact-head evidence, obtained Albert's combined authorization, merged each authorized head, and observed every automatic release. Phase 5 was explicitly excluded.

## 3. Current state — what is true right now

- Issue #335 is OPEN. All 17 policy commits are now landed on their repositories' `main` branches; the central 17-row coverage ledger has **not** been updated and the mixed/missing guard has **not** run.
- POP CRM #8 merged head `ee319d447f5311d723a830a4cd42ca5050ba9773` as `acc367ff493b556ce3639365dbe0d5b794c09100`. GitHub run `34519543318` passed and its production step proved the merged commit is serving.
- PopDAM #122 merged head `e41c9f5635b8f0efb712896db778b35386b4bfaf` as `562dc999ac0039e017fd6b0fd0e32c6172ac6893`. CI run `34519586692` passed; deployment `6379307635` reports `success` for `popdam / production`.
- POP PIM #6 merged head `d5ab6897f0893aafd91ad7973cc34814e648e2f2` as `8ff0c71c23c050dac811cdb4dee1cb879c69b083`. Its image publication succeeded, but run `34519549206` failed before production verification.
- Backrest Wiz #7 merged head `27f4c72f50961ba14b15976eb253c6186567b650` as `daf86a69c8ed02391e73576212634d022313891b`. Its qualified Codex final review `20260910T180614-131691-15227` approved the exact source digest `1f9ae21a…e8436`. Its image build succeeded, but deploy run `34519554165` failed its digest proof.

## 4. Everything we tried that did NOT work

- The renewed Claude exact-head review ended BLOCKED because its provider envelope could not be verified. It is not approval. A separately qualified Codex read-only final check then completed APPROVE in 154 seconds without source change.
- POP PIM's deployment workflow successfully patched Coolify's service configuration, then used a GET request to `/restart`. Coolify returned HTTP 405, so no production verification ran. Do not rerun the unchanged workflow.
- Backrest's server-side `docker login ghcr.io` was denied. `docker compose pull` therefore could not fetch the freshly built digest and recreated the container from a prior cached image; the workflow correctly rejected that stale digest. Do not accept the container restart as a release.

## 5. Root causes and key findings

- POP PIM's deploy workflow contains a method mismatch: its restart endpoint requires POST, while the merged workflow uses GET. Its successful configuration PATCH means the desired service configuration may already name the new SHA-tagged image, but the running release was never verified.
- Backrest's failure is a production registry-pull credential problem, not an application or policy defect. The CI-side build login works, while the production host's separate GHCR credential is denied.
- CRM and PopDAM provide direct release evidence. PIM and Backrest do not, so Phase 4 cannot claim release completion or update coverage as complete.

## 6. Exact next steps

1. Re-resolve Issue #335, the four merge commits, current main heads, and release runs. You will know the starting state is valid when the four PRs remain MERGED and the SHAs above are ancestors of each main branch.
2. After Albert grants the consolidated repair authority in §0, create an isolated current-main POP PIM worktree and make the smallest workflow-only POST-restart repair. Run its focused verification, exact-head review, and required PR checks. You will know it is ready when a fresh authorized merge starts a deploy that verifies the new production commit.
3. After Albert grants §0, use only the protected 1Password procedure to replace Backrest's production GHCR pull credential, then redeploy the already-built `daf86a69` image through the authorized route. You will know it is complete only when the live container digest equals that run's expected digest and the service is healthy.
4. When both releases have direct proof, update all 17 central coverage rows and run the mixed/missing guard. You will know Phase 4 is complete only when it reports no incomplete or mixed row.
5. Only after Step 4, reread all Phase 5 steps, record drift, write its handoff, and stop. Do not execute Phase 5 in this session.

## 7. Constraints and gotchas in force

- Use fresh isolated worktrees; never reset, force-push, or overwrite concurrent work.
- Production changes need exact current-chat authority. The previous authorization covered only the four already-merged heads.
- Do not expose credential values in logs, chat, commits, or review briefs. Use 1Password `vibe_coding` only through its protected process.
- The Backrest review report is private under the ignored `.ai/reviews/` directory. Its APPROVE applies only to `27f4c72f`.
- Keep Issue #335 open, do not update #159/#166, and do not start Phase 5.

## 8. Access and environment

EDGE-DEV has authenticated GitHub CLI, Git, and the installed reviewer wrappers. `C:\Program Files\Git\bin\bash.exe` is the supported Bash. The canonical AI DevOps checkout remains landing-only; this handoff is written from an isolated worktree. Production credential material is in the `vibe_coding` 1Password vault and must never appear in command arguments or output.

## 9. Open questions and risks

The only open owner decision is the combined repair authority in §0. PIM's failed PATCH/GET sequence may have changed its desired Coolify configuration without changing the running deployment; inspect it read-only before any repair. Backrest is currently running a prior image, not the merged policy image. No Phase-5 prerequisite is satisfied until both releases and the 17-row guard are directly proven.

## Self-audit

1. Yes — §§1–3 provide the business purpose, all exact commits/runs, and live outcomes; §6 is executable from a clean session.
2. Yes — §§4–5 preserve the two failed release mechanisms and the review recovery that a successor must not rediscover.
3. Yes — §§0–9 cover decisions, evidence, failures, constraints, access, risks, and gated next steps without secret values.
4. Yes — a line-by-line §§1–9 sweep found only the two production-repair decisions; both are consolidated in §0 with recommendations and a single-message instruction.
