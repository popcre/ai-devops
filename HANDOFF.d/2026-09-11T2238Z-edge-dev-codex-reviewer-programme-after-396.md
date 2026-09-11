---
issue: 159
status: OPEN
owner: codex/159-handoff-after-396
---

# Reviewer programme continuation after #396

## 0. Decisions only the owner can make

None. The remaining #159/#337 work is already authorized. Do not ask Albert to
merge, approve, contact the shared-database orchestrator, change database
structure, reorder #398, or run #166 early.

Already settled — do not re-ask:

- Preserve frozen maintenance round `0c62f3dffce145c4b2768855b912b958`.
- #398 runs last inside #337; #166 runs last inside #159.
- Reviewer work does not enter the shared-database structure lane.
- Preserve every reviewer capability and safety assertion; an unavailable
  provider is not permission to disable or replace it.

If a genuinely new owner-only choice appears, present the entire current list
to Albert in one short message before the first blocked action.

## 1. What this application is

`popcre/ai-devops` is POP Creations' public recovery toolkit for installing and
operating AI reviewers consistently on Windows and Linux. It is not an
application service or database. GitHub `main` is the source of truth;
installation from canonical `C:/repos/ai-devops` is deployment.

Reviewer programme #337 is a child of throughput programme #159. It must deliver
exact-source reviews, truthful terminal outcomes, durable evidence, safe
same-session recovery, bounded waits, installed live proof, and reconciliation
of the frozen private incident round. The separate shared-database throughput
plan is not authorized by this handoff.

## 2. What this session set out to do, and why

Resume the 18:41 UTC handoff and finish #396 from refreshed PR #416 evidence,
including exact-head independent review, CI, merge, canonical installation,
installed live proof, and incident reconciliation. Preserve the database
boundary, maintenance round, and closure order. Then prepare a clean continuation
covering every remaining phase through #159 completion.

## 3. Current state — exact live checkpoint

- #396 is CLOSED. PR #416 exact head
  `ce97c710578e1b693f763e18df7ba3227027bf54` received independent Muse APPROVE.
  PR-head CI `34646058019` and merge-group run `34650896712` passed. It merged as
  `a031c1de77a11bbf16fe5be8699d78dfdc6233e9`.
- Canonical installation and machine-tools doctor passed. Installed live proof
  covered same-profile/model backoff, immutable replay, different-scope
  eligibility, eight concurrent observations, and guarded eligibility after
  expiry with zero provider calls and no credential reads.
- Two affected private incidents are resolved. Incident
  `20260907T213817Z-edge-dev-kimi-805796` is partially resolved because an
  unknown first Kimi call can still hit a genuine five-hour provider limit; its
  remaining work has permanent carry-forward evidence.
- Three frozen candidates were classified. Round
  `0c62f3dffce145c4b2768855b912b958` is still active with all 198 candidates:
  36 incident and 162 unclassified. Only #398 may complete it.
- Public reconciliation PR #443 merged as
  `e7d9b61d4c012ade8028496c7c45d45dfa6786d7`. Its evidence is
  `tests/verification/reviewer-reliability/issue-396-scoped-admission.md`.
- At this handoff refresh, `origin/main` is
  `1470868d319966a44f68dd208382e86111b8b7e1`. Canonical
  `C:/repos/ai-devops` is clean but at `e7d9b61d`; it has not installed the
  later concurrent #393/#397 changes. Re-resolve before landing or installing.
- OPEN: #159, #166, #271, #337, #393, #394, #397, #398. #430 is CLOSED after
  PR #428 merged as `f0c4127ce15d2d539c7206bbc93aed9a3d04d296`.
- Current stacked PR snapshot, which is context rather than merge authority:
  #422 (`13625aa6`, base `main`) is the #397 base; #418 (`03c6c394`), #419
  (`c4987867`), and #424 (`6257622b`) target #422's branch. Refresh every base,
  head, review, and check before acting. PR #344 remains open for older #393
  source-base work; current main contains newer #393 slices, so reconcile the
  issue contract rather than assuming #344 should merge unchanged.
- No database contact, structure change, production mutation, credential read,
  or paid provider call occurred in the #396 live gate.

