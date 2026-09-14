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

On Windows through Git Bash, the Muse real-command phase fixtures passed
52/0/0 and the narrow Grok terminal/native-witness cases passed 30/0/0. These
counts are passed/failed/skipped. The complete Qwen owning suite passed 166
checks with zero failures on September 14; its summary does not report a skip
count. Its log is `.test-logs/bash-20260914T154535Z-279217/test-ai-qwen.sh.log`.
The complete Muse owning suite passed 159 checks with zero failures; its summary
does not report a skip count. Its log is
`.test-logs/bash-20260914T154352Z-266653/test-ai-muse.sh.log`. The full Grok
owning suite remains in progress; narrow cases are not full-suite acceptance.

Cross-review found that metadata presence alone did not prove whether Muse had
contacted the provider. The first full-suite attempt was interrupted to repair
that defect, not counted as a result. The replacement full run uses the
explicit phase checks exercised above.

The candidate Qwen compatibility path preserves pre-stderr recovery records
and privately publishes their sealed saved answer as INCOMPLETE, without an
authorizing verdict or a provider request. It does not invent missing error
evidence. This legacy-only restriction is awaiting the owner's decision;
partial version-2 metadata or orphan stderr is never treated as legacy.

The governed consumer's terminal mappings and DeepSeek terminal invocation
flag are a separately delivered repository-maintenance slice in shared-db.
Source-receipt integration remains #393. Both sides must agree on the stable
failure reason and reject a failed wrapper that prints a fake approval.

## Remaining delivery gates

Full owning suites, safety/parity verification, exact-head independent review,
required CI and merge queue, canonical installation, installed live checks,
consumer acceptance, and affected incident reconciliation remain pending.
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
