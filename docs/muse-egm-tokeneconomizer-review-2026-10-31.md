# Muse evaluation — EGM, TokenEconomizer and our implementation plans

Owner: the coordinator of [#2227](https://github.com/popcre/ai-devops/issues/2227).
Purpose: retain the corrected independent assessment and small-pilot consensus,
without confusing plans with running software. Maintain this as a decision
record; the two implementation plans remain the execution authorities.

Continuation: [small-trials handoff](../HANDOFF.d/2026-11-01T0208Z-edge-dev3-codex-small-trials-handoff.md).
Children: [TokenEconomizer #2220](https://github.com/popcre/ai-devops/issues/2220)
and [fresh reader #2222](https://github.com/popcre/ai-devops/issues/2222).
Plans: [optimizer](../plan_tokeneconomizer-desktops.md),
[fresh reader](../plan_selective-fresh-reader.md). Keep them separate.

## Evidence and limits

Muse Spark 1.3 Contributor reviewed pinned public upstream source, then our
plans, using the existing read-only private-copy second-opinion route. Source
baseline: [e701c9fb](https://github.com/popcre/ai-devops/commit/e701c9fb299427f40c170dd40838e40b5cbb5ce5).
Pinned upstream inputs:

* [EGM 403d8881](https://github.com/google/elephant-goldfish-model/tree/403d8881d62022490637d740657b33f01e321ea8).
* [TokenEconomizer c53a4a6](https://github.com/microsoft/TokenEconomizer/tree/c53a4a6dcdebaeb9df6fcaa5c7026f0401cd8f23).

The corrected review received all 227 EGM files and 267 TokenEconomizer files;
the coordinator verified byte-identical copies before relying on it. The first
attempt omitted optimizer source because the toolkit's filename ignore pattern
matched its directory. That incomplete verdict was discarded. The corrected
complete review was followed by a targeted evidence challenge; the final verdict
was **APPROVE for narrow qualification pilots**, not approval of installation,
runtime behavior, platform support or savings.

Neither program was implemented or installed by this session. No native desktop
trial, benchmark reproduction or savings measurement ran. CLI observations on
Ubuntu edge-dev3 at 9:41 PM EDT October 31, 2026 were Codex
`0.166.0-alpha.5.1` and Claude Code `2.1.309`; these are not desktop embedded
engine versions. The review's conclusions are static source/plan assessment.
No private transcripts, portable-memory contents or secrets were supplied.

## Agreed program fit

**EGM:** pilot only its single paraphrase-first comprehension idea for selected
complex plans/handoffs. The full five-stage review and nested reviewer loops do
not earn their cost for routine work here. Native Codex/Claude routes must prove
no-history invocation, actual input/read evidence, and exclusion of ambient
memory/optimizer state. A new conversation alone is insufficient.

EGM's [Codex integration guide](https://github.com/google/elephant-goldfish-model/blob/403d8881d62022490637d740657b33f01e321ea8/docs/codex.md)
distinguishes its ChatGPT desktop package from Codex integration. Do not infer
Codex Desktop support from ChatGPT desktop support, or any desktop support from
a CLI example. Missing native proof means unverified, not demonstrated failure.

**TokenEconomizer:** qualify the advisory loop guard and LLM-free environment
facts separately on one applicable Ubuntu surface first. Keep automatic tool
pruning off. Keep model-generated memory/proposer processing off unless the
existing privacy policy admits it; synthetic/public-session qualification does
not authorize private transcript ingestion. No global tool removal, forced
termination, vendor patch or custom unsupported adapter.

The [pinned README](https://github.com/microsoft/TokenEconomizer/blob/c53a4a6dcdebaeb9df6fcaa5c7026f0401cd8f23/README.md)
records a validated Codex range ending at `0.164.0`; the observed `0.166` alpha
needs current qualification or a documented supported re-pin. This is version
skew, not proof of incompatibility and not permission to downgrade the app.
Historical MiMo/ZCode limitations require current native rechecking. No qualified
route presently established is an honest result; do not substitute another
engine and label it desktop proof.

## Agreed plan assessment and refinements

Muse's final conclusion: neither plan has a blocker to a narrow qualification
pilot as written. The coordinator agrees. Both plans already preserve scope,
independent acceptance, private evidence, capabilities, cost honesty, restoration
and parent-owned combined compatibility.

Useful execution refinements, not new merge/review gates:

1. Record the known Codex skew in the current inventory, then qualify the actual
   app and embedded runtime. Discover the live agent schema; do not hard-code
   a parameter name that the running version does not support.
2. Name the native reader proof explicitly: launch/schema record, visible input
   inventory, declared safety/project-instruction sources, successful required
   reads and effective settings/state roots. Hidden platform instructions remain
   unknown; never demand their inaccessible text or pretend to hash them.
3. Track style-only/nonactionable feedback and author effort as well as useful
   findings. Pre-register an advisory-noise criterion before the first real
   artifact. No automatic extra reader rounds to chase stylistic perfection.
4. After current applicability and privacy audit, run at most three synthetic
   baseline/treatment pairs for each selected optimizer mechanism on the first
   supported isolated Ubuntu surface before building the managed installer
   matrix. This is a learning smoke, not proof of general savings. The original
   ten-pair-per-adopted-desktop cost gate remains later, if the smoke justifies it.
5. Balanced alternation and frozen cache conditions already exist. Randomized
   starting order is optional if predeclared. Missing counters do not become zero
   or get silently dropped; leave acceptance incomplete and use only the plan's
   bounded, documented measurement-error rerun.

## Findings corrected or withdrawn after coordinator challenge

* App and embedded-engine versions were already required by optimizer step 1.
* Cache state, cache-token counters, priced overhead and unknown-counter handling
  were already required by optimizer step 6. There was no missing-cache-accounting
  defect; randomization is an optional refinement.
* The positive Windows contract already requires an official loader and native
  lifecycle/configuration/payload support, plus current version and event proof.
* Parent issue ownership comments and one writer per shared file are sufficient;
  no new lock registry, atomicity claim or PR waiter for file locks is required.
* Exact hashes of inaccessible platform/system prompts are not a feasible test.
* Out-of-range versions and historical missing hooks do not prove current
  incompatibility. Requalification is already the plan's answer.

## Continuation and closure conditions

Use the linked handoff's ordered trial instructions. Standalone trials stay
separate, each on its existing child issue. Combined proof stays on #2227 and
must show ordinary author optimization still works while reader context and
events remain excluded. A combined smoke is not a joint savings benchmark.

All implementation and live-proof items remain open. A running-implementation
review can occur only after there is a real implementation and native evidence.
No new review service, application deployment or database work is justified by
this decision record. Read-only review and source acquisition are not adoption.
