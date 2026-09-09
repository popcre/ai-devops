# Reviewer issue recording

For the current end-to-end repair and cache/session qualification work, read
the STATUS in [the reviewer reliability and efficiency plan](../plan_reviewer-reliability-and-efficiency.md)
first. It reuses the completed checkpoint/diagnostic tooling and existing provider
work; it does not replace this incident lifecycle or authorize closing unexplained failures.

## Repair-round checkpoints

Begin a maintenance sweep with `ai-reviewer-issue maintenance show`, then
`ai-reviewer-issue maintenance start`. If a round is already active, use
`maintenance start --resume ROUND-ID`. Resume returns the same frozen interval;
it never takes a later upper boundary. Ordinary failure reporting still uses
`record` immediately and does not begin a maintenance sweep.

`maintenance show` reports the host, previous completed round, active round,
source boundaries, outcome counts, candidate IDs, and individual blockers. State
is private beneath the existing incident directory's `maintenance/` folder.
Started records, outcomes, preserved event identities, carry-forward records,
and completed records are immutable. The last completed record is derived from
the parent chain; there is no mutable checkpoint pointer or Markdown archive.

For each candidate, either link its exact existing incident:

```bash
ai-reviewer-issue maintenance classify ROUND-ID CANDIDATE-ID --issue ISSUE-ID
```

or record and link a new incident without guessing its run or source identity:

```bash
ai-reviewer-issue maintenance record ROUND-ID CANDIDATE-ID --summary "Observed failure" --details-file PRIVATE-DETAILS.txt
```

The recorder preserves the event's observed commit even when the repository has
since moved. Older rows without run/caller identifiers use their exact frozen
event digest; no provider identifier is invented. An event without repository
and commit identity cannot be guessed into an incident. The original incident package and its resolutions stay in
place. Linking checks the provider and every available exact identity; legacy
incidents without run IDs are bound to their own immutable issue digest.

An expected outcome requires an explicit classification and evidence:

```bash
ai-reviewer-issue maintenance classify ROUND-ID CANDIDATE-ID --reason expected-refusal --evidence PRIVATE-PROOF.txt
```

Allowed reasons are `expected-refusal`, `quota-exhaustion`, `user-cancellation`,
`application-failure`, `duplicate-event`, and `in-progress`. A nonzero wrapper
exit is a candidate, not an automatic diagnosis. `in-progress` applies only to
an invocation without a terminal event and needs current worker evidence. It
remains carried into subsequent rounds until a terminal event accounts for it;
an orphaned start must be investigated, not repeatedly called healthy.

Close incidents through the existing `resolve` command. For a partial repair,
also preserve an explicit remaining-work document:

```bash
ai-reviewer-issue maintenance carry-forward ROUND-ID CANDIDATE-ID --remaining PRIVATE-REMAINING.txt --evidence PRIVATE-PROOF.txt
```

This appends a separate carry-forward record even when the candidate was linked
earlier. Open incidents always block completion. Partially resolved incidents
without this evidence block; with it, the candidate is included in the next
round. Existing incidents cannot be reclassified away as non-defects.

Completion requires a private JSON proof document containing `repair_commit`
(a full SHA) plus `tests`, `independent_review`, `installation`, and `live`
(nonempty file paths or evidence URLs). The first round additionally requires
`legacy_audit`: the review of pre-journal evidence described below. Local files
are fingerprinted. The round and every linked repair commit must be present in
the toolkit's fetched `origin/main`; linked repairs use their recorded repair
repository's fetched `origin/main`. Refresh upstream in each before completing.

```bash
ai-reviewer-issue maintenance complete ROUND-ID --proof PRIVATE-COMPLETION.json
```

Missing outcomes, open incidents, changed evidence, source corruption, incomplete
proof, or publication failure leave the preceding completed checkpoint intact.
Repeated completion is idempotent. Concurrent writers use a private directory
lock and immutable publication; a lock left by a killed owner requires inspection
of that exact owner before recovery, never an age-based automatic unlock.

