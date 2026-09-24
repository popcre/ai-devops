# Standing-rules details (load only when needed)

The always-loaded client globals keep the short rule. This file holds the long
procedure behind each one. Load it when the task needs the detail — it is not
startup context.

## BlockerWatch (waiting on anything machine-checkable)

**Registration is the default; polling is the exception.** A wait that may
exceed ~10 minutes — on an issue, a pull request, a CI run, or another
session's work — is registered with BlockerWatch and only then does the turn
end. The scheduled watcher wakes the session when the wait releases. Holding a
poll open inside the turn is for short waits only, while the session keeps
working; a turn never ends by saying it is still waiting.

```text
ai-blocker-watch wait <owner/repo#N> [--until <UTC>] (--for <owner/repo#M> | --park "<title>") --brief-file <file>
```

- `N` is the blocker — an issue or a pull request. A pull request is watched
  directly (GitHub cannot link a PR as a blocker; the wake says so if it closed
  unmerged). A CI run is its pull request, or `--until` as a check-in.
- `M` is the issue this work belongs to. No issue of your own, or the issue is
  already closed? Use `--park "<plain-English title>"` and one is opened.
- The brief is required. Write, in plain English, what this work is, what is
  already done, and the exact next steps — a brand-new session may have to
  continue from that text alone.
- Subagents register too (#723). A dispatched headless agent registers its own
  session; an in-chat subagent inherits the parent session's ID, and that is
  the correct wake target, because the parent chat owns the work. A session
  with no session ID passes `--harness` and `--session` explicitly.
- Combine a blocker and `--until` for a long job: the wake rechecks and
  re-registers if it is still running. Never hold such a wait open for days.
- A registered wait makes ending the turn correct. The closeout hook accepts a
  turn that ends on waiting language only when the session holds a wait still
  in flight (`ai-blocker-watch has-wait <session-id>`).
- Waiting on a PERSON is not a BlockerWatch wait: name who holds it and what
  you need in the reply's Still-open block instead.

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
  branch before every commit; only the agent that opened an issue closes it;
  and any wait that may exceed ~10 minutes is REGISTERED with ai-blocker-watch
  — by the subagent itself unless the dispatcher holds it — never polled
  ad hoc. Name the blocker and the owning/parked issue in the prompt so the
  subagent can register without guessing.

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
