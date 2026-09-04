# Shared DB orchestrator operating manual

## Contents

1. Startup recovery
2. Author locks
3. Preview and merge locks
4. Release and recovery
5. Review and production
6. Dynamic queues and automatic refill
7. External review rotation
8. Operational blocker recovery

## Startup recovery

Fail closed if GitHub cannot be read. First distinguish a real GitHub outage or
login failure from the known Windows Codex profile failure. If `gh config get
git_protocol` reports `GitHub CLI\\config.yml: Access is denied`, say exactly
that the restricted Codex task profile cannot read the local GitHub settings.
Repair it with `pwsh -NoProfile -File
C:\repos\ai-devops\bin\repair-codex-github-cli-access.ps1`, then repeat the
same command. Do not call GitHub unavailable and do not widen the task to full
filesystem access. The repair grants read-only access to that one settings
folder; GitHub credentials remain in Windows Credential Manager.

Confirm the sole open orchestrator marker,
then rebuild state from current `main`, open `db-work` and `db-claim` issues,
open pull requests, GitHub coordination refs and local worktrees. Documents and
local scratch registers are never authority.

Run the coordination audit before dispatch:

```bash
node scripts/manage-migration-author-lanes.mjs --audit
```

Audit must report malformed or orphaned records while still showing readable
records. Do not allocate while any malformed claim or lock exists.

## Author locks

Albert's 2026-08-14 ruling allowed no more than three unrelated migration
authors; he raised it to five on 2026-08-25. The manager acquires GitHub-backed
object locks and one of `MAX_AUTHOR_LANES` renewable active-author slots across all
computers. Read the constant in
`scripts/manage-migration-author-lanes.mjs` rather than trusting a number
written in prose. The cap is throughput only: isolation comes from the exact
object lock, the acquisition mutex, the permanent version reservation, and the
single-holder preview/merge/production refs, and preview, merge and production
stay serial at any cap. The readable GitHub issue mirrors the lock; it does
not create the lock.

```bash
node scripts/manage-migration-author-lanes.mjs --claim \
  --task "<issue and outcome>" --owner "<agent/session>" \
  --branch "<branch>" --worktree "<absolute isolated worktree>" \
  --objects "<every exact normalized database object>"
```

The manager must include open draft and ready pull requests, paginate all GitHub
reads, reject unreadable input, reserve a permanent unique migration version and
return success only after lock read-back. Older claims protect their objects and
versions until adopted or explicitly released. A lease expiry is a warning and
releases neither object protection nor active-author capacity.

When a durable external blocker stops a clean worktree and the claim holds no
preview, merge, or production stage, relinquish only capacity:

```bash
node scripts/manage-migration-author-lanes.mjs --relinquish-author-lease \
  --claim <claim> --owner <owner> --blocked-on issue:#<blocker>
```

The protected claim remains in every collision calculation. After the blocker
clears, resume through the guarded command; it renews the clock lease and
rechecks active capacity, every collision, and the permanent version reservation:

```bash
node scripts/manage-migration-author-lanes.mjs --resume-author-lease \
  --claim <claim> --owner <owner> --lease-hours <hours>
```

Do not create migration files before acquisition succeeds. Do not choose a
version manually. Do not edit fenced claim blocks.

## Dynamic queues and automatic refill

Every open `db-work` issue must carry this machine-readable block:

````text
```db-work-scope
status: ready
work_type: structural
route: shared-db-orchestrator
priority: 100
depends_on:
objects:
  - table schema.name
````
```

Allowed statuses are `ready`, `blocked`, and `owner-decision`. Allowed work types
are `structural`, `curated-master-data`, `application-data`, `source-data`,
`repo-maintenance`, `documentation`, and `security-settings`. Routes are explicit
and have no default: `shared-db-orchestrator`, `curated-master-data-governance`,
`application-session`, `source-data-session`, `owner-only`, or `repo-maintenance`.

