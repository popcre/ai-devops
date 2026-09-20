# IMPLEMENTATION PLAN — TypeSafe Jev advisory integrations (2026-09-20)

**Tracking issue:** [#643](https://github.com/popcre/ai-devops/issues/643)

**Decision record and measured background:** [`plan_typesafe-jev-decision-layer.md`](plan_typesafe-jev-decision-layer.md)

**Session handoff:** [`HANDOFF.d/2026-09-20T1412Z-916-codex-jev-integration-plan.md`](HANDOFF.d/2026-09-20T1412Z-916-codex-jev-integration-plan.md)

## STATUS — read this first

| Step | Status | Last updated | Evidence / next gate |
|---|---|---|---|
| 0. Reconfirm policy, data boundary, and current upstream | open | 2026-09-20 | Start at §9.1; no integration code exists yet |
| 1. Consolidate the bounded Jev client and configuration | open | 2026-09-20 | §9.2; existing transport is duplicated in `bin/ai-jev-probe` and `bin/ai-jev-completion-shadow` |
| 2. Build and measure public-issue duplicate/supersession shadow triage | open | 2026-09-20 | §9.3–§9.4; this is the only first pilot |
| 3. Decide keep, tune once, or retire the issue pilot | open | 2026-09-20 | §9.5; requires a checked-in evaluation artifact |
| 4. Evaluate the reviewer-report contradiction sentinel | open | 2026-09-20 | §9.6; cannot start before step 3 passes or Albert explicitly redirects |
| 5. Evaluate additive pre-review risk hints | open | 2026-09-20 | §9.7; reviewer-safety class and independent exact-head review required |
| 6. Evaluate reviewer-maintenance suggestions | open | 2026-09-20 | §9.8; suggestions may never write durable outcomes |
| 7. Evaluate task-class/skill disagreement logging | open | 2026-09-20 | §9.9; public synthetic eval prompts only |
| 8. Reconcile adoption, installation, documentation, and retirement | open | 2026-09-20 | §9.10 and §13 |

**Fresh-session start:** begin at §9.1 in a new current-upstream worktree. Execute
only one numbered outcome per session. Before each later phase, load the
`fresh-session` skill, reread this STATUS table plus that phase, and update this
file in the same session so downstream instructions do not drift.

## 1. The ultimate goal — what we are trying to achieve

Use TypeSafe Jev's extremely low-cost typed decisions to remove repetitive human
or frontier-model sorting work where an error is cheap and reversible, while
leaving every existing safety, review, evidence, ownership, test, database, and
production rule intact.

When this plan is finished, every audited opportunity will have one of two
evidence-backed outcomes: a narrowly scoped advisory integration that proved it
saves time or cost without weakening the baseline, or a recorded retirement that
prevents future sessions from retrying an unhelpful idea. Jev will never approve
work, mutate GitHub, omit required evidence, reduce test or review scope, classify
private/licensed data, or replace deterministic control flow.

**If any step below conflicts with this goal, the goal wins — stop and flag it.**

## 2. What this application is

`popcre/ai-devops` is POP Creations' public recovery and operating toolkit for a
multi-model AI development workflow. It contains Bash and PowerShell commands,
reviewer wrappers, evidence-packet builders, lifecycle records, machine setup,
skills, policy, and offline verification. It is not a hosted application and has
no application database. Installation from this repository is its deployment
mechanism.

GitHub repository: `https://github.com/popcre/ai-devops`. The protected target is
`main`; implementation must use a `codex/` feature branch and pull request. The
canonical checkout is landing-only. Windows development uses Git Bash for Bash
tests; the complete suite is launched through `bin/ai-test-local` after its
collision check.

TypeSafe Jev is an external typed-decision API at
`https://api.typesafe.ai/v1/systemone`. The verified model on 2026-09-20 was
`jev-1.13.0`; `jev-latest` is an alias and must not be used for calibrated
thresholds. It accepts state plus `Choice`, `Score`, or `Noul` questions and
returns probabilities. Typed output prevents free-form prose, not wrong judgment.

## 3. What triggered this work

Albert asked for the latest repository to be reviewed for places where Jev could
help because it costs `$0.042 / 1M` input tokens and output is unmetered. A
whole-repository audit on 2026-09-20 reviewed 807 tracked files and identified
five plausible advisory uses. The strongest new pilot is public-issue
duplicate/supersession triage. Four later candidates touch increasingly sensitive
reviewer or routing paths and therefore require separate proof.

The audit was recorded in §11 of
[`plan_typesafe-jev-decision-layer.md`](plan_typesafe-jev-decision-layer.md).
Existing experiments also established two negative facts that control this plan:

- safe Jev compaction saved effectively nothing and unsafe settings discarded
  later-used information; the plugin stays off;
- completion-honesty shadowing missed the one real unsupported completion at the
  required threshold (`0.73` versus `0.91`); it stays record-only and is not part
  of this implementation.

## 4. Scope — in and out

### In scope

1. One reusable, bounded, pinned Jev transport and validation layer.
2. Public `popcre/ai-devops` issue-pair triage with the closed result set
   `duplicate | supersedes | related | distinct | abstain`.
3. A public-repository-only shadow sentinel for contradictions between reviewer
   analysis and its final verdict.
4. Public-repository-only, additive risk hints in review evidence packets.
5. Non-authoritative suggestions for frozen reviewer-maintenance candidates,
   using only a minimized safe projection.
6. Offline disagreement logging for public synthetic task/skill eval prompts.
7. Per-phase measurement, explicit keep/tune-once/retire decisions, tests,
   documentation, installation only for integrations that pass, and removal of
   failed experimental code.

### NOT in this plan

- Installing or re-evaluating `fast-jev-compaction` before upstream PRs #44,
  #45, and #57 land and the existing replay passes.
- Reviving completion-honesty measurement or lowering its `0.91` bar without a
  new owner decision.
- Sending private repositories, raw transcripts, licensed product descriptions,
  shared-database material, secrets, credentials, or production data to TypeSafe.
- Shared-db intake, structural database decisions, production/infrastructure
  approval, permissions, secret detection, BlockerWatch ownership, GitHub
  backoff, CI selection, source identity, packet integrity, provider health,
  task-stage skipping, required-test selection, or plan retirement decisions.
- Any Jev result that approves a change, closes or edits an issue, creates a
  dependency, transfers ownership, writes a reviewer-maintenance outcome,
  suppresses a file/test/review, or changes the deterministic strongest task
  class.
- A broad rollout to another repository. Every additional repository requires a
  separate data-classification and value decision.

## 5. Current state of the code

Baseline for this plan: `origin/main` commit
`211bc94b4861131ad025927516019285e412302f` on 2026-09-20.

- `bin/ai-jev-probe:1-60` performs one bounded reachability call. It resolves
  `TYPESAFE_API_KEY` through `op run`, validates an empty key, and checks a
  numeric `Noul` result. Its endpoint, model alias, timeouts, request, and secret
  bootstrap are local to that script.
- `bin/ai-jev-completion-shadow:1-104` repeats the secret bootstrap, HTTP call,
  probability extraction, and timeout logic. It is record-only, writes hashes
  rather than message text, and is not installed as a hook.
- `tests/test-ai-jev-scripts.sh:1-30` has six offline guards for empty secrets,
  outage escalation, log privacy, and probe failure. It does not yet cover
  successful typed responses, pinned-model identity, allowlists, size limits,
  malformed responses, or `Choice` validation.
- `config/tool-versions.json:1-39` pins other model names but has no Jev model.
  There is no central Jev policy/config file.
- `plan_ai-devops-work-claims.md:429-435` explicitly leaves truly duplicated
  issue records to human triage. Work Claims prevents two writers on one issue;
  it does not determine whether two issues describe the same work.
- `bin/ai-review-lifecycle:263-304` validates report substance, source digest,
  terminal verdict, and accounting, but does not compare the meaning of the
  analysis with the verdict.
- `bin/ai-review-pool:271-300` validates the literal terminal verdict, head
  binding, and body size before lifecycle finalization. A well-formed report can
  still describe a blocking defect and end `APPROVE`.
- `bin/ai-review-packet:582-713` collects the changed-file lists and writes the
  sealed review manifest. It is the one common place to add non-binding
  `inspect first` hints before the packet hash is created at lines 715-733.
- `tools/reviewer_maintenance.py:251-388` discovers and freezes abnormal
  candidates. `outcome()` at lines 442-474 is deliberately authoritative;
  `audit()` at lines 538-575 refuses missing classifications. No suggestion
  layer exists.
- `config/task-gates.json:24-73` defines deterministic task classes.
  `docs/skill-trigger-eval.md` explains that skill triggering must be measured
  with the actual client and remains stochastic. Jev cannot replace either.
- No code for the five new integrations has been written, committed, installed,
  or deployed. Issue #643 is the umbrella implementation record; a landed phase
  without live proof must still open exactly one phase-specific proof issue.

## 6. Key findings and root cause

1. **The opportunity is triage, not authority.** Jev's price is valuable where
   people repeatedly sort bounded choices. It adds no value to exact rules already
   enforced by code.
2. **Typed output is not truthful output.** The API can still be confidently
   wrong, unavailable, malformed in transit, or affected by adversarial state.
   Code must own all side effects and baseline decisions.
3. **The current Jev code has copied transport.** The probe and completion shadow
   independently implement secret resolution, HTTP timeouts, model selection,
   and response parsing. Adding five more copies would create inconsistent safety
   and make calibration impossible.
4. **Public-only is a functional requirement.** Reviewer reports, prompts,
   maintenance records, and diffs can reveal private repositories even if they
   contain no literal secret. Initial integrations must prove repository identity
   against an explicit allowlist before any external call.
5. **The issue-pair use has the smallest blast radius.** A wrong result can only
   waste a human look because the command cannot mutate GitHub. It directly fills
   the human-triage gap left by Work Claims.
6. **Reviewer contradiction checking has asymmetric value.** It may eventually
   downgrade an apparent approval to `BLOCKED`, but may never create or upgrade an
   approval. Shadow evidence must first show zero false blocks at the chosen bar.
7. **Risk hints must remain additive.** The reviewer still receives the complete
   packet and decides independently. A low Jev risk score cannot omit a file or
   narrow a review.
8. **Maintenance suggestions are not evidence.** The durable maintenance engine
   requires exact source and proof. A suggested category can order human work but
   cannot satisfy `outcome()` or `audit()`.
9. **Prompt routing is a quality diagnostic, not a runtime gate.** Only the actual
   client can prove skill invocation, and task gates derive the enforced class
   from the real change set.

## 7. Approaches considered and REJECTED, and why

1. **Integrate every candidate at once — rejected.** It would combine unrelated
   failure modes, prevent attribution of value, and violate the one-unproven-
   outcome-per-session rule.
2. **Put Jev inside existing deterministic gates — rejected.** Network or model
   judgment would replace exact local evidence and create a new way to pass or
   fail for the wrong reason.
3. **Use `jev-latest` after calibration — rejected.** An alias can move to a new
   model while thresholds and historical measurements silently retain the old
   meaning.
4. **Copy the HTTP/secret code into each integration — rejected.** The two
   existing scripts already drift independently. One shared client is the only
   acceptable new provider surface.
5. **Log raw issue bodies, reports, prompts, or diffs — rejected.** Logs need IDs,
   input digests, model, probabilities, latency, and disposition, not vendor-bound
   source text.
6. **Permit private data behind an environment override — rejected for this
   plan.** A hidden switch is not a data-governance decision. Expanding the
   allowlist requires its own reviewed change.
7. **Auto-close or auto-link duplicate issues — rejected.** The model is not
   evidence of issue identity and issue mutation is unnecessary to realize the
   triage savings.
8. **Use Jev to replace a reviewer or approve a contradictory report — rejected.**
   Independent review must explain findings and bind them to exact source.
9. **Let risk hints reduce review scope — rejected.** The only acceptable value is
   ordering attention inside an otherwise unchanged complete review.
10. **Write suggested maintenance classifications directly — rejected.** It would
    bypass frozen evidence, incident ownership, and completion proof.
11. **Use Jev as the skill-trigger evaluator — rejected.** That measures Jev's
    opinion rather than whether Claude or Codex actually invoked the skill.
12. **Continue compaction or completion enforcement now — rejected by evidence.**
    The safe compaction threshold saved nothing, and the real unsupported
    completion did not clear the confidence bar.

## 8. Design decisions already made (2026-09-20)

### LOCKED — do not relitigate

- Jev is advisory and asymmetric: it may suggest, abstain, or later close a
  reviewer approval path; it can never open a gate or create an approval.
- The public-issue pilot is first. Later phases wait for its measured decision,
  unless Albert explicitly redirects after seeing that artifact.
- All thresholds use a pinned exact model. The API response model must equal the
  configured model or the result is `unavailable`.
- The initial repository allowlist contains only `popcre/ai-devops`, whose live
  GitHub visibility must be `PUBLIC`. Repository identity, not a path or caller
  assertion, controls eligibility.
- External state is capped before network I/O: at most 32,000 UTF-8 bytes of
  state and 64,000 bytes for the complete request. Runs are sequential, bounded,
  and rate-limited; every phase has a maximum item count.
- A timeout, HTTP error, malformed response, unknown label, out-of-range
  probability, model mismatch, low confidence, edited input, or ineligible data
  yields `abstain`/`unavailable` and preserves the existing baseline behavior.
- Raw vendor-bound text is never written to logs or verification artifacts.
  Store only public identifiers, content digests, labels, probabilities, model,
  latency, and disposition.
- Configuration owns model, timeouts, size/call limits, labels, questions, and
  thresholds. Tests may override paths/endpoints through explicit test hooks;
  production callers may not silently replace safety settings.
- Every phase is a separate branch/PR/session and one unproven live outcome. A
  phase that lands without live proof opens exactly one phase-specific proof
  issue before that session ends.
- Reviewer phases are `reviewer-safety` work. They require the repository's
  protected gate, full affected suites, and one read-only exact-head independent
  final review before merge.
- Completion-honesty remains record-only; compaction remains off; shared-db and
  private/licensed data remain excluded.

### OPEN — resolve only with the stated evidence

- The actionable confidence threshold starts at `0.91`; the issue-pair pilot may
  tune it once on a training partition, then must freeze it before holdout. The
  holdout result decides adoption, not preference.
- A later phase may be retired even if the issue pilot passes. Each use case has
  its own precision, coverage, latency, and safety acceptance gate.
- The public issue CLI's final display wording is implementer judgment, provided
  it always shows `advisory`, probabilities, input IDs, and `no GitHub changes
  made`.
- Whether the contradiction sentinel ever changes a verdict is a later owner
  decision after shadow evidence. This plan authorizes evaluation, not promotion.
- Whether installed commands are worth machine-wide deployment is decided only
  after the corresponding pilot passes. Experimental tools run from the
  worktree and are deleted if retired.

## 9. The plan — numbered, ordered steps

### Phase 0 — shared safety foundation

#### 9.1 Reconfirm scope, policy, and data eligibility

Start a current-upstream `codex/` worktree, read `AGENTS.md`, this plan's STATUS,
and the current §11 of `plan_typesafe-jev-decision-layer.md`. Run
`ai-task-gates start --class code` for the shared client and issue pilot. Before
touching reviewer files in later phases, start a new session/worktree and declare
`reviewer-safety` instead.

Use `bin/ai-gh` to verify `popcre/ai-devops` is still public. Record the checked
visibility and current model documentation date in the phase verification
artifact. Do not send any source text during this step.

**You'll know it worked when:** the phase branch is current with `origin/main`,
the task class is recorded, GitHub reports `PUBLIC`, the Jev model/API contract
is rechecked, and no implementation assumption conflicts with current policy.

#### 9.2 Build one bounded Jev client contract

Create `config/jev-decisions.json` with schema version, exact model
`jev-1.13.0`, endpoint, connect/call timeouts, byte limits, per-run call caps,
rate interval, public-repository allowlist, and per-use closed labels/questions/
thresholds. Also add the exact Jev model to `config/tool-versions.json`; one file
is the operational decision policy, while `tool-versions.json` remains the
machine-wide model inventory.

Create `tools/lib/jev-client.sh` as the only code allowed to resolve
`TYPESAFE_API_KEY`, re-exec through `op run`, send HTTP, enforce timeouts and
sizes, validate the response model/schema/probabilities, and return normalized
`Choice`/`Noul` values. Its shell API is fixed:

- `jev_bootstrap "$0" "$@"` runs before a consumer reads stdin; when the key is
  absent it spools stdin to a mode-0600 temporary file, resolves the one managed
  `op://` reference, re-execs the consumer through `op run`, and returns only in
  the keyed child. An empty resolution is nonzero and loud without revealing the
  reference value.
- `jev_request REQUEST_JSON RESPONSE_JSON` accepts regular files, enforces the
  configured byte limits before network I/O, sends one bounded request, and
  returns zero only for HTTP 200 plus the configured exact response model.
- `jev_read_noul RESPONSE_JSON QUESTION_ID` prints one canonical probability in
  `[0,1]`; `jev_read_choice RESPONSE_JSON QUESTION_ID ALLOWED_LABELS_JSON` prints
  canonical JSON containing exactly the allowed labels, probabilities, selected
  label, and confidence. Invalid/missing/extra values are nonzero.
- `jev_cleanup` removes client-created secret/request/response temporaries and
  unsets key material. A trap calls it on normal exit and signals.

The client prints no decision word on failure; consumers alone convert nonzero
to `unavailable`/`abstain`. It may accept an injectable endpoint only when an
explicit offline-test flag is set. It must not print headers, request bodies,
keys, or raw responses on error.

Refactor `bin/ai-jev-probe` and `bin/ai-jev-completion-shadow` to source the
shared client without changing their observable contracts. Keep the completion
tool manual and record-only. Expand `tests/test-ai-jev-scripts.sh` with a local
stub for valid and hostile API responses. Extend
`tests/test-tool-version-pins.sh` to validate `config/jev-decisions.json` and
require its Jev pin to equal `config/tool-versions.json`.

**You'll know it worked when:** both existing commands pass their prior tests,
all transport/secret code has one owner, pinned-model and schema mismatches fail
safe, request limits are enforced before the stub sees traffic, and no raw state
or secret appears in stdout, stderr, or logs.

**Context cut point:** merge Phase 0 only after its code tests and normal review
pass. If live reachability is not proven in that same session, open one Phase-0
proof issue. Start Phase 1 in a fresh session and reread §9.3–§9.5.

### Phase 1 — public-issue duplicate/supersession pilot

#### 9.3 Implement a non-mutating issue-pair shadow command

Add `bin/ai-jev-issue-triage` plus its Windows `.cmd` shim. Inputs are explicit:
`--repo OWNER/REPO --left NUMBER --right NUMBER` or `--input FILE --max N` for a
bounded labeled run. Fetch through `bin/ai-gh` only. Before fetching bodies,
require the repository identity to be in the config allowlist and live visibility
to be `PUBLIC`. Fetch each issue once, keep its ID/title/body/state in memory,
compute a digest, and never call a GitHub mutation command.

Submit a single `Choice` with exactly
`duplicate | left-supersedes-right | right-supersedes-left | related | distinct | abstain`.
Treat a missing option, probability outside `[0,1]`, model mismatch, low
confidence, or edited/re-fetched digest as `abstain`. Display the full
distribution and a plain advisory statement; never print an instruction to
close, transfer, block, or link an issue.

Write the shadow event to
`${XDG_STATE_HOME:-$HOME/.local/state}/ai-devops/jev-shadow/issue-triage.jsonl`
with mode `0600`. Store timestamp, repo, issue numbers, body digests, configured
model, probabilities, latency, threshold, and disposition—never body text.

Add `tests/test-ai-jev-issue-triage.sh` with stubbed `ai-gh` and Jev endpoints.
Do not add the command to `config/machine-tools.tsv` yet; experimental execution
uses the repository path.

**You'll know it worked when:** offline tests prove it cannot target a private or
unallowlisted repo, cannot invoke a mutating GitHub command, abstains on every
invalid/uncertain response, and logs no issue text.

#### 9.4 Build the labeled evaluation and run one bounded live pilot

Create `tests/fixtures/jev/issue-triage-labels.json` with at least 60 public issue
pairs: at least 15 duplicate/supersession positives, at least 30
related/distinct negatives, and at least 10 deliberately ambiguous/adversarial
pairs. Store issue IDs, human label, rationale, and the digest seen when labeled;
do not duplicate full issue bodies in the repository. Split the set before
tuning: 40% tuning, 60% untouched holdout, stratified by label.

Run no more than one tuning pass. Freeze the threshold and question before the
holdout. Save `tests/verification/jev/issue-triage-<UTC>.md` with model, config
digest, label-set digest, per-label confusion counts, actionable precision,
positive recall, abstention, median/p95 latency, request bytes, estimated cost,
and every error by issue-pair ID. The artifact must let a reader recompute each
metric; a bare percentage is not evidence.

Acceptance requires all of the following on holdout:

- zero false `duplicate` or `supersedes` actionable suggestions;
- at least 30% recall across true duplicate/supersession positives;
- every ambiguous/adversarial case either correct or `abstain`;
- no mutation, private-data attempt, raw-text log, timeout over the configured
  bound, or model/schema mismatch accepted as a decision;
- median elapsed time below 2 seconds per pair and recorded estimated cost.

**You'll know it worked when:** the checked-in artifact reproduces the holdout
metrics from the labels and shadow log, and every acceptance condition has a
named passing or failing result.

#### 9.5 Make the issue-pilot decision and stop cleanly

Choose exactly one result in the same PR that records the evaluation:

- **KEEP:** all acceptance conditions pass. Add the command to
  `config/machine-tools.tsv`, installation tests, `docs/deployment.md`, and the
  task router. Before touching those installation/catalog files, redeclare the
  task as `installation`; the stronger class and its owner-request gate apply.
  Install through the repository's supported installer, run one public pair
  live, and record the installed proof.
- **TUNE ONCE:** only a predeclared threshold/question error on the tuning set is
  implicated, not a safety/privacy failure. Change once, freeze, rerun a newly
  held-out set, and then choose KEEP or RETIRE.
- **RETIRE:** any actionable false positive, privacy/safety failure, useless
  coverage, or second miss. Delete the experimental command and config section;
  keep the verification artifact and decision record.

Update this STATUS table and issue #643. Do not begin reviewer phases after a
RETIRE result without Albert explicitly redirecting based on the artifact.

**You'll know it worked when:** the repository contains either a tested,
installed advisory command with live proof or no experimental command plus a
reproducible retirement record—never an indefinite shadow tool.

**Context cut point:** stop. Use `fresh-session` before any reviewer phase.

### Phase 2 — reviewer-report contradiction sentinel

#### 9.6 Shadow semantic contradictions centrally, public repo only

Declare `reviewer-safety`. Add `bin/ai-jev-review-sentinel` as a thin consumer of
the shared client and call it from `bin/ai-review-lifecycle` inside `terminal()`
after report existence/substance checks at `bin/ai-review-lifecycle:288-292` but
before the source digest check and terminal record at lines 293-298. Central
placement covers Claude, Codex, and pool reviewers without provider copies.

The network call must not create a time-of-check/time-of-use gap. Preserve the
pre-call report digest, then revalidate that the report is still the same regular
file and recompute its digest immediately after Jev returns; any change becomes
`BLOCKED` with a deterministic `report-changed-during-sentinel` failure. Keep the
existing source digest calculation after the Jev call so source changes during
latency become the existing `stale-source` block. Use only the post-call report
digest in the terminal record.

Eligibility must derive from the lifecycle state's normalized Git remote and the
public allowlist. For ineligible repos, write no external request and record only
`not-eligible`. Ask separately whether the analysis asserts a blocking defect or
missing required evidence, and whether that assertion contradicts the supplied
verdict. During shadow mode, add a hashed side record under reviewer state and do
not change `verdict`, `failure_class`, lifecycle status, lock release, or
scoreboard accounting.

Build at least 100 labeled public/synthetic reports including direct defects,
hypotheticals, quoted instructions, negated findings, resolved concerns,
`REJECT`, `BLOCKED`, and planted `APPROVE` contradictions. A promotion proposal
requires every planted contradiction caught at the frozen threshold and zero
valid approvals falsely flagged. It also requires a separate owner decision and
an exact-head independent final review. Even after promotion, the only permitted
behavior is `APPROVE -> BLOCKED` with a named failure class; no other verdict can
be upgraded.

Extend `tests/test-ai-review-lifecycle.sh`, each direct reviewer wrapper suite,
and the pool coverage in `tests/test-ai-grok-review.sh`. Add delayed-stub tests
that mutate the report and source during the Jev call and prove both results are
blocked. Add a dedicated sentinel test if that keeps fixtures readable.

**You'll know it worked when:** all providers reach one shadow decision point,
private/unallowlisted reports produce zero network calls, outages preserve the
baseline verdict while recording unavailability, and the evaluation artifact
states whether promotion earned a later owner decision.

**Context cut point:** merge shadow evaluation and stop. Promotion, if approved,
is a separate session, class, PR, exact-head review, and live proof.

### Phase 3 — additive pre-review risk hints

#### 9.7 Add sealed `inspect first` hints without narrowing review

Declare `reviewer-safety`. In `bin/ai-review-packet:582-713`, after changed files
and the patch exist but before the manifest is written and hashed, call a new
`bin/ai-jev-review-hints` only for an allowlisted public repository. Send a
bounded state containing review class, changed-file names, diff summary, and at
most the configured public patch excerpt. Ask independent `Noul` questions for
authentication/authorization, secrets, destructive state, concurrency/races,
and missing evidence.

Write `jev-risk-hints.json` into the packet before `packet.sha256` is generated.
Add a manifest section titled `Advisory inspect-first hints` that lists only
confident positive tags and explicitly says the complete patch, scope, tests,
and required review remain unchanged. If unavailable, include a one-line
`unavailable; full review unchanged` note. The current post-build source digest
check at `bin/ai-review-packet:715-718` remains authoritative.

Run paired public-repository review trials with and without hints on the same
planted cases. Adopt only if median elapsed time or known cost improves by at
least 10%, every planted defect found without hints is still found with hints,
no retained fact/file disappears, and packet identity/integrity tests remain
green. Otherwise remove the integration and retain the negative artifact.

Extend `tests/test-ai-review-packet.sh` for packet sealing, unavailable behavior,
private-repo no-call, hostile filenames, no scope reduction, and digest drift.

**You'll know it worked when:** the hints are sealed but non-authoritative, the
review receives the same complete evidence, and a reproducible paired artifact
passes the 10%/no-regression gate or records retirement.

### Phase 4 — reviewer-maintenance suggestions

#### 9.8 Suggest priorities without touching durable outcomes

Add a `suggest` subcommand to `tools/reviewer_maintenance.py` and route it through
the existing `ai-reviewer-issue maintenance` entry point. It may run only after
`start` freezes a round. Candidate records contain joined digests rather than a
trustworthy repository name, so suggestion code must recover the one matching
event from the frozen source snapshot by `event_sha256`, extract its repository,
normalize the Git remote locally, and verify allowlist membership plus live
GitHub `PUBLIC` visibility before any TypeSafe call. A missing/non-unique event,
unknown remote, GitHub failure, or private/unallowlisted repo yields
`not-eligible` and zero Jev requests.

After eligibility, build a minimized projection from each candidate's already-
validated fields: provider, existing classification, terminal status, failure
class, cancellation/health enums, and whether evidence exists. Do not send
repository paths, report text, event text, SHAs, issue details, or repository
names.

Return one of `incident | expected-refusal | quota-exhaustion |
user-cancellation | application-failure | duplicate-event | in-progress |
evidence-unavailable | uncertain`, with probabilities and an ordering score.
Write suggestions to a separate mode-0600 file under the active maintenance
round. `outcome()`, `record_incident()`, `audit()`, and `complete()` must not read
that file; the human/operator still supplies every classification and evidence
reference.

Extend `tests/reviewer_maintenance_cases.py` to prove suggestions cannot create
outcome files, cannot make `audit()` pass, cannot alter ordering/source digests,
and abstain when minimized fields are insufficient. Measure agreement and time
saved across at least two maintenance rounds before keeping it. Retire if it
does not reduce manual candidate-reading time by 10% or if any suggestion causes
an incorrect durable classification in the controlled trial.

**You'll know it worked when:** suggestions can reorder the display but cannot
change, complete, or resolve a frozen round, and the measured artifact supports
KEEP or RETIRE.

### Phase 5 — offline task/skill disagreement logging

#### 9.9 Add an eval-only semantic disagreement report

Create `tools/jev-route-shadow.py`,
`tests/fixtures/jev/route-shadow.json`, and
`tests/test-jev-route-shadow.py`. The CLI is
`tools/jev-route-shadow.py --manifest FILE --max N --output FILE`. Each manifest
row contains a stable ID, `source_file`, zero-based `case_index`, the closed
candidate-skill list, `expected_task_class`, and `expected_skills`. The tool
loads the `query` from that exact committed
`tools/skill-trigger-eval/*.eval.json` case and verifies its digest; it does not
invent ground truth from the existing `should_trigger` boolean. The new manifest
is the reviewed ground truth for this diagnostic.

It may read only those committed public synthetic prompts. It must never crawl
Codex or Claude transcripts, hook live prompts, or change `ai-task-gates`.

Ask `Choice` questions over the exact configured task-class enum and a bounded
candidate skill list. Write a report containing fixture IDs, digests,
probabilities, expected labels, and disagreements—never the prompt text. Treat
the report as a way to find weak eval wording or missing router coverage. The
actual-client skill-trigger runner and real change-set task class remain the
only acceptance evidence.

Keep only if the report finds reproducible router/eval defects that the existing
actual-client suite confirms and the triage time saved exceeds its maintenance
cost. Otherwise retire the tool and retain the negative result.

**You'll know it worked when:** a Jev disagreement cannot change an enforced
class or claim a skill invoked, and every retained finding is independently
confirmed by the existing real evaluator.

### Phase 6 — reconciliation and closeout

#### 9.10 Consolidate what earned a permanent home

For every KEEP result, update the relevant STATUS row with a commit/verification
artifact. Before adding supported user-facing commands to
`config/machine-tools.tsv` or invoking `bin/install-machine-tools.ps1`, redeclare
the task as `installation` and satisfy that class's owner-request gate. Then run
`ai-machine-tools-doctor`. Update `docs/deployment.md`, the AGENTS router, and
the current Jev decision record. Do not create another provider wrapper, plan,
or config home.

For every RETIRE result, remove experimental code/config/install entries in the
same phase PR while preserving the verification artifact and rationale. Once all
rows are complete or retired, fold the durable decisions back into
`plan_typesafe-jev-decision-layer.md`, close issue #643, and delete this handoff
under the successor rule. Keep this plan as the decision record unless repository
policy explicitly retires completed plans.

**You'll know it worked when:** `origin/main` has one coherent Jev client, only
evidence-backed integrations remain, installed state matches the repo, all
STATUS rows cite artifacts, issue #643 is closed, and no open obligation exists
only in chat.

## Adversarial cases — required trust-boundary coverage

| External input | Hostile or failure case | Required test |
|---|---|---|
| 1Password reference/key | Missing item, empty field, key accidentally echoed | Extend `tests/test-ai-jev-scripts.sh`: empty resolves nonzero; stdout/stderr/log contain no key |
| API connection | DNS failure, timeout, HTTP 4xx/5xx, truncated JSON | Client stub tests: bounded exit; disposition `unavailable`; baseline result unchanged |
| API model/schema | Alias moved, wrong model, missing answer, unknown label, NaN/string/bool/out-of-range probability | Client fixture matrix rejects every case before a decision is exposed |
| Request state | More than 32,000 bytes, full request over 64,000 bytes, invalid UTF-8/control characters | Client size/encoding tests reject locally and assert zero stub requests |
| Issue repository | Private/internal/unallowlisted repo, forged local path, renamed remote | Issue-triage tests assert live `PUBLIC` + exact allowlist identity and zero external call otherwise |
| Issue pair | Edited between label/fetch, closed issue, self-pair, missing issue, ambiguous relation | Issue tests require digest match, reject self/missing, and return `abstain` for ambiguity |
| Issue body | Prompt injection asking for closure, secrets, shell/GitHub actions, or label spoofing | Fixture asserts closed label parsing only and mutation-command stub is never invoked |
| Reviewer report | Analysis names a blocker but verdict says `APPROVE` | Sentinel fixture must confidently flag the planted contradiction in shadow |
| Reviewer report | Hypothetical/quoted/negated defect or a concern explicitly resolved before `APPROVE` | Sentinel holdout must not produce an actionable flag |
| Reviewer report | Private repo or report over limit | Lifecycle test asserts zero network and unchanged deterministic verdict |
| Reviewer finalization | Report or source changes while the delayed Jev stub is running | Lifecycle tests require `report-changed-during-sentinel` or existing `stale-source`; no terminal approval |
| Review packet | Malicious filename/text that looks like instructions; source changes during Jev latency | Packet tests preserve literal JSON encoding and existing after-build digest refusal |
| Risk hints | Jev says no risk, returns only some categories, or is unavailable | Packet tests prove every file/test/scope item remains and full review still runs |
| Maintenance candidate | Missing evidence, duplicate, active invocation, private path in source record | Maintenance tests return `uncertain`/safe projection and create no outcome file |
| Maintenance repository | Frozen event is missing/non-unique or resolves to private, unknown, or unallowlisted identity | Maintenance tests assert `not-eligible` and zero TypeSafe calls |
| Route prompt | Skill name bait, mixed intent, strongest protected class omitted | Eval test logs disagreement only; actual class/skill test result remains authoritative |
| Shadow log | Newlines, huge identifiers, raw source accidentally included | Tests parse every JSONL line, enforce mode `0600`, and grep for forbidden raw fixtures |

## 10. Tests required

### Phase-specific focused tests

- `bash tests/test-ai-jev-scripts.sh` — shared secret/transport, successful and
  malformed `Noul`/`Choice`, pinned model, timeouts, limits, and log privacy.
- `bash tests/test-tool-version-pins.sh` — Jev model pin and operational config
  must exist and match exactly.
- `bash tests/test-ai-jev-issue-triage.sh` — public allowlist, bounded `ai-gh`
  reads, no mutation, closed labels, abstention, digest and JSONL behavior.
- `bash tests/test-ai-review-lifecycle.sh` plus direct reviewer and pool suites —
  central shadow invocation, no private calls, baseline verdict preservation,
  planted contradiction fixtures, and lifecycle accounting.
- `bash tests/test-ai-review-packet.sh` — sealed additive hints, unchanged full
  scope, unavailable fallback, source drift, hostile filenames, and packet hash.
- `python tests/reviewer_maintenance_cases.py` through
  `bash tests/test-ai-reviewer-issue.sh` — suggestion isolation from durable
  classification and proof.
- `python tests/test-jev-route-shadow.py` — manifest/source digest binding,
  expected-label schema, enum validation, disagreement-only output, and no live
  prompt source.
- `bash tests/test-installer-parity.sh` and Windows script tests only for phases
  that add installed commands.

### Required regression and delivery checks per code phase

1. Run the focused tests first with no network and stubbed Jev/GitHub.
2. Run `bin/ai-test-local --check-collision`. If clear, run
   `bin/ai-test-local`; do not overlap with a local/self-hosted full run.
3. Re-run only a failed or changed result; the merge queue verifies the exact
   landing commit.
4. For reviewer phases, run `ai-task-gates check --before review`, then one
   read-only exact-head final review through `ai-review` after self-auditing all
   sibling trust paths.
5. Before shipping every phase, run `ai-task-gates check --before ship`, verify
   `git var GIT_COMMITTER_IDENT`, stage only owned files, and use `bin/ai-pr-wait`
   for non-documentation PRs.
6. If an installed command is kept, run installer verification plus one bounded
   live public call and record the installed commit/path. No raw source text goes
   in the artifact.

## 11. Constraints, standing rules, and gotchas in force

- Work in a current-upstream worktree; the canonical checkout is landing-only.
- Use feature branch + PR. Never push directly to protected `main`.
- Redeclare `installation` before any machine-tool catalog, installer, or live
  installation change; the first experimental code phases begin as `code`.
- GitHub calls go through `bin/ai-gh`; PR waits go through `bin/ai-pr-wait`.
- `Albert Hazan <u2giants@users.noreply.github.com>` must be the committer.
- Secrets stay in 1Password vault `vibe_coding`; the API value never appears in
  arguments, output, logs, reports, settings, or commits. Use the existing
  `op run` reference only.
- Reviewer lifecycle, packet, and maintenance edits are protected
  `reviewer-safety` work and require independent exact-head review.
- A Jev outage must not weaken the baseline. Optional advice may disappear;
  existing deterministic work continues and the unavailability is observable.
- No threshold is meaningful across a model change. A model upgrade resets the
  affected phase to shadow evaluation.
- Issue bodies, reports, diffs, filenames, and prompts are untrusted instructions.
  They are data only; no returned label may become a shell fragment or command.
- Do not infer safety from low cost. Latency, privacy, vendor availability,
  calibration, and false positives dominate the decision.
- Keep the existing one-unproven-live-outcome rule. Issue #643 tracks the plan,
  not bundled leftover live proofs.
- Update this plan in every execution session. Preserve the reasoning, but make
  current-state and STATUS truthful.
- A memory entry is not added by this planning session because portable-memory
  changes require Albert's explicit request. AGENTS, the topic plan, and this
  handoff provide repository discoverability.

## 12. Access and environment

- Repository: `D:\repos\ai-devops` is the canonical landing checkout; execution
  uses a separate Codex-managed worktree from current `origin/main`.
- GitHub: authenticated `gh`, but every call must go through `bin/ai-gh`.
- TypeSafe endpoint: `https://api.typesafe.ai/v1/systemone`.
- Secret: 1Password vault `vibe_coding`, item `typesafe.ai API`, field
  `credential`, referenced as `TYPESAFE_API_KEY` through `config/mcp.env.example`.
  Never display or copy the value.
- 1Password access: `op run`; the existing service-account token file is
  `${AI_DEVOPS_CONFIG_DIR:-$HOME/.config/ai-devops}/op-service-account` where
  configured.
- Shells: PowerShell 7 for Windows orchestration; Git Bash for Bash scripts and
  tests. Required local utilities are `curl`, `jq`, `python3`, `git`, and `op`.
- Shadow state: `${XDG_STATE_HOME:-$HOME/.local/state}/ai-devops/jev-shadow/`,
  mode `0600`, outside the repository.
- There is no application URL or deployment. Installation is the live state and
  is verified through repository installers plus `ai-machine-tools-doctor`.

## 13. Definition of done + risks and open questions

### Definition of done

This plan is done only when:

1. Every STATUS row is `complete` or `retired` and cites a file, commit, CI run,
   exact command, or phase-specific proof issue for a single landed outcome.
2. One shared pinned Jev client owns secret resolution, limits, transport,
   validation, and normalized typed answers.
3. The public issue pilot has a reproducible holdout artifact and KEEP/RETIRE
   decision; no indefinite experiment remains.
4. Each later candidate has its own measured KEEP/RETIRE result. A skipped phase
   is not done unless its evidence-backed retirement is recorded.
5. No Jev path can approve, mutate GitHub, write durable maintenance outcomes,
   reduce review/test scope, change task class, or send ineligible data.
6. Focused and full required tests pass, reviewer-safety phases have exact-head
   independent review, PRs merge through repository policy, and intended commits
   are verified on `origin/main`.
7. Every kept user-facing command is installed through supported tooling and has
   one bounded live public proof. Every rejected experiment is removed.
8. Documentation and the original Jev decision record reflect the final state;
   issue #643 is closed; the handoff is retired by the finishing session.

### Risks and mitigations

- **Vendor/model drift:** exact pin and response-model check; any upgrade resets
  calibration.
- **Confident semantic error:** precision-first holdouts, mandatory abstention,
  advisory/asymmetric behavior, and code-owned side effects.
- **Private-data disclosure:** explicit public allowlist plus live visibility and
  normalized remote identity before network I/O.
- **Prompt injection:** closed schemas, JSON construction, no execution of model
  output, and adversarial fixtures.
- **New network dependency:** bounded timeout; optional advice failure preserves
  the deterministic baseline and is logged.
- **Reviewer latency/race expansion:** strict call deadline, existing source
  digest recheck, and adoption only with measured net improvement.
- **False sense of cost savings:** artifacts record latency, request bytes,
  coverage, errors, and estimated cost; price alone cannot produce KEEP.
- **Stale plan:** every implementing session updates STATUS/current state in the
  same PR and rereads downstream phases at context cuts.

### Open questions and how they are decided

- **Does issue triage earn a permanent command?** §9.4 holdout and §9.5 decide.
- **Should a contradiction flag ever block an approval?** Only after §9.6 passes
  with zero false flags and Albert makes the separate promotion decision.
- **Do risk hints actually save reviewer time?** The paired ≥10%/no-regression
  gate in §9.7 decides.
- **Is minimized maintenance state informative enough?** Two measured rounds in
  §9.8 decide; otherwise retire.
- **Does route disagreement reveal real defects?** Only independently confirmed
  actual-client/task-gate findings in §9.9 count.

### Rollback

Every integration is additive. Disable its config mode, remove its caller and
experimental files, reinstall from the prior good `origin/main`, and preserve the
negative verification artifact. No data migration, database rollback, GitHub
repair, or production action is required because Jev owns no authoritative
state.

## Mandatory self-audit — final answers

1. **Could a brand-new AI session execute this perfectly without asking a
   question? Yes.** §§2–6 define the application, trigger, exact baseline, and
   evidence; §§8–12 give locked decisions, concrete files/functions, order,
   context cuts, commands, data boundaries, and verification gates. §13 states
   how every open decision is resolved.
2. **Does the plan carry the background, nuance, and rejected approaches? Yes.**
   §§3, 6, and 7 preserve the audit findings, failed compaction/completion work,
   copied-client root cause, privacy boundary, and every rejected unsafe use.
   No gap remained after the checklist pass.
3. **Is the ultimate goal clear enough for a correct judgment if a step is
   wrong? Yes.** §1 makes measured labor/cost reduction subordinate to unchanged
   safety and requires KEEP or RETIRE evidence. §§8 and 13 convert that goal into
   non-negotiable asymmetry, adoption gates, rollback, and completion proof.

All 13 required sections are present. The adversarial table covers every external
input with a named test; locked/open decisions are labeled; secrets are referenced
only by location; plan/handoff links are bidirectional; and delivery includes
commit, push, CI, merge, installation, and live verification.
