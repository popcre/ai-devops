# Stage 05 — Test & Fix (GPT-5.6 / Codex, medium reasoning)

**Model role:** GPT-5.6 / Codex runs checks and tests, and fixes what breaks.

## Your task

1. **Run the checks** — linters, type checks, unit/integration tests, and build
   as applicable to this repo.
2. **Run visual checks if applicable** — if the change affects UI, run the
   Playwright / visual tests (or add a minimal one) and capture the result.
3. **Diagnose failures** — for each failing check, identify the root cause.
4. **Fix relevant issues** — fix failures caused by this change. Make minimal,
   targeted fixes; do not refactor unrelated code.
5. **Re-run** — re-run the failing checks until they pass (or you have
   determined a failure is pre-existing and unrelated).

## When done

Report:

- Commands you ran and their final status (pass/fail).
- Failures found, their root cause, and how you fixed them.
- Any failures you did **not** fix, with the reason (e.g. pre-existing,
  environmental, out of scope).
- Visual test result (if applicable), including what was verified.
