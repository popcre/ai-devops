---
issue: 2619
status: OPEN
owner: codex/reviewer-quality-cost-plan
---

# Reviewer quality and cost rollout

## 0. Business decisions

None pending. On November 18, 2026, Albert explicitly accepted Muse Contributor's data-use terms and said not to ask again. Preserve defaults during implementation and qualification.

## 1. Application

[AI DevOps](https://github.com/popcre/ai-devops) provides GitHub reviews and local second opinions. The fleet is edge-dev3 and hetz on Ubuntu and edge-dev on Windows.

## 2. Goal

Make reviews cheaper without weakening findings, citations, context, or verdicts. This session authored the [execution plan](../plan_reviewer-quality-cost.md). Implementation and live proof remain open on [#2619](https://github.com/popcre/ai-devops/issues/2619).

## 3. Current state

Planning started from [d1bea4a8](https://github.com/popcre/ai-devops/commit/d1bea4a82e2a8b2b1d9bf0c50e006ab73ff43a7b). [The previous signed receipts](https://github.com/popcre/ai-devops/issues/2551#issuecomment-6967526056) establish historical installed coverage. This planning session made no host or reviewer changes.

## 4. Prior dead ends

The [fleet cost record](https://github.com/popcre/ai-devops/blob/main/plan_deepseek-harness-openrouter.md#status) documents lean prompt quality loss, the wrong file-map citation, incomplete Muse direct billing, and the short Hy4 deadline. Reuse these findings.

## 5. Findings

Muse OpenRouter's earlier paired sample saved 28% with six usable results in each group. DeepSeek and Hy4 had no demonstrated saving per usable review. The [route implementation](https://github.com/popcre/ai-devops/blob/d1bea4a82e2a8b2b1d9bf0c50e006ab73ff43a7b/tools/reviewer_routes.py#L141) already contains the opt-in settings.

## 6. Exact next steps

1. Claim #2619 and execute Step 1 of the linked plan. Verify the case manifest, billed smoke, and current defaults on each host.
2. Execute Steps 2–3. Verify native installation receipts, full input, and unchanged defaults.
3. Execute Steps 4–6. Verify the isolated Muse pilot, independent route comparisons, rollback, and signed fleet live proof.

Use the plan's launch prompt for the implementing session.

## 7. Constraints

Reuse billing and sessions, keep private evidence protected, use exact-head fixtures and native installers, and keep all experimental settings scoped. No fleet-wide activation.

## 8. Access

Use the governed GitHub CLI as u2giants, existing SSH access and configured providers. The plan identifies the protected 1Password vault and read-only billing credential. Verify access in Step 1.

## 9. Open risks

Endpoint, billing and runtime can drift. Reconcile installed state separately from source. Record any inconclusive test and keep its setting off. No loss of user evidence or review capability is acceptable.

Self-audit passed. Sections 0–2 establish the owner's decision and purpose, §§3–5 preserve the baseline and prior failures, and §§6–9 route a fresh session to executable steps and proof.
