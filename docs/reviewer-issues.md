# Reviewer issue recording

For the October 15 edge-dev3 recurrences, read the [repair plan](../plan_reviewer-recurrence-repair.md) STATUS first. It accounts for all local unresolved incidents and preserves existing repair ownership; incident collection alone is not a repair.

For the current end-to-end repair and cache/session qualification work, read
the STATUS in [the reviewer reliability and efficiency plan](../plan_reviewer-reliability-and-efficiency.md)
first. It reuses the completed checkpoint/diagnostic tooling and existing provider
work; it does not replace this incident lifecycle or authorize closing unexplained failures.

## Before recording a missing reviewer

Before recording a reviewer as missing or not on PATH, run `ai-review-preflight usable <provider>`; its output names the exact resolved wrapper (`wrapper_command`, e.g. grok -> `ai-grok-review`). Never hand-type a guessed wrapper name: a 2026-09 report of "ai-grok not on PATH" was wrong because the real wrapper is `ai-grok-review`.

## Shared fleet archive and installed-skill verification

The shared destination is the private
[`u2giants/ai-devops-reviewer-logs`](https://github.com/u2giants/ai-devops-reviewer-logs)
repository. The reporting skill (`log-reviewer-issue`, deleted in #2074)
records the incident locally, then runs `ai-reviewer-logs-sync sync` to upload
encrypted evidence immediately. The hourly schedule is a fallback. The recorder
alone does not upload; a failed upload leaves the original incident intact and
must be reported as pending without recording a duplicate.

A merged skill change does not prove fleet installation. Compare the installed
Claude and Codex copies against merged source on each development machine. Use
the [scoped skill refresh](deployment.md#install) (`ai-install-skills --only
log-reviewer-issue --dry-run`, then the same selection without `--dry-run`) from
a dedicated worktree of merged source. Do not advance an installed checkout by
pulling it merely to refresh one skill.

To verify a specific incident, locate its original machine and exact incident
ID, read the published archive, decrypt its bundle using the existing protected
key procedure, and compare every incident file's hash with the original. A recent
archive commit, a successful upload from another machine, or `nothing new` alone
does not prove that incident is present. Inspect collection notes and
`LAST-SYNC.txt`: oversized files and read failures can make a collection partial.
Do not describe a partial collection as complete historical coverage.

On 2026-10-15, the current reporting skill was verified installed for both
clients on edge-dev3 and refreshed from merged source on hetz, edge-dev, and
916-alien. Upload checks succeeded on all four machines. One reported hetz
incident was decrypted from the published archive and all seven package files
matched the originals. This verifies that incident's delivery and the installed
skill rollout; it does not certify every historical raw log or prove a future
incident's immediate upload before it happens. Private incident content and the
decryption key remain outside this public repository.

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
`application-failure`, `duplicate-event`, `in-progress`, and
`evidence-unavailable`. The last reason is terminal for the frozen candidate and
requires both exact provenance through `--evidence` and an explicit retained
obligation through `--carry-forward`; it does not reconstruct or silently drop
missing history, and it does not create a duplicate candidate in the next
bounded round. A nonzero wrapper
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
checkout. Owner decision 2026-10-12 (PR #1626): redacted incident packages are
published on main as evidence. The public-boundary gate allows that one
subtree and still forbids every other generated AI artifact, plus any
secret-bearing file type (`*.env`, `*.pem`, `*.key`, and the other
`.gitignore` secret names) even under `.ai/reviewer-issues/`. Packages may
refer to private repositories and provider sessions only after redaction.

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

### Platform: where it failed and where the fix runs

Every incident records its machine and operating system (`machine` in `show`).
Before diagnosing, name both: the OS the failure happened on, and every OS the
fix will run on. The same toolkit runs two ways — Ubuntu (hetz server, edge-dev3 desktop) and
Windows (4837/al8960ofc, 916 with its checkout on D:, edge-dev: PowerShell
installer, Git Bash, OpenCode folder shell). A shared-code fix
(lifecycle core, pool, packet, validators, briefs) reaches both, so it is not
done until its tests pass on Linux **and** on Windows (Git Bash plus PowerShell
5.1 and 7) and it is installed by each platform's route
([`docs/deployment.md`](deployment.md)): `update.sh` on Ubuntu,
`bin/install-ai-devops-windows.ps1` on Windows. Do not assume a symptom seen on
one OS exists on the other, or that a fix proven on one works on the other;
record which platforms were proven in the resolution. Windows traps that fake or
hide results: CRLF in Bash scripts, PowerShell 5.1 stripping native argument
quotes, the gh keyring being unreadable over SSH. EDGE-ALIEN and Envy are not
review hosts.

## Kimi issue #46 qualification record

The 2026-08-19 Kimi evidence exposed report-persistence, partial-output, and
terminal-diagnostic defects. Those repairs passed exact-head independent review,
installation, and the authenticated production matrix on 2026-08-23. The
redacted proof is in
[`tests/verification/kimi-review-issue-46/2026-08-23-live.md`](../tests/verification/kimi-review-issue-46/2026-08-23-live.md).
Original local evidence packages remain historical records and must not be
rewritten.

## Closing a repaired incident

### Durable report publication and cleanup

Reviewer wrappers reserve report evidence before paid review work. Prepared reports
are published as immutable private receipts in the existing reviewer-events store;
the event ledger contains only opaque references. A publication failure
retains local output and refuses cleanup. Successful failure-diagnostic publication
does not turn an interrupted or failed review into an approval.

Managed snapshot markers record every paid invocation that used them. Removal and
refresh verify each invocation's durable receipt, including a separately recorded
local finalization linked to the original invocation. A stale-source finalization
preserves the original head and explicitly remains non-authorizing for current
source. It never submits another provider request or rewrites the original event.
New standalone snapshots have an explicit empty ownership list and retain ordinary
creation, refresh, and removal behavior.

Older snapshots without ownership proof are retained until exact private metadata
and prepared reports establish their identity. Recover them locally with:

```text
ai-reviewer-issue evidence reconcile-sandbox PROVIDER SANDBOX METADATA REPORT [REPORT ...]
```

The command verifies the exact stored workspace and provider-session/report link,
publishes the prepared evidence, then records cleanup ownership. It does not infer
ownership from a shared repository or head, synthesize a historical run ID, or
claim historical source authorization. Unknown or missing evidence remains unknown.

When a review's report is provably gone (its caller worktree was deleted, or its
publication failed and no report from that invocation survives), the owner records
that loss instead of inventing evidence:

```text
ai-reviewer-issue evidence reconcile-lost PROVIDER SANDBOX "REASON"
```

Only GLM is accepted: the report search depends on GLM's report naming, so any
other provider is refused rather than risk missing a recoverable report. It
refuses while the invocation is still running, while a required patch or
prepared artifact exists, and while a report that review could have written still exists (the exact
review name; for an owned invocation, any such report newer than its start), and
refuses when partial evidence was published. It writes `evidence-lost.json` with the
reason and time beside the invocation's requirement — a new `local-reconciliation`
invocation for a legacy sandbox — and records cleanup ownership. Verification then
reports the terminal reference `RUN_ID/evidence-lost`, which prune honours; the
paid result stays recorded as unknown, never as published.
Implementation workspaces use the same private event store and bind their existing
owner record to the original invocation. Before that invocation reserves paid work,
ordinary setup cleanup remains available; afterwards cleanup requires its receipt.
For legacy implementation owners, use `ai-reviewer-issue evidence reconcile-owner
PROVIDER OWNER METADATA REPORT`. This verifies the exact session/report identity
and that every Git-visible workspace change equals the existing canonical patch,
then preserves both report and patch centrally. Unexported files or differing work
remain blocked for recovery; a later cleanup never assumes they were published.
Current implementation owners additionally retain the exact prepared report and
patch paths and hashes. Reconciliation republishes every missing original
artifact; a different report from the same session cannot replace a paid result.
`ai-reviewer-issue evidence verify-prepared PROVIDER ORIGINAL_RUN_ID KIND PATH`
checks that proof even after the disposable owner file has been removed.

Explicit Qwen and Kimi implementation-state deletion first archives the complete
owned local state in the existing private evidence store. The equivalent local
commands are `ai-reviewer-issue evidence archive-implementation-state PROVIDER
METADATA` and `ai-reviewer-issue evidence verify-implementation-archive PROVIDER
METADATA`. They preserve the exact metadata, owner manifest, canonical patch,
older owned generations, and explicitly recorded recovery patches. Unknown files,
changed bytes, and missing known paid-result evidence refuse deletion. A legacy
archive records the original paid result as unknown; preserving surviving bytes
does not reconstruct lost evidence or grant source approval.
Use `ai-reviewer-issue evidence verify-sandbox SANDBOX` to check the resulting
cleanup proof. Keep all command arguments and artifacts private; this operation is
not a disposition sweep and does not change a frozen maintenance round.

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
