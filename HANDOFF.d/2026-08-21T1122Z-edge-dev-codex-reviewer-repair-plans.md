---
status: OPEN
owner: edge-dev/codex/reviewer-repair-plans
---

# HANDOFF — reviewer repair plan set

Albert asked for one implementation plan per reviewer fix after the full audit in
[`../bugs.md`](../bugs.md). No reviewer code was changed. The governing plans are:

- [`../plan_reviewer_shared_evidence_integrity.md`](../plan_reviewer_shared_evidence_integrity.md)
- [`../plan_codex_reviewer_trust_repair.md`](../plan_codex_reviewer_trust_repair.md)
- [`../plan_deepseek_reviewer_safety_repair.md`](../plan_deepseek_reviewer_safety_repair.md)
- [`../plan_gemini_reviewer_safety_repair.md`](../plan_gemini_reviewer_safety_repair.md)
- [`../plan_grok_reviewer_runtime_repair.md`](../plan_grok_reviewer_runtime_repair.md)
- [`../plan_kimi_reviewer_completion_repair.md`](../plan_kimi_reviewer_completion_repair.md)
- [`../plan_muse_reviewer_availability_repair.md`](../plan_muse_reviewer_availability_repair.md)
- [`../plan_qwen_reviewer_evidence_repair.md`](../plan_qwen_reviewer_evidence_repair.md)
- [`../plan_glm_reviewer_startup_repair.md`](../plan_glm_reviewer_startup_repair.md)

Fresh sessions start with the shared plan, then execute provider plans in the
priority order listed in `bugs.md`. Each plan owns its own STATUS table and must
be updated by the session that executes it. Remove this handoff only after every
linked plan is complete or has been replaced by a clearly linked successor.

