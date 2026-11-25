---
issue: 2869
status: OPEN
owner: GitHub pilot implementing lead
---

# GitHub continuity and throughput trial

## 0. Business decisions

None required for the bounded experiment.

## 1. Application

POP Creations uses the public ai-devops toolkit for Ubuntu and Windows coding sessions. GitHub owns authoritative submissions and checks.

## 2. Objective

Test whether work survives a GitHub interruption, shared PR notifications save requests, and measured check delays can be reduced.

## 3. Current state

The [plan and STATUS](../plan_github-continuity-pilot.md) are the execution record. All trials are open on [the pilot issue](https://github.com/popcre/ai-devops/issues/2869). No code or service was installed by the planning session.

## 4. Prior attempts

Albert reported difficulty implementing Entire and one unnamed alternative. Keep the experiment on GitHub. Earlier quota work on #658 is closed.

## 5. Findings

The [existing waiter](https://github.com/popcre/ai-devops/blob/a43b08da/bin/ai-pr-wait#L193-L209) already shares snapshots. Compare against its real behavior. The incident cause and fleet-wide request distribution are unmeasured.

## 6. Sequence

1. Freeze the reproducible one-day sample using plan step 1.
2. Run steps 2–4 independently. Keep outage injection local, validate events against current revisions and separate queue time from execution. Each step specifies numerical or exact pass criteria.
3. Record all three verdicts, cleanup evidence and verification on the same issue. Follow step 5 and section 13.

## 7. Constraints

GitHub remains authoritative. Preserve quota and merge controls. No fleet rollout, production changes or paid capacity.

## 8. Environment

Start on edge-dev3 in a fresh task worktree. Repository read access worked during planning. Draft creation, webhook administration and runner capacity must be checked separately. Plan section 12 specifies access and secret handling.

## 9. Uncertainty and audit

On November 25, 2026, repo representativeness, live ingress and comparable job samples remained uncertain. Sections 8–13 specify how to handle each. A fresh session can reproduce the sample, distinguish the prior attempts from the new experiments and verify each verdict without chat context.
