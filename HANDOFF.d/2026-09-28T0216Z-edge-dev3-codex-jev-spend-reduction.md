---
issue: 643
status: OPEN
owner: codex/jev-token-savings-plan
---

# HANDOFF — measured Jev token savings

## 0. Decisions only Albert can make

None currently. Albert asked for the plan; he has not asked this session to run the integration. Existing safety and data boundaries are settled and must not be reopened. If a future phase proposes sending private transcript contents to TypeSafe, obtain fresh explicit authority first; the present plan uses local aggregate analysis and public or synthetic evaluation cases.

## 1. What this application is

`popcre/ai-devops` is Albert's public toolkit for AI-assisted development, review, and machine setup. It is not a web app. Repository installation is deployment. Main is protected and work uses isolated branches and PRs.

## 2. What this session set out to do

Albert asked for a TypeSafe-skill-informed implementation plan to save tokens with Jev after a transcript review. The deliverable is [the new plan](../plan_typesafe-jev-spend-reduction.md). It specifically distinguishes a cheap additional judgment from a verified reduction in paid frontier tokens.

## 3. Current state

Planning PR [#900](https://github.com/popcre/ai-devops/pull/900) merged as `b64a206b41eb5bca96ea8968ffa6835615cab1a9` on `origin/main`; it changed prose only. The [plan](../plan_typesafe-jev-spend-reduction.md) and router link are present there. No token-saving lane is implemented or installed. Existing `bin/ai-jev-probe` and `bin/ai-jev-completion-shadow` remain committed, the older [advisory plan](../plan_typesafe-jev-advisory-integrations.md) still has open implementation rows, and this plan's STATUS rows remain open. No Jev data call, secret read, runtime installation, or transcript upload occurred in the planning session.

## 4. What did not work / rejected paths

The prior decision-layer experiments found safe compaction saved no useful context and looser compaction discarded later-needed information. Completion shadowing missed the real unsupported completion at the required threshold. The exploratory transcript keyword count did not measure paid calls. The older issue-pair pilot targets human sorting and cannot, by itself, substantiate token savings. See the plan §§3, 6–7 and [`plan_typesafe-jev-decision-layer.md`](../plan_typesafe-jev-decision-layer.md) §§7–11.

## 5. Root causes and findings

The existing Jev advisory plan measures cost of added Jev calls but does not first identify an existing frontier call to displace. The new plan requires that baseline before implementation. TypeSafe's skill says Jev gives typed `Noul`, `Choice`, and `Score` judgments and recommends code-owned workflow, live API verification, and representative domain evaluation. It cannot replace explanatory review or coding agents. Source links are in the plan §§2 and 6.

## 6. Exact next steps

1. In a new current-upstream worktree, claim the first open STATUS row and execute plan §9.1 only. You'll know it worked when a reproducible baseline identifies one eligible paid call/context load or records no-go.
2. Follow the plan's later rows one outcome per session, updating STATUS and issue #643 as each row is proved. You'll know it worked when each row cites its actual artifact and no unproven live outcome is bundled.

## 7. Constraints and gotchas

Never copy private transcripts into the public repo or upload their text under this plan. Keep deterministic gates and independent review. Use the shared Jev client from the advisory plan rather than another copy. No runtime activation follows merely from publishing this plan. `ai-task-gates` class for this prose PR is `prose`; future code and reviewer-safety changes must declare their actual stronger class. Use `bin/ai-gh` for GitHub and stage only owned files.

## 8. Access and environment

Planning host `edge-dev3`, current-upstream worktree branch `codex/jev-token-savings-plan`. GitHub remote is `popcre/ai-devops`. Jev secret location, for future implementation only: 1Password vault `vibe_coding`, item `typesafe.ai API`; resolve through `op run`, never display. TypeSafe API and agent-skill links are in the plan. Local private transcript archive path is in the plan §5.

## 9. Open questions and risks

The central unknown is whether any recurring call qualifies for actual token displacement. Plan §9.1 decides; no target means no-go. A successful shadow result still needs a paired trial showing net frontier-token and dollar savings without quality or safety loss. No owner decision is pending now. A future private-data expansion would be a new request, not an implied part of this work.
