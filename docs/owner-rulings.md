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
Scope (clarified 2026-10-22, #1962): this ruling covers PR and code-review
gates only; it does not repeal the standing safety rule that the assigned AI
reviewer's explicit APPROVE gates every technical production action, so
`ai-task-gates check --before production` stays enforced in every repository.

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

## 2026-10-27 — on-machine secret exposure: redact, do not rotate

Verbatim, from Albert's chat: "if the keys were not published outside of
this computer then no need to rotate, just redact them from where they
appeared."

Current rule: when a secret's only exposure is the local AI session
transcript on this machine (no GitHub, logs, or third-party systems received
the value), the remedy is in-place redaction of every occurrence on this
machine, not credential rotation. Applied 2026-10-27 to the PopDAM session
transcript on hetz (one Supabase sb_secret value; 7 occurrences redacted,
zero remaining); rotation plan `plan_credential_rotation_20261027.md` in
u2giants/popdam3 was cancelled by this ruling (issue #551).

## 2026-10-29 — reviewer system rebuilt simply, four reviewers

Verbatim, from Albert's chat: "rebuild it simply, but with 4 reviewers, not
2."

Current rule: the reviewer system is rebuilt per
`plan_simple-reviewer-rebuild.md` (issue #2041). The reviewers are Muse, GLM,
DeepSeek and StepFun. Reviews run in CI on the PR head, not from chat
sessions, and carry no lease, budget, allowlist or provenance layer. Patching
the old path (#1993, #2000) is dropped. The observation-week freeze lifts at
the plan's step 4.

## 2026-10-29 (afternoon) — review is advisory, never a gate

Verbatim, from Albert's chat: "this past week where i didn't have to deal
with reviewer errors was the first time in 10 months where things actually
got done ... you need to find a way to cut more reviewer 'fat'."

Current rule: review is advisory and never blocks a merge. One reviewer per
PR rotates through Muse, GLM, DeepSeek and StepFun. It runs once per PR in CI
and skips docs-only PRs. Every other reviewer gate, hook, instruction and job
is removed per the REVISION section of `plan_simple-reviewer-rebuild.md`.
Production keeps owner authorization only. This supersedes earlier rulings
that require an exact-head APPROVE.

## 2026-10-29 (evening) — production promotion is automatic, never the owner's

Verbatim, from Albert's chat: "the owner (me) is non-technical and not
qualified to authorize promotion to production. That has to be done
automatically by the ai agent."

Current rule:
- No step anywhere may wait for Albert to authorize production.
- An AI agent promotes merged shared-db changes to production automatically once the preview rehearsal and tests pass and the advisory review has no open real findings (any `review-finding` issue on that change is resolved).
- This is the only point where a review result is checked. Merging still never waits.

## 2026-10-29 (night) — freeze off; reviewers preferred, never required

Verbatim, Albert's chat: "take off the freeze and make reviewers preferred but
not required. now that's unblocked".

Current rule (issue #2041):
- The observation-week freeze ends now. The window file is removed on every
  host; nothing is frozen and no merge is labelled `unreviewed-week`.
- AI reviews keep running as advice and are preferred, but no ruleset, branch
  protection, gate or instruction may require an AI-review check or an
  APPROVE verdict to merge, deploy, install, or touch shared-db, production or
  infrastructure. Test checks and non-review production safety gates stay.
- This supersedes every earlier ruling that required an exact-head APPROVE.

## 2026-10-30 — lean required checks (issue #2172)

Verbatim, Albert's chat: "can we bypass/eliminate some or all of the automatic
checks?" then "yes. and do it in a permanent way in the ai-devops repo so that
it hits all apps/harnesses on all machines". Also ordered killed permanently:
the shared-db rule "one licensor per change" for curated Master Data loads.

Current rule:
- A merge-blocking check must directly prevent production-data damage or a
  secret leak. Process, ownership, claim, lease, evidence-pair, handoff,
  hygiene and broad test-suite checks are advisory or removed.
- A required check that hangs or flakes is dropped from the required set at
  once, then repaired.
- Curated Master Data loads may cover any number of licensors in one change.