The separate invocation ledger uses a kernel-owned file lock. Windows and Linux
release it automatically when its writer exits or dies; an existing `.append.lock`
file does not mean a writer is active and must not be deleted. Tests prove that a
live owner retains the lock and a killed owner releases it. If appending the
terminal record fails, the wrapper preserves its report and records no false
success: callers receive a bookkeeping failure and the start remains visible.

Do not rotate or compact either ledger: retention is outside version 1. If a
source is replaced, keep the active round and last completed checkpoint, preserve
both generations, and investigate the exact source named by `show`. Restore
continuity only through the source owner's reviewed recovery procedure with all
bytes accounted for. If continuity cannot be proven, leave the round blocked;
never delete checkpoint history or reset an offset to manufacture a clean round.

## Structured source inventory

The source inventory was verified against the nine-provider registry for issue
#308. Previously, provider registration did **not** mean every wrapper invocation
had durable lifecycle accounting. The checkpoint reader must not infer historical
coverage from registration or from a successful session summary.

All nine wrappers now use the shared invocation recorder:

- Claude and Codex: `ai-claude-review` / `ai-codex-review`; retain their existing
  per-run `review-lifecycle/runs/**` state and scoreboard accounting.
- Grok: `ai-grok-review`; reusable `grok/sessions/**`, session/turn records, and
  retained uncertain-work records remain supporting evidence.
- Kimi: `ai-kimi`; reusable `kimi/sessions/**` plus Windows `kimi/jobs/**/job.json`
  and owned worker logs remain supporting evidence. Detached workers get their
  own invocation records; submission success does not mean worker completion.
- GLM: `ai-glm`; reusable `glm/sessions/**` records remain supporting evidence.
- Muse: `ai-muse`; reusable `muse/sessions/**` state remains supporting evidence.
- Gemini: `ai-gemini`; reusable `gemini/sessions/**` and preserved failure
  artifacts remain supporting evidence, with its existing qualification gate.
- Qwen: `ai-qwen`; reusable `qwen/sessions/**`, pending events, and qualification
  diagnostics remain supporting evidence.
- DeepSeek: `ai-deepseek-agent`; repository-local `.ai/deepseek-sessions/*.meta.json`
  sidecars remain supporting evidence. Raw conversation JSON is not a scan source.

The authoritative new source is `reviewer-events/events.jsonl` below
`AI_REVIEWER_STATE_BASE` (default `~/.local/state/ai-devops`), or the explicit
`AI_REVIEW_EVENT_DIR`. Every recorded invocation writes an immutable start before
entering its existing wrapper and a terminal exit afterward. Failed bookkeeping
never creates a successful terminal claim. A killed recorder leaves its start
visible. Help and passive inspection commands do not create invocation events.
No prompt, command arguments, response, credential, or raw transcript is copied.
The recorder runs with an allowlisted environment; the original wrapper retains
its own credentials, traps, sandbox, model, cancellation and report checks.

`review-scoreboard/reviews.jsonl` is a required cross-check source, honoring
`AI_REVIEW_SCOREBOARD_DIR` and `AI_REVIEW_SCOREBOARD_FILE`. It can discover
semantic failures such as missing verdicts or stale evidence even when an outer
command exits zero. Unknown provider registration or source formats block rather
than silently dropping records. Provider metadata and owned log/report paths are
supporting incident evidence, not an append-only event history.

**First-round boundary:** invocation coverage begins when the updated wrappers
are installed. It cannot reconstruct overwritten historical turns. Before the
first completion, privately audit the existing provider metadata, lifecycle
failures, owned logs, and known DeepSeek repository sidecars, record newly found
defects, and attach that audit as `legacy_audit`. Existing unresolved incidents
are automatically included, and later new/reopened incidents are rediscovered
even without a new provider event. An unresolved historical coverage
gap is a blocker, not permission to assert that old logs were fully examined.
Do not use a synthetic installation proof to claim a real incident backlog clear.

JSONL boundaries contain a byte offset, complete-line digest, full-prefix digest,
size, modification time, canonical path, and platform file identity. Equal
timestamps do not collapse events. Late appends belong to the next round.
Replacement, rotation, truncation, disappearance, malformed JSONL, a partial final
line at capture, and linked paths fail closed. Source files are never edited.
The Python 3 helper is an internal part of `ai-reviewer-issue`, using the runtime
already required by the toolkit installer; it is not a separate service.

