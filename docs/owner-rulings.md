# Owner rulings (verbatim)

Albert Hazan's dated standing rulings, quoted exactly. The global rule files
keep only the current rule in one line plus a pointer here; the procedures
that apply each ruling live in `docs/standing-rules-details.md`. Add a new
ruling here with its date, exact words, and what it changed.

## 2026-09-28 — no human approval

Verbatim: "never ask a human to approve. as i have said at least 1000 times, i
am a solo vibe coder with no technical knowledge. ai has to do everything for
me without asking me to do manual things. institute that."

Current rule: no human approval is ever requested; assigned AI reviewers gate
technical actions through an explicit exact-input APPROVE; AI performs every
manual step itself; only business-meaning questions go to Albert.

## 2026-09-28 — no separate production reviewer identity (popcre/shared-db#3656)

Verbatim: "i don't need an independent production reviewer. remove that
requirement"

Current rule: shared-db manual production recovery needs no separately
registered reviewer identity; the allocator-assigned exact-head APPROVE and
every other evidence gate still apply.

## 2026-10-02 — AI may launch the shared-db promotion workflow

Verbatim: "let AI launch it and remove that rule permanently."

Current rule: an AI session may launch the merged-preview run of the activated
automatic migration promotion workflow for an approved, merged change after
`ai-task-gates check --before shared-db-promotion` passes. It authorizes no
manual production command, other repository, or bypass of the workflow's
checks.

## 2026-10-13 — discretionary review is shared-db-only (popcre/ai-devops#1714)

Current rule (recorded in `docs/standing-rules-details.md`): outside
`popcre/shared-db`, dispatch a review only when the task class's gate demands
one.

## 2026-10-14 — database writes skip the second AI

Verbatim: "Our own safety rules require a second AI to approve database writes.
Remove that rule."

Current rule: no assigned AI reviewer APPROVE is required for a database
write. Every other gate stays: task declaration, class escalation,
protected-class seals, target identity proof, claim rules, and live proof.
`ai-task-gates check --before database` opens without `--reviewer-approval`.

## 2026-10-15 — review is required only in popcre/shared-db

Verbatim, from Albert's chat: "we turned off reviewing in all repos aside from
shared-db. why is this waiting for a review?"

Current rule: only `popcre/shared-db` requires an AI review. No other
repository's PR, merge, or task waits for one; a task-class gate that still
names a review outside shared-db is stale and does not apply.

## 2026-10-21 — ai-pr-wait defaults to 60 minutes; no new wait tooling

Verbatim, from Albert's chat: "add NO new tooling"; the waiter default was
raised to 60 minutes on purpose and runs in the background.

Current rule: `bin/ai-pr-wait` keeps its 60-minute default deadline and is run
in the background; the explicit `--timeout-minutes` flag is optional. This
supersedes the #1183 child 3 requirement that every `ai-pr-wait` call name an
explicit deadline. A lone `sleep` is legitimate; sleep-in-a-loop shapes are
refused by the pr-poll-guard hook, not by a blanket permission deny (#1962).

## 2026-10-21 — reviewed install authorized for the edge-dev repair release

Verbatim, from Albert's chat: "yes" (after: "The reviewer says we can finish
with one extra safety blessing. That is only for putting the software on this
machine. It does not break your earlier rule about reviews for our fixes.").

Current rule: the one-time reviewed install of the merged edge-dev repair
release (plan `plan_edge-dev-reviewer-repair-no-review.md` step 7) is
authorized. That reviewed install is an install-time safety authorization,
not a merge gate on the repair PRs. The earlier "only shared-db requires an
AI review" rule still governs PR merges everywhere else.

## 2026-10-23 — no PR reviews by Albert; AI merges; DesignFlow merges on sandbox-albert

Verbatim, from Albert's chat: "i don't review pull requests, you must merge
everything", then refined the same day: "merge to sandbox-albert, not develop.
open a PR to develop".

Current rule: Albert never reviews or merges pull requests; the AI does every
merge. For the DesignFlow repos the AI's merge target is the user sandbox
branch (`sandbox-albert` / `albert-2sandbox`) — pushing it auto-deploys the
sandbox (alsand) — and the AI opens the PR from that branch to `develop`
without merging it. This supersedes the earlier "DesignFlow goes from Albert's
sandbox branch to develop, never self-merged" insofar as it waited on Albert:
nothing waits on him; the develop PR simply stays open.
