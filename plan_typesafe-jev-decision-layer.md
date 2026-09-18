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
| 4. Shadow-mode evaluation on completion-honesty checks | ⬜ not started | — | — |
| 5. Go/no-go on promoting any check to enforcing | ⬜ not started | — | — |

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

**Candidate uses, in order of safety:**

1. **Completion-honesty checks** (`plan_completion-honesty-enforcement.md`).
   "Does this turn claim completion without naming installed evidence?" is a
   textbook `Noul` question. A wrong answer costs one redundant human look.
   This is the only use that should be prototyped first.
2. **Reviewer and gate routing.** "Does this change set touch the reviewer
   safety path?", "which task class does this work actually belong to?" —
   `Noul` and `Choice` respectively. Higher value, higher blast radius.

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
