---
issue: 2531
status: OPEN
owner: codex/01a1e599
---
# Reviewer rollout continuation

## 0. Business decisions

None for candidate implementation and isolated qualification. Albert explicitly said “don't switch any defaults yet.” Carry that hold through implementation and tests. Activation is outside the current authorization.

## 1. Application

[POP Creations AI DevOps Toolkit](https://github.com/popcre/ai-devops) provides automatic advisory pull-request reviews and interactive second opinions on Ubuntu and Windows. Work from current protected main in isolated worktrees. Release through the established merge queue and platform installers.

## 2. Goal and trigger

Albert picked DeepSeek Harness through OpenRouter for both review entry points. A single OpenCode setup must offer Muse Spark 1.3 Contributor through Meta direct and OpenRouter, plus Hy4 through OpenRouter, on both entry points. Meta direct credential interruptions motivated same-model Muse fallback. Hy4 remains an explicit on-demand choice and final GitHub fallback. Preserve advisory publication, scoped read-only reviews and ongoing conversations.

## 3. Current state

The [implementation plan](../plan_deepseek-harness-openrouter.md) also has a [portable main link](https://github.com/popcre/ai-devops/blob/main/plan_deepseek-harness-openrouter.md). The plan and cache phase landed through [#2532](https://github.com/popcre/ai-devops/pull/2532), [#2545](https://github.com/popcre/ai-devops/pull/2545), [#2547](https://github.com/popcre/ai-devops/pull/2547) and [#2548](https://github.com/popcre/ai-devops/pull/2548). [Parent #2531](https://github.com/popcre/ai-devops/issues/2531) owns integrated live acceptance and the activation hold. GitHub confirmed three open child issues: [DeepSeek #2549](https://github.com/popcre/ai-devops/issues/2549), [OpenCode #2550](https://github.com/popcre/ai-devops/issues/2550), and [caching #2551](https://github.com/popcre/ai-devops/issues/2551). No production candidate wiring, installation, or default switch has occurred. Test PRs [#2537](https://github.com/popcre/ai-devops/pull/2537) and [#2538](https://github.com/popcre/ai-devops/pull/2538) closed without merging. Their purpose was disposable live evidence. Preserve them for reproduction and keep their code out of main.

## 4. Attempts and dead ends

OpenCode’s built-in OpenRouter integration failed for Muse and DeepSeek in the [smoke test](https://github.com/popcre/ai-devops/issues/2531#issuecomment-6927103076). The custom OpenAI-compatible setup passed. Native Muse Code ran slower than OpenCode in the larger comparison and was not selected. A direct DeepSeek endpoint override hits its intentional legacy pin. Loading a cache label into the existing prompt order yielded zero cache reads in six probes. A stable prefix plus a shared label produced hits. The earlier test publisher only relayed locally generated verdicts. PR #2538 did run inference in GitHub Actions. Neither prototype qualifies the permanent route implementation.

## 5. Evidence and limits

- [Larger benchmark](https://github.com/popcre/ai-devops/issues/2531#issuecomment-6927912521): both native harnesses resumed twice and stayed read-only on edge-dev. With the same upstream provider, DeepSeek Harness was faster than OpenCode and had extra false findings in the wider tests. Hy4 found all 27 seeded instances with zero extra findings on synthetic fixtures. It has yet to be scored against real TypeScript review cases.
- [Regular GitHub workflow run](https://github.com/popcre/ai-devops/actions/runs/43948851731) posted [both native verdicts](https://github.com/popcre/ai-devops/pull/2538#issuecomment-6928212224) and an exact-head advisory check. Muse was native Muse Code there. Dogfood the two selected OpenCode Muse routes separately.
- [Muse cache benchmark](https://github.com/popcre/ai-devops/issues/2531#issuecomment-6928592964): on five distinct TypeScript PRs, stable prefix plus cache key saved about 9% of model-request cost with no overall speedup. [OpenRouter guidance](https://openrouter.ai/blog/tutorials/prompt-caching-sticky-routing/) informs the separate Phase C. Long-context behavior and retention require new evidence.

## 6. Exact next steps

1. Begin with [#2549](https://github.com/popcre/ai-devops/issues/2549) and [#2550](https://github.com/popcre/ai-devops/issues/2550). Claim the relevant issue and follow the plan's Phase A. The first gate is a shared four-route registry with scoped credentials and unchanged defaults.
2. Wire both normal review entry points behind candidate selection. Prove status handling, same-model Muse failover, scope checks, and per-session continuation with the plan’s focused tests.
3. Execute Phase B against the exact candidate. Use controlled TypeScript PRs and the regular GitHub workflow. Attach one exact-head publication receipt per route. Verify restart, read-only controls, and credential failure on Ubuntu and edge-dev. Put integrated evidence on the parent, leaving the activation hold in place.
4. After the route candidate passes, execute [#2551](https://github.com/popcre/ai-devops/issues/2551) under Phase C. Its cost, speed and rollback proof is independent of initial route activation.

## 7. Constraints

Preserve GLM and StepFun behavior, legacy sessions, writable delegation, existing defaults, and advisory merges. Candidate reviews use protected credentials, authorized repositories and read-only isolation. Treat policy refusals as terminal and preserve OpenRouter guardrails. Keep exact-head evidence, no anonymous fallback results, and no private prompt or credential content in public receipts.

## 8. Access

Use the authorized POP toolkit GitHub identity and existing protected setup for Ubuntu, Windows edge-dev and GitHub Actions. The plan’s access section names approved vault references in `vibe_coding` without values. Qualification uses disposable public fixtures and test-scoped routing.

## 9. Risks

Shared OpenRouter outage affects three routes. Muse cross-route resume remains unproven and may need scoped replay of visible history. Candidate default settings, read-only enforcement and final verdict attribution need proof on the exact integrated release. No unresolved branch or fixture should be merged to make the workspace appear clean.

## Self-audit

1. §§1–3 and 6 identify the goal, current baseline, four routes, child ownership and executable next gates.
2. §§4–5 preserve the failed integration, comparative evidence, cache data and limits on interpreting the GitHub test.
3. §§6–9 and the linked plan specify what to run, acceptable proof, risks, protected access and rollout scope.
4. The §§1–9 sweep found no new business decision. §0 carries the existing no-switch instruction. The closed fresh-reader pilot was not used.

## Next-session prompt

Continue popcre/ai-devops #2531 from current main. Read the [four-route plan](https://github.com/popcre/ai-devops/blob/main/plan_deepseek-harness-openrouter.md) and this handoff. Begin candidate wiring on #2549 and #2550. Require exact-head GitHub verdicts, scoped read-only review and resume on Ubuntu and edge-dev. Start #2551 after route qualification. Keep all defaults unchanged.
