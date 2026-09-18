# Implementation plan: TypeSafe Jev as a bounded decision layer

**Tracking issue:** not yet filed  
**Owner:** Albert Hazan  
**Handoff:** retire on completion or on rejection at the go/no-go gate

## STATUS

| Step | Status | Last updated | Evidence |
|---|---|---|---|
| 1. Confirm Jev is real, and what it actually guarantees | ✅ complete | 2026-09-18 | Section 3 below |
| 2. Register the API key reference (no value in the repository) | ✅ complete | 2026-09-18 | Vault item `typesafe.ai API` (API Credential); key is in field `credential` (non-empty, 108 chars; value never printed). `config/mcp.env.example` line active; resolved via `op run` on hetz → `PASS len=108` |
| 3. Reachability probe from one machine | ✅ complete | 2026-09-18 | `bin/ai-jev-probe` (self-resolves via `op run`, 10s connect / 20s call timeout, fails loudly on empty key). Live on hetz: printed `ok` in 1.1s; the API reported model `jev-1.13.0`, response shape `answers.<id>.noul`. Offline guards: `tests/test-ai-jev-scripts.sh` 6/6 |
| 4a. Track A: confirm upstream #33/#34 landed, then single-machine compaction trial | ⛔ gate not met — stopped | 2026-09-18 | Upstream issues #33 and #34 are both OPEN. Fixes exist only as unmerged PR #44 (bounded concurrency) and PR #45 (deadlines/cancellation); #28, #30, #35, #36 also still open. No upstream commit contains both fixes, so nothing was installed. Re-check when #44 and #45 merge |
| 4b. Track B: shadow-mode evaluation on completion-honesty checks | 🟡 tool built, awaiting real traffic | 2026-09-18 | `bin/ai-jev-completion-shadow` replays Stop payloads through the existing hook and one Jev `Noul` question at a 0.91 floor; logs hashes and verdicts only, outside the repo; outage/uncertainty = `escalate`. Synthetic 7-item run worked end to end. Real-traffic replay NOT run: sending transcript text to TypeSafe needs Albert's approval. Note: the existing hook matches "nothing pending" closings, not "done without evidence", so some disagreement is scope difference, not error |
| 5. Go/no-go per track on promoting anything to enforcing | ⬜ not started | — | — |

**Workstream state:** evaluation only. Nothing in this plan authorizes Jev to
decide anything in the reviewer safety path, a task gate, or the shared-db
workflow until step 5 passes.

## 1. Ultimate goal

Cut cost and wall-clock time on the many small, typed, yes/no and
pick-one-of-N judgements this toolkit currently spends frontier-model calls on
— without weakening a single safety gate. If a step conflicts with that second
clause, the second clause wins. Stop and flag the conflict.

## 2. Why this repository would consider another provider at all

`AGENTS.md` requires that a new provider copy justify itself against reuse.
The justification here is not "another model." It is a different *class* of
call. Every existing provider wrapper (`ai-glm`, `ai-deepseek-agent`,
`ai-qwen`, `ai-grok-review`, the Claude and Codex reviewers) invokes a
generative model that returns prose we then have to parse, trust, and
occasionally re-ask. Jev returns a typed value from a fixed set and cannot
return anything else. No existing wrapper can serve that need, because none of
them have a provider that structurally cannot emit malformed output.

**Retirement path:** if step 5 is a no-go, delete this plan, the commented
reference line, and any probe script; nothing else will have been wired.
If it is a go, the decision layer is owned by the reviewer-reliability
workstream (`plan_reviewer-reliability-and-efficiency.md`) and this plan is
retired into that one rather than living on as a second home.

## 3. What Jev is, verified

Launched 2026-09-15 by TypeSafe AI. A "System One" decision model: it does not
generate text, write files, or hold a conversation. It takes state plus a typed
question and returns a value.

- **Question types:** `Choice` (one of N, with per-option probabilities),
  `Score` (against ordered descriptive levels), `Noul` (binary, returns the
  probability of yes). All three return a calibrated confidence.
- **API:** `POST https://api.typesafe.ai/v1/systemone`, model `jev-latest`.
  Official Python and JavaScript SDKs.
- **Latency:** 70–500ms end to end, published.
- **Cost:** $0.042 per 1M input tokens, output unmetered. Roughly $0.0004 per
  decision.

### What is verified versus what is vendor marketing

