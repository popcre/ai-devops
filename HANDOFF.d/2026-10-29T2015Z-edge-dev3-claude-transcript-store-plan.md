---
issue: 2050
status: OPEN
owner: claude/transcript-store
---

# HANDOFF — shared, topic-cut transcript store (2026-10-29, edge-dev3/claude)

- **Plan:** [plan_transcript-store.md](../plan_transcript-store.md). Read its STATUS table first and start at step 1. Do not re-plan.
- **Design record:** [docs/transcript-store-decision-2026-10-29.md](../docs/transcript-store-decision-2026-10-29.md).
- **Nothing is built yet.** The prototype review labels (6,490 rows) are at `~/.local/share/ai-devops/transcript-index/labels.db` on edge-dev3.
- **Owner rulings 2026-10-29:** ScaleDown cost does not matter; minimize LLM use; reviewers never block. All are quoted in the plan.
