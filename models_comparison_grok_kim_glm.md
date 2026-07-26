# Grok 4.5, Kimi K3, and GLM 5.2 — observed coding-agent comparison

**Report date:** 2026-07-26  
**Prepared for:** Albert Hazan / POP Creations  
**Evidence base:** supervised work in `u2giants/shared-db`, principally the ColdLion licensor/property correction and cutover Phases 3–6  
**Models compared:** Grok 4.5 through Grok Build, Kimi K3 through Kimi Code, and GLM 5.2 through the isolated Z.ai/Claude Code agent

> **This file now holds TWO independent field reports on the same three models.**
> They were run on different projects by different supervising sessions, and they
> **do not fully agree** — which is itself the most useful thing in here.
>
> 1. **Report A (below):** ColdLion licensor/property cutover in `u2giants/shared-db`.
>    Concludes Grok is best overall and most autonomous.
> 2. **[Report B](#report-b--designflow-sample-tracking-2026-07-2425):** DesignFlow
>    Sample Tracking adoption across `popcre/designflow-tracking` +
>    `popcre/designflow-frontend`. Concludes **GLM** was best overall and most
>    autonomous, and rates Grok the **weakest implementer** of the three.
>
> Read both before routing a task. Where they disagree, Report B's
> "[Where this disagrees with Report A](#where-this-disagrees-with-report-a)"
> section explains why the task shape — not model quality alone — probably drove
> the difference.

## Executive conclusion

All three models were capable of serious repository work. None was best at everything.

- **Best overall for Albert's vibe-coding workflow: Grok 4.5**, provided another strong model reviews safety-critical work. It showed the best combination of speed, initiative, broad implementation ability, live debugging, and recovery.
- **Best production-code author for dangerous database work: Kimi K3.** Its Phase 4 implementation was the cleanest example of careful, exact, contract-driven execution.
- **Best specialist reviewer: GLM 5.2.** It was the most methodical architecture, SQL, permission, and contract reader, although it sometimes classified operationally important risks as non-blocking.
- **Smartest under ambiguity and changing evidence: Grok 4.5.**
- **Most thorough plan reader before implementation: Kimi K3**, with GLM close behind when acting as reviewer.
- **Most autonomous: Grok 4.5.**
- **Best practical bug finder during a live failure: Grok 4.5.**
- **Best safety checker for an exact data cutover: Kimi K3.**
- **Best architecture and privilege reviewer: GLM 5.2.**

The strongest operating pattern is not to choose one model exclusively. Use the model whose natural strengths fit the work, then have a differently strong model check it:

1. Grok implements broad integrations, automation, and uncertain debugging tasks.
2. Kimi implements high-risk migrations and exact data corrections.
3. GLM reviews architecture, SQL contracts, permissions, monitoring, and evidence design.
4. A second model always checks consequential work before merge or promotion.

## Important limits on this comparison

This is an evidence-based field report, not a controlled benchmark or a claim about permanent model intelligence.

The models did not receive identical tasks:

- GLM implemented Phase 3 and reviewed Phases 5 and 6.
- Kimi reviewed Phase 3 and implemented Phase 4.
- Grok reviewed Phase 4, documented the Phase 5 no-op decision, and implemented Phase 6 plus its live parser correction.

The tasks also differed in difficulty and kind. Phase 4 was a precise, high-risk database linking operation. Phase 6 was a much broader monitoring and workflow integration with live GitHub Actions behavior. Phase 5 deliberately required no programming. Consequently:

- Grok has the largest and richest implementation sample.
- Kimi has the strongest sample for exact database mutation, but fewer observed tasks.
- GLM has the strongest review sample, but less implementation evidence.

Ratings below describe what was observed in this engagement. They should be revisited after several more comparable rotations.

## The work used as evidence

### Phase 3 — GLM implemented; Kimi reviewed

Phase 3 was a reconciliation and decision phase. It had to:

- remain preview-only;
- avoid canonical and source-reference mutations;
- refresh trustworthy DesignFlow evidence;
- create a complete ruling ledger;
- freeze and hash the Phase 4 input;
- preserve the Phase 2B immutability baseline;
- avoid claiming that proposed automatic mappings were human-approved.

The finished work produced a deterministic row-level ruling ledger, correct entity-typed collision handling, frozen inputs, reproducible evidence, and offline tests. A particularly important correction was made to an earlier draft that had treated 542 exact-compatible mappings as already approved. The final Phase 3 state correctly separated:

- 542 proposed mappings;
- two pending NASA mappings;
- the unlinked and canonical-only cases;
- an empty approved input until Albert explicitly approved it.

This phase showed GLM's ability to absorb a large plan and produce structured evidence. Kimi's review role provided the independent safety check before the high-risk linking phase.

### Phase 4 — Kimi implemented; Grok reviewed

Phase 4 was the most exacting data-mutation task in the rotation. It had to link only the approved rows while proving that no canonical records, names, codes, statuses, parents, or UUIDs changed.

The completed implementation:

- consumed exactly 542 approved rows;
- linked 38 licensor rows and 504 property rows;
- attached them to 271 distinct canonical UUIDs;
- preserved all 505 existing DesignFlow source references;
- added 542 ColdLion source references;
- created zero canonical rows;
- left excluded and pending records unlinked;
- rehearsed rollback before committed apply;
- passed repeated idempotency runs;
- locked the approved input by hash, count, distinct count, target environment, and approver;
- rejected malformed JSON shapes and unauthorized browser execution.

The preview apply run was `875109b5-2ac9-41a9-8280-4c4a36f6b639`. Subsequent runs made zero changes and reported all 542 mappings unchanged.

The canonical immutability proof remained stable:

- 26 licensors;
- 256 properties;
- licensor UUID hash `590ea83ea6df1487fcfc1e18b3ef6a0d`;
- property UUID hash `e0e6c36eb02bb2d320c0deaff7aa8f8c`;
- licensor status hash `d9b07759bf80ff227e2fa9bd635d2138`;
- property status hash `f436d4acd79761fedbfc9b5796ac7bce`;
- property-parent hash `7459f6826cc59468779e7ead33ec0edc`.

This was the strongest evidence for Kimi as a careful production-code author. The task rewarded exactness, conservative interpretation, and exhaustive enforcement of a frozen contract. Kimi performed very well on all three.

### Phase 5 — Grok documented the no-op; GLM reviewed

Phase 5 existed only if Albert approved creating new canonical licensors or properties. He approved none. Therefore, the correct implementation was no implementation.

Grok correctly treated “Phase 5 is not needed” as an engineering outcome rather than inventing work. It documented why the create phase was blocked/not needed and preserved the boundary into Phase 6. GLM reviewed that conclusion.

This is a meaningful autonomy signal. Coding agents often feel pressure to produce code even when the plan says the safe answer is no change. Grok did not manufacture schema or data work merely to appear productive.

Because Phase 5 required no programming, it is not evidence of Grok's coding quality. It is evidence of scope discipline and correct no-op reasoning.

### Phase 6 — Grok implemented; GLM reviewed repeatedly

Phase 6 was the broadest task. It added preview-only parallel-run evidence, health monitoring, alerts, GitHub Actions scheduling, forced-failure drills, tests, and documentation. It had to preserve the exact Phase 4 baseline and start a 14-day observation gate without touching production.

Grok's initial implementation was a large vertical slice of roughly 3,180 added lines, including:

- an additive SQL migration;
- live database-computed evidence;
- alerting;
- comparison and health runners;
- preview guards;
- GitHub Actions scheduling;
- forced-failure drills;
- SQL contract tests;
- Node tests;
- verification documentation and a handoff.

GLM's first review was methodical and approved the work with no blockers. It specifically identified:

1. the workflow omitted a static guard test;
2. wall-clock cron-to-job mapping could misroute a delayed schedule;
3. CLI result parsing was best-effort and might fail on real output formatting;
4. several lower-priority maintainability and reporting concerns.

Independent supervision then found two more important design defects that GLM's first review missed:

1. Evidence used a date primary key with an upsert, so a rerun or drill could overwrite a green observation from the same day. That violated the requirement for immutable evidence.
2. The first observation could establish a new baseline from the current database. If drift had already happened, the system could silently accept the drift instead of comparing with the exact Phase 4 baseline.

Grok corrected both promptly:

- observations became append-only UUID-keyed records;
- drills were separated from real observations;
- the exact Phase 4 hashes and counts were pinned on every observation, including the first;
- health checks ignored drills;
- schedule routing used the exact `github.event.schedule` value;
- the missing static workflow test was added.

GLM's second review was stronger and more exact. It approved the corrections, verified the full migration and test suite, and identified one remaining evidence question: the separate licensor and property status hash encodings needed a live preview query because the repository did not contain their original producer query. The live query reproduced the pins exactly.

The initial live GitHub Actions comparison then failed despite the database recording a green observation. The Supabase CLI on Ubuntu rendered JSONB as a Unicode box table containing Go-style `map[...]` output. The runner's fallback parser could not interpret that real format and exited with code 2.

This incident is especially useful for assessing the models:

- GLM had predicted the parser risk, demonstrating good anticipatory review.
- GLM called it non-blocking/low-medium, underestimating its immediate operational impact.
- Grok diagnosed the exact integration failure quickly.
- Grok built a shared strict parser, added exact real-output regression fixtures, supported JSON and the CLI envelope, and retained fail-closed exit behavior.
- GLM reviewed the parser and found a duplicate-key shadowing hardening opportunity.
- Grok immediately added duplicate-key rejection and tests.

After correction:

- normal comparison succeeded with exit 0;
- normal health succeeded with exit 0;
- forced comparison failed explicitly with exit 1;
- forced health failed explicitly with exit 1;
- all four outcomes wrote the expected durable database evidence;
- the schedule was enabled on preview;
- production was never accessed.

This phase gave the clearest view of Grok's breadth, autonomy, and recovery ability, and of GLM's strengths and limitations as a reviewer.

## Comparative scorecard

Scores use a five-point scale and are intentionally approximate.

| Dimension | Grok 4.5 | Kimi K3 | GLM 5.2 | Best observed |
|---|---:|---:|---:|---|
| Reasoning under ambiguity | 5.0 | 4.4 | 4.5 | Grok |
| First-pass code safety | 4.0 | 4.9 | 4.2* | Kimi |
| Broad implementation ability | 5.0 | 4.5 | 4.1 | Grok |
| Database migration exactness | 4.3 | 5.0 | 4.6 | Kimi |
| Plan and handoff adherence | 4.4 | 5.0 | 4.8 | Kimi |
| Architectural review | 4.4 | 4.7 | 5.0 | GLM |
| SQL/grant/contract review | 4.3 | 4.8 | 5.0 | GLM |
| Live integration debugging | 5.0 | 4.3 | 4.2 | Grok |
| Adversarial bug finding | 4.7 | 4.8 | 4.8 | Close; task-dependent |
| Autonomy | 5.0 | 4.4 | 4.1 | Grok |
| Speed | 5.0 | 4.0 | 3.3 | Grok |
| Thoroughness | 4.5 | 4.9 | 4.9 | Kimi/GLM |
| Scope discipline | 4.8 | 4.9 | 4.8 | Close |
| Recovery after feedback | 5.0 | 4.5** | 4.6 | Grok |
| Communication usefulness | 4.6 | 4.5 | 4.7 | GLM |
| Overall fit for Albert | 5.0 | 4.7 | 4.4 | Grok |

\* GLM's first-pass code-safety score has lower confidence because most of its observed work was review rather than implementation.  
\** Kimi had fewer observed correction cycles, so this score is based on less evidence.

## Grok 4.5 analysis

### Strongest qualities

#### 1. Highest autonomy

Grok needed the least step-by-step steering. In Phase 6 it moved from plan interpretation through SQL, runners, workflow automation, tests, documentation, preview application, workflow dispatch, failure diagnosis, parser repair, and final verification.

That makes Grok especially valuable to a non-programmer owner. It is the closest of the three to behaving like an engineering lead who keeps advancing the work instead of returning every decision to Albert.

#### 2. Best at broad, cross-layer implementation

Grok was comfortable crossing:

- PostgreSQL functions and grants;
- Node runners;
- GitHub Actions;
- parsing and process exit semantics;
- alert records and notifications;
- test design;
- preview deployment and live workflow evidence;
- documentation and handoff.

This breadth matters in real software work because many failures happen at boundaries, not inside a single function.

#### 3. Best live debugger and recovery agent

The CLI output failure was not obvious from local tests. Grok found the root cause in the real Ubuntu/Supabase output, created regression fixtures from that exact format, centralized parsing, preserved fail-closed behavior, and reran the real workflows successfully.

Its recovery was fast and technically coherent. It did not patch around the symptom with “assume success” logic.

#### 4. Strong response to review

When flaws were identified, Grok did not argue for the original design. It made the evidence append-only, pinned the historical baseline, fixed schedule mapping, added the missing test, hardened parsing, and then added duplicate-key rejection after GLM's follow-up.

This is a high-value trait for vibe coding: the agent is productive without being brittle about its own first draft.

#### 5. Good no-op judgment

Grok did not invent Phase 5 programming after the owner decided no canonical creates were needed.

### Weaknesses and risks

#### 1. First-pass ambition can outrun exact safety requirements

Grok's first Phase 6 slice was impressive, but it missed two fundamental evidence properties:

- observations had to be immutable;
- the baseline had to come from Phase 4, not from the first Phase 6 observation.

These were not cosmetic issues. Either could weaken the validity of the 14-day proof.

The pattern is that Grok moves fast and constructs the whole system, but its first design can contain a few assumptions that need a skeptical reviewer.

#### 2. Integration robustness was initially under-tested

The parser passed local tests but failed on the real CLI representation. Grok's original fixtures did not capture actual Ubuntu output.

The corrective work was excellent, but the incident reinforces a rule: require one real end-to-end run before trusting Grok's integration layer.

#### 3. Broad changes increase review burden

Grok's vertical slices are large. That is efficient when correct, but it gives reviewers more surface area. For a dangerous database cutover, constrain the contract tightly and insist on staged evidence.

### Best uses for Grok

- ambiguous debugging;
- broad features spanning several layers;
- workflow and automation integration;
- root-cause investigations;
- repository-wide implementation;
- rapid prototypes that must become real production code;
- recovering a failing CI or live integration;
- leading a phase while another model provides safety review.

### Do not use Grok alone for

- destructive or irreversible database changes;
- exact financial, permission, or identity migrations;
- evidence systems where audit semantics are subtle;
- any change where one hidden assumption could corrupt canonical data.

For those tasks, pair Grok with Kimi or GLM.

## Kimi K3 analysis

### Strongest qualities

#### 1. Best exact production-code quality in the observed work

Kimi's Phase 4 implementation was disciplined and narrow. It enforced the frozen approval set at multiple levels and proved:

- exact input count and hash;
- exact target environment;
- exact approver;
- zero canonical creates;
- zero canonical field changes;
- rollback safety;
- idempotency;
- permission boundaries;
- preservation of excluded rows.

This is the code quality Albert needs when the database is shared by many applications.

#### 2. Best plan adherence

Kimi behaved as if the handoff and frozen contract were executable specifications. It did not reinterpret the approved set, link NASA, promote unapproved candidates, create Phase 5 records, or broaden scope.

This was the strongest observed evidence that a model had read the plan before implementing.

#### 3. Conservative interpretation of data work

Kimi's work favored explicit rejection over permissive fallback:

- wrong counts rejected;
- wrong hash rejected;
- malformed shape rejected;
- unauthorized roles rejected;
- wrong target rejected.

That bias is desirable for database mutations and migrations.

#### 4. Strong safety mindset

The rollback rehearsal and repeated idempotency proofs were not just unit tests. They demonstrated transactional and operational safety against preview.

### Weaknesses and uncertainties

#### 1. Smaller evidence sample

Kimi had one major implementation phase and one review phase. It performed extremely well, but there is less evidence about its behavior in broad frontend/backend integrations, live CI failures, or long ambiguous investigations.

#### 2. More deliberate pace

Kimi appeared slower and more cautious than Grok. That is often a benefit in high-risk work, but may be less efficient for exploratory tasks where the system must be understood through repeated experiments.

#### 3. Less evidence of cross-layer recovery

The engagement did not expose Kimi to a failure like the Phase 6 CLI parser incident. Therefore, it would be unfair to rank its live debugging ability as confidently as Grok's.

### Best uses for Kimi

- shared-database migrations;
- canonical-data corrections;
- exact contract implementations;
- security-sensitive input validation;
- rollback and idempotency design;
- reviewing a risky diff for scope creep;
- any task where “change exactly these rows and nothing else” is the core requirement.

### Best pairing

Have Kimi implement dangerous data work, then use Grok to stress-test operational assumptions and GLM to inspect architecture, grants, and contracts.

## GLM 5.2 analysis

### Strongest qualities

#### 1. Best architectural reviewer

GLM read large migrations, workflows, runners, tests, schema definitions, function signatures, grants, and handoffs as a connected system. Its reviews explained why the work was safe, not merely whether tests passed.

It was particularly strong at:

- `security definer` and `search_path` analysis;
- RLS and grant matrices;
- function signature validation;
- schema and enum cross-checking;
- workflow guard analysis;
- verifying that caller-supplied hashes could not forge evidence;
- confirming forced failures could not mutate canonical data.

#### 2. Most methodical written review

GLM produced the most structured review artifacts. It separated:

- verdict;
- strongest evidence;
- blocking findings;
- prioritized improvements;
- model-performance assessment;
- concrete next gates.

This makes GLM's work easy for a supervising agent to audit.

#### 3. Good anticipatory risk detection

GLM predicted the CLI parsing weakness before the first live comparison failed. It also found:

- missing workflow test coverage;
- schedule jitter risk;
- separate status-hash provenance uncertainty;
- duplicate-key shadowing in the corrected parser;
- maintainability risks from duplicated guard logic.

These are meaningful findings.

#### 4. Strong adversarial checking

In the parser review, GLM tested nested maps, arrays, free-form strings, Unicode, nil, booleans, integers, malformed output, ambiguity, truncation, and unrelated text. It then found the duplicate-key case that the initial parser tests omitted.

### Weaknesses and risks

#### 1. Slower

GLM's reviews took materially longer than Grok's implementation/debug cycles. The extra time often bought depth, but it makes GLM less suitable as the sole agent for rapid interactive iteration.

#### 2. Risk prioritization can be too optimistic

The biggest example was the parser. GLM identified it correctly but categorized it as non-blocking/low-medium. The first live comparison then failed for exactly that reason.

Similarly, the first review approved the design while missing:

- overwriteable same-day evidence;
- silent first-observation baseline establishment.

GLM is excellent at reading the implemented structure, but an independent supervisor should still challenge the underlying audit semantics and real-world operational assumptions.

#### 3. Less evidence of implementation autonomy

GLM implemented Phase 3 successfully, but most of the detailed evidence comes from its reviews. It has not yet demonstrated the same broad, live, end-to-end ownership as Grok or the same high-risk mutation implementation as Kimi.

#### 4. Occasional tool-protocol friction

Its saved reviews included apologies for attempting unavailable interaction tools. This did not affect repository correctness, but it is a small autonomy/agent-environment weakness compared with Grok's smoother operational flow.

### Best uses for GLM

- architecture review;
- SQL and database privilege review;
- monitoring and evidence-system review;
- contract and plan consistency checks;
- security review;
- adversarial parser and input testing;
- final review of a broad Grok implementation;
- second opinion when a diff appears safe but has subtle systemic consequences.

### Do not rely on GLM alone for

- determining whether a theoretical integration risk is operationally blocking;
- fast live incident response;
- final approval of audit semantics without an independent challenge;
- tasks where execution speed and continuous environment interaction matter most.

## Direct answers to Albert's questions

### Which is the smartest?

**Grok 4.5 was the smartest under ambiguity in this engagement.**

“Smartest” here means combining incomplete evidence, moving across multiple technical layers, responding to changing facts, diagnosing a live failure, and converging without repeated human steering. Grok showed the strongest version of that.

Kimi may be equally or more intelligent within a tightly specified correctness problem, but the observed sample was narrower. GLM showed deep analytical intelligence, especially in review, but less execution speed and less operational adaptability.

### Which writes the best code?

**Kimi K3 wrote the best safety-critical production code observed.**

Its Phase 4 work was exact, defensive, idempotent, rollback-tested, and tightly aligned with the approved data contract.

**Grok wrote the best broad systems code**, especially after review and live correction. Its final Phase 6 implementation was strong, but the first pass needed meaningful safety corrections.

GLM's implementation-code sample was too small to rank it above either with confidence.

### Which is the most thorough?

There are two answers:

- **Kimi was most thorough as an implementer.**
- **GLM was most thorough as a reviewer.**

Kimi translated a frozen plan into layered enforcement. GLM read and documented the architecture and contracts with the most explicit analytical detail.

### Which reads plans before implementing?

**Kimi K3 showed the strongest plan fidelity.**

It treated the approved mapping, exclusions, environment boundary, field-ownership rules, and phase boundary as hard constraints.

GLM also read plans closely, especially during review. Grok read them well enough to stay in scope, but its fast, expansive style produced two first-pass design assumptions that a slower plan-to-invariant translation might have prevented.

### Which is the most autonomous?

**Grok 4.5, clearly.**

It owned the largest portion of the work from planning through live proof, and it required the least handholding.

### Which finds bugs best?

It depends on the bug:

- **Live integration and root-cause bugs:** Grok.
- **Data-safety, exactness, and scope bugs:** Kimi.
- **Architecture, permissions, contracts, and adversarial edge cases:** GLM.

### Which is best overall?

**Grok 4.5 is best overall for Albert's workflow**, because Albert benefits most from an agent that can autonomously turn a business goal into a working, verified result.

That recommendation always includes a condition: consequential Grok work should be reviewed by Kimi or GLM before merge, database apply, or deployment.

## Recommended model routing for a vibe coder

Albert should not have to decide based on programming terminology. Route by business risk and task shape.

### Ask Grok to lead when

- “Figure out why this is broken.”
- “Build this whole feature.”
- “Connect the database, script, CI, and deployment.”
- “Keep going until the live workflow passes.”
- “Explore the repo and choose the implementation path.”

Reviewer:

- Kimi if data correctness or destructive scope is the main risk.
- GLM if architecture, permissions, or monitoring is the main risk.

### Ask Kimi to lead when

- “Change exactly these database records.”
- “Write this migration without changing anything else.”
- “Make the operation reversible and idempotent.”
- “Enforce this frozen input or approval contract.”
- “Check that a broad implementation cannot corrupt shared data.”

Reviewer:

- Grok for live operational stress testing.
- GLM for schema/grant/contract review.

### Ask GLM to lead when

- “Review this architecture.”
- “Audit these grants, policies, and security-definer functions.”
- “Check whether the evidence actually proves the claim.”
- “Find contract gaps in this migration or workflow.”
- “Adversarially test this parser or validation boundary.”

Reviewer:

- Grok to determine whether theoretical risks reproduce in the real environment.
- Kimi when the review concerns exact data mutation.

## Recommended rotations

### Broad application or automation phase

1. Grok implements.
2. GLM reviews architecture, permissions, contracts, and evidence.
3. Grok fixes findings and runs the real end-to-end proof.
4. Kimi checks any risky database or canonical-data portion.

### Dangerous shared-database cutover

1. Kimi implements the exact migration and rollback.
2. GLM audits SQL, grants, signatures, invariants, and proof design.
3. Grok performs live stress testing and investigates any operational failure.
4. No production promotion until the exact preview evidence passes.

### Bug investigation with uncertain root cause

1. Grok investigates and proposes/fixes.
2. Kimi checks that the fix does not broaden data mutation.
3. GLM checks that the root cause and tests cover the wider architectural pattern.

### Plan or handoff review

1. GLM checks completeness and internal consistency.
2. Kimi checks whether the steps are executable without violating stated constraints.
3. Grok checks whether the plan covers likely live integration failure modes.

## Suggested supervision rules

Regardless of model:

1. Give the agent the exact environment and prohibit production unless explicitly authorized.
2. Require it to read `AGENTS.md`, the current priority, the phase handoff, and the governing plan.
3. Freeze consequential inputs by hash and count.
4. Require rollback or a recoverable path before mutation.
5. Require a real environment test, not only mocks or local fixtures.
6. Make the reviewer read the plan independently instead of only reading the diff.
7. Ask the reviewer to name both blocking findings and risks it considers non-blocking.
8. Have the implementing agent respond to every finding with evidence.
9. Preserve failed runs and corrections in the handoff; they are valuable future context.
10. Never equate an agent's confident verdict with proof.

## Model-specific supervision

### For Grok

- Narrow the invariant contract before it starts.
- Require an explicit list of what must remain unchanged.
- Insist on a real end-to-end run.
- Use a skeptical reviewer for evidence semantics and data safety.
- Let it own diagnosis and correction after failures.

### For Kimi

- Give it the exact frozen inputs and exclusion set.
- Allow extra time for deliberate implementation.
- Use it when false positives are more dangerous than slow progress.
- Add Grok when the task expands into CI, deployment, or live system debugging.

### For GLM

- Use review-only mode by default.
- Ask it to distinguish “theoretically safe” from “proven in the real environment.”
- Challenge every non-blocking operational finding: “What happens on the first real run?”
- Pair its structured review with Grok's live reproduction.

## Final ranking

### Overall usefulness to Albert

1. **Grok 4.5** — best autonomous lead and overall problem solver.
2. **Kimi K3** — best careful coder for high-risk, exact work.
3. **GLM 5.2** — best specialist reviewer, but slower and less proven as a broad implementation lead.

### If only code quality for a dangerous database change matters

1. **Kimi K3**
2. **Grok 4.5 after independent review**
3. **GLM 5.2**, provisional due to limited implementation evidence

### If only review quality matters

1. **GLM 5.2** for architecture, SQL, grants, and contracts
2. **Kimi K3** for exact data safety and scope
3. **Grok 4.5** for operational realism and live stress testing

### If only speed and autonomy matter

1. **Grok 4.5**
2. **Kimi K3**
3. **GLM 5.2**

## Bottom line

Grok is the best lead engineer of the three for a vibe coder, Kimi is the safest precision engineer, and GLM is the strongest formal reviewer.

The winning “team” is:

> **Grok for momentum and live problem solving; Kimi for exactness and data safety; GLM for architecture and adversarial review.**

The Phase 3–6 rotation supports keeping all three. Their weaknesses are complementary:

- Grok's speed benefits from Kimi's conservatism and GLM's formal review.
- Kimi's deliberate precision benefits from Grok's operational stress testing.
- GLM's analytical depth benefits from Grok proving whether a predicted risk actually breaks the live system.

For Albert, the best overall process is therefore not model loyalty. It is deliberate rotation, independent checking, and evidence from the real environment before consequential changes are declared done.

---
---

# Report B — DesignFlow Sample Tracking (2026-07-24/25)

**Report date:** 2026-07-26
**Prepared for:** Albert Hazan / POP Creations
**Supervising session:** Claude Opus (separate session from Report A; formed its conclusions before reading Report A)
**Evidence base:** implementing `fix_sample_tracking.md` Phases 1–6 across `popcre/designflow-tracking` (Node/Express) and `popcre/designflow-frontend` (Angular), against a Sample Tracking schema already live in production
**Models as observed:** `glm-5.2` (via `ai-glm-agent`), Kimi Code CLI `0.27.0`, `grok-4.5-build` (Grok CLI `0.2.111`). Codex `codex-cli 0.144.5` also appears as a reviewer.

## Executive conclusion (this engagement)

- **Best overall: GLM 5.2.** Smartest single judgement call observed, cleanest large implementations, and the only model that completed two big multi-file phases in one autonomous pass.
- **Best production code: Kimi.** The only model whose implementation needed **zero** corrective edits from me.
- **Most thorough / best plan reader: Kimi**, clearly. Matches Report A.
- **Best reviewer of the three: Grok.** Its two read-only reviews were the most useful review artifacts any of the three produced here.
- **Weakest implementer: Grok.** Its one implementation phase shipped two real defects an independent reviewer had to catch.
- **Most autonomous: GLM.** Opposite of Report A — see the disagreement section.

## What each model was actually asked to do

| Phase | Scope | Implementer | Checker | Outcome |
|---|---|---|---|---|
| 1 (§4) | 7 P0 contract fixes vs live CHECK constraints; 14 source files | **GLM** | Grok | 488 tests; 0 blocking defects; 2 minor fixes by me |
| 2 (§5) | Ledger adoption, 8 sub-items; ~15 files | **Kimi** | GLM | 530 tests; **0 defects requiring any fix** |
| 3 (§5.6) | Add-to-box-from-inventory; new endpoint | **Grok** | Codex | **2 real defects**, both fixed by me |
| 6 (§6) | Frontend P0+P1; 22 files, new UI surfaces | **GLM** | Grok | 996 tests + build green; 2 medium fixes by me |

Tasks were not equal. GLM got the two biggest surface-area phases; Kimi got the most conceptually intricate one; Grok got the smallest, most self-contained one — and still produced the most defects. That asymmetry cuts *against* Grok here rather than excusing it.

## The moments that decided the ratings

### GLM's best moment — refusing to write a wrong foreign key (§4.7)

The plan said to stamp a box's `owner_factory_id_fk`. GLM read the code, concluded that `dflow.vendor.vendor_id` is a **different identifier space** from the portal's `Factory.id` (vendor links to Factory via its own `factory_id_fk`), and refused to write the value — leaving `ownership_state` as `unassigned` and documenting the open prerequisite instead.

I later verified this against live production data: `vendor_id` values are 95, 97, 98, 99… while `factory_id_fk` values are 2, 3, 1, 31…. **GLM was exactly right.** It inferred a cross-system data-model mismatch from source code alone and chose to fail safe rather than satisfy the plan. That is the strongest single reasoning act by any model in this engagement.

### Kimi's best moment — flagging its own design decisions for a human

Kimi implemented Phase 2 and then, unprompted, surfaced two decisions it had made that it judged a human should confirm: that an unboxed departure posts no movement (the move lands at arrival), and that whole-batch ship means the four-piece split needs the UI to send partial quantities. It also wrote the best drift documentation of the engagement (`§5.10`), precise enough that later phases could start from it without re-reading its diff.

Neither GLM's review nor my own inspection found anything in Kimi's code that needed changing. It is the only clean sheet here.

### Grok's worst moment — and its best

**Worst:** its Phase 3 endpoint validated an explicit `leg_type` only against the 8-value vocabulary, not against the chosen office or destination. A caller could persist a self-contradictory shipment line (origin `Ningbo_office_inventory`, leg `nyc_to_factory`, destination `customer/88`). Separately, its error mapper treated *any* 409/422 from the movement layer as "insufficient inventory", so an idempotency conflict would be reported to the user as an over-withdrawal. Codex caught both; I fixed both. The second is a band-aid pattern of exactly the kind Albert's standing rules forbid.

**Best:** as a *reviewer*, Grok was excellent — twice. Its Phase 1 review was the best-structured review artifact of the engagement, and its Phase 6 review found two genuine silent-failure paths in GLM's frontend code (a `catch` that turned a failed shipment-line load into an innocuous "no lines yet", and a missing refresh after a successful withdrawal). Both were real; both were worth fixing.

### GLM as reviewer — competent, not decisive

GLM reviewed Kimi's Phase 2 and returned all ten checks PASS with five minor observations. I judged none worth changing. That is *probably* correct (Kimi's code was genuinely clean) rather than a miss — but it means GLM's review produced no actionable value in this rotation, whereas Grok's did twice.

