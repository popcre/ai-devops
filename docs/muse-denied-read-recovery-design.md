# Exact non-authorizing Muse denied-read recovery

Owner: existing ai-devops issue #674. Recurrence coordination: #1783. This change does not authorize acceptance of a failed review, installation, automatic paid retry or alteration of any retained evidence.

## Demonstrated boundary and decision

Two original OpenCode Muse turns on edge-dev3 ended with process exit zero and complete retained native streams but no successful terminal stop. One contains a preliminary reference to “approval evidence” before a successful in-copy read and one denied read in the next step. The other contains one successful in-copy read in its first step and three consecutive denied read calls in its final step. Both original retained packets passed the installed read-only `verify-retained` command. Their raw prompts, paths and streams stay private. Separate later packets with a hash mismatch remain separately blocked.

Current finalization permits one denied read only and rejects the noun “approval” even inside neutral preliminary text. The proposed receipt remains strictly non-authorizing: it archives exact failure evidence and opens only the existing normal same-session ask route. It creates no report or approval, replays no request, resets no accounting and asserts nothing about billing.

## Technical decision requested

Review the technical safety of the bounded recovery predicate below, not whether these documentation edits are mergeable. Return `DESIGN DECISION: APPROVE` only if this exact acceptance model is safe to implement on the verified original shapes; otherwise return `DESIGN DECISION: REVISE` with the failed invariant. This decision authorizes no installed command, original-state write or successful review acceptance. The normal report Verdict must agree with the technical decision. Coordinator retains go/no-go after reading it.

## Original evidence qualified read-only before this design review

Sanitized exact event ordering (the source paths, native IDs, text and raw streams remain private):

- Three-denial specimen: `step_start, text, read:completed, step_finish:tool-calls, step_start, read:error, read:error, read:error, step_finish:tool-calls`.
- Neutral-one-denial specimen: `step_start, text, read:completed, step_finish:tool-calls, step_start, read:error, step_finish:tool-calls`; preliminary text contains the exact neutral phrase `approval evidence`.
- Independently checked on each ORIGINAL descriptor/stream/packet: all events match retained session = true; original stream SHA256 = true; original prompt SHA256 = true; all error tools/read/error strings match exactly = true; retained native process_exit=0 = true; source head matches retained head = true; installed read-only failed-invocation verifier confirms exact unsignaled original wrapper failure = true; installed read-only retained-packet verifier = true. These are observations of existing unchanged evidence, not a modified/synthetic replacement.

## Proposed acceptance predicate (requires independent technical design APPROVE before implementation)

Keep the original identity/binding checks for caller, repository, head, packet inventory hash, prompt hash, stream hash, invocation identity, unsignaled wrapper completion, process-exit-zero and original session byte-for-byte. Only the explicitly specified native-stream classifier below changes. Existing successful reconciliation is unchanged.

The native stream must satisfy all these conditions:

1. Every event is an object belonging to exactly the retained session. Event types stay restricted to step_start, step_finish, text and tool_use. Every start/finish part has the proper type. There must be one or more balanced steps; a step_start opens one step and step_finish closes it, with no nested starts, no orphan finishes and no text/tool outside an open step. Every finish reason is tool-calls, never stop, error, aborted or unknown. Thus no successful review completion is accepted by this failure route.
2. Tool events must be complete native tool parts. Before the failure suffix, completed tool events are permitted exactly as today. Error count is bounded to one, two or three. Every error must be `read` with exact error text `The user rejected permission to use this specific tool call.`. Other tool errors, additional unknown errors and any fourth denial refuse.
3. The error events must be consecutive, in the final open step, and occupy the entire suffix immediately before its final step_finish, which must be the last event in the stream. No text, completed tool, start/finish, successful tool output or other event may intervene after the first denial. Earlier steps may contain completed tools but no earlier errors.
4. Preliminary text must remain non-verdict-like. Preserve the existing forbidden VERDICT/DECISION/APPROVE/APPROVED/APPROVAL/REJECT/REJECTED/REJECTION/STOP/STOPPED checks and additionally reject approving, LGTM and no-blockers verdict phrases. This remains a narrow textual denylist, not a complete natural-language meaning classifier; a failure receipt never promotes any text into approval. Permit only the precise neutral noun phrase `approval evidence` (case-insensitive, word-bounded) by removing that phrase for the existing forbidden-word check; any remaining standalone APPROVAL still refuses. In particular `VERDICT: APPROVE`, `I approve`, `Approved`, `approval granted`, `final approval`, `DECISION: ...`, rejection and stop tokens continue to refuse. No text follows the first denial regardless of wording.

