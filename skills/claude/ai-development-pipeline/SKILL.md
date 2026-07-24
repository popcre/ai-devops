---
name: ai-development-pipeline
description: >-
  Drive the staged multi-model coding workflow (plan → review → implement →
  review → test → security → final). Use when the user wants to run a change
  through the full AI DevOps pipeline with Opus for planning/review and
  GPT-5.5/Codex for implementation/testing. Scaffolding v0.1.
---

# AI Development Pipeline (Claude / Opus)

This skill orchestrates the staged AI coding workflow for an application repo.
Claude (Opus) owns **planning** and **review**; GPT-5.5 / Codex owns
**implementation** and **testing**.

> Status: v0.1 scaffolding. It defines the stages and the commands to run; full
> automated orchestration is future work.

## When to use

- The user asks to take a task through the full staged workflow.
- The user wants a plan, then reviewed implementation, then security/final sign-off.

## Model roles

- **Opus 4.8 (high reasoning)** — Stage 01 plan, Stage 07 final review.
- **Opus** — Stage 02 plan review, Stage 04 diff review, Stage 06 security review.
- **GPT-5.5 / Codex** — Stage 03 implement, Stage 05 test/fix.

(Fable is not used anywhere; planning/final review use Opus 4.8 high reasoning.)

## The stages & commands

Run from inside the target git repo. Scaffold a run first:

```bash
ai-run-task "Short description of the task"
```

Then, per stage (prompts live in the toolkit's `templates/prompts/`):

| Stage | Model | Command / template |
|-------|-------|--------------------|
| 01 Plan | Opus 4.8 high | `ai-model-call plan   <prompt> <out>` · `01-opus48-plan.md` |
| 02 Plan review | Opus | `ai-codex-review plan-review` / `02-opus-plan-review.md` |
| 03 Implement | GPT-5.5/Codex | `ai-model-call implement <prompt> <out>` · `03-gpt55-implement.md` |
| 04 Diff review | Opus | `ai-codex-review diff-review` · `04-opus-diff-review.md` |
| 05 Test | GPT-5.5/Codex | `ai-model-call test <prompt> <out>` · `05-gpt55-test.md` |
| 06 Security review | Opus | `ai-codex-review security-review` · `06-opus-security-review.md` |
| 07 Final review | Opus 4.8 high | `ai-model-call final <prompt> <out>` · `07-opus48-final-review.md` |

## Guardrails

- **Phased plans:** each phase spec must end with an instruction telling the
  implementing agent to, when the phase finishes, re-read all downstream phases
  (to plan-end) and report any drift it introduced or discovered. This is the
  authoring side of the `fresh-session` skill's Step 3 check.
- Feature branch only; never work on `main`/`master`.
- Planning/review stages are read-only.
- Implementation makes the smallest safe change and adds/updates tests.
- No secrets; no weakening auth. Never merge/push/force without human approval.
- Run `ai-workspace-status` before starting and before opening a PR.

## Output

End with the completion report (`templates/repo-docs/docs-ai-completion-report.md`),
including the plain-English summary for Albert.
