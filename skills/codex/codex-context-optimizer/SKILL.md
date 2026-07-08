---
name: codex-context-optimizer
description: Reduce Codex token use by loading only relevant repo docs, compressing repeated prompts, and turning long pasted instructions into reusable references. Use when the user asks to reduce token usage, start from a handoff, read docs efficiently, avoid re-pasting instructions, or get lower-cost GPT-5.4/5.5 behavior close to a larger model.
---

# Codex Context Optimizer

Use this before or during large Codex sessions where repeated context is eating
tokens. The goal is to preserve the contract while shrinking the prompt.

## Minimal Loading Order

1. Read `AGENTS.md` first.
2. If present, read `HANDOFF.md` next and make it the task spine.
3. Read only docs named by the repo's documentation map for the current task.
4. Search code with `rg` before opening many files.
5. Keep large transcript/history files out of context unless the task is about
   transcript analysis.

## Compression Pattern

When the user pastes a long repeated prompt:

1. Extract the durable rule, trigger, and verification gate.
2. Replace the pasted text with a short standing instruction, skill, or doc
   pointer.
3. Put machine-specific facts in the machine atlas, repo-specific facts in
   `AGENTS.md`, and task-specific state in `HANDOFF.md`.
4. Avoid duplicating the same rule in multiple places; link to the source of
   truth.

## Lower-Cost Model Guidance

For GPT-5.4 or GPT-5.5 to approximate a stronger model on Albert's work:

- Give exact anchors: repo, branch, paths, URLs, table names, and expected
  verification.
- Split work into plan, implement, verify, closeout phases.
- Require read-before-edit, smallest safe change, tests, and evidence.
- Keep system instructions stable and short; move project facts to repo docs.
- Ask the model to stop when the plan is wrong instead of improvising broad
  architecture changes.
- For high-risk areas, use a second review pass rather than a larger always-on
  prompt.

## Output

Produce a compact session brief when useful:

```md
Goal:
Repo/branch:
Read:
Do not read:
Rules:
Verification:
Closeout:
```
