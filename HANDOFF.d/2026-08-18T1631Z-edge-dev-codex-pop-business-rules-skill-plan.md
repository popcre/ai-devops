---
issue: 35
status: OPEN
owner: codex/pop-business-rules-plan
---

# HANDOFF: implement the `pop-business-rules` Skill

## 0. DECISIONS ONLY THE OWNER CAN MAKE

None. Albert settled the key design on 2026-08-18: one cross-client Skill named
`pop-business-rules`, one companywide library organized by business topic, and
an application/task map for selective reading. Do not re-ask those questions.

## 1. What this application is

`u2giants/ai-devops` is Albert Hazan's public toolkit for installing shared AI
Skills and operating rules across Claude and Codex on Windows and Ubuntu. The
Business Logic Library itself belongs to the separate `u2giants/shared-db` repo.

## 2. What this session set out to do

Write a complete implementation plan for a new shared Skill that teaches AI
sessions to read, add, change, reconcile, and audit POP business rules without
copying the rules into the Skill or application repositories.

The full plan is [`plan_pop-business-rules-skill.md`](../plan_pop-business-rules-skill.md).

## 3. Current state

The companywide library is merged through `u2giants/shared-db` PR #1178. The
Skill, trigger set, tests, and usage documentation are merged through
`u2giants/ai-devops` PR #36, merge commit `e7d713d`. The Skill was installed to
both `~/.claude/skills/pop-business-rules/` and
`~/.codex/skills/pop-business-rules/`; both SHA-256 hashes exactly match the
published source (`E18C7A8F9154928C0DE4219FF104D2C65DFE7C52B1A783011A9C85663E8576F1`).

Offline Skill, installer, parity, Codex-runner, and context tests pass. Live
trigger measurement is blocked on this machine: `claude auth status` reports
`loggedIn: false`, and Windows returns `Access is denied` when the runner starts
the Codex desktop executable. The original Claude runner misleadingly reported
logged-out runs as 0/10 with zero errors; that result was invalid. The runner now
refuses a score unless authentication is proven. The Codex runner now converts
an inaccessible executable into an explicit incomplete-run failure instead of
crashing. Issue #35 remains open for valid live evidence.

## 4. What did not work

- Running the normal installer from a linked worktree installed and verified the
  Skill, then correctly refused to install durable machine launchers from that
  non-canonical path. Do not call that Skill installation a failure; do not call
  the whole machine sync complete either.
- Claude live evaluation returned 0/10 because Claude was logged out. The runner
  failed to classify authentication responses as errors.
- Codex live evaluation failed with `WinError 5` because the WindowsApps desktop
  executable cannot be launched as a child process from the runner.
- The rejected designs remain recorded in plan Section 7.

## 5. Root causes and key findings

The procedure and the knowledge require separate owners. `ai-devops` owns the
cross-client procedure; `shared-db/docs/business-rules/` owns the business
knowledge. One shared Skill prevents Claude/Codex drift. The application/task
map prevents unnecessary whole-library loading.

## 6. Exact next steps

1. Log Claude CLI in on this machine and verify `claude auth status` says `loggedIn: true`.
2. Provide a callable Codex CLI outside the protected WindowsApps desktop package, or fix the runner to use the supported Codex CLI launcher without weakening its read-only/low-effort safeguards.
3. Re-run both three-round evals from plan Phase 5. Inspect transcripts before treating a miss as a Skill defect.
4. Run the three read/add/audit probes.
5. Record valid evidence, close issue #35, update the plan to complete, and delete this handoff in the completing commit.

## 7. Constraints and gotchas

Do not copy business rules into the Skill. Do not create client-specific copies.
Do not point the permanent Skill at an unpublished branch. Do not use the old
skill-creator trigger loop. Do not edit application mirrors of shared-db. Do not
stage unrelated work from the dirty main checkout. GPT-5.6 may use low or medium
reasoning only.

## 8. Access and environment

The implementer needs authenticated `gh`, Claude CLI, and Codex CLI. No database,
cloud, deployment, or secret access is required. The repository is public; no
licensed rows, transcripts, or credentials may be committed.

## 9. Open questions and risks

No owner question is open. The main dependency risk is that the central library
may not yet be published on shared-db main. The main behavior risks are an
over-broad trigger, an under-broad trigger, or copied rule content. The plan has
specific gates and rollback for each.

## Self-audit

1. A new developer can continue without this chat: yes, Sections 1–9 and the linked plan cover the complete state and execution path.
2. They can continue as effectively as this session: yes, Sections 3–7 preserve the dependency, reasoning, rejected directions, and exact next actions.
3. Failed approaches are included: yes, Section 4 points to the detailed rejected approaches in plan Section 7.
4. Every next step is executable and verifiable: yes, Section 6 and plan Section 9 provide explicit gates.
5. Terms, paths, repositories, branch, issue, and access are defined: yes, Sections 1–3 and 8.
6. Section-0 sweep passed: yes. Sections 1–9 contain no unsettled owner decision; Section 0 says none and lists the settled design.

Final synthesis: this handoff is comprehensive for a zero-context implementer;
it carries all relevant background and remaining work; every required detail is
in this file or the directly linked plan; and Section 0 contains every owner
decision, which is currently none.
