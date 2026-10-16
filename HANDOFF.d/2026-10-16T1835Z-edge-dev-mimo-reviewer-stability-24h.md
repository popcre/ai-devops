issue: https://github.com/popcre/ai-devops/issues/1822
status: open
owner: mimo/edge-dev-class-level

# Handoff — reviewer stability ≥24h (class-level remediation)

**Machine:** edge-dev · **Agent:** MiMo · **UTC:** 2026-10-16T18:35Z

## Plan (read first)

Implementation plan: [`plan_reviewer-stability-24h.md`](../plan_reviewer-stability-24h.md) — STATUS table at top; start at the first open step after reading §§5–8.

## Why this exists

2026-10-16 diagnosis of reviewer failures on edge-dev / edge-dev3 (93 incident packages + partial extract) found six classes behind the ~24h green ceiling. Albert asked for a plan to fix every problem found. Sibling programmes already own host-scoped work:

- [plan_reviewer-recurrence-repair.md](../plan_reviewer-recurrence-repair.md) — edge-dev3 recurrence
- [plan_edge-dev-reviewer-repair-no-review.md](../plan_edge-dev-reviewer-repair-no-review.md) — edge-dev without AI-reviewer gates

This plan owns **class closure** and the 24h observation gate. Do not re-derive those programmes.

## What a successor must know

- ScaleDown bulk extract of raw transcripts was **stopped for cost** (~210M+ tokens). Incident packages are the source of truth. No bulk third-party extract without an explicit token budget on #1822.
- Dominant class is **auto-requalification on install/pull**, not "the model is bad."
- edge-dev repairs must not use AI reviewers as a gate (owner 2026-10-15).
- Shared files (`review-lifecycle-core.sh`, packet/sandbox, doors) serialize with sibling owners.

## Done when

Status rows in the plan cite artifacts; #1822 checklist includes live proof; this file is retired only when nothing is carried.

Posted by MiMo chat ses_ffe5ebaa99123ffe4HFF1eZnbd on edge-dev
