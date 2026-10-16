# Exact non-authorizing Muse denied-read recovery

Owner: existing ai-devops issue #674. Recurrence coordination: #1783. This change does not authorize acceptance of a failed review, installation, automatic paid retry or alteration of any retained evidence.

## Demonstrated boundary and decision

Two original OpenCode Muse turns on edge-dev3 ended with process exit zero and complete retained native streams but no successful terminal stop. One contains a preliminary reference to “approval evidence” before a successful in-copy read and one denied read in the next step. The other contains one successful in-copy read in its first step and three consecutive denied read calls in its final step. Both original retained packets passed the installed read-only `verify-retained` command. Their raw prompts, paths and streams stay private. Separate later packets with a hash mismatch remain separately blocked.

Current finalization permits one denied read only and rejects the noun “approval” even inside neutral preliminary text. The proposed receipt remains strictly non-authorizing: it archives exact failure evidence and opens only the existing normal same-session ask route. It creates no report or approval, replays no request, resets no accounting and asserts nothing about billing.

## Proposed acceptance predicate (requires independent design APPROVE before implementation)

Keep the original identity/binding checks for caller, repository, head, packet inventory hash, prompt hash, stream hash, invocation identity, unsignaled wrapper completion, process-exit-zero and original session byte-for-byte. Only the explicitly specified native-stream classifier below changes. Existing successful reconciliation is unchanged.

The native stream must satisfy all these conditions:

1. Every event is an object belonging to exactly the retained session. Event types stay restricted to step_start, step_finish, text and tool_use. Every start/finish part has the proper type. There must be one or more balanced steps; a step_start opens one step and step_finish closes it, with no nested starts, no orphan finishes and no text/tool outside an open step. Every finish reason is tool-calls, never stop, error, aborted or unknown. Thus no successful review completion is accepted by this failure route.
2. Tool events must be complete native tool parts. Before the failure suffix, completed tool events are permitted exactly as today. Error count is bounded to one, two or three. Every error must be `read` with exact error text `The user rejected permission to use this specific tool call.`. Other tool errors, additional unknown errors and any fourth denial refuse.
3. The error events must be consecutive, in the final open step, and occupy the entire suffix immediately before its final step_finish, which must be the last event in the stream. No text, completed tool, start/finish, successful tool output or other event may intervene after the first denial. Earlier steps may contain completed tools but no earlier errors.
4. Preliminary text must remain non-verdict-like. Preserve the existing forbidden VERDICT/DECISION/APPROVE/APPROVED/REJECT/STOP checks. Permit only the precise neutral noun phrase `approval evidence` (case-insensitive, word-bounded) by removing that phrase for the existing forbidden-word check; any remaining standalone APPROVAL still refuses. In particular `VERDICT: APPROVE`, `I approve`, `Approved`, `approval granted`, `final approval`, `DECISION: ...`, rejection and stop tokens continue to refuse. No text follows the first denial regardless of wording.

The denial boundary and tool permissions do not change. We do not make outside-copy reads available; the repair is truthful classification of an already-ended failure with exact retained proof.

## Preventing misleading reviewer paths

The reviewer-facing packet manifest should identify `.` as the only repository root for tool reads and use repository-relative file paths. It should explicitly say original host paths in older conversation history are identity metadata, not accessible read targets. The original full source identity remains unchanged and sealed in identity.json and snapshot markers; no previous packet is rewritten. Neither the source checkout absolute path nor the current snapshot absolute path appears as a reviewer navigation instruction in the new manifest; both identities remain available in sealed identity metadata. This is presentation of the existing boundary, not a new permission or source-identity model.

## Required tests

- End-to-end wrapper fixtures: exact single denial, two and three consecutive denied reads after a successful prior step, same-session fresh follow-up after non-authorizing finalization (a new ordinarily authorized provider invocation, never replay of the old invocation), and neutral approval-evidence preamble.
- Negative native streams: four errors, a generic tool error, a denied bash/write/list tool, a completed tool or text between denials, error in an earlier step, a new step after denial, stop/error finish, nested/unbalanced steps, wrong session, explicit verdict text and non-neutral approval wording.
- Update `tests/test-ai-muse.sh` existing `failedturn-multiple-errors` fixture: it currently constructs exactly three consecutive denied reads and must become an explicit positive case; add a four-denial negative instead. Add focused native part-type, unknown-event and outside-open-step negatives.
- Update `skills/shared/ask-muse/SKILL.md` and the recovery section of `docs/muse-opencode.md` from the singular sole-error condition to the exact bounded denied-read suffix. Update `tests/test-ai-review-packet.sh` old absolute-checkout navigation assertion to verify unchanged original identity.json instead.
- Existing original process/signal/time/source/caller/engine and retained prompt/stream/packet tamper tests remain green. Dry-run must modify nothing and contact no provider. Finalization preserves original descriptor archive and incomplete report and produces no accepted review.
- Packet tests prove in-copy relative navigation remains available, original identity is unchanged, host worktree paths are not emitted as tool-readable roots, and outside-copy read protections remain unchanged.
- Run full affected Muse, Muse Code and packet suites and shared-packet regressions. Independent exact-head review gates shipment; supported exact-merged-target installation and real original-session recovery remain coordinator-owned follow-up gates.
