# Standing-rules details (load only when needed)

The always-loaded client globals keep the short rule. This file holds the long
procedure behind each one. Load it when the task needs the detail — it is not
startup context.

## BlockerWatch (waiting on anything machine-checkable)

**Registration is no longer required.** Use bounded `ai-pr-wait` while you
remain in the turn; otherwise leave the existing issue or pull request as the
card and return later — GitHub notifications are the reminder. A turn may end
with an unchecked checklist on the issue.

Waiting on a PERSON is named in the reply's Still-open block: say who holds it
and what you need.

A blocker issue gets an owner at birth. Assign yourself (or the session that
will own it) and say so, or hand it to a named queue owner with an `owner:`
line in the body. Never leave it unowned.

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
  and every wait uses a bounded in-session tool with an explicit deadline
  (`ai-pr-wait --timeout-minutes N` / `ai-gh-wait --timeout-minutes N`). Never
  poll ad hoc. If the wait will outlive the turn, leave the issue or pull
  request as the card — do not create a waiter, registry entry, or park-state.

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
exception is `shared-db`'s activated automatic migration promotion workflow,
running only after its guarded merge and merged-main preview. That lane must
independently re-prove the one open structural work issue, immutable preview
evidence, production target, bounded allowlist, fresh dry-run, exclusive lock,
and post-apply result; missing evidence stops for an engineer.

Owner ruling (2026-09-28, Albert Hazan, verbatim: "never ask a human to approve.
as i have said at least 1000 times, i am a solo vibe coder with no technical
knowledge. ai has to do everything for me without asking me to do manual things.
institute that."): the 2026-09-16 rule that sent every production approval to an
independent reviewer in place of Albert is replaced. Assigned AI reviewers gate every technical production action through an
explicit exact-input APPROVE; anything else stops. No human approval is ever
requested, and AI performs every manual step itself (access, tooling, sign-in,
keys). Only genuine business-meaning questions go to Albert; platform-level
safety limits outside the repository still apply.

An **assigned AI reviewer** is: for `popcre/shared-db` work, the reviewer the
shared-db allocator draws; everywhere else, a rotation reviewer run through
`ai-review` whose engine differs from the implementing session's. The
implementing session never approves its own change. Authority an AI cannot
obtain itself (a platform limit) is reported `Blocked —`; `ai-task-gates`
approval gates take `--reviewer-approval <report>`, the assigned reviewer's
exact-head APPROVE report (popcre/ai-devops#996), from a review run with
`ai-review --implementer <engine>` (auto-detected for Claude Code and Codex). Such a limit is
never bypassed and never becomes a request for Albert's approval.

Owner ruling (2026-09-28, Albert Hazan, verbatim: "i don't
need an independent production reviewer. remove that requirement"; popcre/shared-db
#3656): no separately registered independent reviewer identity is required for
shared-db manual production recovery; the allocator-assigned exact-head AI review
APPROVE and every other evidence gate still apply. Workflow detail:
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
