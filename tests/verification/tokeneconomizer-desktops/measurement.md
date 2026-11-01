# Separate optimizer smoke and cost ledger

Owner: the implementing coordinator on [#2220](https://github.com/popcre/ai-devops/issues/2220).
No baseline/treatment pair has run. The failed native authentication preflight
is preparation, not a measured treatment. Reader calls never enter these arms.

## Frozen tiny-smoke schedule, before results

Use the immutable upstream `c53a4a6dcdebaeb9df6fcaa5c7026f0401cd8f23` only after
native applicability/privacy/model access succeeds. Freeze the actual native
model ID/effort, OS/app/engine, synthetic repository commit, starting state,
supported profile aliases, cache conditions and success checks before warm-up.
The failed Claude preflight resolved `claude-opus-5-5`; any different resolved
model must be explicitly reconciled before a comparable pair, not silently substituted.

Run one baseline/treatment pair per mechanism in this initial smoke, within
the handoff's maximum of three. Loopguard pair order: baseline then treatment.
Facts pair order: treatment then baseline. Keep each mechanism's baseline state
independent and clean; do not copy learned treatment state into a baseline.
Do not pool costs or make a combined optimization claim.

The pinned normal loopguard thresholds require five clean resolved samples,
`gate_min_turns=18` and `min_turns=20`. Schedule exactly five clean native
edit/check warm-up turns, retaining every receipt and model cost. Then one
pair with twenty harmless repeated synthetic failures followed by the same
ordinary edit/check recovery. Keep facts, pruning and repomap off. The guard
may advise, never forcibly stop the turn. If native folding does not produce
the five clean samples or no expected signal appears, stop inconclusive; do
not add warm-ups or tune thresholds after seeing results.

Environment facts require `K_PROMOTE=3` confirmations and `FIRE_MIN_N=4`
exercised sessions with a firing rate of at least 0.40. Schedule exactly four
synthetic native learning sessions, each demonstrating one known harmless
setup failure and its successful supported repair, followed by the one pair.
Use `microskills=envfacts`, loopguard/pruning/repomap off. Confirm the detector
recognizes the chosen command/error shape before the first paid learning run.
If those four sessions fail to seed an injectable fact, stop inconclusive.
No model proposer is permitted. Four learning sessions are overhead, not free
history and not four extra matched pairs.

## Ledger contract

For every preflight, warm-up, learning session and arm, retain source/packet
hashes, model/settings/profile/state aliases, order and cache condition;
input, output, cache-read and cache-write counters; judge/proposer calls;
elapsed time; checks/output correctness; and unchanged capability results.
Do not discard an inconvenient arm or replace unknown counters with zero.
Native reported cost and cache-aware subscription-equivalent estimates are
different fields. Author/setup usage and any unavailable price are unknown.
At most the plan's one documented measurement-error rerun is allowed.

This tiny smoke yields proceed/reject/inconclusive/blocked, never a saving
percentage. Later adoption needs ten pairs per adopted app/host installation,
no additional task/check/capability loss, and at least 10% lower aggregate
priced cost including all optimizer overhead. No study or rollout is claimed.
