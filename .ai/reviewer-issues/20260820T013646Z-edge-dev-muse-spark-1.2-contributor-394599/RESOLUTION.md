# Resolved — 2026-08-19, edge-dev, claude

Fixed in ai-devops commit 469f59f ("ai-muse: stop discarding complete reviews
over the verdict line"), pushed to u2giants/ai-devops main.

## Confirmed root cause

Both causes named in details.redacted.txt were correct, plus a third underneath them.

1. Vocabulary. bin/ai-muse matched only `^VERDICT: (FINDINGS|NO FINDINGS)$`.
   The review returned `VERDICT: APPROVE`, so a correct verdict was rejected
   on wording alone.
2. ANSI. The match ran over OpenCode's coloured interactive stream. Escape
   sequences adjacent to the token defeat an anchored line match.
3. Conflicting instructions (not previously identified). The wrapper appended
   its own "Finish with exactly one final line: VERDICT: FINDINGS or
   VERDICT: NO FINDINGS" to the caller's brief, which had already asked for
   APPROVE/REVISE. The model was given two contradictory orders; the
   unexpected verdict word in (1) is a direct consequence of that.

## What changed

- Output is ANSI- and CR-stripped before the verdict match AND before the
  report is written, so saved artifacts are clean text.
- Any verdict word is accepted; the extracted verdict is recorded in the
  report header table.
- The wrapper no longer appends its own verdict instruction when the caller's
  brief already contains "VERDICT:".

## Evidence

Replaying this issue's error.redacted.txt:
- old matcher: no verdict found (defect reproduced)
- new matcher: `VERDICT: APPROVE`

The gate was NOT loosened into uselessness. Replaying the genuinely truncated
run from issue 20260819T205645Z-edge-dev-ai-muse-359552 (model stopped
mid-review, no verdict line) still yields no verdict and is still filed as
incomplete.

Six regression tests added to tests/test-ai-muse.sh, exercising the shipped
matcher itself (extracted from bin/ai-muse, not a copy): plain verdict,
ANSI+CR-wrapped verdict, multiple verdict lines (last wins), bare "VERDICT:"
with no word, and a mid-sentence mention that must not count. All 15 checks in
the file pass.

Docs updated: skills/shared/ask-muse/SKILL.md now states the verdict contract
correctly (any word; brief may set its own; write it once, not twice).

## NOT addressed by this commit

- The false ".ai/reviews is not git-ignored" warning reported in ai-kimi,
  ai-grok-review and ai-gemini. bin/ai-muse has no such check, so nothing to
  fix here. The reported fix (use `git check-ignore`) still stands for those
  three wrappers and is open.
- ai-gemini returning a bare/empty verdict. Separate wrapper, still open.
- The exit-code observation in the report ("wrapper exits 0 while printing
  error:") could not be reproduced: `die` exits 1, and the incomplete path
  calls `die`. Left as-is. If a caller genuinely saw exit 0, capture the
  invocation, because the cause is then outside bin/ai-muse.
