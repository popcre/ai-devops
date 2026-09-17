---
issue: 542
status: OPEN
owner: claude/ai-muse-native-engine-parity-plan
---

# HANDOFF — ai-muse native-engine parity plan (2026-09-17 14:16 UTC, edge-dev, Claude)

The executable plan is [`../plan_ai-muse-native-engine-parity.md`](../plan_ai-muse-native-engine-parity.md)
(tracking issue [#542](https://github.com/popcre/ai-devops/issues/542)). **Read
its STATUS table first.** Phase 0 and Phase A are done with artifacts; B, C, D
remain open.

## What this workstream is

Close every wrapper-closable gap between the opt-in native Muse Code engine
(`AI_MUSE_ENGINE=muse-code`, PR #529) and the default OpenCode engine, add the
worthwhile native-only extras (reasoning effort, first-party catalog truth,
durable-store deletion hygiene), live-qualify the engine, update shared-db's
`REVIEWERS` evidence, then flip the default. Owner decision: Albert, 2026-09-17.

## Next exact action

Phase B (first-party catalog truth), in a fresh session and worktree under
`ai-task-gates start --class reviewer-safety`: B1 doctor catalog checks, B2
catalog-priced estimate in the `muse-code` adapter, B3 tests — all per the
plan's §9 Phase B. Phase A landed as PR #554 (merge `8e1426f5`). Before
editing `bin/ai-muse`, re-check whether
`claude/muse-cred-lock-wait-20260917` (PR #540) has landed and cut the worktree
from the then-current `origin/main`.

## Decisions only the owner can make

None outstanding. Already settled — do not re-ask:

- **2026-09-17, Albert:** switch to the native CLI once the wrapper has closed
  all closable gaps and gained the useful missing functionality; OpenCode
  stays installed as the explicit-engine fallback.

## Traps for whoever continues

- `bin/ai-muse` is hot: the credential-lock branch (PR #540, `load_key` +
  `tests/test-ai-muse.sh`) is still open — cut from current `origin/main`,
  keep hunks disjoint, let the merge queue serialize, and re-run the full muse
  suites before requesting review.
- The durable store and model-catalog formats are internal to pinned build
  `1.3.0-R3233.1` — fail closed on any shape mismatch; never guess counters.
- Every phase PR is reviewer-safety class: independent read-only exact-head
  review before merge is mandatory.
