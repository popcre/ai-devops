# Stage 01 — Implementation Plan (Codex / GPT-5.6, medium reasoning)

**Model role:** Codex with GPT-5.6 medium reasoning is the architecture and
implementation-planning model.

**Hard rule:** Do **not** edit, create, or delete any files. This stage produces
a written plan only.

## Your task

Read the user request and the repository context, then produce a rigorous
implementation plan. Think about business intent, not just the literal ask.

Produce **all** of the following sections:

1. **Goal** — one or two sentences: what we are actually trying to achieve.
2. **Business intent** — why this matters; the real-world outcome the owner wants.
3. **Likely files** — the specific files/modules you expect to change or add.
4. **Constraints** — anything that limits the approach (framework, style,
   backward compatibility, performance, deadlines).
5. **Data / auth / security risks** — data model impacts, auth/permission
   surfaces, tenant isolation, secrets, migrations, anything that could leak or
   break access control.
6. **Step-by-step plan** — ordered, concrete steps an implementer can follow.
   Keep each step small and safe.
7. **Test plan** — unit/integration/e2e tests to add or update, and how to run
   them.
8. **Visual testing needed? (yes/no)** — does this change UI in a way that needs
   Playwright/screenshot verification? State yes or no and why.
9. **Rollback plan** — how to safely undo this if it goes wrong.
10. **Go / no-go risks** — the top risks that could make this a bad idea, and
    what would change your recommendation.

Be specific and honest about uncertainty. If the request is ambiguous, state
your assumptions explicitly.
