# Reviewer recurrence — step 1 inventory (edge-dev3, October 16, 2026, 9:40 AM EDT)

Issue: [#1783](https://github.com/popcre/ai-devops/issues/1783). Plan: [plan_reviewer-recurrence-repair.md](../../../plan_reviewer-recurrence-repair.md) step 1. Sanitized facts only; raw incidents stay private.

## Incident manifest

- Unresolved edge-dev3 records: **82** (planning snapshot said 80). Open 80, partially-resolved 2.
- By provider: Qwen 48, Gemini 9, DeepSeek 7, StepFun 6, Muse 4, GLM 4, Grok 2, Codex 2.
- Private exact-ID manifest (ID, first time, provider, state, category, evidence-directory SHA-256, owner, disposition) is kept machine-locally with mode 0600; its SHA-256 is `72ba98e6aa2a79294e6d13dfdcef15d41b6a807a46481092273cf4589df97b97`. Zero records lack evidence directories.
- Existing maintenance round `9ab8742784db401b8018fe97e5da44e0` is active and was preserved, not reset.

| Provider group | Owner | Disposition |
|---|---|---|
| Muse (4) | #674 recovery; #1783 coordinator | Reproduce under step 3 |
| GLM (4) | #1349 | Reproduce under step 5; final-receipt route already proved live on #1783 (assignment 6604) |
| StepFun (6) | #1370 | Reproduce under step 4 |
| DeepSeek (7) | #1405 | Reproduce under step 5 |
| Qwen, Gemini, Grok (59) | #1783 | Frozen provider: tracked limitation; common-layer causes checked in step 2 |
| Codex (2) | #1783 | Non-member: tracked limitation |

No record was marked resolved by this inventory.

## Installed identity

- Installed checkout `4ddd46d3676f5783787830b005028d0dc32423b2`, clean; current main `2e0b9d35` is two commits ahead (closeout UTF-8 fix, gates fixture route — neither touches reviewer wrappers).
- `/usr/local/bin` launchers for ai-review, ai-muse, ai-stepfun, ai-glm, ai-deepseek-agent, ai-review-packet, ai-review-sandbox and ai-reviewer-issue resolve into the installed checkout and are byte-equal to its committed source.
- Muse Code: pin `1.4.7-R6101.1` binary present; `muse` on PATH reports `1.4.9-R6297.1`. Step 3 re-pin must start from this split.

## Ownership refresh

Bounded lanes already active on #1783: Muse final-packet receipt (PR1799 installed), protected install + GLM governed proof (4ddd46d3), consumer recording incident. Their scopes are retained.
