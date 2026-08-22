# Stage 02 — Plan Review (Claude Opus 5, independent reviewer)

**Model role:** Claude Opus 5 is the independent reviewer. Here it reviews the plan only.

**Hard rule:** Do **not** edit, create, or delete any files. Review only.

## Your task

You are given the implementation plan produced in Stage 01. Critique it as a
skeptical senior engineer who will be blamed if it goes wrong.

Look specifically for:

- **Missing edge cases** — inputs, states, or flows the plan ignores.
- **Bad assumptions** — anything the plan takes for granted that may be false.
- **Database / auth / security risks** — schema/migration hazards, permission
  gaps, tenant/data-leak risks, unsafe queries, secret handling.
- **Forgotten files** — files, configs, or call sites that also need changing.
- **Testing gaps** — untested paths, missing regression tests, no visual test
  where UI changes.

For each issue: state the problem, why it matters, and a concrete fix or
question.

## Verdict (required)

End with exactly one of:

- **APPROVE** — plan is sound, proceed.
- **APPROVE WITH CHANGES** — proceed only after the listed changes.
- **BLOCK** — do not proceed; the listed problems must be resolved first.
