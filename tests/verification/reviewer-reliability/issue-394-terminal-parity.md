# Issue #394: terminal diagnostic parity

Status: accepted on current `main`. This record closes #394 only; #337 and
#159 remain open for their later sequence positions.

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

## Delivered acceptance

PR #464 merged through the protected queue as
`9e94e73a3feb1b1fff44efaab5f200b21e5a88e2`. Exact-head GLM 5.3 review approved
its reviewed head, and the pull-request and merge-group suites passed. The
canonical Windows checkout was fast-forwarded to the merge commit and the
managed launchers resolve to its Qwen, Muse and Grok wrappers.

Installed normal canaries completed through all three providers. Qwen returned
the requested model and an approving read-only report after the official
standalone 0.23.0 runtime and credential hardening were restored; Muse and Grok
both read the repository and returned `CANARY_OK`. No canary edited a file.

The shared-db consumer landed separately through guarded PR #2932 as
`86a9aca6a9b5086b0effb0fb17f7e24bdb658990`. Its 52-test suite, 286-site semantic
truth audit, contract gate, tools checks, ephemeral database checks and exact-head
governed Muse review passed. No database or production write was performed, and
shared-db #2707 is closed.

All four affected incident packages now carry append-only `partially-resolved`
records tied to the toolkit merge and installed reports. The remaining provider
limit or unknown historical cause is stated in each record. PRs #418/#419 are
obsolete because their surviving terminal obligations are present in #464; their
branches remain preserved. The frozen 198-candidate maintenance round is unchanged.

Installed acceptance reused the owning refusal-fixture results and completed
normal Qwen, Muse and Grok reviews. It did not deliberately provoke a paid
content-filter or turn-limit failure. The existing DeepSeek Unicode and
same-session evidence remained applicable because its shipped wrapper was unchanged.

The affected historical incidents require partial, evidence-backed resolution:
Qwen `20260910T223006Z-edge-dev-qwen-94730`, Muse
`20260910T223025Z-edge-dev-muse-95504`, and Grok
`20260910T192734Z-edge-dev-grok-8417` and
`20260911T054028Z-edge-dev-grok-419831`. Better classification does not repair a
provider limit or establish an unknown historical cause. Preserve those
limitations explicitly; successful normal canaries cannot rewrite the original
failed outcomes. Each incident now has that partial resolution recorded.
