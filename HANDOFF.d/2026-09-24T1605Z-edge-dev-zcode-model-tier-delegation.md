---
issue: 782
status: OPEN
owner: zcode/model-tier-delegation-plan
---

# Model-tier delegation — plan registered, implementation not started

Albert approved (chat, 2026-09-24) a standing instruction so frontier models
(GPT-Sol-6 medium, GLM 5.3 MAX, Mimo v2.6 pro) hand mechanical implementation to
their lower tiers (GPT-6 Luna, GLM 5.3 Flash, Mimo v2.6 flash) from plans that
pass the implementation-plan standard, with the frontier session keeping the
verification duty. Plans stay implementer-agnostic — that ruling is locked.

**The full brief is the plan file:** [`plan_model_tier_delegation.md`](../plan_model_tier_delegation.md)
(repo root). Read its STATUS table first — Step 0 is done (this plan + parent
issue #782); a fresh session starts at Step 1 (verify the three lower-tier
dispatch paths, read-only).

Next exact action: run `bin/ai-task-gates start --class prose` in your own
worktree, then execute Step 1 of the plan and comment the result on
[issue #782](https://github.com/popcre/ai-devops/issues/782).

Delete this file in the same PR that completes the plan's final step.

Posted by ZCode chat unknown on edge-dev
