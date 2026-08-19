# Reviewer issue recording

Use `ai-reviewer-issue` when a reviewer fails, returns no decision, reviews the
wrong change, takes an unusual amount of time, or behaves differently from its
documented contract. This supplements the numerical scoreboard with evidence
needed for diagnosis.

## Instruction to give the reporting session

Copy this sentence into the session:

> Record the reviewer problem before trying again. Run `ai-reviewer-issue record`
> with the reviewer name, a short title, the exact failed command, and detailed
> notes using `--details` or `--details-file`. If the failed command wrote an
> error log, add `--error-file <exact-log-path>`. Do not run `list` or `show`.

Example:

```bash
ai-reviewer-issue record --provider grok \
  --summary "No decision after 15 minutes" \
  --command "ai-grok-review ask pricing-review --prompt-file review.md" \
  --details "The reviewer completed its run but returned neither approval nor rejection. It was the first attempt; no retry has been made."
```

The title is only an index label. `--details` has no length limit. For longer
notes, the session can write a file and pass `--details-file <path>`, or pipe
notes through standard input with `--details-file -`.

The command automatically captures:

- the repository, branch, current commit, remote, and existing working changes;
- the computer and shell;
- the newest structured metadata for that reviewer, with sensitive fields removed;
- every matching review report, copied in full;
- reviewer log files changed within the previous two days, copied in full;
- the latest matching scoreboard record;
- the names and sizes of recent review artifacts; and
- when supplied, the complete error log and detailed session notes.

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
summary. The path printed by `path` contains the complete local evidence package.

The command intentionally does not publish reports, create GitHub issues, retry
the reviewer, select another provider, or alter the scoreboard. Those actions
require a maintenance session to review the evidence first.
