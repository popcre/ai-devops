# Jev spend reduction baseline — no-go (2026-09-27 EDT)

## Recompute

Run `python3 tests/verification/jev/spend_baseline_audit.py /home/ahazan/Dropbox/ai/chat_transcripts` on the private archive. The script prints aggregate counts only. It parses JSONL records, skips subagent paths and duplicate session IDs, counts Claude usage once per assistant message ID, and uses the final cumulative Codex `token_count` for each session. It counts `Skill` tool calls, explicit `SKILL.md` reads, and reviewer-maintenance commands inside assistant tool calls. It never prints message text, identifiers, paths from the archive, or provider replies. Its structural counters are indicators for caller inspection, **not** counts of substitutable decisions.

## Measured archive structure

| Provider | Unique parent sessions | Billed records | Fresh input | Cache read | Cache write | Output |
|---|---:|---:|---:|---:|---:|---:|
| Claude | 659 | 82,262 assistant messages | 2,614,642 | 14,429,947,549 | 306,665,510 | 51,093,128 |
| Codex | 2,034 | 1,932 sessions with usage | 11,705,580,257 total input, including cached | 11,429,668,013 cached subset | 40,884 | 25,301,637 |

The Codex input figure is a total with cached input inside it; do not add that column to the cache-read figure. The archive also had 1,270 excluded Claude subagent files, 31 duplicate parent files, 18 Claude files without an early usable session ID, and 16 malformed Claude lines. It mixes dates, models, and unrelated work. The aggregate cannot be priced using one model rate, and no measured token record is attributable to a standalone Jev-replaceable decision. Estimated **replaceable** spend is therefore unavailable, not zero. No savings claim is supported.

## Ordered candidate decision

1. **Reviewer-maintenance category suggestions — fails.** The audit found 7 Claude and 167 Codex assistant tool calls whose arguments mention `ai-reviewer-issue` and `maintenance`. These are tool calls inside broader paid sessions, not paid category calls. `bin/ai-reviewer-issue` dispatches maintenance to `tools/reviewer_maintenance.py`, whose `candidates()` and `invocations()` derive classifications from structured events. The subsequent `classify` and `record` paths use an operator-provided outcome. There is no existing category-suggestion model invocation to skip. The frozen private incident records are also not 30 independently labeled public cases. Public/synthetic representative labels would be `failed-invocation`, `completion-unproven`, and `reviewer-outcome-needs-classification`; they demonstrate the existing deterministic categories, not a paid substitution.
2. **Public issue/task-intent sorting — fails.** The advisory plan's public issue-pair command is still an open future pilot. Its existing caller is a person using GitHub issues, not a paid sorting wrapper. A public pair labeled `duplicate`, `supersedes`, `related`, or `distinct` could support human-time evaluation, but no current frontier invocation is identified for it to displace. Thirty public issue pairs would not cure that missing baseline.
3. **Optional skill suggestion before full load — fails.** The audit saw 385 Claude `Skill` tool calls, 370 Claude explicit skill-file reads, and 2,986 Codex explicit skill-file reads. These include required skills, repeated reads, tests, and unrelated/private work. In Claude, the model already selects a skill from the available-skills list and then loads its body; in Codex, task instructions and the matching router row direct file reads. `docs/skill-trigger-eval.md` evaluates skill-trigger accuracy through paid `claude -p` runs, but that is a test harness, not a recurring production call. The archive supplies no observable ground-truth label that any particular full read was unnecessary, or 30 independent public cases with such labels. Example public/synthetic labels are `required shared-db skill`, `optional documentation skill`, `irrelevant skill`; assigning those to archived reads would be speculation.

## Decision and boundary

No candidate meets all four locked conditions: a concrete existing paid call or avoidable full skill load, at least 30 independent public cases, observable ground truth, and a reversible caller path. Selection stops at **no-go**. The evidence supports no new Jev runtime dependency, shadow call, trial, or installation for this spend-reduction lane. The separately owned advisory issue-pair pilot can proceed on its own human-time merits; it cannot inherit a token-saving claim from this audit.

The audit is intentionally conservative. It does not inspect or publish private source text, infer labels from keyword mentions, price mixed model traffic, or count a human decision as a frontier-model call. A future newly instrumented caller with at least 30 public ground-truth cases would require a fresh baseline and selection decision.
