# Standing-rules details (load only when needed)

The always-loaded client globals keep the short rule. This file holds the long
procedure behind each one. Load it when the task needs the detail — it is not
startup context.

## BlockerWatch (waiting on another issue)

A session never ends its turn to say it is still waiting. Hold the wait inside
the turn: sleep, re-check, repeat. Come back only with the finished result or a
real blocker with its verbatim evidence line.

The one exception is a wait on another GitHub issue that has its own owner (a
shared-db ticket, a gate bug, another repository's work):

```text
ai-blocker-watch wait <owner/repo#N> --for <owner/repo#M> --brief-file <file>
```

- `N` is the blocker, `M` is the issue you are working on.
- When there is no work issue yet, use `--park "<plain-English title>"` instead
  of `--for` and one is opened for you.
- The brief is required. Write, in plain English, what this work is, what is
  already done, and the exact next steps — a brand-new session may have to
  continue from that text alone.
- A pull request is just a blocker reference. A point in time is `--until <UTC>`.
  A long job is an issue that says what "finished" means, waited on with
  `--until` as a check-in.
- Never hold such a wait open for days.

A blocker issue gets an owner at birth. Assign yourself (or the session that
will own it) and say so, or hand it to a named queue owner with an `owner:`
line in the body. Never leave it unowned.

Parked work is findable later with `ai-blocker-watch find <plain words>`.

## Subagent dispatch

- Split a task that plausibly needs more than ~30 steps; dispatch one piece at a
  time. A subagent carries its own context.
- Delegate wide reads (surveys, multi-file audits, log sweeps) so the raw
  material never enters this turn. Return conclusions, not transcripts.
- Never delegate a schema change, a merge decision, a production command, or a
  security judgement.
- When relaying owner authority, quote Albert's exact words and say they came
  from his chat message.
- A sub-agent report that is neither finished work nor a blocker with its
  verbatim evidence line is a failure; resume that agent immediately.
- Before parallel agents, list the files each will touch; overlapping work goes
  to one agent in sequence.
- Every dispatch prompt says: create a uniquely named worktree and verify its
  branch before every commit; only the agent that opened an issue closes it.

## Quiet tool output

Everything put into a conversation is re-sent on every later turn. Keep routine
output under ~40 lines. Correctness outranks this: when the full text is what
you need to be right, read it and say why.

- Do not return full logs, JSON, diffs, or command output to the conversation.
  Redirect long output to a scratch file; return only the decisive result.
- Find before you read; filter logs by what matters, not by position.
- Never re-run a command only to re-read output already in this conversation.
- Quote only the part of an error that identifies the cause.
- Do not repeat a deterministic failing command without changing something. A
  transient failure may be retried up to three times with backoff.

## Production trigger incident

Before production trigger or Terraform-state work, read
`docs/cloud-build-prod-trigger-incident-2026-07-20.md`. The sole narrow
exception is `shared-db`'s activated automatic migration promotion workflow;
its full checklist lives in `skills/shared/shared-db-orchestrator/` and
`skills/shared/shared-db-change/`. That exception authorizes no manual
production command.

## Reviewer rotation details

`docs/reviewer-rotation-rules.md`. Reviewer wrappers never call 1Password
during a review, reviewer state never leaves its home drive, and reviewer paths
never grow with names.

## Worktree merge quirk

`gh pr merge` from a linked worktree can print `'main' is already used by
worktree`. That is local branch cleanup failing AFTER the merge succeeded.
Confirm with `gh pr view <n> --json state`, delete the remote branch, and
continue — do not report it as a failed merge.
