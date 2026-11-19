---
issue: https://github.com/popcre/ai-devops/issues/988
status: OPEN
owner: Codex weekly verification maintenance
summary: Continue the scheduled-run proof for issue 988 after a successful complete manual verification.
kind: handoff
read-when: Verifying the weekly Verify workflow or closing issue 988.
---

# Weekly verification proof

## 0. Business decisions

None. Albert asked in this Codex chat to keep the issue open until a scheduled run passes and to have the weekly task repair, merge, and deploy failures. The standing task is active independently of this chat.

## 1. System

[AI DevOps Toolkit](https://github.com/popcre/ai-devops) is the recovery and development toolkit for Ubuntu and Windows. Its [Verify workflow](https://github.com/popcre/ai-devops/blob/main/.github/workflows/verify.yml) runs the complete matrix weekly on GitHub-hosted workers. The [plan](https://github.com/popcre/ai-devops/blob/main/plan_issue-988.md) holds the workstream status.

## 2. Goal

Make the weekly verification trustworthy again. Preserve complete Linux and Windows coverage, prove the production schedule works, and close [#988](https://github.com/popcre/ai-devops/issues/988) only on a successful scheduled run.

## 3. Verified state

- The [complete manual verification](https://github.com/popcre/ai-devops/actions/runs/44409696550) passed all four Linux sections, all five Windows sections, and both aggregates on [the tested source](https://github.com/popcre/ai-devops/commit/124fca8517b8dc27cc9c3f8315936a2da885b046). [Signed proof and installed-runtime receipts](https://github.com/popcre/ai-devops/issues/988#issuecomment-6995374136) are on the issue.
- [PR #2682](https://github.com/popcre/ai-devops/pull/2682) restored the usual Monday trigger. It removed the temporary schedule after the test window. The manual-run source and restored workflow differed only in that temporary schedule entry.
- The standalone Codex task **Weekly verification maintenance · #988** was created, verified active, and configured to check on Monday evenings on the local ai-devops project host. It is the continuation owner. [#988](https://github.com/popcre/ai-devops/issues/988) still carries the unchecked live proof.
- The latest scheduled run at the handoff check was the [cancelled November 16 run](https://github.com/popcre/ai-devops/actions/runs/43899158401), verified on November 19 at 10:54 AM EST. Earlier independent work [#2445](https://github.com/popcre/ai-devops/issues/2445) and [#2426](https://github.com/popcre/ai-devops/issues/2426) is closed.

## 4. Attempts that did not supply proof

The temporary [dated trigger](https://github.com/popcre/ai-devops/pull/2656) and [weekday fallback](https://github.com/popcre/ai-devops/pull/2681) produced no observed scheduled run in their bounded windows. The [issue receipt](https://github.com/popcre/ai-devops/issues/988#issuecomment-6995135865) records both attempts and the cleanup. Earlier manual runs surfaced real fixture and runtime defects, repaired before the successful run in section 3.

## 5. Findings

GitHub-hosted Windows exposed native shell lookup, module loading, and inherited test-directory permissions that differed from developer hosts. The fixes preserve real policy checks while selecting the right interpreter and initializing disposable fixture permissions. Relevant examples are the [Windows shard repair](https://github.com/popcre/ai-devops/pull/2671), [native ACL repair](https://github.com/popcre/ai-devops/pull/2676), and [merge evidence repair](https://github.com/popcre/ai-devops/pull/2678). The [Linux timestamp fix](https://github.com/popcre/ai-devops/pull/2680) removed independently reproduced fixture skew.

## 6. Exact continuation

1. Read the plan status, the issue, and the newest scheduled Verify run using the repository's governed GitHub route. The run must report event `schedule` on the default branch. Verify that its source contains the applicable fixes. If GitHub has created no new run, leave the proof open.
2. If the run is active, use the bounded waiter. If it fails, inspect the exact failed jobs and check existing ownership before making a minimal fix. Use normal tests and the protected merge queue. For installed runtime changes, use the [supported installation route](https://github.com/popcre/ai-devops/blob/main/docs/deployment.md) on affected hosts and prove installed behavior. Keep the issue open while scheduled proof remains pending.
3. Close the issue only after a successful real scheduled run includes the fixes and all four Linux and five Windows sections and both aggregates pass. Post a signed receipt linking the exact run, check live proof on the same issue, and verify GitHub reports it closed. The weekly maintenance task continues to monitor for recurrence.

## 7. Constraints

Use the current [repository rules](https://github.com/popcre/ai-devops/blob/main/AGENTS.md). Keep the existing weekly trigger, full coverage, and fail-closed checks. A manual dispatch proves readiness. GitHub's scheduled event supplies closure proof. Keep evidence on the same issue and avoid duplicate follow-up work.

## 8. Access

The standalone task runs in the local ai-devops project and uses the established GitHub CLI account through the repository wrapper. Follow [the tool guide](https://github.com/popcre/ai-devops/blob/main/docs/ai-tools-cheat-sheet.md) and [the deployment guide](https://github.com/popcre/ai-devops/blob/main/docs/deployment.md). No credential material is required in this handoff.

## 9. Risks

GitHub can delay scheduled events, and the full Windows matrix can take close to its job deadline. Observe the actual results through the bounded path. No business decision remains.

## Coordinator evidence

- **rollout** owned #988, verified the final manual matrix and restored schedule, and posted the [signed receipt](https://github.com/popcre/ai-devops/issues/988#issuecomment-6995374136). The agent finished its turn. The new weekly task owns the remaining check.
- **triage** verified and closed [#2445](https://github.com/popcre/ai-devops/issues/2445#issuecomment-6988876057), fixed Windows shard and Linux fixture defects for #988, and finished after landing [the last fixture fix](https://github.com/popcre/ai-devops/pull/2680). It holds no pending implementation.
- **runner_scan** verified and closed [#2426](https://github.com/popcre/ai-devops/issues/2426#issuecomment-6988892304), verified the installed Windows ACL fix, and finished after [merge evidence](https://github.com/popcre/ai-devops/pull/2678) landed. It holds no pending implementation.

## Self-audit

1. A fresh developer can start with the system and source links in sections 1–3 and execute the ordered checks in section 6.
2. Sections 4–5 distinguish the failed triggers and platform-specific conditions so a successor can avoid repeating the investigation.
3. Verified source, production constraints, evidence links, ownership, access, and the precise close condition are covered in sections 3 and 6–9 and the coordinator evidence.
4. Each remaining decision is technical or depends on GitHub delivery. Section 0 accounts for the owner question sweep and records that none needs Albert.

Resume prompt: Continue popcre/ai-devops #988 from main using this handoff and its plan. Verify the next real scheduled Verify run. Repair, merge, and deploy any reproduced failure. Close #988 only after all nine sections and both aggregates pass on the scheduled run.
