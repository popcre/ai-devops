---
issue: 2531
status: OPEN
owner: codex/01a1e599
---
# Implement the selected review routes

## 0. Business decisions

None pending for implementation or isolated qualification. Existing defaults remain in place. Begin activation only when the user lifts the prior no-switch hold.

## 1. Application

[AI DevOps Toolkit](https://github.com/popcre/ai-devops) provides automatic advisory PR reviews and interactive second opinions on Ubuntu and Windows.

## 2. Purpose

Albert requested one implementation plan for both callers. Use DeepSeek Harness via OpenRouter and one OpenCode runtime for Muse Spark 1.3 Contributor via Meta, the same Muse model via OpenRouter, and Hy4 via OpenRouter. Meta outages require transparent same-model fallback. Hy4 is explicit for second opinions and availability fallback on GitHub.

## 3. Current state

Start at step 1 of the [implementation plan](../plan_deepseek-harness-openrouter.md), with current upstream. The [baseline](https://github.com/popcre/ai-devops/commit/ec4886f57232a1bb2741b7cf66d5fa1a949a1def) landed the earlier route choices. The plan and handoff are documentation only. Candidate wiring to the normal entry points and default changes were not implemented. See [#2531](https://github.com/popcre/ai-devops/issues/2531) for the live-proof checklist.

## 4. Dead ends

The built-in OpenCode OpenRouter connection failed for Muse and DeepSeek in the prior smoke test, and a custom connection passed. DeepSeek’s direct endpoint cannot be overridden in the old client. The plan records why wholesale workflow replacement and legacy state conversion were discarded.

## 5. Evidence

The [smoke test](https://github.com/popcre/ai-devops/issues/2531#issuecomment-6927103076) qualified isolated OpenCode provider requests. The [Ubuntu and edge-dev benchmark](https://github.com/popcre/ai-devops/issues/2531#issuecomment-6927912521) measured native restart, read-only behavior, speed and finding accuracy. [GitHub test PR #2538](https://github.com/popcre/ai-devops/pull/2538#issuecomment-6928212224) published live native DeepSeek and native Muse verdicts. The latter used Muse Code and cannot count as qualification of OpenCode Muse.

## 6. Next actions

1. Claim #2531 and implement shared route definitions, isolation, and credential selection. The registry test must accept only the four selected routes and the correct secret scope.
2. Wire both normal entry points behind candidate selection. The existing defaults must pass regression tests. The new failure paths must preserve the exact PR head and scoped second-opinion history.
3. Run the route and platform matrix in the plan. GitHub must generate and publish verdicts for four attributable routes. On Ubuntu and edge-dev, prove read-only access, two restarts and same-model Muse failover. Record links and revisions on #2531.
4. Once activation is in scope, use a separate revertible default change. Prove live behavior and retain rollback.

## 7. Constraints

Current defaults, advisory behavior, separate credential custody, read-only scope, legacy session state and unrelated writable commands remain intact during the candidate phase. Confirmed transport or credential unavailability can fail over. Ambiguous policy outcomes terminate the attempt. See plan §§8–13.

## 8. Access

Use official Ubuntu and Windows runtime/install routes and existing GitHub access. Plan §12 names credential locations in the protected `vibe_coding` vault. Planning used no credential values.

## 9. Risks

The two OpenRouter routes share a dependency. A Muse session may require replay of approved visible turns to continue through a new connection. Model results must remain attributable to the exact head and route, and Windows isolation must be proven on edge-dev. See the plan’s failure matrix and rollback gates.

## Self-audit

1. §§1–3 and 6 give a newcomer the purpose, source baseline and actionable next gates.
2. §§4–5 record the route trial outcomes and distinguish prior evidence from the remaining proof.
3. §§6–9 and the linked plan specify access, constraints, test conditions and release risks.
4. The sweep of §§1–9 surfaced no business choice needed for implementation. §0 carries the existing activation hold. The closed fresh-reader pilot was not used.
