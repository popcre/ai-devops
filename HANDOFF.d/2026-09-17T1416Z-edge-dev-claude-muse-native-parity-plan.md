---
issue: 542
status: OPEN
owner: claude/ai-muse-native-engine-parity-plan
---

# HANDOFF — ai-muse native-engine parity plan (2026-09-17 14:16 UTC, edge-dev, Claude)

The executable plan is [`../plan_ai-muse-native-engine-parity.md`](../plan_ai-muse-native-engine-parity.md)
(tracking issue [#542](https://github.com/popcre/ai-devops/issues/542)). **Read
its STATUS table first.** No implementation has started; every row is open.

## What this workstream is

Close every wrapper-closable gap between the opt-in native Muse Code engine
(`AI_MUSE_ENGINE=muse-code`, PR #529) and the default OpenCode engine, add the
worthwhile native-only extras (reasoning effort, first-party catalog truth,
durable-store deletion hygiene), live-qualify the engine, update shared-db's
`REVIEWERS` evidence, then flip the default. Owner decision: Albert, 2026-09-17.

## Next exact action

Phase 0A: check whether the credential-lock wait branch
`claude/muse-cred-lock-wait-20260917` (worktree
`C:\repos\ai-devops-wt-muse-lock-0917`, another live session's work) has
landed; then start Phase A (usage telemetry) in a fresh worktree under
`ai-task-gates start --class reviewer-safety`.

## Decisions only the owner can make

None outstanding. Already settled — do not re-ask:

- **2026-09-17, Albert:** switch to the native CLI once the wrapper has closed
  all closable gaps and gained the useful missing functionality; OpenCode
  stays installed as the explicit-engine fallback.

## Traps for whoever continues

- `bin/ai-muse` is hot: the credential-lock branch edits `load_key` and
  `tests/test-ai-muse.sh`; do not start Phase A's wrapper edit before it lands.
- The durable store and model-catalog formats are internal to pinned build
  `1.3.0-R3233.1` — fail closed on any shape mismatch; never guess counters.
- Every phase PR is reviewer-safety class: independent read-only exact-head
  review before merge is mandatory.
