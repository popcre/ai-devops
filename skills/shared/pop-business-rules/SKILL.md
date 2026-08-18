---
name: pop-business-rules
description: Find, explain, add, change, reconcile, or audit POP Creations business rules through the companywide Business Logic Library. Use for business meaning, authority, workflows, statuses, approvals, pricing, taxonomy, identities, or application behavior that may embody a business rule. Do not use for programming logic, lint rules, deployment policy, or generic documentation edits.
---

# POP Business Rules

The Skill is the procedure. The rules themselves live only in the canonical
`u2giants/shared-db/docs/business-rules/` library.

## Start here

1. Locate `u2giants/shared-db`. Prefer a current canonical checkout. A consumer
   repo's `shared-db/` directory is a read-only mirror and may lag `main`.
2. Open `docs/business-rules/application-map.md`.
3. Load only the topics touched by the application, task, or business object.
   Cross-topic work must load every applicable topic.
4. If the local map or a required topic is missing or stale, read canonical
   `https://github.com/u2giants/shared-db/tree/main/docs/business-rules` and say
   that the canonical source was used.

Never infer a Settled business rule from code, database shape, screens, or old
plans. Those can reveal behavior, evidence, conflict, or an unanswered question.

## Rule status

- **Settled:** confirmed by Albert or an explicitly named business authority.
- **Proposed:** a suggestion awaiting approval. Do not implement it as Settled.
- **Historical:** previously true or previously documented, but not controlling.
- **Unknown:** evidence does not answer the question. Do not guess.

## Read or explain

- State which applicable topics were read.
- Separate Settled, Proposed, Historical, and Unknown findings.
- Cite the official topic and relevant heading.
- Report material contradictions instead of silently choosing one statement.
- Follow links to implementation evidence only when the question needs it.

## Add or change a rule

1. Capture the exact business question, answer, authority, and effective date.
2. Update the existing business-topic document. Create a new topic only when no
   current topic fits. Organize by business subject, never by application.
3. Mark the rule Settled, Proposed, Historical, or Unknown. Only Albert or the
   named authority can make a new statement Settled.
4. Search `shared-db` and every relevant application repo for competing current
   statements. In the same workstream, correct them, mark them Historical, or
   replace them with a pointer to the companywide topic.
5. Update `application-map.md` when relevance changes.
6. Keep application field names, screens, code paths, and technical safeguards
   in the application as implementation evidence. Do not copy the business rule.
7. If authority is missing, ask one plain business question and leave the rule
   Proposed or Unknown until answered.

## Audit an application or document

1. Build the applicable-topic list from the map.
2. Compare the application, code, workflow, and documents against Settled rules.
3. Report:
   - behavior that conflicts with a Settled rule;
   - a Proposed or Unknown rule implemented as though Settled;
   - duplicate or stale current-looking authority;
   - missing business decisions;
   - broken library links;
   - implementation evidence mislabeled as business authority.
4. A read-only audit does not authorize code or data changes. Implement fixes
   only when the user requested them.

## Boundaries

- Never copy rule content into this Skill.
- Never edit a consumer repo's `shared-db/` mirror.
- Database structure changes route through `codex-shared-db-change` or
  `shared-db-orchestrator`; this Skill grants no database-change authority.
- Outside-sourced writes into curated Master Data retain shared-db governance.
- Licensed row contents stay in approved private repositories and never enter
  public docs, issues, commits, or outside-model prompts.
- Preserve plans and incident records as evidence when useful, but label them
  Proposed or Historical so they cannot compete with current authority.