Only `ready + structural + shared-db-orchestrator` is eligible for an author lane.
It must use exact normalized objects, including every whole-body function or
trigger the implementation replaces. Non-structural work must not claim database
objects. Outside-sourced writes into curated `core.*` Master Data keep the
`curated-master-data-governance` route and never consume an author lane. Higher
priority runs first. Open dependencies make otherwise ready structural work wait.

Run `node scripts/manage-migration-author-lanes.mjs --queue-audit` at startup,
after every merge, and immediately after every claim release. Exact-overlap
components form serial queues; unrelated components fill the available lanes.
Claims and permanent version reservations protect future work independently of
active-author capacity. A relinquished claim is not an active author but still
blocks overlap. Report a lane as working only when current worker evidence exists.
When any author slot frees, run a live queue audit immediately, close stale issues
whose outcome is already delivered, and dispatch the next genuinely eligible
issue in an isolated worktree. Keep explicit successor queues, but say plainly
when the audit proves no eligible successor exists. Do not ask Albert to approve
dispatch.

An empty lane is justified only by a complete audit with no eligible candidate.
Unclassified or malformed issues make that proof impossible and the command
fails. Blocked work consumes no active-author slot only after the guarded
relinquishment above; its claim remains protected. Owner-decision and every
non-structural work type are reported but never consume a lane. `needs-albert` is not a route: after an answer, change
status only and preserve work type and route. Preview and merge remain globally serialized. An
author waiting for those stages keeps doing safe local work or prepares the next
issue without creating an overlapping migration.

## Operational blocker recovery

An orchestrator must never sit silently idle when blocked. The blocker repair is
part of orchestration even when its implementation is repo maintenance,
documentation, tooling, reviewer infrastructure, or another repository. Start a
separate appropriately scoped task immediately; never absorb non-structural work
into the orchestrator context. Continue independent structural work, disclose
the blocker and business consequence immediately, and follow the repair task
until the original capability is restored.

