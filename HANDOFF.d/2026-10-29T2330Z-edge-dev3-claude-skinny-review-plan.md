---
issue: 2041
status: OPEN
owner: claude/skinny-review-plan
---

# HANDOFF — skinny advisory review plan (edge-dev3/claude, 2026-10-29)

The plan to execute is [plan_skinny-review.md](../plan_skinny-review.md). Read its STATUS table first. A–E are complete; continue stage F (#2074), including the remaining cleanup in PR #2113, and stage G (#2075)'s pending real-migration promotion and hold proofs when the next shared-db migration PR is available.

- **Parent issue:** #2041.
- **Stage child issues:** #2070 (A), #2071 (B), #2072 (D), #2073 (E), #2074 (F), #2075 (G).
- **Stage C is done** in popcre/shared-db#5055.
- **Supersedes:**
  - `plan_simple-reviewer-rebuild.md`
  - `HANDOFF.d/2026-10-29T1925Z-edge-dev3-claude-skinny-review.md`
  - `HANDOFF.d/2026-10-29T1900Z-edge-dev3-claude-simple-reviewer-rebuild.md`

  Their facts are folded into the plan's §5–§7.

**Next session prompt:** "Resume popcre/ai-devops#2041 from plan_skinny-review.md; read its STATUS table and continue F (#2074, remaining cleanup in #2113) and G (#2075, pending migration proofs). Do not restart completed stages A–E or recreate the retired freeze window."

**Completeness check:** yes. The plan's §1–§13 and self-audit cover the goal, the exact state, rejected approaches, steps with done-when, access and risks.
