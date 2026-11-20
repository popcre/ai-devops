---
issue: 2367
status: OPEN
owner: codex/ghost-run-proof-handoff-2367
---

# Ghost-run recovery live proof

## 0. Business decisions

None. Albert authorized the guide update, merge, and live proof tracking on the existing issue.

## 1. What this project is

[popcre/ai-devops](https://github.com/popcre/ai-devops) runs shared development checks through GitHub Actions.

## 2. Goal

Restore checks during a confirmed ghost-run blockage and capture the first live example using the revised [recovery guide](https://github.com/popcre/ai-devops/blob/main/docs/ghost-run-escape.md).

## 3. Current state

[PR #2714](https://github.com/popcre/ai-devops/pull/2714) landed as [1d9acc59](https://github.com/popcre/ai-devops/commit/1d9acc59). Documentation safety and link checks passed before merge. The separate live proof checkbox was verified open on [#2367](https://github.com/popcre/ai-devops/issues/2367). No live recovery or installation was performed.

## 4. Approaches that did not work

[Incident history](https://github.com/popcre/ai-devops/blob/main/docs/critical-incidents.md) documents ghosts that listed as queued with zero jobs and refused cancellation or deletion. GLM, Muse, and Codex checked that a new commit on the same PR can reuse the held group. A manual run cannot establish that a PR or queue check recovered.

## 5. Key findings

[Verify](https://github.com/popcre/ai-devops/blob/main/.github/workflows/verify.yml) groups PR runs by PR number, queue runs by queue ref, and manual and scheduled runs by SHA. The existing repository-wide setting can rename groups before the new run is created. This is recovery from an active blockage. GitHub handles the ghost record separately.

## 6. Exact next steps

1. At the next suspected incident, match the ghost to a still-needed check and its held group. Follow the [guide](https://github.com/popcre/ai-devops/blob/main/docs/ghost-run-escape.md). If the next run would reuse the held group, confirm legitimate runs across affected workflows have drained and rotate the setting before triggering it.
2. Trigger a fresh run through the original event. Push a fresh commit to the same PR for a PR check, use normal merge-queue handling for a queue check, or observe the next scheduled run for a schedule check.
3. Capture the ghost ID and held group, the setting change if any, and the fresh run ID, event, target, and expected check results on [#2367](https://github.com/popcre/ai-devops/issues/2367). Tick only the ghost-run proof item once the expected checks complete successfully. Record any GitHub Support cleanup separately.

## 7. Constraints

Use the project’s [operating rules](https://github.com/popcre/ai-devops/blob/main/AGENTS.md). Keep group rotation manual. Preserve legitimate runs and the original check event. A record with zero jobs alone does not establish an active blockage. Keep the existing issue for proof.

## 8. Access and environment

Use the authorized repository connection and the existing workflow and repository settings. This session introduced no credentials, infrastructure changes, or new runtime dependencies.

## 9. Open risks

The trigger for this handoff is the next confirmed blockage. A routine successful check does not close the proof item. The broader checklist on #2367 remains independent.

## Self-audit

1. A new responder can start from §3 and §6. The guide and issue provide the current procedure and evidence destination.
2. Sections 4–5 explain why a fresh same-PR commit alone can fail and why a manual dispatch is insufficient.
3. Sections 3 and 6–9 cover delivery, the activation condition, drain safety, proof criteria, and access. The future incident is the only missing evidence for this item.
4. Sections 1–9 require no business decision. Section 0 records the settled authorization.