- **Structurally true:** it cannot return malformed output. It does not emit
  tokens that we parse; there is no JSON to be wrong. This is the entire
  reason to consider it.
- **Vendor claims, not independently benchmarked:** "193.6x faster, 444.6x
  cheaper" is TypeSafe's own peak in-house testing. Treat as marketing.
- **Commonly misread:** the guarantee is about *format*, never *judgement*.
  Jev can be confidently wrong. Any gate built on it must treat a Jev answer
  as a signal, never as evidence.

## 4. Where it fits this toolkit, and where it must not

Three candidate tracks. They are **independent, not ranked against each
other** — they share one API key, one vendor relationship, and this plan, but
they touch unrelated parts of the system and can proceed in parallel. Track A
is sequenced first only because it pays off soonest and cannot corrupt a
decision; that is an ordering argument, not a reason to drop the others.

### Track A — context compaction (`fast-jev-compaction`)

A third-party Claude Code plugin and npm package
(https://github.com/tamaratran/fast-jev-compaction, MIT) that replaces Claude
Code's built-in compaction. Rather than summarising old turns, it asks Jev to
score every tool call and tool result, then deletes or truncates the stale
ones and leaves everything it keeps **verbatim**. User and assistant text is
never rewritten.

Two reasons this fits measured reality in this repository:

- `docs/ai-spend-waste-analysis-2026-09-04.md` measured that tool traffic is
  most of what accumulates (52.5% of Claude characters, 70% of Codex
  characters; worst single offender `sed`, 3,435 calls, 78% of its output
  oversized), and that turns past 200 were 40% of activity but 66% of input
  tokens. Stale tool output in long sessions is exactly what this deletes.
- Delete-or-keep-verbatim is structurally safer than summarisation for a
  repository whose gates demand named evidence. A summary can silently lose an
  exact error string, a file path, or a failing command; this cannot rewrite
  them, only drop them whole.

**Risk and its mitigation.** The failure mode is quiet: a misjudgement drops
something needed, with no error, and the session simply forgets a constraint.
The mitigation is a high confidence floor, applied in the safe direction —
**delete only on high confidence that an item is stale; retain on any
uncertainty.** The inverse framing ("keep only when confident it matters")
uses the same number and deletes everything uncertain. This is not
hypothetical: upstream issue #30 is "Reject keep thresholds that discard even
a certain keep decision," so threshold handling there has already been wrong
in that exact direction. Read the setting, do not assume it.

A confidence floor is only worth its number if the model is calibrated on
*our* traffic. Vendor calibration claims are unbenchmarked. Verify against the
transcript archive rather than assuming: replay real sessions, apply the
threshold, and check whether the deletions above the floor were in fact safe.

**Maturity, as of 2026-09-18.** 2.2k stars, roughly 30 commits. Open issues
cover unbounded concurrent Jev requests (#33), no request deadline or caller
cancellation (#34), an auto-compaction lock acquired too late (#35), logging
failures breaking the fallback path (#36), and malformed-answer and
control-flow race handling (PR #28). `AGENTS.md` requires bounded, rate-limited
outbound calls, so #33 and #34 are not cosmetic here. Confirm both have landed
before installing; otherwise pin a commit that has them, or wait.

**Trial scope:** one machine (`edge-dev`, which is where the spend measurement
came from, so there is a real baseline to compare against). Not installed by
`ai-install-skills`, not added to managed config, nothing committed that other
machines pick up. A wider rollout is a separate decision with its own
evidence.

### Track B — completion-honesty checks

`plan_completion-honesty-enforcement.md`. "Does this turn claim completion
without naming installed evidence?" is a textbook `Noul` question. A wrong
answer costs one redundant human look, which is why this is the first
*decision* use to prototype. Shadow mode first: it runs alongside the existing
check and records agreement and disagreement only.

### Track C — reviewer and gate routing

"Does this change set touch the reviewer safety path?" (`Noul`), "which task
class does this work actually belong to?" (`Choice`). Higher value than Track
B, and higher blast radius. Not before Track B has produced shadow-mode
evidence.

**Excluded, permanently:**

- Anything on the shared-db structural path.
- Anything that would *replace* an independent review. A probability is not
  a review, and `AGENTS.md` requires reviewers that can show their reasoning.
- Any gate that would open on a Jev answer. Jev may only ever *close* a gate
  early or *escalate*; a protected class stays protected.

## 5. Non-negotiable design constraints

- **Fail closed.** If the API is slow, down, or returns low confidence, the
  check escalates to the existing human or frontier-model path. A vendor
  outage must never quietly turn a check into a pass. This is the main new
  failure mode a single early-access vendor introduces.
- **Shadow mode first.** Every check runs alongside the existing path and only
  records agreement and disagreement. Nothing changes behavior until step 5.
- **The key never enters the repository, a prompt, a report, a command
  argument, or a settings file** — the same rule already enforced for
  `ZAI_API_KEY`, `DEEPSEEK_API_KEY`, and `BAILIAN_CODING_PLAN_API_KEY`.
  Self-resolved at exec time via `op run`, as `ai-deepseek-agent` does.
- **Loud on empty.** An `op` reference to a missing or empty field returns the
  empty string with exit status 0. This repository has been bitten by that
  before (see `ZAI_API_KEY` in `config/mcp.env.example`). Any wrapper fails
  loudly on an empty key rather than sending an unauthenticated request.
- **Bounded calls.** A connect timeout and a call timeout, as the other
  provider wrappers already set.

## 6. Step 2 — resolved 2026-09-18

Historical note kept for context: the guessed reference `TypeSafe Jev API/credential` was wrong; the real title is `typesafe.ai API`.


`config/mcp.env.example` carries the `TYPESAFE_API_KEY` line commented out.
Activating it needs two non-secret facts that only the vault can supply: the
exact 1Password item **title**, and the exact **field label** holding the key.
A guessed reference resolves to an empty string silently, so the line stays
commented until both are confirmed.

## 7. Backtest results, 2026-09-18 (owner-approved; transcript text sent to TypeSafe, none committed)

**Track B (150 real Claude session endings, hetz, floor 0.91).** Jev confident on
73, unsure on 77 (median p of the unsure = 0.19, so most lean "clean" but miss
the bar). Of the confident ones: 68 agree with the existing hook, 5 disagree.
All 5 were closings that list open work and say "nothing needed from you": the
existing hook flags that phrase; Jev correctly says they are not unsupported
"done" claims. The two checks answer different questions; neither was wrong.
The highest unsure scores (0.83-0.90) included real "that's what I fixed"
closings with no named evidence that the existing hook misses. Next: tune the
question wording and test a lower floor for the *flag-only* direction.

**Track A calibration (6 longest local sessions, 300 old tool outputs).** At a
point 60% through each session, Jev was asked whether each older tool output
was safe to delete; "used later" = at least 3 distinctive tokens from it
(paths, identifiers) reappear afterwards. 82 of 300 were used later.

| delete when p(stale) >= | items deleted | of those, used later |
|---|---|---|
| 0.50 | 155 | 34 (22%) |
| 0.80 | 2 | 0 |
| 0.91 | 0 | 0 |

At Albert's 0.91 floor Jev deletes nothing, so it is safe but saves nothing;
at 0.50 it would discard needed material one time in five. Jev is not
confidently calibrated on our traffic for this question. Caveat: this used our
own question wording, not the plugin's; rerun with the plugin's prompt before
the edge-dev trial.

## 8. How fast-jev-compaction actually decides (source read 2026-09-18)

Read from `src/compact.ts` and `src/state.ts` at upstream HEAD:

- It asks two `Noul` questions per old tool call: "should this **call** stay"
  and "should this call's full **output** stay verbatim". The probability is
  **p(keep)**, not p(stale).
- `decideCall` keeps the output when `keepResult >= keepThreshold`, otherwise
  drops it (keeping a 300-char head and a note). Default `keepThreshold` is 0.5.
- **Albert's rule "delete only when 91% sure it is stale" is
  `keepThreshold: 0.09`.** Setting 0.91 is the inverse: it would delete every
  output Jev is less than 91% sure is still needed, which is most of them.
- Jev never sees the tool outputs. The state is the conversation history with
  each output replaced by `ok, N chars (omitted)`, plus the last three user
  requests as the goal, fitted into about 25k tokens.
- A failed Jev call is treated as keep for everything (`?? {keepCall: 1,
  keepResult: 1}`), which is fail-safe. Batches still run through an unbounded
  `Promise.all` (#33) with no deadline (#34).

The section 7 Track A numbers used our own question and showed Jev the
output text, so they do not predict the plugin's behavior. The rerun with the
plugin's exact state and questions is written and ready; it was stopped by
the session's safety filter before sending any transcript text.