## 4. What did not work

- Main moved while the #396 closeout branch was being prepared. Committing on
  the earlier main would have produced stale evidence, so current main was
  merged before PR creation and the changed-file list was rechecked.
- One full preflight run had 91 passes and one ten-second timing failure under
  heavy concurrent load. The unchanged targeted case then completed three times
  in 1004, 942, and 854 ms. The assertion was not weakened and the failure was
  recorded as non-reproducing load jitter.
- The first one-second installed expiry observation crossed its time boundary
  before the initial read. A three-second bounded fixture proved backoff before
  expiry and eligibility afterward; no product change was made.
- A patch initially named one stale handoff incorrectly. The patch failed
  atomically; the exact filename was resolved before retrying, so no partial
  edit occurred.
- Earlier Grok reviews ended at their bounded turn limit without verdicts.
  Final Muse exact-head approval was used; no non-verdict was called approval
  and no unchanged paid review was retried.

## 5. Root causes and key findings

- Scoped refusal evidence can prevent repeat paid calls without pretending to
  know provider quota or reset time. Unknown quota remains unknown.
- Admission identity must be profile/model scoped and derived without reading or
  hashing credentials. Replaying identical evidence must not extend its expiry.
- Exact-head approval is invalidated by every head change. PR #416 required a
  final review on `ce97c710`, not any earlier reviewed integration head.
- The designed primary Windows safety-job cancellation is acceptable only when
  its bounded fallback and aggregate/product gates pass on the same PR head.
- #396 changes no downstream interface outside the existing preflight and Kimi
  admission contract. #394/#397 retain their own boundaries; #393/#271 retain
  their own acceptance gates.
- The two stale #161/#167 handoffs named by the predecessor were retired only
  after their landed work, transferred obligations, and unique decisions were
  proven. This new file carries every still-open predecessor obligation, so the
  18:41 UTC predecessor is retired in the same documentation PR.

## 6. Exact next steps

1. Start a fresh current-`origin/main` worktree for one child only. Read
   `AGENTS.md`, `docs/task-router.md`, both root plans, this handoff, the child
   issue, and its verification artifact. Refresh open PRs, exact heads/bases,
   runners, worktrees, canonical installation, and maintenance ownership.
   Gate: the session can name current main, child owner, exact PR topology,
   active CI, installed source, and frozen-round state before editing.
2. Finish #397's base before its stacked consumers. Reconcile #422 against
   current main and its issue contract; preserve retained paid turns, exact
   session identity, no-replay finalization, and truthful incomplete states.
   Then refresh #418/#419/#424 against the landed/current base, separating #394
   terminal diagnostics from #397 recovery. Gate per child: focused and full
   required tests, independent exact-head review, green CI/queue, merge,
   canonical install, live recovery proof, and affected incident reconciliation.
3. Finish #394's remaining provider terminal matrix. Every wrapper must return
   one parseable verdict or stable failure reason; filtered, malformed,
   encoding/start/tool/cancel/turn-limit failures cannot become generic success.
   Gate: governed consumption matches wrapper outcome and installed live proof.
4. Reconcile #393 against current main and current issue acceptance. Its installed
   nine-wrapper source contract is not full closure until the governed live
   comparison matches GitHub's intended base/head/file set and affected
   incidents are reconciled. Gate: exact source identity end-to-end, not a
   generic reviewer APPROVE.
5. Complete #271 only with the original Windows read-only capability preserved:
   intended source read succeeds, source write and out-of-boundary read fail,
   and exact-head report identity matches. If the supported runtime cannot meet
   both halves, retain it as an external blocker rather than weaken sandboxing.
6. Run #398 only after every component child is closed. Resume — never reset —
   round `0c62f3dffce145c4b2768855b912b958`; account for all 198 candidates, run
   the installed nine-provider matrix and bounded recurrence scan, reconcile
   incidents exactly, complete the round once, and close #337. Unknown history
   stays unknown.
7. Continue any remaining #159 obligations, then execute #166 last. Re-resolve
   the live GitHub ruleset before any write, prove required contexts on a
   throwaway PR and merge queue, retain recovery/admin history, then close #159.
