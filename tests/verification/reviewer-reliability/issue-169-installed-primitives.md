# #169 installed shared-primitives acceptance

Owner: #169 within reviewer programme #337. Verified on Windows, 2026-09-11.

The shared extraction merged in PR #381 as
`26e893db03754b6668238c266142f8e61abb01bc`. Its recorded Linux, four Windows
offline sections, and Windows reviewer fallback checks passed. The original
Windows reviewer lane was cancelled; the successful fallback is the executable
reviewer-safety evidence, not a claim that the cancelled job passed.

Only Kimi and Qwen migrated to the shared library. Both delegate name validation
and file hashing; the exact pre-extraction functions implement the same accepted
character set and `sha256sum`/`awk` pipeline. No lock, payment, terminal, retry,
uncertainty, or failure policy was moved into the library. The other seven
reviewers have no migrated primitive contract to qualify under this extraction.

## Installed proof

The canonical installed library and current merged source both hash to
`f63526bf3406cd41b0228b52444ab6128a188049c89c9015b9d8140524758bae`.
The existing fixture-adapter test ran against the installed canonical library:
accepted name, rejected spaced/empty names, and exact file digest all passed.
That adapter imports one library and calls its two primitives; it copies no
lock, process supervision, payment, or completion infrastructure.

The actual installed `ai-kimi.cmd` and `ai-qwen.cmd` launchers each refused a
synthetic spaced name with exit 1 and the expected invalid-session-name reason.
Code inspection confirms this refusal precedes repository locks and provider
submission in both adapters. No paid turn or credential inspection was needed.

The merged extraction diff was compared directly with the installed call sites.
Both still call the shared functions, while their provider-specific execution
contracts remain in their own wrappers. Subsequent source/evidence/recovery
changes have separate #393/#395/#397 acceptance and are not credited here.

A bounded audit examined 45 private `issue.json` summaries and found no record
specifically identifying shared name/hash extraction or invalid-name/repository-
hash behavior. No incident or frozen-round disposition was changed by that audit.

Kimi allocation, quarantine, cooldown and disposition follow-through belongs to
#396, as both child issue boundaries now state. GLM pending-turn recovery belongs
to #397. This acceptance does not resolve those incidents, classify any of the
frozen 198 maintenance entries, or close #337/#159.
