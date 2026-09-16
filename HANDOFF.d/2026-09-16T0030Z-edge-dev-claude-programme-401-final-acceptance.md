# Handoff — programme #401 final acceptance audit, records reconciled

- **Created:** 2026-09-16T00:30Z, machine `edge-dev`, agent Claude Code (Opus 5)
- **Plan:** [`../plan_shared-db-complete-throughput-repair.md`](../plan_shared-db-complete-throughput-repair.md). Read its STATUS table first; it is now reconciled against live GitHub and must not be re-derived.
- **Tracking issue:** [popcre/ai-devops #401](https://github.com/popcre/ai-devops/issues/401) — **still OPEN**
- **Retires:** the three 2026-09-11 Codex `-401` handoffs and the 2026-09-15 Claude stall-integration handoff. Their content is superseded by the STATUS table and by the acceptance audit comment on #401.

## 1. What this session was doing, and why

Non-orchestrator final acceptance for #401: read `u2giants/shared-db#3003`, verify every
stated outcome against live GitHub, record all remaining gaps together, and drive the
programme as far toward closure as this route authorizes.

## 2. What was actually done

- Independently rechecked the 2026-09-15 acceptance audit against live GitHub rather than
  accepting it. Confirmed: shared-db #2705, #2709, #2715, #2727, #2728, #2729, #2912 and
  #2987 are CLOSED; **#2716 is still OPEN**.
- Reconciled the plan STATUS table. Every step now carries its true state — accepted,
  code-landed-but-not-accepted, open, or not-authorized — with the merge evidence behind it.
- Rescued ai-devops PR #412 (the #2716 policy half). It was stale at `3070b4a3` from
  2026-09-11 and BLOCKED because the required `verification-closure` context did not exist
  when it last ran. Merged current `main` into it cleanly (no conflicts) and pushed
  `1b289200`. `tests/test-shared-db-routing-rules.sh`: 26 passed, 0 failed.

## 3. Preview and production

Nothing was applied to shared preview or production. No database, deployment,
infrastructure, marker, repository-transfer or GitHub-settings mutation occurred.

## 4. What remains — the complete gap list

The authoritative list is the STATUS table plus the acceptance audit comment on #401.
In short: Steps 1–7 have merged code but **no linked live behavior proof**; Step 5 has a
named missing component (the single sidecar declaration registry); Step 8 is unstarted and
is **not authorized by #401**; Step 9 is contradicted while #412 is open; Step 10 — the
five-outcome live acceptance trial — has no committed report at all.

## 5. Why #401 cannot be closed by a session

Step 10 requires five consecutive post-install structural application outcomes measured in
real operation, including a median request-to-live improvement of at least 50%. That is
elapsed operational evidence; it cannot be manufactured. Step 8 requires an organization
transfer that #401 explicitly does not authorize. **Do not close #401 without both.**

## 6. Exact next action

1. Land #412, then complete shared-db #2716's live promotion and refusal-path proof.
2. Ask Albert to authorize Step 8 (the `popcre` transfer) as its own scoped work.
3. Start the Step 10 trial only after Steps 1–7 each have a linked live proof; record the
   five outcomes in a committed report with raw `n` and every exception.

## 7. Blockers

Step 8 needs owner authorization. Step 10 needs elapsed live operation. Neither is a
technical blocker this session could clear.

## 8. What was tried and did not work

Treating merged PRs and closed child issues as programme acceptance. They prove landed
implementation only; #401's outcome is live behavior.

## 9. Facts that may become stale

Checked live 2026-09-15/16 America/New_York. All issue states, PR states, SHAs and check
results must be rechecked before acting.
