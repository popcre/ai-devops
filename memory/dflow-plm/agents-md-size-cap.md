---
name: agents-md-size-cap
description: "AGENTS.md is a router with a 60KB soft cap; per-session content goes to docs/idiosyncrasies.md, docs/incident-log.md, docs/pending-work.md"
metadata: 
  node_type: memory
  type: project
  originSessionId: 5f7586c7-ec02-4a0f-bbc6-bcbb6d5a76e8
  modified: 2026-08-18T21:44:32.444Z
---

`AGENTS.md` is loaded in full at the start of every session, so its size is a
permanent context-window tax. Soft ceiling 60 KB, hard ceiling 80 KB. Content that
grows one entry per session lives under `docs/` with only a pointer and a one-line
title index in `AGENTS.md`:

- a new quirk / gotcha / "do not fix this" note → `docs/idiosyncrasies.md`
- an incident write-up → `docs/incident-log.md`
- in-flight or unverified status → `docs/pending-work.md`

**Why:** `designflow-frontend/AGENTS.md` reached 151 KB (~38k tokens, about a fifth
of a 200k window) because ~87 sessions each appended a quirk or incident and the
`session-docs-update` spec told them to, with no size limit and no eviction rule.
Split 2026-08-18: frontend 151→57 KB, backend 61→33 KB, tracking 33→17 KB. Same
pass moved four legacy full-document `HANDOFF.md` files into `HANDOFF.d/` pointers
(tracking 55 KB, item-master 28 KB, data-syncing 7 KB, bff 4 KB).

**How to apply:** never delete history to make room — move it. The rule lives in
the `session-docs-update` and `repo-docs-overhaul` skills, and closer step 0 makes
every docs pass run `wc -c AGENTS.md HANDOFF.md` per repo and report the numbers.
The HANDOFF.md pointer rule already existed and was ignored for months, which is
why the check reports a number rather than restating a rule. Those skills live in
`u2giants/ai-devops` — see [[claude-skills-are-a-build-output]] before editing
them.
