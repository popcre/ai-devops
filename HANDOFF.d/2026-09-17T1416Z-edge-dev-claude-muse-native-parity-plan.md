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

Phase D (qualification, evidence, flip), in a fresh session and worktree under
`ai-task-gates start --class reviewer-safety`, strictly D1-D4 in order per the
plan's Phase D. Phases A, B and C have landed: A as PR #554 (merge `8e1426f5`),
B as PR #574 (merge `85df6d6e`), C as PR #678 (merge `57170b62`, 2026-09-23;
independent Grok 4.6 exact-head APPROVE after one fixed REJECT round). D1 runs
real paid muse-code turns with a real review brief (the pattern of #2285);
use the wrapper's supported verdict option and note issue #622 if the review
tooling misbehaves. For independent reviews only `bin/ai-grok-review` (proven)
and `ai-qwen --governed-verdict` are available; pin the packet base with
`--base <origin/main SHA>` and keep `--tests` fast. Machine note (2026-09-23):
the 1Password `op` CLI alias disappeared from this machine (doctor fails that
line identically on main) and the Grok CLI auto-updated past the qualified
1.0.13 (restore with `grok update --version 1.0.13`).

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
