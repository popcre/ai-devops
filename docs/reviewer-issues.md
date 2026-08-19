# Reviewer issue recording

Use `ai-reviewer-issue` when a reviewer fails, returns no decision, reviews the
wrong change, takes an unusual amount of time, or behaves differently from its
documented contract. This supplements the numerical scoreboard with evidence
needed for diagnosis.

## Instruction to give the reporting session

Copy this sentence into the session:

> Record the reviewer problem before trying again. Run
> `ai-reviewer-issue record --provider <reviewer-name> --summary "<one sentence describing what went wrong>"`.
> If the failed command wrote an error log, add `--error-file <exact-log-path>`.
> Do not write a separate report and do not run `list` or `show`.

Example:

```bash
ai-reviewer-issue record --provider grok \
  --summary "The review ran for 15 minutes and returned no approve or reject decision."
```

The session supplies one sentence. The command automatically captures:

- the repository, branch, current commit, remote, and existing working changes;
- the computer and shell;
- the newest structured metadata for that reviewer, with prompt and credential
  fields removed;
- the names and sizes of up to ten recent review artifacts; and
- when supplied, the final 200 lines of the error log with common credential
  forms redacted.

Reports are stored under `.ai/reviewer-issues/` in the installed ai-devops
checkout. That directory is excluded from Git because evidence can refer to
private repositories and provider sessions.

## Later diagnosis

An ai-devops maintenance session can find and inspect reports without involving
the original reporting session:

```bash
ai-reviewer-issue list
ai-reviewer-issue show <issue-id>
ai-reviewer-issue path
```

`list` prints one line per recorded problem. `show` prints the safe structured
summary. The path printed by `path` contains the redacted metadata, recent
artifact inventory, and optional error tail.

The command intentionally does not publish reports, create GitHub issues, retry
the reviewer, select another provider, or alter the scoreboard. Those actions
require a maintenance session to review the evidence first.
