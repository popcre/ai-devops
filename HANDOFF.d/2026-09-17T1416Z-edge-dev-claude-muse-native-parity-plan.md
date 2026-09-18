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

Phase C (native extras), in a fresh session and worktree under
`ai-task-gates start --class reviewer-safety`: C1 `AI_MUSE_REASONING_EFFORT`
support in `run_turn` (validate against the catalog's
`reasoning_effort_variants` when readable, refuse unknown tiers before any
provider contact, record the effective tier in `retained_turn`, args
byte-identical when unset) and C2 deletion hygiene
(`muse_code_delete_session` also removes the date-bucketed durable dir with
the same enter-verified-parent discipline) — all per the plan's §9 Phase C.
Phases A and B have landed: A as PR #554 (merge `8e1426f5`), B as PR #574
(merge `85df6d6e`; independent Grok 4.6 exact-head APPROVE, Codex quota
exhausted and the Claude reviewer account no longer exists — owner, chat
2026-09-18). For the pre-merge independent review use an available reviewer
(`bin/ai-grok-review` is proven; `ai-qwen` carries `--governed-verdict`), pin
the packet base with `--base <origin/main SHA>` so a concurrent fetch cannot
invalidate it, and keep the `--tests` command fast (the unit suite, not a
20-minute shell suite).

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
