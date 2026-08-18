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

The plan and this handoff were created on branch `codex/pop-business-rules-plan`
from `origin/main` commit `74b78f6`. No Skill implementation has started. The
central library files existed only as uncommitted shared-db work when the plan
was written, so the plan correctly makes publication to `shared-db/main` its
first hard gate.

## 4. What did not work

No implementation was attempted. The rejected designs are recorded in plan
Section 7: copied rules in the Skill, application-specific Skills, global prompt
bloat, premature search infrastructure, code-as-business-authority, and the
obsolete skill-creator trigger loop.

## 5. Root causes and key findings

The procedure and the knowledge require separate owners. `ai-devops` owns the
cross-client procedure; `shared-db/docs/business-rules/` owns the business
knowledge. One shared Skill prevents Claude/Codex drift. The application/task
map prevents unnecessary whole-library loading.

## 6. Exact next steps

1. Read the plan STATUS table and the entire plan.
2. Prove the central map and library home exist on `shared-db/main`; success is
   two non-404 GitHub content responses.
3. Follow plan Phases 2–4 to author, test, and document the Skill; success is the
   offline contract test passing and all load-bearing procedures present.
4. Follow Phase 5 for real Claude and Codex installation and trigger evidence;
   success is byte-identical installation, all positives firing, and no negatives firing.
5. Follow Phase 6 to land the work, update the plan, close issue #35, and delete
   this handoff when GitHub proves completion.

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
