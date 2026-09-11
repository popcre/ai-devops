# #333: truthful usage without changing review context

Owner: reviewer programme #337. This extends the existing wrappers and their
reports; it introduces no service, provider, or replacement conversation store.
The shared formatter is `tools/reviewer_usage.py`; retire any older inline
aggregation when a wrapper adopts it rather than maintaining parallel totals.

## Counting contract

DeepSeek writes provider-returned usage to a private session JSONL sidecar,
outside the persisted request messages. Missing, negative, invalid, and unsupported
counters remain null. A returned zero remains zero. Input includes cache reads;
output includes reasoning. Those overlapping fields must not be added again.
Provider billed cost and cache-write counts remain unknown.

Muse totals unique completed step parts, keyed by session/message/part identity.
Duplicate identical events count once. Conflicting duplicates, mixed sessions,
missing step boundaries, and missing terminal completion cannot produce complete
totals. Message aggregates are excluded. GLM's existing final message counters
are explicitly labelled as the last assistant step, not the entire paid turn.
Grok preserves unknown values through session accumulation instead of replacing
them with zero or making a later known turn repair earlier missing data.

Usage publication is optional. Failure cannot erase the retained provider
response, change a successful verdict, or submit another model turn.

## Pinned runtime evidence

Installed OpenCode was 1.18.12. Source commit
`0dd6950d1b06958fbcdcadf0ad56258257ab7fdb` establishes the adapter semantics:

- `packages/opencode/src/session/session.ts`, getUsage: input removes cache;
  visible output removes reasoning; absent/invalid provider values become zero.
- `packages/opencode/src/session/processor.ts`: one stable step-finish part per
  step; assistant message tokens are overwritten while estimated cost accumulates.
- `packages/opencode/src/cli/cmd/run.ts`: JSON output emits the step-finish part.

Consequently these are observed adapter values, with original provider
missingness unavailable. OpenCode cost is a model-price estimate, not billed cost;
its price-effective date is unavailable. Runtime and observation time accompany
the normalized record. An unqualified runtime version produces unavailable usage.

## Private live fixture, 2026-09-11

A synthetic two-file repository required two successive reads. The installed
Muse wrapper completed three provider steps in one named session. A sanitized
fixture retains only numeric counters and synthetic event IDs:

- Whole-turn input including cache: 35,602; cache reads: 23,266; writes: 0.
- Output including reasoning: 2,508; reasoning: 2,164; total: 38,110.
- Adapter cost estimate: 0.0295689 USD; billed cost unknown.
- A same-session follow-up recalled both exact synthetic markers with zero tool
  calls: input 14,009; cache read 0; visible output 136; reasoning 1,101.
- Provider-session elapsed time was 21.908 seconds for the initial three-step
  turn and 11.803 seconds for the one-step recall. Neither turn compacted.

This proves continuity in this fixture; it does not prove a general cache saving.
No compaction, retention, review-input, or context setting was changed. Any future
optimization still requires paired measurements after correctness gates pass.
Raw exports remain private. They are not committed or sent as review input.

## Verification and remaining acceptance

The formatter has 13 provider-shaped cases, including absent/zero/invalid,
incremental steps, cumulative message exclusion, duplicate/conflicting events,
missing terminal state, mixed sessions, and unqualified versions.
Focused wrapper probes: Muse 44 passed/0 failed; Grok 13/0; DeepSeek 46/0;
GLM last-step scope/unchanged-answer/zero-preservation check passed.
These include actual accounting failure preserving the paid response and no replay.

Grok exact-head review of `780c3b45dd9c2701ec7bfef119890363d2f2a94a`
approved with no blocking accounting defects (17 turns, $0.21912966).
Its doctor-display suggestion is applied; final follow-up review remains pending.

Required CI, final exact-head independent review, merged installation, and live checks
of the changed accounting are pending. This evidence does not close #333.
