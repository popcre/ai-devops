---
name: mirror-shared-standards-into-repo-router
description: A standard that lives only in the ai-devops template or a skill is not in force in a repo until AGENTS.md restates it
metadata: 
  node_type: memory
  type: feedback
  originSessionId: c5af23b0-7d73-46d2-9442-8bcab37b1943
  modified: 2026-08-13T20:19:07.881Z
---

When a shared standard from `u2giants/ai-devops` (templates or skills) governs
day-to-day work in an application repo, restate its enforceable parts in that
repo's `AGENTS.md`. Sessions are routed by `AGENTS.md`; many never load the
skill that carries the rule.

**Why:** on 2026-08-13 the Oracle repo's `HANDOFF.d/` had 12 open handoff files
against a limit of 5. The handoff standard's successor-delete rule (the session
finishing the next phase deletes the previous phase's file) existed correctly in
`templates/system/handoff-standard.md` and in the `handoff-writer` skill, but
`AGENTS.md` contained zero occurrences of `HANDOFF.d` and still taught the
retired single-root-file model. Nine Codex sessions each did exactly what they
were told and the folder grew every time. The mechanical `open handoffs: N`
count in `context-audit.py` only runs against `ai-devops`, so nothing caught it.

**How to apply:** when a shared rule is not firing, check the repo's router file
before blaming the sessions. Look for the half of a rule that is easy to
remember ("never edit another session's file") versus the half that is easy to
forget (the exemption that permits deleting a proven-landed predecessor) — a
rule with a forgettable exemption needs to be written where it is read. Also
check whether the enforcing tool actually runs on that repo. Related:
[[no-hardcoded-model-names-in-adapters]].
