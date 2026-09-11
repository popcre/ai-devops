# Issue #397: exact-session completion recovery

This is the qualification record required by the reviewer reliability plan. It
records the recovery slice under #337; it does not close #397 or the parent.

## Root causes and repaired behavior

- Qwen could discard the pending stream before active metadata was durable, and
  a conditional caller could swallow report-publication failure. Local
  `finalize` now validates the exact session, terminal stream, source packet,
  model, runtime/preloader fingerprints, and original invocation. It publishes
  the report and metadata before removing pending bytes. It sends no prompt.
- GLM could mistake the previous stopped assistant for the submitted turn while
  the status endpoint was blind. A pre-submission assistant watermark identifies
  the new turn. Completed bytes are retained before optional reporting, and
  `recover` only observes the existing remote turn or finalizes retained bytes.
  Permission replies for that existing turn remain allowed; no prompt is replayed.
- Muse `reconcile` previously cleared uncertain state solely because a session
  ID existed. It now requires a retained successful process and exact matching
  terminal stream. Raw response, request, process result, session, packet, and
  original invocation survive local post-processing failure. Recovery compares
  an existing report byte-for-byte and reuses its inode; a different report is
  never replaced. Native Windows and Git Bash paths represent the same stored
  identity consistently.
- GLM and Muse can retain a completed response after source movement, explicitly
  non-authorizing, then permit an ordinary fresh turn in the same conversation.
  Shared `verify-retained` validates the sealed isolated snapshot and full patch
  but never emits the live-source authorization receipt.
- Dependency #395 keeps the original paid invocation as the sandbox owner for
  local recovery. A failed local retry cannot create an additional fictitious
  paid-work cleanup obligation. Each successful local retry still needs its own
  durable linked receipt.

## Recorded local evidence

- Exact-head independent GLM review of
  `c68854717ad447223cb3bf0d15924e0b06d839b9`, base
  `69716e401c7d1913d235a160d9b6ec710c2648e8`: wrapper exit 0, terminal APPROVE,
  model `zai-coding-plan/glm-5.3`. The private report remains under the owning
  worktree's ignored `.ai/reviews/`. Its valid availability findings drive the
  subsequent deterministic-context and local-retry ownership repairs; that
  approval does not cover later commits.
- Packet suite: 113 passed, 0 failed. Includes unchanged retained evidence after
  source movement, no authorizing receipt, snapshot tampering, and packet tampering.
- Qwen narrowed real-evidence recovery fixture: 7 passed, 0 failed. Metadata
  publication failure retains the complete response; exact local retry reuses
  one report; a different returned session cannot be adopted.
- GLM recovery fixture: successful prior-watermark, failed-publication,
  retained-byte tamper, exact retry/repeat, completed-stale, and missing-origin
  refusal cases. Provider submission count remains zero during recovery.
- Muse report-retry subset with dependency `aec890d7`: 47 passed, 0 failed.
  Includes changed-report refusal, identical inode reuse, fresh continuation,
  and refusal to clear a failed process merely because its session ID is known.
  Stale completion, retained-byte tamper, and no-provider repeat cases also
  passed in the preceding focused run. The first full owning suite recorded
  139 passed and 6 failed: shared cleanup obscured original failure states and
  skipped exact staging/lock cleanup. Dependency `ebbc1773` repairs that cause;
  the integrated full run then recorded 142 passed and 3 cascading fixture
  failures: a test claimed evidence was missing while retaining a recoverable
  successful turn. The fixture now removes that proof for the refusal check.
  The final recovery subset, including #333 immutable usage observations, passed
  53 checks with zero failures. All new recovery cases passed.
- GLM elapsed-deadline fixtures: 3 passed, 0 failed. HTTP time and initial sleep
  count against the existing turn limit; an expired recorded deadline permits
  no further polling. The existing recovery composite also passed afterward.
- GLM permission authentication now travels through the existing protected curl
  configuration pipe. The synthetic regression proves authentication remains
  present on standard input and absent from command arguments. No real password
  was inspected; this is code-path evidence, not proof of external disclosure.
- Independent GLM review of `060cd3d27256be6b66e49a1aeccb37871d35d73a`
  returned APPROVE with wrapper exit 0. Its valid Muse accounting retry finding
  is repaired by saving the chosen accounting JSON in the existing atomic
  retained-turn write. There is no second metadata write that can leave the
  paid report and retained accounting inconsistent. The focused owning recovery
  suite passed 55 checks, including a fault that rejects the former second
  write and recovery of the original unavailable accounting without recomputation.
- DeepSeek formal reviews now bind caller, requested model, repository and
  session across wrapper restarts. Changed caller/model refuses before provider
  contact; ordinary conversations retain their existing model selection.
  Source-change metadata preserves these identities so ordinary fresh-source
  review continuation remains possible. The existing focused suite passed
  32 checks with zero failures/skips; unknown legacy model provenance is not
  inferred from current configuration.

## Outstanding qualification

### DeepSeek local publication recovery

The additional DeepSeek slice retains the exact request, original invocation,
HTTP observation, paid response hash, attachment ledger intent and formal
packet before local publication. `ai-deepseek-agent finalize SESSION` repairs
the transcript, ledger and metadata without credentials or a provider request.
Pending evidence blocks accidental replay. Completed source-stale work remains
non-authorizing; a later explicit turn can resolve fresh source. Proven HTTP
refusals can also be finalized locally as incomplete, with a nonzero result and
ordinary explicit continuation preserved. Unknown transport outcomes and legacy
markers lacking exact retained intent remain fenced rather than guessed.

The owning offline recovery cases passed 25/0/0 and cover publication faults, changed response
bytes and source inventories, caller mismatch, repeat finalization, stale
formal source, HTTP refusal and explicit continuation. The source/identity
subset passed 32/0/0 before the additional inventory-binding assertion. This
slice still requires its final exact-head review, CI, installation and live
qualification; the extraction helper preserves existing terminal parsing for
the separate #394 native-status repair.

The expired-deadline recovery regression passes: recovery makes one bounded
GET observation before consulting the original polling deadline. A new terminal
assistant message can be retained after that deadline; an old or incomplete
message leaves the original deadline and pending fence unchanged. No POST,
deadline renewal, or automatic replay is introduced (owning focused case: 1/0).

Grok 1.0.13 exposes retained transcript export but no documented authoritative
remote-run status or acknowledged cancellation command. A live timed-out review
was exported read-only: 8,321 bytes, SHA-256
`9e322a20d35ab15f9e500dc995e5c35862981aa6502f62163e194522a0cc750e`.
The private export contains intermediate paid progress and no terminal verdict.
Its existing incident and uncertain work lock remain open and untouched. Local
leader state cannot establish remote cancellation. This is an unresolved
qualification limitation, not a recovered result or permission to retry.

Required CI, final exact-head independent review, merge, serialized installation,
and governed Qwen/GLM live canaries remain outstanding for the final integrated
head. Muse's full suite and final installed continuation proof are also pending.
The wider #397 matrix still includes Kimi, Grok, Gemini, DeepSeek, two callers and
repositories, and GLM service restart versus Muse process restart. Existing
provider tests must be reused; no replacement generic harness is introduced.

Legacy GLM records without an original invocation binding and prior-assistant
watermark remain unknown. A session ID or a unique timestamp is not sufficient
to invent that provenance. Paid transcripts are retained privately and no
uncertain prompt is automatically repeated. Pre-existing live-checkout sessions
also cannot acquire an invented isolated historical snapshot.
