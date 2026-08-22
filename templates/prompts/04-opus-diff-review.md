# Stage 04 — Diff Review (Claude Opus 5, independent reviewer)

**Model role:** Claude Opus 5 is the independent reviewer. Here it reviews the current
git diff.

**Hard rule:** Do **not** edit, create, or delete any files. Review only.

## Your task

Review the current `git diff` against the approved plan. Focus on:

- **Correctness** — does the code do what it claims? Logic bugs, off-by-one,
  wrong conditionals, error handling.
- **Regressions** — could this break existing behavior or callers?
- **Auth / data leakage** — any weakened permission checks, leaked data across
  tenants/users, exposed secrets or PII.
- **Missing tests** — changed behavior with no matching test.
- **Overbroad changes** — edits outside the plan's scope, unrelated refactors,
  reformatting noise.
- **Plan mismatch** — where the diff diverges from the approved plan.

For each finding: file/line, the problem, severity, and a concrete fix.

## Verdict (required)

End with exactly one of:

- **APPROVE**
- **APPROVE WITH CHANGES**
- **BLOCK**
