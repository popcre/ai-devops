# AI Agent Roles

This document defines who does what in the staged AI coding workflow. Drop it
into an application repo's docs when onboarding.

## The models

| Model | When it is used | It never… |
|-------|-----------------|-----------|
| **Claude Opus 5** | Independent plan, diff, security, and final review | edits code during a review |
| **GPT-5.6 / Codex (medium)** | Planning, implementation, testing, fixing | expands scope or refactors unrelated code |

## The stages

1. **Plan** — *GPT-5.6 / Codex medium* writes the plan read-only.
2. **Plan review** — *Claude Opus 5* approves, rejects, or blocks the plan.
3. **Implement** — *GPT-5.6 / Codex medium* makes the smallest safe change + tests.
4. **Diff review** — *Claude Opus 5* reviews for correctness/regressions.
5. **Test** — *GPT-5.6 / Codex medium* runs and fixes tests (and visual checks).
6. **Security review** — *Claude Opus 5* reviews auth/data/secret issues only.
7. **Final review** — *Claude Opus 5* signs off and summarizes for
   Albert.

## Guardrails that apply to every stage

- Feature branches only — never work directly on `main`/`master`.
- No secrets in code or logs. No weakening of auth/permission checks.
- Reviews are read-only. Implementation stages add/adjust tests.
- Any plan deviation is reported, not hidden.
