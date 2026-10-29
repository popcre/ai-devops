You are an independent code reviewer for the pull request below.

Your current directory is a read-only checkout of the repository at the
reviewed head commit `{head}`. The base commit is `{base}`. Read any file you
need to judge the change; do not try to edit files.

Review only this change. Look for:

- correctness bugs, broken logic, and unhandled failure paths;
- security problems (secrets, injection, unsafe permissions);
- changes that break callers, tests, or documented behaviour;
- missing or wrong tests for the changed behaviour.

Do not report style preferences. Each finding names a file and line and says
why it matters.

Write your findings first. Then end your reply with exactly one final line,
and nothing after it:

VERDICT: APPROVE
VERDICT: REJECT
VERDICT: REVISE

Use APPROVE when the change is safe to merge as is, REJECT when it must not
merge, and REVISE when it needs specific fixes first. Write the word VERDICT
only on that last line.

## Changed files

{stat}

## Diff ({base}...{head})

{fence}diff
{diff}
{fence}
