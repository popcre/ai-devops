# Current context contract

This is the compact, current specification for Claude/Codex context in
`ai-devops`. The completed historical work and decisions remain in the STATUS
table of [`../plan_context-engineering-consolidation.md`](../plan_context-engineering-consolidation.md).

- Always-loaded globals contain only universal behavior and safety rules.
- `AGENTS.md` holds repository invariants and the category router;
  `docs/task-router.md` holds specialized routes; `CLAUDE.md` is a small adapter.
- Procedures live in task-triggered skills/docs; machine facts live in the
  machine atlas and are preserved by `ai-adopt-globals`.
- Portable facts live in the protected Markdown hub and are read through
  `ai-facts`; Codex SQLite is never the portable sync target.
- A rule has one owner. Other files carry only a path plus a trigger.
- Source budgets and effective installed-global bytes are separate ratchets.
  Installed measurement includes preserved machine sections.
- Skill-description changes require the matching committed trigger-eval set.
  Use repeated runs and more than one platform for decisions; a single
  stochastic score is only an observation.

Generate the current measurements rather than copying numbers into prose:

```powershell
python tools/context-audit/context-audit.py --root . `
  --claude-home "$env:USERPROFILE\.claude" `
  --codex-home "$env:USERPROFILE\.codex" `
  --json .ai/context-current.json --strict
python tools/context-audit/render-measurements.py .ai/context-current.json
```

Acceptance is: strict audit success, no budget warnings, no missing safety or
parity rules, no broken links, and an explicit effective-installed measurement.

## What a root router may contain

A repository's root router (`AGENTS.md`) answers one question: what does a
session need to know before it does anything here. It carries only:

1. what the repository is for, in a few lines;
2. the safety and ownership boundaries that never change — who may write here,
   what may never be edited directly, which identity is used;
3. the routes for the tasks that actually come up often, one line each; and
4. links to the specialized routes for everything else.

Everything else has an owned home and is reached from there: procedures live in
task-triggered skills and docs, machine facts in the machine atlas, live values
resolved at the moment they are needed, and history in its plan's STATUS table.
A rule has one owner; every other mention is a path plus a trigger.

Size is a warning, never a failure. A router that grows past its budget gets a
diagnostic saying so, and the fix is to move content to its owner — never to
delete a safeguard to fit. Nothing may be dropped in a migration: every removed
line is accounted for as kept, moved, consolidated, or deliberately removed.

## Task classes and gates

`config/task-gates.json` says what a change is (its class) and, separately,
which gates that class must pass. `config/task-gates.schema.json` is the
contract; `tools/ci/validate-task-gates.py` enforces it. A repository may ship
its own `.ai-devops/task-gates.json`, which can only strengthen a class.

`bin/ai-task-gates` records the declared class at the start of work and
rechecks the complete change set before any expensive or risky action. A
protected class — reviewer safety, shared database, deployment, infrastructure,
production, private evidence — can never be acknowledged or owner-requested
away, and anything the tool cannot classify is refused rather than allowed.
