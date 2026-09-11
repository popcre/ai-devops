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

PR #411 subsequently exposed a second mismatch in the same evidence gate:
run `34567280854` at head `f685d676982c59d942273ce738ce857eb114c966`
completed the hosted equivalent safety lane successfully, but the original lane
hit its configured 30-minute ceiling. Both workflow jobs execute the identical
Codex and Grok suites. The gate rejected the whole cancelled run before looking
at that successful replacement evidence.

The additional repair accepts only completed equivalent fallback proof with
successful Linux, Windows aggregate and classifier jobs. Every other reported
job must be complete and clean; original assertion failure, failed runs, missing
jobs, unrelated cancellation/failure and moving queue identity still refuse.
The original lane may remain queued/running or be skipped/cancelled, avoiding a
redundant wait while preserving all required coverage. No run was cancelled or
rerun, and no timeout or branch-protection rule was changed.

- Extended regression suite: 41 passed, 0 failed, 0 skipped.
- The actual exact-head job evidence from run `34567280854` satisfies the narrow
  replacement proof; private job metadata is retained with the review evidence.

This is the bounded classification repair, not final #166 programme acceptance.
Exact-head independent review, CI and landing evidence are recorded on the PR.
