# Issue #394: terminal diagnostic parity

Status: preparation and verification in progress. This record does not close
#394, #337, or #159. Delivery follows #397's current-main acceptance gate.

## Scope and preserved behavior

The fresh baseline is `28c86d1b0c4fd9bbb7a1801a4f8b6454b2bbbbfd`.
The terminal-only changes are ported semantically from the obsolete #418/#419
branches; those branches must not be merged over the newer #397 recovery code.

- Qwen recognizes the provider's exact content-inspection refusal token across
  result, assistant, and stderr output. A success-shaped answer cannot override
  that refusal. Retained stderr and its digest keep the same classification
  during local finalization without another provider call.
- Muse distinguishes a refusal before provider launch from a provider-turn
  failure or retained-turn reconciliation failure. Missing or invalid caller
  identity has a fixed startup reason; an invalid caller value is not echoed
  in the diagnostic. The diagnostic phase does not change cleanup ownership.
- Grok preserves incomplete paid evidence before cleanup and publishes stable
  terminal reasons. A cancelled result is classified as a turn-limit result
  only with one matching native completion event bound to the same session and
  request. Missing, duplicate, mismatched, or changed evidence cannot establish
  that stronger diagnosis. The original provider stop token remains retained.

Existing exact-session recovery, caller/source identity, paid-work fences,
private evidence publication, and nonempty report validation remain required.
No provider is removed, no timeout is increased, and no real uncertain turn is
replayed to qualify this change.

## Verification in progress

On Windows through Git Bash, the rebased candidate's Qwen terminal/recovery
slice passed42/0/0 and Muse's management/refusal slice passed58/0/0. Complete
owning suites then passed Qwen166/0 (skip count unreported), Muse165/0 (skip
count unreported), and Grok270/0/0. Private logs are
`C:/Temp/394-qwen-terminal-current.log`, `394-muse-phase-current.log`,
`394-qwen-full-current.log`, `394-muse-full-current.log`, and
`394-grok-full-repaired.log`.

The first rebased Grok full run passed267/270 checks but its interrupt fixture
stalled before the provider-ready marker on a degraded host. The surrounding
uncertain-work and lock protections passed. A test-only focused mode now prints
safe fixture stderr if readiness stalls, without changing wrapper behavior or
the assertions. The focused interrupt section passed34/0/0, including process
termination, uncertainty preservation and owned-lock release; the subsequent
full270/0/0 run proved the failure did not recur. The failed run is retained at
`C:/Temp/394-grok-full-current.log`; it is diagnostic evidence, not acceptance.

Independent GLM review of `d676261b1bc972503e7ad8e8956c7b7adf011886` returned
REQUEST CHANGES. Follow-up addresses Muse management-command phase labels and
corroborates Grok's native terminal format against installed evidence. The
review correctly retained the pending owner decision on legacy Qwen recovery.
This is not independent approval, and the earlier complete-suite results do
not qualify subsequent code changes without their relevant verification.

The Muse follow-up selects management/reconciliation phases before metadata
lookup, runtime validation or locking. Actual mocked CLI checks for missing
records, a busy retained session and a refused provider deletion passed
58/0/0, preserving foreign ownership and metadata and making no generated turn.
The private log is `C:/tmp/394-muse-management-phase.log`.

Grok native-format corroboration used the retained terminal metadata of incident
`20260911T054028Z-edge-dev-grok-419831`, without a provider call. The installed
runtime reports `grok 1.0.13 (5e9a58528b76) [stable]`; its executable SHA-256 is
`bf43dc75f5478a106eab1e86d422c963e4dbe9666cf14dab363733d27bf1e672`.
The real store uses `GROK_HOME/sessions/<encoded-working-directory>/<sessionId>/updates.jsonl`.
The retained event has `params.sessionId`, `params.update.prompt_id`,
`params.update.sessionUpdate=turn_completed`, `params.update.stop_reason=cancelled`
and `params._meta.cancellationCategory=max_turns_reached`. Both observed IDs
are UUID-shaped and satisfy the wrapper's current charset gate.

The actual candidate capture and reason functions consumed that real native
metadata with a tiny **synthetic result** containing only those proven IDs and
the cancellation token. They produced exactly one native match and
`turn_limit_cancelled`, with the result digest verified. The matched native
event SHA-256 is `c12ffe7bc5637135aeb72ebf257343c2992f4aaf71a23c8189e3ec42c8a664e4`;
the native file remained unchanged. This establishes parser/schema compatibility,
not a successful historical review, historical executable identity, or a future
ID-format guarantee. The private proof is
`C:/Temp/394-native-f2-5z7ac8pv/verification.json`; no raw transcript or response
body is included in this public record.

Cross-review found that metadata presence alone did not prove whether Muse had
contacted the provider. The first full-suite attempt was interrupted to repair
that defect, not counted as a result. The replacement full run uses the
explicit phase checks exercised above.

The candidate Qwen compatibility path preserves pre-stderr recovery records
and privately publishes their sealed saved answer as INCOMPLETE, without an
authorizing verdict or a provider request. It does not invent missing error
evidence. Albert approved GLM 5.3's recommendation on September 14: retain these
old answers privately but prevent approval authority when their original error
evidence is missing. No record deletion or automatic replay is authorized.
Partial version-2 metadata or orphan stderr is never treated as legacy.

The governed consumer's terminal mappings and DeepSeek terminal invocation
flag are a separately delivered repository-maintenance slice in shared-db.
Source-receipt integration remains #393. Both sides must agree on the stable
failure reason and reject a failed wrapper that prints a fake approval.

## Remaining delivery gates

Full owning suites and the owner decision are complete. Exact-head independent
review, required CI and merge queue, canonical installation, installed live
checks, consumer acceptance, and affected incident reconciliation remain pending.
PRs #418/#419 are reconciled only after their surviving obligations are
delivered. The frozen 198-candidate maintenance round is unchanged.

Installed acceptance will reuse the owning refusal fixtures and normal
governed Qwen, Muse and Grok reviews. Deliberately provoking paid content-filter
or turn-limit failures is not required. The existing DeepSeek Unicode and
same-session evidence remains applicable while its shipped wrapper is unchanged.

The affected historical incidents require partial, evidence-backed resolution:
Qwen `20260910T223006Z-edge-dev-qwen-94730`, Muse
`20260910T223025Z-edge-dev-muse-95504`, and Grok
`20260910T192734Z-edge-dev-grok-8417` and
`20260911T054028Z-edge-dev-grok-419831`. Better classification does not repair a
provider limit or establish an unknown historical cause. Preserve those
limitations explicitly; successful normal canaries cannot rewrite the original
failed outcomes. No resolution record has been appended during preparation.
