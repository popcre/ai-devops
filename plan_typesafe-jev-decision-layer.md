# Implementation plan: TypeSafe Jev as a bounded decision layer

**Tracking issue:** not yet filed  
**Owner:** Albert Hazan  
**Handoff:** retire on completion or on rejection at the go/no-go gate

## STATUS

| Step | Status | Last updated | Evidence |
|---|---|---|---|
| 1. Confirm Jev is real, and what it actually guarantees | ✅ complete | 2026-09-18 | Section 3 below |
| 2. Register the API key reference (no value in the repository) | ⏸ blocked | 2026-09-18 | `config/mcp.env.example` line added but commented out; needs the exact 1Password item title and field label |
| 3. Reachability probe from one machine | ⬜ not started | — | — |
| 4a. Track A: upstream gate (#52 plus #33/#34/#30/#31), then single-machine compaction trial | ⛔ gated | 2026-09-18 | 12 open issues; PR #28 fixes 11 but is open and unreviewed; #52 not covered by it and measured 0/337 tool calls retained on defaults |
| 4b. Track B: shadow-mode evaluation on completion-honesty checks | ⬜ not started | — | — |
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

The intended mitigation is a confidence floor applied in the safe direction.
**Get the direction right — it is the opposite of the intuitive reading.** The
knob is `keepThreshold` and it keeps an item when its score is at or above the
threshold, so RAISING it deletes MORE. Conservative therefore means a LOW
`keepThreshold`, not a high one. Setting it to 0.91 against the scores
observed upstream (0.13-0.44, issue #52) would delete essentially everything.
Upstream issue #30 is a related defect: out-of-range thresholds are accepted
and then discard entries that were certain keeps.

A floor is only worth its number if the model is calibrated on *our* traffic.
Vendor calibration claims are unbenchmarked. Verify against the transcript
archive rather than assuming: replay real sessions, apply the threshold, and
check whether the deletions were in fact safe. Respect the private-data
boundary — transcripts are a private submodule and this repository is public.

**Upstream state as of 2026-09-18 — this is the real blocker.** 2.2k stars,
roughly 30 commits, 12 open issues.

Five are blocking for our use:

- **#52** — question wording hides Jev's signal, and late fitting stages strip
  non-pinned messages while still scoring them, so Jev judges calls it cannot
  see. Replay of a real 1084-message session retained **0 of 337 tool calls**
  on default settings. This is the exact silent-loss failure we care about,
  measured rather than hypothesised.
- **#33** — unbounded concurrent Jev batches; conflicts with the bounded-call
  rule in `AGENTS.md` (the rule that exists because of #401).
- **#34** — no request deadline or caller cancellation.
- **#30** — invalid keep thresholds discard certain keep decisions.
- **#31** — duplicate `tool_use_id` can delete PINNED content while the
  decision report still claims it was kept: silent loss that misreports itself.

Quality but not safety: #32, #35, #36, #38, #39. Irrelevant: #37, #54.

**PR #28 fixes 11 of the 12** (including #30-#36), 13 commits, 36 unit and 49
regression tests passing. It is **open, unreviewed, and authored by a
community contributor, not the maintainer**. No maintainer response appears on
any issue read, including #52 (which offers a replay script and a test branch)
and #54 (an unanswered README question). Treat this as possibly unmaintained
rather than as work in flight.

Critically, **#52 is not among PR #28's fixes**. Even if #28 merged, the defect
that makes the plugin delete everything on default settings would remain open.

**Gate before installing anything:** #52 resolved or a configuration proven on
our own replayed transcripts to retain sensibly, AND #33/#34/#30/#31 landed
(by merge, or by pinning a commit that carries them). If neither upstream
movement nor a proven local configuration exists, the honest answer is to
stop and report, not to install and tune.

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

## 6. Step 2, in detail — what is blocking

`config/mcp.env.example` carries the `TYPESAFE_API_KEY` line commented out.
Activating it needs two non-secret facts that only the vault can supply: the
exact 1Password item **title**, and the exact **field label** holding the key.
A guessed reference resolves to an empty string silently, so the line stays
commented until both are confirmed.
