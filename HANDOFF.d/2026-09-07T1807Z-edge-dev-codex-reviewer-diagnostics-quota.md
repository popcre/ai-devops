---
issue: 312
status: OPEN
owner: codex/reviewer-diagnostics-quota-plan
---

# Implement reviewer diagnostics and quota preflight

## 0. Owner decisions

None needed. Albert requested a plan for points 1 and 2 on September 7: clearer
reviewer failure evidence and checking capacity before starting. No purchase,
provider switch or service restart is authorized. Do not re-ask whether to preserve
reviewer capabilities. If quota is unavailable, keep live acceptance pending.

## 1. Toolkit

The public `popcre/ai-devops` repository installs Albert's local AI reviewer
wrappers. It is a Bash/PowerShell toolkit. EDGE-DEV's canonical installation is
`C:\repos\ai-devops`; implementation belongs in a fresh upstream worktree.

## 2. Objective

Execute the [implementation plan](../plan_reviewer-diagnostics-quota-preflight.md),
owned by [issue #312](https://github.com/popcre/ai-devops/issues/312).
Its goal is useful failure evidence and avoiding review submissions when quota is
known exhausted, while allowing normal guarded reviews when quota is unknown.

## 3. Current state

Planning only; no implementation has started. The plan's STATUS has six open
steps. Baseline main is `586de2511d680f2d69e5cd4d550a7d4485ea0c76`.
Earlier fixes #310 and shared-db #2532 are merged and installed; plan section 3
names exact commits and private incident records. This planning branch contains
only prose: plan, handoff and discovery links. Verify its merged PR before execution.
The older residual-failures handoff remains independently open: this plan improves
future evidence and cannot prove the original intermittent causes by itself.

## 4. Failed approaches

No implementation attempted in this planning task. The preceding repair task
misclassified Kimi's quoted text as permissions, encountered quota during live
proof and recovered GLM without proving its hang cause. Plan section 7 records
why tiny paid prompts, sticky quota blocks and local-exit-as-remote-cancelled
inference are rejected. Do not repeat them.

## 5. Findings

Shared lifecycle/preflight/incident infrastructure already exists. Extend it;
do not create another owner lock or ledger. Kimi quota API support is unproven,
and a cancelled Grok result does not identify its initiator. Plan sections 5–8
provide code anchors, scope and the additive contracts.

## 6. Next steps

1. Fetch current main into an own worktree; read plan STATUS, section 9 step 0 and
   current AGENTS.md. Gate: ownership and provider interface matrix documented.
2. Execute phases A, B and C in order, updating STATUS with actual evidence.
   Gate: each step's named regression/live proof, not a declaration of completion.
3. Follow section 13's landing and acceptance checklist. Gate: installed merged
   bytes, passing exact-head review/CI, live reviews and honest quota limitations;
   retire this handoff only when #312 is actually complete.

## 7. Constraints

Independent read-only review is mandatory for safety code. Preserve exact-head
binding, full allowed read access, quarantine and cancellation uncertainty.
No CI/local reviewer-suite overlap on the same host. No secrets/public raw logs,
automatic retries, purchases, service restart or checkpoint implementation (#308).
Do not touch other sessions' dirty shared-db files or handoffs.

## 8. Access

Git Bash, PowerShell, jq, curl and authenticated gh were available while planning.
Secrets remain in `vibe_coding` through existing wrappers. Private evidence root
and incident IDs are in plan section 3; do not put their raw contents in Git.
Recheck live authentication and current provider pins before qualification.

## 9. Risks and audit

September 7: unsupported quota interface, quota race, cancellation races and
diagnostic privacy are explicit risks; plan tests name each acceptance case.
No owner judgment is hidden here: the only conditional spending boundary is in
section 0, and the recommended path needs no purchase.
Self-audit passes: newcomer background and current status are in sections 1–3;
failed approaches and findings in 4–5; executable gates in 6 and the linked plan;
constraints/access/risks in 7–9. Equivalent planning knowledge is carried in the
plan's 13 sections. The owner-decision sweep found no outstanding decision.
