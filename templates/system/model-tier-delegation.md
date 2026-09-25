# Model-tier delegation

Frontier sessions plan, spec, and verify. Lower-tier sessions implement. This
sheet is the single routing authority for that split — the client globals point
here and carry no routing rules of their own.

## The rule

When you, a frontier session, hold an implementation plan that passes
[`templates/system/implementation-plan-standard.md`](implementation-plan-standard.md)
and the remaining steps are mechanical, dispatch them to your harness's lower
tier and verify the result yourself. Money is saved on every planned task;
quality does not change, because every step keeps its verification gate and the
session that wrote the plan is the one checking the result.

| Harness | Frontier (plans, verifies) | Lower tier (implements) |
|---|---|---|
| Codex | GPT-5.6-Sol (medium) | GPT-6 Luna when the plan exposes it; today `gpt-5.6-luna` |
| ZCode | GLM 5.3 MAX | GLM 5.3 Flash |
| MiMo | Mimo v2.6 pro | Mimo v2.6 flash |

Judgment-heavy work stays on the frontier tier by design — read the
do-not-handoff list before dispatching anything.

## Handoff checklist

All four must be true before you dispatch a single step:

1. The plan passes `templates/system/implementation-plan-standard.md`
   (zero questions, concrete files, per-step gates).
2. Every remaining step has its verification gate named.
3. The remaining work is mechanical: named files, named edits, runnable checks.
4. No remaining step appears on the do-not-handoff list below.

If any item fails, the work is frontier work. Fix the plan or do the step
yourself — never loosen the checklist to justify a handoff.

## Do-NOT-handoff list

Never dispatch to the lower tier:

- Architecture or judgment calls.
- Security review.
- Cross-repo design.
- Anything touching production or the shared database — shared-db work has
  its own governed route.
- Ambiguous steps, or steps a new session could read two ways.
- Trust-boundary work whose adversarial-cases table is missing.
- Any step whose gate the lower tier cannot run itself.

## The verification duty

The frontier session verifies; the lower tier never grades its own work.

- Run every step's gate on the lower tier's result yourself before anything
  lands.
- A failed gate goes back to the lower tier exactly once, with the failing
  check quoted. If it fails again, implement the step yourself.
- You own the commit and the pull request either way. An unverified
  lower-tier result cannot land.

## The implementer-agnostic rule

- Implementation plans never name their implementer. The model lineup rotates;
  implementer-named plans stale-date immediately.
- This sheet is the only routing authority. If a plan seems to require a
  specific implementer, that is a defect in the plan — fix the plan instead of
  naming an implementer.

## Per-harness dispatch table

Rows verified 2026-09-25 (read-only review; Codex slug live-probed the same
day); evidence quoted in
[issue #782](https://github.com/popcre/ai-devops/issues/782#issuecomment-5827260474).
Anything not proven stays marked unverified — never guess a command.

| Harness | How to dispatch | Status |
|---|---|---|
| Codex → Luna | `codex exec -m gpt-5.6-luna` — the only Luna the ChatGPT plan accepts today (probe returned `PONG`). Also `-c model="…"`. `~/.codex/config.toml` pins a frontier default, so pass `-m` explicitly | Two live probes 2026-09-25 (quotes on #782): `gpt-6-luna` (new generation) rejected — "not supported when using Codex with a ChatGPT account"; `gpt-5.6-luna` works headlessly (levels up to `max`, no `ultra`). Re-probe `gpt-6-luna` when the lineup updates; never guess slugs |
| ZCode → GLM 5.3 Flash | Manual: open the ZCode app, switch the model to GLM 5.3 Flash, hand it the plan file path | Verified impossible 2026-09-25 on the newest CLI core (0.16.9): no `--model` flag, config `defaultModelSelection` ignored in headless runs, app-server registry has no subscription provider (evidence on [#828](https://github.com/popcre/ai-devops/issues/828#issuecomment-5837096435)). Retest when a newer core advertises a model flag |
| MiMo → Mimo v2.6 flash | Manual: open the Xiaomi MiMo AI app, select Mimo v2.6 flash, hand it the plan file path | No `mimo` CLI on PATH; gap tracked in [#829](https://github.com/popcre/ai-devops/issues/829) |

When a gap issue closes with a supported selector, update this table in the
same change that lands it.

## Failure modes and responses

- Lower tier skips a gate → send the step back once with the gate quoted, then
  run the gate yourself after the retry.
- Lower tier improvises beyond scope → revert the extra edits, re-dispatch the
  step once with the scope restated.
- Lower tier silently "improves" the plan → treat it as a failed step and
  implement the step yourself. Never merge unplanned edits.