The observed-shape positive must include the prior successful read in its own completed step; the existing duplicate-event three-error fixture is additional coverage, not a replacement. Fourth denial, a completed tool after the final denial, any whitespace/empty text after any denial, and every malformed part/event are explicit negatives. New standalone shell suites require both the per-suite timing metadata and CI discovery registration verification.

The denial boundary and tool permissions do not change. We do not make outside-copy reads available; the repair is truthful classification of an already-ended failure with exact retained proof.

## Preventing misleading reviewer paths (separate presentation repair)

Preserve both original source checkout and snapshot absolute identities in the shared manifest as explicitly labeled immutable provenance, keeping the August 18 real-checkout/snapshot distinction and existing assertions. Add an authoritative navigation paragraph: tool root is the actual current working directory `.`, source reads use repository-relative paths, and original host paths in identity metadata/history must not be read or retried. Thus no provenance is removed and no provider loses context. The shared change is additive clarification for every reviewer; Muse wrapper and Muse door also append the relative-root instruction so a resumed conversation does not obey an old host path. Neither tool permissions nor identity.json/snapshot markers change.

Explicit code/test targets for this bounded repair: `bin/ai-muse`, `bin/ai-review-packet`, `tools/lib/review-doors/muse.sh`, `tests/test-ai-muse.sh`, new focused stream fixtures, `tests/test-ai-review-packet.sh`, Muse door fixture coverage and corresponding shared skill/docs. The shared packet/sandbox regression suites must preserve all provenance and outside-copy denial assertions, including both adjacent real-checkout and disposable-snapshot manifest assertions. This presentation work does not expand the failed-turn acceptance model.

## Required tests

- End-to-end wrapper fixtures: exact single denial, two and three consecutive denied reads after a successful prior step, same-session fresh follow-up after non-authorizing finalization (a new ordinarily authorized provider invocation, never replay of the old invocation), and neutral approval-evidence preamble.
- Negative native streams: four errors, a generic tool error, a denied bash/write/list tool, a completed tool or text between denials, error in an earlier step, a new step after denial, stop/error finish, nested/unbalanced steps, wrong session, explicit verdict text and non-neutral approval wording.
- Update `tests/test-ai-muse.sh` existing `failedturn-multiple-errors` fixture: it currently constructs exactly three consecutive denied reads and must become an explicit positive case; add a four-denial negative instead. Three is a conservative upper bound for the observed native final-step failure burst; a fourth stays unqualified, never silently truncates. Add focused native part-type, unknown-event and outside-open-step negatives.
- Update `skills/shared/ask-muse/SKILL.md` and the recovery section of `docs/muse-opencode.md` from the singular sole-error condition to the exact bounded denied-read suffix. Preserve `tests/test-ai-review-packet.sh` real-checkout and disposable-snapshot identity assertions, and add relative-navigation precedence and unchanged identity.json assertions.
- Existing original process/signal/time/source/caller/engine and retained prompt/stream/packet tamper tests remain green. Dry-run must modify nothing and contact no provider. Finalization preserves original descriptor archive and incomplete report and produces no accepted review.
- Packet tests prove in-copy relative navigation remains available, original checkout/snapshot identities stay visible as provenance metadata with explicit do-not-read labels, identity.json is unchanged and outside-copy read protections remain unchanged.
- Read-only implementation qualification must run the candidate classifier against both exact original private streams, verify their unchanged SHA256 against original descriptors and re-run retained-packet verification. Publish only booleans/counts, never paths/content; do not invoke candidate finalization, change state or reconstruct mismatched evidence. Add a completed disposable-copy command before denial positive case to preserve existing review capability.
- Run full affected Muse, Muse Code and packet suites and shared-packet regressions. Independent exact-head review gates shipment; supported exact-merged-target installation and real original-session recovery remain coordinator-owned follow-up gates.