8. At the end of every phase, re-read every downstream phase through plan-end
   in both root plans. Report either `no downstream drift` or update the plan
   with every changed assumption, interface, identifier, decision, or evidence
   requirement before starting the next phase.

## 7. Constraints and gotchas

- Canonical checkout is landing/install only. Every write-capable child uses its
  own fresh current-upstream worktree and stages only owned files.
- Work through branch and PR; verify Albert's Git identity before the first
  commit. Never push directly to main or force-push.
- Do not run a full local Windows suite while a GitHub runner is active. Use
  bounded event-aware waits and do independent work during CI.
- Reviewer safety changes require one independent read-only exact-head review.
- Preserve capabilities, assertions, evidence, unknown states, and exact-session
  protections. Do not bypass, disable, retire, or replace a failure to go green.
- The repository is public. Private incidents, raw provider bodies, transcripts,
  credentials, and temporary live evidence remain private.
- No shared-database structure/data work or production/cloud mutation is in
  scope. The reviewer integration boundary does not grant database authority.
- Closure order is fixed: component children, #398/#337, remaining #159, #166,
  then #159. A child completion is never parent completion.

## 8. Access and environment

- Repository: `C:/repos/ai-devops`; GitHub remote
  `https://github.com/popcre/ai-devops`; GitHub CLI is authenticated.
- Git Bash: `C:/Program Files/Git/bin/bash.exe`.
- Canonical installation: `C:/repos/ai-devops`; private incident state is under
  the managed local `.ai/reviewer-issues` area and must not be committed.
- Secrets, only if a later live gate truly needs them, are in 1Password vault
  `vibe_coding`. Load `secrets-to-1password`, serialize access, and expose no
  value in chat, arguments, output, logs, or commits.
- No database credential or shared-database checkout is needed for the next
  reviewer child.

## 9. Open questions and risks

- The stacked PR heads are drift-prone and may already be superseded by main.
  Treat every identifier in section 3 as a checkpoint, not authorization.
- Canonical source trails current main at handoff. Do not install blindly while
  other sessions own reviewer processes; first resolve the exact landed delta
  and active processes.
- #393's old PR #344 may contain superseded or overlapping work. Reconcile its
  current changed files and issue acceptance before choosing merge, replacement,
  or evidence-only closure.
- The remaining Kimi first-call quota risk is real but cannot be eliminated
  without an authoritative non-generating provider capacity interface. #398
  must preserve this limitation rather than manufacture quota/reset evidence.
- No current risk needs Albert's decision. A database/production mutation,
  capability reduction, credential purchase/rotation, or closure-order change
  would be new authority and must be raised as one consolidated list.

## Parallel-agent accounting

### Bacon / `ci_watch`

Watched PR-head and merge-group checks while implementation and reconciliation
continued. Confirmed PR #416's exact landing evidence and merge. Made no edits,
provider calls, installation changes, or database contact. Work is finished.

### Kierkegaard / `install_live_plan`

Independently mapped the safe canonical installation and zero-provider live
acceptance sequence. Its scope/isolation/concurrency/expiry gates were executed
by the coordinator after merge. Made no repository edits or external mutations.
Work is finished.

### Socrates / `closure_doc`

Audited incident disposition, stale-handoff successor conditions, programme
wording, and closure order. Identified the two safely retired #161/#167 files
and the one partially resolved Kimi incident. Made no repository edits or
database contact. Work is finished.

## Handoff self-audit

1. Yes. Sections 1–3 define the toolkit, programme, exact commits/runs, installed
   state, open issues, PR topology, round counts, and database boundary.
2. Yes. Sections 4–5 preserve every material dead end, timing artifact, review
   outcome, scoped-admission finding, and successor-retirement judgment.
3. Yes. Sections 6–9 provide ordered work through plan-end, verification gates,
   constraints, access, risks, exact identifiers, and the mandatory downstream
   re-read rule. Parallel-agent accounting records all delegated contributions.
4. Yes. A line-by-line sweep of sections 1–9 and agent accounting found no
   current owner decision. Section 0 states this explicitly and consolidates all
   settled rulings plus the trigger for any genuinely new authority.

