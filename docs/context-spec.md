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

## Task-gate contract

[`../config/task-gates.json`](../config/task-gates.json) is the versioned,
central contract for task classification. It separates observed change classes
from the gates required before an expensive or protected action. The command
implementation is intentionally centralized; repositories contribute only
small declarations that may strengthen the applicable class or gate.

- Start by recording the requested class and a short reason. Before formal
  review, a long pull-request wait, shipping, deployment, database,
  infrastructure, or production action, recompute the complete change set.
- Mixed changes take the highest-precedence class. Unknown paths are treated as
  code/configuration; an unknown repository or missing policy stops the action.
- An explicit owner request is recorded with its reason. It cannot downgrade a
  reviewer-safety, UI/live-workflow, database, deployment, infrastructure,
  production, or private-evidence requirement.
- The policy defines ordinary prose, code/configuration, reviewer safety,
  UI/live workflow, shared database, deployment, infrastructure, production,
  and private/licensed evidence. It does not replace the procedures selected by
  those classes.

## Lean repository routers

A root router contains only repository purpose, invariant safety and ownership
boundaries, high-frequency task routes, and links to specialized routes.
Procedures, machine facts, changing operational facts, and history belong in
their owned documents or skills. Size is a warning measurement, never a reason
to remove a unique safeguard.

For a documentation task, the router loads the durable repository boundaries
and documentation route without loading database, production, or reviewer
procedures. Those procedures remain reachable through their specific triggers.
Every baseline item must be kept, moved to a named owner, consolidated with
proof, or removed with documented proof.

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