For richer exact-run failure diagnostics and non-generating quota checks, read
the STATUS table in the [diagnostics and quota plan](../plan_reviewer-diagnostics-quota-preflight.md).
Unknown capacity remains explicit; it is not proof of availability or permission
to disable a reviewer.

## Exact-run diagnostics and capacity preflight

Kimi, Grok, and GLM record a bounded exact-run diagnostic envelope through
the shared lifecycle validator. It contains phases, safe terminal observations,
local health and cancellation certainty, plus the capacity result; it never
contains prompts, responses, unrestricted provider text, commands, environment,
or credentials. `ai-reviewer-issue` copies only an exact matching envelope into
the private incident package and accepts older runs with no envelope.

Before each affected review submission, `ai-review-preflight capacity <provider>
--json` returns `available`, `exhausted`, or `unknown`. Exhausted stops before
generation. Unknown prints one explanation and preserves the review capability.
The installed Kimi, Grok, and GLM interfaces currently return unknown without
network access because none has a qualified structured non-generating capacity
contract. The measured matrix is in `tests/verification/reviewer-diagnostics-quota/`.

The implementation plan for durable maintenance-round log checkpoints is
[`plan_reviewer-log-repair-checkpoints.md`](../plan_reviewer-log-repair-checkpoints.md).
Read its STATUS table before implementing or changing incremental repair scans.

## Grok lock scope

Grok reviews are not globally or repository-wide serialized. Only the same
exact named session/turn or an idempotently identical submission is serialized.
Independent reviews may run concurrently in the same logical repository.

When recording an interrupted or cancellation-uncertain Grok run, capture its
caller, logical session name, durable provider identifier when available,
source identity, prompt/packet digest prefix, timestamps, and cancellation
confirmation state. A retained exact-work record protects only that provider
call; it must never be interpreted as a repository-wide stop. Do not capture
raw prompts, credentials, command lines, authentication files, or secret
environment values.

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
- the exact matching bounded diagnostic envelope, when present;
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

## Kimi issue #46 qualification record

The 2026-08-19 Kimi evidence exposed report-persistence, partial-output, and
terminal-diagnostic defects. Those repairs passed exact-head independent review,
installation, and the authenticated production matrix on 2026-08-23. The
redacted proof is in
[`tests/verification/kimi-review-issue-46/2026-08-23-live.md`](../tests/verification/kimi-review-issue-46/2026-08-23-live.md).
Original local evidence packages remain historical records and must not be
rewritten.

## Closing a repaired incident

A reviewer repair is not complete merely because its tests pass or a wrapper is
installed. Every local incident whose recorded symptoms the repair addresses
must receive an explicit resolution record before completion is reported:

```text
ai-reviewer-issue resolve <issue-id> --status resolved \
  --summary "What is now fixed" \
  --repair-commit <exact-commit> \
  --evidence <test-review-install-or-live-proof>
```

Use `resolved` only when every symptom in the original package is proven fixed.
For a repair committed in another repository, add `--repair-repo <worktree-path>`.
The recorder validates the commit in that repository and records its canonical
repository path; omitting this option keeps the toolkit repository default.
Use `partially-resolved` and state what remains when the proof covers only part
of a multi-symptom report. With no adequate proof, leave the incident open.

Resolution files are append-only records under the incident's `resolutions/`
directory. The original `issue.json`, logs, and captured evidence remain
unchanged. `list` reports the latest status (`open`, `partially-resolved`, or
`resolved`), and `show` joins the latest resolution into its displayed JSON.

Resolved incidents stay in their original directories. Do not move them into a
`resolved.md` file or a second archive: the incident plus its append-only
resolution is the machine-readable audit record.

Before the final repair claim, audit `ai-reviewer-issue list`, resolve every
affected record, and cite the exact commit plus test, independent-review,
installation, or live-production evidence. This is the standard operating
procedure for reviewer repairs.
