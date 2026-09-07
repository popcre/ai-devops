---
name: log-reviewer-issue
description: Record the current AI reviewer failure with complete diagnostic evidence using ai-reviewer-issue. Use when Albert says "log the reviewer error", "record this reviewer issue", "log this review failure", "save the reviewer problem", or names ai-reviewer-issue after a Grok, Kimi, GLM, Muse, Gemini, Qwen, Codex, DeepSeek, or other reviewer behaves unexpectedly.
---

# Log Reviewer Issue

Record the issue immediately. Do not ask Albert to restate information already
present in the conversation, write a separate report, retry the reviewer, or
diagnose the failure first.

## Procedure

1. Infer from the current session:
   - reviewer/provider name;
   - short title;
   - exact reviewer command when known;
   - detailed symptoms, expected result, attempts, timing, and unusual behavior;
   - repository root; and
   - the exact run ID or session name and caller (`codex` or `claude`) when the
     failed wrapper exposed them; and
   - an existing error-log path when one is known.
2. Run `ai-reviewer-issue record` with `--provider`, `--summary`, `--details`,
   `--command`, and `--repo`. Add `--error-file` only for a real known file.
   Add `--run-id` or `--session-id` together with `--caller` whenever those
   exact values are known. Without them, the recorder deliberately captures no
   nearby provider evidence instead of guessing.
   Details must be comprehensive; `--summary` is only the short index title.
3. If the command is not on PATH, locate the installed launcher or the canonical
   ai-devops checkout and invoke its `bin/ai-reviewer-issue`. Do not claim the
   recorder is missing until both were checked.
4. Report only the resulting issue ID and saved path to Albert.

## Required behavior

- Do not make Albert type command options or repeat the error.
- Do not reduce the details to one sentence.
- Do not invent a log path, command, duration, or retry.
- Do not include secrets. The recorder also redacts common credential forms.
- Do not run `ai-reviewer-issue list` or `show` while recording a new failure;
  those are maintenance actions.

## Required repair closure

For a maintenance sweep, first run `ai-reviewer-issue maintenance show`, then
start a round or explicitly resume its active ID. The frozen candidates define
the interval: classify each against an exact existing incident or use
`maintenance record` to preserve its event identity and record a new incident.
Do not start a sweep while merely recording a newly reported failure.

After the closure audit below, use `maintenance complete` with merged repair,
test, independent-review, installation, and live evidence. A partial repair also
needs `maintenance carry-forward` with the remaining-work document and proof.
An unfinished invocation needs current worker proof for `in-progress` and stays
carried until a terminal event accounts for it. The first round requires a
private pre-journal audit; new invocation recording cannot reconstruct overwritten
history. Follow `docs/reviewer-issues.md` for commands and source coverage.
Resolved incidents remain in place; never create a Markdown archive.

Durable incremental log-scan checkpoints are planned in
`plan_reviewer-log-repair-checkpoints.md` at the ai-devops repository root.
Read its STATUS table before implementing or changing that workflow. Until it
is complete, incident status does not prove how far provider logs were scanned.

Recording the failure is only the first half of the lifecycle. Whenever you
claim that reviewer behavior was repaired, close every affected incident in the
same workflow with `ai-reviewer-issue resolve` before reporting completion.

Use `resolved` only when the repair evidence covers every symptom recorded in
that incident. Use `partially-resolved` when any symptom remains, and name the
remaining problem in the resolution details. Leave the incident open when the
available evidence does not prove a repair. Each resolution requires the exact
repair commit and at least one test, review, installation, or live-production
evidence reference.

The resolution command appends a separate immutable record beneath the issue;
it never rewrites or deletes the original evidence package. Run
`ai-reviewer-issue list` and inspect every affected record before making the
final repair claim. This closure audit is standard operating procedure for all
reviewer repairs.

Resolved incidents remain in their original incident directories with their
append-only resolution records. Never move them into a `resolved.md` file or a
second archive.
