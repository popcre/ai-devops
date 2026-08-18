---
name: muse-opencode-plan
description: "Muse Spark 1.2 OpenCode work is governed by plan_muse-opencode-harness.md and issue #40; read its STATUS table first and do not copy or weaken ai-glm."
metadata:
  node_type: memory
  type: project
  modified: 2026-08-18
---

Muse Spark 1.2 OpenCode work is specified in
[`plan_muse-opencode-harness.md`](../../plan_muse-opencode-harness.md), tracked by
`u2giants/ai-devops#40`. Read the plan's STATUS table first; do not re-plan from
chat.

Locked architecture: separate `ai-muse` and `ai-glm` commands and live services,
but one provider-neutral tested OpenCode safety core. Albert stated on 2026-08-18
that he is only interested in `muse-spark-1.2-contributor`; its provider-training
terms are accepted, and standard Muse must never be substituted. Preserve every measured constraint in
`docs/glm-opencode.md` section 5.
