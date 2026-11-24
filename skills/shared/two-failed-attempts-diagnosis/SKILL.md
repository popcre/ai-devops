---
name: two-failed-attempts-diagnosis
description: Use when the same technical symptom remains after two separately evidenced diagnostic or repair attempts and the request explicitly asks one outside reviewer for a read-only diagnosis while the primary session retains ownership.
---

# Reviewer-assisted problem solving

Use one healthy external reviewer as a bounded diagnostic partner. The primary
session keeps ownership of diagnosis, implementation, verification, and delivery.
This is advisory problem solving, never formal approval.

## 1. Qualify the escalation

Escalate only when either condition is true:

- two distinct evidence-based hypotheses or repair attempts failed against the
  same symptom; or
- focused inspection produced a material contradiction that the primary session
  cannot resolve from available evidence.

Do not use this route for a first failure, exploratory wide read, routine code or
plan review, a named-provider request, an external wait, missing authority, an
owner decision, or a reviewer-wrapper malfunction. Use `log-reviewer-issue` for
reviewer failures. A hard stop remains a hard stop; a reviewer cannot manufacture
permission.

## 2. Freeze a safe diagnostic brief

Give the reviewer only:

- desired behavior and the exact observed symptom;
- reproducible evidence and the two attempts or unresolved contradiction;
- constraints and the primary session's current best theory;
- current safe file paths or bounded excerpts; and
- one concrete diagnostic question asking for testable hypotheses,
  discriminating checks, and risks.

Never paste a raw chat, uncontrolled logs, secrets, credentials, licensed or
private source data, environment dumps, or process command lines. Summarize the
minimum safe evidence instead.

Template:

> Desired behavior: ...
> Symptom and reproduction: ...
> Evidence: ...
> Attempt 1 and result: ...
> Attempt 2 and result, or unresolved contradiction: ...
> Constraints and current theory: ...
> Question: Which testable hypothesis best explains this, what check separates
> it from the alternatives, and what repair risk should we guard?

## 3. Choose one eligible reviewer

Choose a different model or provider from the struggling primary session when
possible. Consult current health and quarantine evidence and run the provider's
existing preflight through its wrapper or skill. Do not invent a ranking and do
not fan out. Load and obey exactly one existing provider-specific skill, such as
`ask-glm`, `deepseek-second-opinion`, `grok-cli`, `kimi-code-delegation`,
`ask-muse`, or `qwen-code`.

The reviewer stays read-only. Use its analysis, architecture, or second-opinion
mode and a named session where supported. Do not ask for a generic verdict.

## 4. Evaluate rather than obey

Keep the reviewer conclusions visibly separate from established evidence.
Check each claim against repository or live evidence, reject unsupported advice,
and select the next diagnostic or repair action yourself. Any mutation uses the
original task authority and is performed by the primary session.

Evaluation record:

> Reviewer hypothesis: ...
> Supporting or contradicting evidence: ...
> Adopted, rejected, or still uncertain: ...
> Next check or repair performed by the primary session: ...
> Formal exact-head review still required: yes/no and why.

## 5. Bound the loop and hand back

Default to one diagnostic turn plus one focused follow-up using
`templates/delegation/debate-turn.md`. This bound overrides a provider skill's
larger ordinary debate allowance while this skill owns the escalation.

One alternate provider is allowed only when the first provider is unhealthy,
fails to return usable output, or leaves a material evidence-backed disagreement.
Never rotate reviewers to obtain a preferred answer.

Report which diagnosis was adopted or rejected, the confirming evidence, and
the next action taken. Diagnostic help never satisfies exact-head approval,
production acceptance, a database gate, testing, or live verification.
