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
and what you need, and whether that work is actively in progress or idle. When
the holder is another session, say which kind: a subagent this agent spawned
and is waiting on, a session already running that it can see, or a session it
is asking Albert to start.

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

Owner ruling (2026-10-02, Albert Hazan, verbatim: "let AI launch it and remove
that rule permanently."): the earlier bar on a session-made dispatch of that
lane is removed permanently. An AI session may launch the merged-preview apply
run of `shared-supabase-migrations.yml` (target preview, mode apply, the merged
source PR) that starts the automatic promotion, for an approved, merged
shared-db change, after `ai-task-gates check --before shared-db-promotion`
passes in the shared-db checkout. The workflow's own re-proof, risk assessment,
lock, and evidence checks stay binding; a refusal there is fixed at its cause,
never bypassed. This allows no manual production command and no other
workflow, repository, or infrastructure action.

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
`ai-review` whose engine differs from the implementing session's. Outside
shared-db there is no draw command: the session itself picks any reviewer the
registry lists as in rotation (`config/reviewer-registry.json`, mirrored from
the allocator) and moves to the next one if it is unreachable. The
implementing session never approves its own change. AI review is required
**only in `popcre/shared-db`** (owner 2026-10-15, verbatim in
`docs/owner-rulings.md`, superseding 2026-10-13 popcre/ai-devops#1714): no other
repository's work waits for a review. Authority an AI cannot
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
its full checklist lives in the [shared-db structural safety reference](shared-db-structural-safety/README.md) and
`skills/shared/shared-db-change/`. That exception authorizes no manual
production command.

## Production and shared-db scope (moved from the globals, #1881)

AI sessions are read-only for production and shared cloud infrastructure by
default. The assigned AI reviewer's explicit APPROVE on the exact inputs gates
`terraform apply`, mutating production `gcloud`, and every other technical
production action; anything else stops. Shared-db structural work is
claim-first: claim exact objects on the existing issue and start; no
orchestrator chat or marker is required. Its scope stays the minimum — only
work that changes the database's SHAPE, or a curated Master Data load.
Proofs, monitoring, reports, tooling, scripts, docs, and repository
maintenance never go there. Reading schema and safe sample data is open;
application row data belongs to the application. Dated rulings:
[`docs/owner-rulings.md`](owner-rulings.md).

## Database writes

Owner ruling (2026-10-14, Albert Hazan, verbatim: "Our own safety rules
require a second AI to approve database writes. Remove that rule."): no
assigned AI reviewer APPROVE is required for a database write. This replaces
the earlier small-owner-entry exception (2026-10-02) and the general
second-AI approval step for `check --before database`.

Every other gate stays: task declaration, class escalation, protected-class
seals, target identity proof, claim rules, and live proof. Prove which
database you are pointed at immediately before every write. Run:

    ai-task-gates check --before database

`--small-owner-entry` is no longer needed; if passed, the gate records it as
optional history and still opens without a reviewer. Private-evidence and
private-tooling licensed-row seals are unchanged.

## Reviewer rotation details

`docs/reviewer-rotation-rules.md`. Reviewer wrappers never call 1Password
during a review, reviewer state never leaves its home drive, and reviewer paths
never grow with names.

## Worktree merge quirk

`gh pr merge` from a linked worktree can print `'main' is already used by
worktree`. That is local branch cleanup failing AFTER the merge succeeded.
Confirm with `gh pr view <n> --json state`, delete the remote branch, and
continue — do not report it as a failed merge.

## Procedures moved from the Claude global (2026-10-21)

These were in `templates/system/CLAUDE-global.md`; the global keeps the rule
and points here.

- **Job plan:** restate goal, scope, done-when in the first reply for anything
  beyond a one-phrase command. It confirms understanding; it is not a request
  for approval. A clear request authorizes ordinary scoped work.
- **Live proof:** until proven live, leave `- [ ] live proof` on the **same**
  issue and name it in the closing note; never open a second ticket for that
  gap. One named owner until the app works live.
- **Authorized scope:** track multi-step work on its existing issue, verify
  each outcome, and continue. Respect actual dependencies, ownership,
  collision controls, and safety gates.
- **Worktrees:** every write-capable task uses its own current-upstream
  worktree. Edit a shared checkout only for a serialized landing,
  installation, or recovery. Each child Git repository in a project folder
  gets its own worktree.
- **Manual steps:** the AI does access, tooling, sign-in, and keys itself;
  never ask Albert to run, click, or set up anything. Prove success with a
  commit, PR, passing check, live result, or screenshot.
- **Task class** (class list stays in the global, test-pinned): start with `ai-task-gates start --class <class>`; before a
  paid review, PR wait, shipment, deployment, database, infrastructure, or
  production action, run `ai-task-gates check --before <action>`. If the work
  outgrew the class, redeclare and say so. private-evidence is read-only
  analysis.
- **Secrets:** values move only through pipes or protected files. Rotation
  needs an assigned AI reviewer's APPROVE of the rotation plan (exact
  credential, provider, and consumers), except a credential under a standing
  owner no-rotation directive.
- **Destructive actions:** inspect the exact target; keep a commit, backup, or
  reviewed preview. No broad staging or destructive Git over unreviewed work,
  another session's files, a repository root, or a machine-local overlay.
- **Production:** the reviewer's APPROVE is on the exact inputs. Database
  writes skip that APPROVE but keep every other gate (see "Database writes").
  The automatic `shared-db` migration promotion exception re-proves the one
  open structural work issue or stops for an engineer; it authorizes no manual
  production command or bypass.
- **Shared database:** claim-first, minimum scope; see "Production and
  shared-db scope".
- **GitHub signature:** `Posted by Claude chat <id> on <machine>`, where
  `<id>` is `$CLAUDE_CODE_SESSION_ID` (or `unknown` when empty). The managed
  shell snippet exports it ready-made as `$AI_GH_SIGNATURE`. When editing a
  body, keep existing signatures and add yours.
- **Successors:** never inherit a predecessor's repository, work type, route,
  or object claim. Private artifacts stay in their approved private repository.
- **Engineering:** never replace operating-system binaries.
- **Git identity:** before the first commit in a repository, run
  `git var GIT_COMMITTER_IDENT`; it must show
  `Albert Hazan <u2giants@users.noreply.github.com>`. Never `git pull` the
  installed ai-devops checkout; see `docs/deployment.md`.
- **Merging:** checks and the merge queue decide
  (`config/repository-policy.json`). A prose-only PR merges with
  `gh pr merge --squash --admin` once `bin/ai-doc-safety` passes on the exact
  head.
- **Compression:** never send secrets, private transcripts, review verdicts,
  or code through a compressor.
- **Subagents:** never delegate schema, merge, production, or security
  decisions. A subagent returns finished work or a blocker with its verbatim
  evidence line. When relaying owner authority, say the words came from
  Albert's chat.
- **Skills and procedures** govern the work and what goes into files; they
  never override the reply style.
