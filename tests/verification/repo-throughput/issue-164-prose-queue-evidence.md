# Queue evidence for prose-only changes (#161 / #164)

The queue evidence gate required successful Windows safety jobs even when the
shared CI classifier intentionally skipped them for prose-only changes. Queue
run 34565819735, job 103156404653, exposed this mismatch for PR #407; its actual
patch contains only a plan and a verification Markdown document.

The repair classifies the actual pinned PR base-to-head diff using the existing
CI classifier, with rename detection disabled. Only the two expected Windows
jobs may report skipped for a proven nonempty prose-only patch. Missing jobs,
failed jobs, code, mixed changes, skill Markdown and unavailable source fail
closed. The source, base and queue identity must remain unchanged after the
classification. No workflow or branch protection was weakened.

Verification on 2026-09-11:

- Reproduction before repair: 16 passed, 1 failed.
- Focused real-Git fixture suite: 29 passed, 0 failed, 0 skipped.
- Existing workflow policy suite: PASS.
- Git whitespace validation: PASS.

This is the bounded classification repair, not final #166 programme acceptance.
Exact-head independent review, CI and landing evidence are recorded on the PR.
