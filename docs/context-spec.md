# Current context contract

This is the compact, current specification for Claude/Codex context in
`ai-devops`. The completed historical work and decisions remain in the STATUS
table of [`../plan_context-engineering-consolidation.md`](../plan_context-engineering-consolidation.md).

- Always-loaded globals contain only universal behavior and safety rules.
- `AGENTS.md` is this repository's task router; `CLAUDE.md` is a small adapter.
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
