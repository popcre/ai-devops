# `pop-business-rules` trigger evidence — 2026-09-15

This evidence closes the remaining live-client gate in issue #35. The tested
source and both installed client copies had SHA-256
`9ED982608A7F11ED9F250E52672F78DF9DFE9B504086DA1EF33EEA2B4FEED888`.
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

## Offline and installation checks

- `test-pop-business-rules-skill.sh`: pass.
- `test-ai-install-skills.sh`: pass, 9/9 sections.
- `test-installer-parity.sh`: pass, 2/2 sections.
- `test-codex-trigger-eval.sh`: pass.
- `test-context-audit.ps1`: pass, including trigger-runner safeguards.
- `ai-test-local --check-collision`: clear; the Windows runner was idle.
- Installer dry-run and real install completed; Claude and Codex installed
  copies matched the source hash above byte for byte.