If Albert's authority is required, record it immediately in plain business
language with one exact request and the consequence of waiting. Never silently
park an owner decision. Reviewer, tooling, allocator, and rate-limit failures are
urgent operational blockers: preserve capability, use bounded API calls, read
and report the provider reset time in Eastern Time, and do not repeatedly invoke
a path already known to be unsafe. The reviewer-allocator redesign blocker is
[u2giants/shared-db#1767](https://github.com/u2giants/shared-db/issues/1767).

### Close what you supersede, in the same turn

Opening a new HANDOVER/tracker issue that restates or carries forward the scope
of an older open issue is normal — but the old issue must be closed in that same
session, with a one-line "superseded by #NNNN" comment, not left for a future
triage pass. This is not optional housekeeping: a 2026-08-18 audit of this
repo's `db-work` queue found ~90 open issues, of which only one was genuinely
live structural work — the rest were stale HANDOVER notes nobody had closed.
Before opening a new issue that continues or restates prior scope, check whether
an older issue already covers it; if so, close the older one instead of leaving
both open. When you file a HANDOVER note as a status record rather than a live
ask, say so explicitly in the issue body so a future triage pass can tell the
difference between "still needed" and "recorded for the log."

Every successor issue must write this block from scratch after classifying its
own requested work. It must not copy the predecessor's `work_type`, `route`, or
`objects`. A structural predecessor does not make an offline-analysis,
application-data, source-data, documentation, or repository-maintenance
successor structural. Record the predecessor under ordinary issue context only;
it is never routing evidence.

When a successor is misrouted, stop before dispatch, preserve private artifacts
in their approved private repository, and hand off to the route named in its own
scope block. Never paste a private artifact into a public shared-db issue.

## Phase 2 preview and reviewer lifecycle

Keep object protection separate from active-author capacity. A dependency wait creates no successful workflow evidence. Immediately before each manual preview run, resolve the live marker, run `node scripts/manage-migration-author-lanes.mjs --prepare-preview-dispatch <issue>`, rerun the read-only selector/fresh-ledger check, and dispatch only the matching instruction. Historical recovery uses `mode=apply` only; its dry-run applies nothing and proves nothing. Repair only a v2-bound stale wrong digest with `--repair-preview-ready <ready-id> --issue <n>`; a corrupt current digest needs an owner decision and no mutation. Reviewer reservations use canonical provider/wrapper execution keys and durable ordered waits.

## Preview and merge locks

Author permission never grants preview or merge permission. Acquire one exclusive
GitHub-backed stage lock bound to the exact pull request and head commit. Only one
preview and one merge operation may exist, and production blocks merge.

Before either stage, fetch `origin/main`, update the branch from the newest main,
and rerun version, object-collision, SQL and contract checks. Release the stage
lock explicitly after the operation. Required CI must connect every migration
file and parsed object to the branch-bound author lock and permanent version.

Never mechanically merge competing full-body `CREATE OR REPLACE` changes.
Re-derive the later body from the newly merged main.

## External review rotation

After an issue reaches its exact final head, run:

```bash
node scripts/manage-migration-author-lanes.mjs --assign-reviewer \
  --issue <issue> --pr <pr> --head-sha <exact-head>
```

The GitHub-backed cursor rotates Grok 4.6, GLM 5.3, Kimi K3, Muse Spark 1.3
Contributor, and Gemini 3.8 Flash, then repeats across machines and restarts.
Gemini is eligible only where `ai-review-preflight status gemini` currently
reports `available`; otherwise the selector skips it. Retrying the same
issue/PR/head returns the same assignment. Use only the returned wrapper:
`ai-grok-review`, `ai-glm`, `ai-kimi`, `ai-muse`, `ai-gemini`, or — for the
overflow provider below — `ai-codex-review`. Never override its model or
reasoning pin, and never call `agy` directly.

The five rotation wrappers are **persistent**: they hold named sessions, so the
same session can be reused for rebuttals. `ai-codex-review` is **not**. It
exposes five one-shot modes only — `plan-review`, `diff-review`,
`security-review`, `visual-review`, `final-check` — with no session, resume, or
continuation of any kind, and `bin/ai-review` whitelists exactly those five.

**Codex is overflow, not rotation.** `codex-gpt-5.6-sol` is assigned only when
every rotation provider is already holding live review work in shared-db, or
when all of them have already failed on the exact head. It never takes an
ordinary turn. The busy probe fails open, so an unreadable GitHub keeps the
ordinary rotation rather than diverting reviews to a provider that costs real
money per run.

**A Codex verdict cannot be debated, and that constrains when to spend one.**
Because the wrapper is one-shot, the rebuttal rule below has no compliant path
for Codex: there is no named session to reuse and nothing to continue. Do not
invent one, and do not treat a fresh one-shot run as a continuation of an
earlier verdict — it is a new review of whatever the repository looks like now.

So when a Codex overflow verdict is disputed on the merits, the debate moves to
a persistent reviewer as soon as one frees up, and that reviewer reviews the
exact head from scratch rather than arbitrating a transcript it never saw. A
Codex `REVISE` whose findings the author accepts needs no debate at all; fix the
code, and re-review at the new exact head under the ordinary rotation.

Prefer waiting for a free rotation provider over spending an overflow review on
work you expect to argue about. Overflow exists to keep the author lanes moving
when every eligible reviewer is genuinely busy, not to review contentious work.

**The retired `glm-5.2` label receives no new work** until an explicit owner
instruction restores it. Qwen 3.8 Max is no longer retired (owner instruction,
2026-09-04); it is gated only by its own preflight qualification. Historical
assignments, failures, and replacement evidence stay readable and must be
recovered through `scripts/manage-migration-author-lanes.mjs`, never
hand-edited.

**A Grok review running in another repository never blocks one here.**
`ai-grok-review`'s locking is scoped to work, not to the reviewer: whatever it
serializes, it does not serialize across repositories, so five repositories with
work can run five Grok reviews at once. Never skip Grok here because Grok is
busy elsewhere, and never read a busy Grok as a Grok outage. What it serializes
*within* one repository changed in `ai-grok-review` 1.1.0 — check
`ai-grok-review doctor` and `skills/shared/grok-cli/SKILL.md` for the installed
wrapper's exact rule instead of assuming either the old repository-wide lock or
none at all.

Require the reviewer to re-read the current exact head and return `APPROVE` or
`REVISE` with evidence. Independently verify every claim. Reuse the same named
session for rebuttals and relay them with `templates/delegation/debate-turn.md`
— this applies to the five persistent rotation wrappers; see the Codex exception
above.
Stop at evidence-backed agreement or after the initial review plus three
rebuttals. If a material disagreement remains, the merge stays stopped and the
dispute goes to a THIRD independent reviewer, or to an engineer. Do NOT ask
Albert to adjudicate it (owner ruling 2026-08-18): he is not a programmer, and a
technical disagreement between two models is not a judgement he can make. Handing
it to him produces a coin-flip dressed as a decision, recorded as owner
judgement. Never expose secrets or licensed rows.

After every review, append objective evidence to
`C:\repos\ai-devops\models_comparison_grok_kim_glm.md` through an ai-devops PR:
issue/PR, model/version requested and proven, verdict, confirmed and disproved
findings, defects caught, false positives, policy/tool adherence, continuity,
latency, turns, tokens/cache/cost only when reported, and final outcome. Kimi's
headless token/cache/cost/returned-model figures are unavailable and must remain
marked unavailable.

After approval, green checks, preview proof, and guarded merge, dispatch the
production workflow with the exact source PR, review run and digest, preview
apply run and digest, current-main SHA, and ordered allowlist. The workflow runs
`scripts/production_business_risk_gate.py` before and after its approval wait.
It independently reads the merged PR and required checks, verifies both pinned
artifacts, proves the preview ledger change, and conservatively inspects the
current-main SQL. Caller-written booleans and explanatory prose are never
evidence. Automatic production promotion is allowed only when the governed
records prove all five: no permanent data loss/rewrite, no expected downtime,
no material access change, tested credible recovery, and no unresolved material
objection. Ambiguous SQL stops. Ask Albert one plain business-risk question and
never ask him to approve migration numbers, project identifiers, SQL, or other
technical details.

Transition rule: this policy cannot authorize its own rollout.
`config/production-risk-policy-activation.json` starts inactive, so the older
exact approval and production-environment review remain binding. Activation is
a later governed change and must name the merged shared-db #1021 and ai-devops
#24 commits, record matching canonical and installed skill hashes, and pin the
forward-test proof hash. The gate re-reads both PRs and all hashes before it can
use the automatic path. A boolean such as `active: true`, an explanation, or a
caller assertion without the complete exact schema fails closed.

## Release and recovery

Release is explicit and owner-checked. Before deleting any GitHub ref, verify it
still points to the expected immutable ownership record. A changed owner or an
ambiguous network result stops cleanup. Never retry a delete without reading the
ref again.

Expired work remains protective until safe cleanup proves the branch, worktree
and pull request are finished. Close the mirror issue only after its temporary
author and object refs are released. Never delete the permanent version ref.

If a session dies mid-acquisition, audit the partial refs and use the manager's
owner-verified recovery command. Never delete refs by hand.

## Review and production

Require independent review with no unresolved Critical or High finding. Merge
one pull request at a time, close its claim, update the next branch from newly
merged main and repeat.

Production is separate and serialized. Apply the business-risk gate above,
freeze merges for the bounded promotion, verify the exact target before any
write, and verify the exact production result. Read
[incident-ledger.md](incident-ledger.md) when a safety rule appears unnecessary.
