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
- Do not run `ai-reviewer-issue list` or `show`; those are maintenance actions.