## Comparative scorecard (this engagement only)

Five-point scale, same convention as Report A. Confidence is low on any row backed by a single observation.

| Dimension | GLM 5.2 | Kimi | Grok 4.5 | Best observed |
|---|---:|---:|---:|---|
| Reasoning under ambiguity | **5.0** | 4.3 | 3.8 | GLM |
| First-pass code safety | 4.5 | **4.9** | 3.5 | Kimi |
| Broad implementation ability | **4.8** | 4.5 | 4.0 | GLM |
| Plan fidelity / reads before coding | 4.3 | **5.0** | 4.0 | Kimi |
| Drift and handoff documentation | 4.4 | **5.0** | 4.2 | Kimi |
| Review quality (as checker) | 3.8 | n/a | **4.7** | Grok |
| Headless autonomy (one clean pass) | **5.0** | 3.0 | 4.6 | GLM |
| Scope discipline | 4.7 | **5.0** | 4.3 | Kimi |
| Surfacing decisions to the human | 4.3 | **5.0** | 3.9 | Kimi |
| Speed | 4.4 | 3.6 | **4.8** | Grok |
| Overall fit for this work | **4.8** | 4.6 | 4.0 | GLM |

**Defect ledger (the hardest number here):**

| Model | Implementation phases | Real defects a checker had to catch |
|---|---:|---:|
| Kimi | 1 (largest sub-item count) | **0** |
| GLM | 2 (largest surface area) | 0 blocking; 4 minor (2 per phase) |
| Grok | 1 (smallest scope) | **2 real** |

