# Reviewer issue recording

Use `ai-reviewer-issue` when a reviewer fails, returns no decision, reviews the
wrong change, takes an unusual amount of time, or behaves differently from its
documented contract. This supplements the numerical scoreboard with evidence
needed for diagnosis.

## Instruction to give the reporting session

Say only:

> Log the reviewer error.

The installed `log-reviewer-issue` skill makes the session infer the reviewer,
command, detailed symptoms, attempts, repository, and known logs from its current
context. Albert does not need to type command options or repeat the problem.

Example:

```bash
ai-reviewer-issue record --provider grok \
  --summary "No decision after 15 minutes" \
  --command "ai-grok-review ask pricing-review --prompt-file review.md" \
  --details "The reviewer completed its run but returned neither approval nor rejection. It was the first attempt; no retry has been made."
```

When the wrapper created provider-neutral lifecycle state, pass
`--lifecycle-state <path>`; it supplies the provider, repository, source digest,
run/session, and caller as one indivisible join. Older wrappers may pass
`--run-id`, `--session-id`, and `--caller` directly. Evidence is copied only when
provider, repository, commit, source digest when available, and these join
fields match exactly. Missing exact evidence is recorded in
`missing-evidence.txt`; the recorder never substitutes the newest nearby run.

The title is only an index label. `--details` has no length limit. For longer
notes, the session can write a file and pass `--details-file <path>`, or pipe
notes through standard input with `--details-file -`.

The command automatically captures:

- the repository, branch, current commit, remote, and existing working changes;
- the computer and shell;
- exact-run structured metadata, with sensitive fields removed;
- exact report paths owned by the matched metadata, copied in full;
- exact log paths owned by the matched metadata, copied in full;
- the exact matching scoreboard record;
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

## Active Kimi repair

The 2026-08-19 Kimi evidence exposed report-persistence, partial-output, and
terminal-diagnostic defects. While issue #46 is open, read the STATUS table in
[`plan_kimi-review-failure-recovery.md`](../plan_kimi-review-failure-recovery.md)
before changing or restoring Kimi. The original local evidence packages remain
historical records and must not be rewritten.
