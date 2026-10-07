---
issue: 1436
status: OPEN
owner: claude/reviewer-spend-waste-plan-20261007
---

# HANDOFF — Reviewer token-waste fixes: plan written, implementation not started

Machine: edge-dev3 · Agent: claude · Written: 2026-10-07 5:22 PM EDT
GitHub signature: `Posted by Claude chat 1dcd748e-4e15-41f6-8e73-0a4ae9016ead on edge-dev3`
Plan: [`plan_reviewer-spend-waste.md`](../plan_reviewer-spend-waste.md) · Parent: https://github.com/popcre/ai-devops/issues/1436 · Audit: https://github.com/popcre/ai-devops/issues/1426

## 0. ⚠️ BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

None open. Already settled by Albert on 2026-10-07 — do NOT re-ask: never cap turn/step budgets (Qwen's 120-turn raise stays); remove every silent pay-per-use API-key fallback; Grok is out of scope.

## 1. What this application is

`popcre/ai-devops`: Albert's AI workflow toolkit (reviewer wrappers, review pool, doors, installers). See plan §2.

## 2. What we set out to do this session, and why

Turn audit #1426 (reviewer token waste, all reviewers except Grok) into an executable plan plus parent/child issues, so reviewer spend drops and silent paid-key billing risk is removed without losing review quality.

## 3. Current state — what is true right now

- Plan committed (this PR); all STATUS rows open. No wrapper code changed.
- Parent #1436 with sub-issues #1427 (C1) … #1435 (C9); #1426 has a comment linking the parent.
- Citations re-verified on `origin/main` 3eb7c605; one correction (Gemini drift check is `bin/ai-gemini:618`, not 616).

## 4. Everything we tried that did NOT work

The separate worktree requested for this task was blocked by this session's worktree hook; the plan was written in the session's own worktree, which was identical to `origin/main` 3eb7c605.

## 5. Root causes and key findings

See plan §6 (pool has no reuse memory, allocator ignores passes, unstable prompt prefix, StepFun cold reruns, Gemini false drift, DeepSeek compaction, generic key fallbacks from #1322).

## 6. Exact next steps

Take the first unticked child on #1436 (C1, #1427), do only that one per plan §9 C1, tick it, comment the next child on #1436, and stop.

## 7. Constraints and gotchas in force

Plan §11. Exact-head independent review for reviewer-safety changes; never `--admin`; GLM out of credit until 2026-10-09.

## 8. Access and environment

Plan §12.

## 9. Open questions and risks

Plan §8 OPEN items and §13 risks. C3 likely needs a `popcre/shared-db` allocator PR.

## Self-audit

1-6: Yes — goal, state, failures, next step, terms and section 0 are covered here or in the linked plan, which carries the full detail.
