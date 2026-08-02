---
name: no-inference-verify-everything
description: "Standing rule from Albert 2026-08-02 — never present an inference as a finding; if something CAN be verified, verify it before saying it"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: c3a45a75-3b00-4aae-9fb1-c6f023a0ad83
  modified: 2026-08-02T18:58:55.682Z
---

**Never state an inference as fact. If a claim can be verified, verify it before
making it — every time, no exceptions.** Where verification is genuinely
impossible, say "NOT VERIFIED" and say what would be needed.

**Why:** in one session three claims were passed to Albert as findings that were
actually reasoning: (1) "the API filters out inactive rows" — read in a repo doc,
never checked against the handler code; (2) "`dflow.merchGroup` is fed by a live
second pipeline" — it was a frozen 2026-05-07 snapshot; (3) "`core.licensor` has
no active/inactive flag" — it has had a `status` column since June. Each one
would have sent work in the wrong direction, and one nearly produced a redundant
schema change. Albert is not a programmer and cannot catch these; he is relying
on the claim being checked.

**How to apply:** reading a claim in our own docs, in a sync script, or in an
earlier agent's report is NOT verification of the upstream fact — those describe
what we *think* a system does. Verify against the system itself: the live API
payload, the live database, the actual handler source. When dispatching a
sub-agent, put this rule in the brief and require a live artefact (raw response,
query result, or quoted `file:line`) behind every claim. Related:
[[plm-master-data-sync-broken]].
