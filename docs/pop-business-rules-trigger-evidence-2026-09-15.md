# `pop-business-rules` trigger evidence — 2026-09-15

This evidence closes the remaining live-client gate in issue #35. After PR #492
merged as `67d2e3c8`, the source and both installed client copies had SHA-256
`B3A8DC4BBEA1A9953BC06EB90C77C937D6FAC6E0D653A46D450CE0CE29104ADA`.
The 20 prompts and their expected outcomes remain in
`tools/skill-trigger-eval/pop-business-rules.eval.json`.

## Claude

The repository evaluator ran every prompt three times in a neutral seeded
project. All 10 intended prompts selected the Skill in all three rounds. None
of the 10 near-miss prompts selected it. There were no errors or timeouts.

## Codex

Codex ran at medium reasoning effort in a read-only sandbox against the same
neutral seeded project. All 10 near-miss prompts declined the Skill in all
three rounds. Eight intended prompts completed with a selection; the PopPIM
audit and cross-application reconciliation prompts opened a full investigation
but exceeded the batch evaluator's completion timeout, which discards partial
event streams.

Those two prompts and the variable DesignFlow settled/proposed prompt were then
run three times each with the same command and project while the event stream
was observed directly. Each prompt opened the installed
`pop-business-rules/SKILL.md` in all three runs. The probe stopped immediately
after that selection event, before any repository or business-data mutation.
Combined result: all 10 intended prompts selected the Skill, and all 10
near-misses declined it, with three observations per prompt.

## Behavioral probes

Three read/write-isolated probes ran in a disposable Git fixture containing a
small application map, two business-rule topics, and one consumer application
document:

- Read: the Skill opened the map and only the mapped taxonomy topic, identified
  `mgCategory` as governed by Product classification, and reported it Settled.
- Add/change: without an authority or effective date, the Skill added the
  hypothetical statement only to the applicable business-rule topic as
  Proposed with both fields Unknown. The consumer application was unchanged.
- Audit: the Skill identified the current application statement as conflicting
  with the Settled sourcing-owner rule, retained the explicitly Historical
  sales-owner statement as non-controlling, and ignored an unrelated Proposed
  packaging rule. The read-only audit changed no files.

## Offline and installation checks

- `test-pop-business-rules-skill.sh`: pass.
- `test-ai-install-skills.sh`: pass, 9/9 sections.
- `test-installer-parity.sh`: pass, 2/2 sections.
- `test-codex-trigger-eval.sh`: pass.
- `test-context-audit.ps1`: pass, including trigger-runner safeguards.
- `ai-test-local --check-collision`: clear; the Windows runner was idle.
- Installer dry-run and real install completed; Claude and Codex installed
  copies matched the source hash above byte for byte.