## Operational notes that matter more than the ratings

- **Kimi stalls in headless mode on a broad prompt.** A single "implement §5" call analysed without editing. Splitting Phase 2 into two bounded, context-resumed calls (`kimi -p … -r <session>`) worked perfectly. This is a harness property, not an intelligence property — but it means *Kimi costs the supervisor more setup*. Budget for decomposition.
- **GLM and Grok both one-shot cleanly** via their launchers. GLM handled 22 files plus a full Angular build in a single call.
- **GLM's launcher enforces no model fallback** (`ai-glm-agent.ps1` rejects a mismatched returned model). Keep that; it is why the "GLM 5.2" claims here are trustworthy.
- **Grok headless permissions are a trap.** `--permission-mode auto` is accepted and silently does nothing; read-only reviews need explicit `--allow Read --allow Grep` plus `--deny Edit --deny Bash`, and implementation needs `--always-approve`. Getting this wrong produces a run that looks like a refusal.

## The finding that outranks the model comparison

**All four models — GLM, Kimi, Grok, and Codex — read the shipping code across six phases and 547 unit tests, and none found the two defects that made the feature physically unusable.** A single live run against the deployed sandbox found both within minutes:

1. Reference lookups used unqualified SQL (`FROM "Factory"`), which is not on the connection's `search_path` → **HTTP 500** when creating a sample with a factory, which blocked the entire opening-movement feature.
2. `shipLine` shipped from a hardcoded `factory` origin instead of the shipment line's own persisted typed origin → **422 "Insufficient sample balance"** on every leg that did not start at a factory, making the core four-piece split impossible.

