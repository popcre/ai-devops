---
issue: 1881
status: OPEN
owner: claude/ruleset-trim
---
# Handoff — ruleset trim and enforcement plan (edge-dev3, Claude)

Written 2026-10-20 10:00 AM EDT by Claude chat ed6aab4c-f27f-4ea4-a1d5-7f8ccb50a780 on edge-dev3.

## What is unfinished

The plan [plan_ruleset-trim-and-enforce.md](../plan_ruleset-trim-and-enforce.md)
is written and nothing in it is implemented. Tracking issue:
[popcre/ai-devops#1881](https://github.com/popcre/ai-devops/issues/1881).

## Start here

Read the plan's STATUS table, then start Phase 1, step 1.1. Phases 1, 2 and 5 can
run in parallel sessions. Phase 4 waits for phase 3. Phase 6, the live proof, runs last.

## Background in one paragraph

A 2026-10-20 transcript audit (103 sessions, private report at
`~/Dropbox/ai/chat_transcripts/_audit/ruleset-audit-2026-10-20.md`, not in Git)
found that the roughly 8,000-word always-loaded ruleset is too long, partly stale,
and partly ignored. Every finding, rejected approach and decision is in the plan.
Do not re-derive them.
