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
  integrated verification remains pending. All new recovery cases passed.

## Outstanding qualification

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