Both predate the three models' work (`1f4de05` and `a7c8d76`), so **neither is attributable to GLM, Kimi, or Grok** — the failure was that four independent static reviews all missed them. Unit tests could not catch either, because the mocks stub `sequelize.query` wholesale and asserted only a movement's destination, never its origin.

**The lesson: static review by more models has sharply diminishing returns. One real execution against a real environment is worth more than a fourth reviewer.** Report A reached a version of this (its "require one real end-to-end run" rule for Grok). This engagement generalises it: require it for *every* model, and prefer a live run over an extra review pass whenever you can only afford one.

## Where this disagrees with Report A

| Question | Report A | Report B | Most likely explanation |
|---|---|---|---|
| Best overall | Grok | **GLM** | Task shape. Report A's work was live-ops/CI/integration — Grok's strength. Report B's was contract conformance against a fixed live schema — GLM's strength. |
| Most autonomous | Grok | **GLM** | Both one-shot well; GLM simply got the bigger phases here and completed them unaided. Different sample more than true contradiction. |
| Best reviewer | GLM | **Grok** | Genuine disagreement. Here Grok's reviews produced actionable findings twice and GLM's produced none. Small sample both sides — treat as unresolved. |
| Best exact/production coder | Kimi | **Kimi** | **Agreement.** Two independent engagements both rate Kimi's first-pass code safety highest. The most trustworthy conclusion in this file. |
| Best plan reader | Kimi | **Kimi** | **Agreement**, and strongly. |
| Grok's first pass needs a skeptical reviewer | Yes | **Yes, emphatically** | **Agreement.** Report A saw two design defects in Grok's first slice; Report B saw two contract defects. Never merge Grok's implementation unreviewed. |

**Safe to conclude across both reports:**

- Kimi writes the safest first-pass code and reads plans most faithfully. *(2/2 engagements)*
- Grok's implementations require an independent checker before merge. *(2/2)*
- All three are capable of serious repository work, and rotation beats loyalty. *(2/2)*

**Not yet settled:** who is the best reviewer, and who is "best overall" — both flipped between engagements. Treat those as task-dependent rather than fixed, and re-evaluate after more rotations.

## Routing advice specific to contract/schema work

Report A's routing guidance holds. Add this for work like Report B's — adopting an already-live database contract in application code:

1. **GLM leads.** It is strongest at inferring an implied data model from code, and at refusing to guess when identifiers do not line up.
2. **Kimi takes the phase with the most sub-items and the most downstream dependents**, because its drift documentation is what later phases actually build on.
3. **Grok reviews**, and implements only well-bounded, self-contained additions — with a checker.
4. **Run the real thing before declaring done.** Not a fourth review. An execution.
