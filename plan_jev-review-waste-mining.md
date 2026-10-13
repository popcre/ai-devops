# IMPLEMENTATION PLAN — Jev review-waste mining from AI transcripts

**Handoff (read first together with this file):**
[`HANDOFF.d/2026-10-12T1444Z-edge-dev-mimo-jev-review-waste-mining.md`](HANDOFF.d/2026-10-12T1444Z-edge-dev-mimo-jev-review-waste-mining.md)

**Related plans (do not duplicate their work):**
[`plan_typesafe-jev-decision-layer.md`](plan_typesafe-jev-decision-layer.md),
[`plan_typesafe-jev-advisory-integrations.md`](plan_typesafe-jev-advisory-integrations.md),
[`plan_typesafe-jev-spend-reduction.md`](plan_typesafe-jev-spend-reduction.md),
[`plan_reviewer-spend-waste.md`](plan_reviewer-spend-waste.md)

## STATUS

| Step | State | Date | Evidence |
|---|---|---|---|
| 0. Session setup (worktree, gates) | done | 2026-10-12 | worktree C:/repos/ai-devops-wt-jev-review-waste branch mimo/jev-review-waste-mining; task class code |
| 1. Inventory + read-all cost baseline | done | 2026-10-12 | [inventory and cost baseline](tests/verification/jev/review-waste-inventory-20261012T162801Z.md) |
| 2. Shared Jev client + decision config | done | 2026-10-12 | `tools/lib/jev-client.sh`, config/jev-decisions.json; pin tests 37/0; contracts 24/0; scripts suite 6/0 |
| 3. Chunk filter + calibration | done | 2026-10-12 | [chunk filter shadow run](tests/verification/jev/review-waste-chunk-shadow-20261012T180611Z.md); fixtures `tests/fixtures/jev/review-waste-chunk-labels.json` |
| 4. Review-arc stitch + value Score | done | 2026-10-12 | [value score shadow run](tests/verification/jev/review-waste-value-shadow-20261012T180611Z.md); `tools/jev_review_waste_arc.py`; pipeline tests 17/0 |
| 5. Aggregation + waste report | done | 2026-10-12 | [review waste report](tests/verification/jev/review-waste-report-20261012T180833Z.md) (bounded 12-file sample; slices n≥5 suppressed) |
| 6. Decision brief for the owner | done | 2026-10-12 | Decision brief section of the waste report (options only; no policy change) |

**Where a fresh session starts:** Step 0. Re-read this STATUS table first — do not re-derive or re-plan. Every row stays `⬜ open` until its verification gate passes and the evidence cell names an artifact a reader can open.

---

## 1. The ultimate goal — what we are actually trying to achieve

Albert pays real money for AI code reviews. Some classes of work we send to reviewers almost never come back with a real correction or improvement. Those reviews are waste. Other classes almost always find something worth fixing.

When this work is done, Albert can see — by reviewer, by class of work, by repository, over time — which review traffic earns its cost and which does not. He can then decide (as a business decision, his alone) to stop or shrink the low-value traffic. Review quality on the high-value traffic must not change.

Plain English: **stop paying for reviews that almost never improve anything, without losing the reviews that do.**

**If a step conflicts with this goal, the goal wins — stop and flag it.**

This plan does **not** change the allocator, the reviewer roster, which reviews are mandatory, or any review policy. It produces evidence. Policy change is a later owner decision.

---

## 2. What this application is

There is no web app. This is a one-off analysis pipeline built on top of `popcre/ai-devops`, Albert's public AI workflow toolkit.

- **Repository:** `popcre/ai-devops` on GitHub (`https://github.com/popcre/ai-devops`). `main` is protected; work lands by feature branch + PR + merge queue.
- **What already exists in the toolkit:** reviewer wrappers (`bin/ai-review`, `bin/ai-review-pool`, `bin/ai-gh`), reviewer event log (`tools/reviewer_events.py` → `~/.local/state/ai-devops/reviewer-events/events.jsonl`), Jev probe tools (`bin/ai-jev-probe`, `bin/ai-jev-completion-shadow`), task gates (`bin/ai-task-gates`).
- **What this plan adds:** a local pipeline that (a) finds review-related slices of AI session transcripts, (b) classifies each complete review interaction on a five-level value scale with the cheap TypeSafe **Jev** decision model, and (c) writes an aggregate waste report. The report is the deliverable; the pipeline is disposable after that unless kept for a later measured trial.
- **Jev (what it is):** TypeSafe's decision model at `POST https://api.typesafe.ai/v1/systemone`. It answers typed questions only — `Noul` (probability of yes), `Choice` (one closed option plus distribution), `Score` (ordered severity levels plus distribution). It produces **no** explanation, code, or free text. Verified model as of 2026-09-20: `jev-1.13.0` at `$0.042 / 1M` input tokens. `GET /v1/models` is authoritative at runtime; never assume the pin without re-checking.
- **Where it runs:** one managed machine that has the transcript archive mounted (see §12). Not CI. Not production. No server.

---

## 3. What triggered this work

On 2026-10-12 Albert said (this session): after Jev excerpting of the massive raw AI session logs, he wants to measure whether some subset of the work we send to reviewers is wasting money — some pattern among what we send to reviewers that rarely results in a correction or some other improvement that justifies the review. He proposed Jev further categorize outcomes into "reviewer found a problem" and "reviewer didn't add anything of value", and said **the more we give to Jev, the cheaper this analysis becomes**.

Earlier related history:

- 2026-09-27: exploratory scan of ~4,000 local Claude/Codex transcript files for Jev-replaceable work. Found many *mentions* of review verdicts and routing, but repeated policy text created false positives. It did **not** count replaceable calls or billable savings. (`plan_typesafe-jev-spend-reduction.md` §3)
- 2026-09-27: that spend-reduction lane was closed **no-go** for its then-selected target (compaction / skill-load substitution). This plan is a **new target** (review-value mining) and does not reopen that no-go.
- 2026-10-07: `plan_reviewer-spend-waste.md` completed tooling-level fixes (no duplicate reviews of the same head, no silent paid-key fallbacks). That cut *duplicate* reviewer spend. This plan finds *low-value* review spend — a different question.

There is no bug URL. The target behavior is: money spent on reviews that almost never improve the work.

---

## 4. Scope — in and out

### In this plan

- Locating and structurally parsing the local AI session transcript archive (Claude, Codex, and any MiMo transcripts that cover reviewer work).
- A two-stage Jev pipeline: (1) chunk-level filter for review-related content, (2) review-interaction-level value classification on a five-level ordered scale.
- Calibration on a hand-labeled sample before any full-archive run.
- Aggregation of labeled results by reviewer, class of work, repository, and time.
- One aggregate waste report (public-safe: counts, rates, costs, no transcript text).
- A short decision brief for Albert naming the low-value patterns.

### NOT in this plan (explicit)

- Changing the reviewer allocator, roster, rotation, or who-reviews-what (`popcre/shared-db` owns that).
- Changing or skipping any mandatory review gate, especially `reviewer-safety`.
- Letting Jev open a task, review, database, production, or permission gate — Jev is read-only labeling.
- Replacing independent code review or its final verdict with Jev.
- Implementing the policy change that the waste report might recommend. That is Albert's business decision.
- Committing raw transcript text, excerpts, prompts, private identifiers, or archive paths into this public repository.
- Shared-database structure changes.
- Fleet installation of anything. One machine, one analysis.
- Re-doing `plan_reviewer-spend-waste.md` (already done) or reviving `fast-jev-compaction` (already rejected).
- Building a second Jev HTTP client if `tools/lib/jev-client.sh` has landed from the advisory plan.

---

## 5. Current state of the code

Worktree base for this plan: `ae490d6d` (`origin/main` as of 2026-10-12).

| Thing | State |
|---|---|
| `bin/ai-jev-probe` | Exists. One bounded reachability call; self-resolves API key via `op run`; 10s connect / 20s call timeout. Uses moving `jev-latest` alias — **not** acceptable for calibrated thresholds. |
| `bin/ai-jev-completion-shadow` | Exists. Record-only completion check; duplicated secret bootstrap (must move onto shared client). |
| `tools/lib/jev-client.sh` | **Does not exist.** Advisory plan §9.2 is still open. This plan's Step 2 may have to build it, or consume it if another session landed it first. |
| `config/jev-decisions.json` | **Does not exist.** Same rule as above. |
| `tests/test-ai-jev-scripts.sh` | Exists. Six offline guards for empty secrets, timeouts, malformed `Noul`/`Choice`, etc. |
| `tests/fixtures/jev/` | Does not yet hold review-waste labels. |
| `tests/verification/jev/spend-baseline-20260928T0243Z.md` | Exists. Negative result for the *old* target (no qualifying displaced paid call). Do not treat as evidence for this target. |
| `tools/reviewer_events.py` | Exists. Reviewer event log writer/reader. |
| `~/.local/state/ai-devops/reviewer-events/events.jsonl` | Live reviewer dispatch/outcome log on installed machines. |
| `bin/ai-jev-review-waste*` (any caller) | **Does not exist.** To be added under Step 2/3/4. |
| Transcript archive | Local, outside the repo. See §12. `tools/jev_review_waste_sample.py` reads it from the `AI_JEV_ARCHIVE_DIR` environment variable (a directory; `~` is expanded); the path is never committed. Owner ruled 2026-10-12: **redacted, no longer private** for the purpose of sending to TypeSafe. Raw files still must never be committed here. |
| Shared-db allocator / roster | Untouched. |

Nothing in this plan is half-written in this repository. The STATUS table above is the only progress record.

---

## 6. Key findings and root cause

These cost real investigation time. Do not rediscover them.

1. **Jev cannot write a review verdict.** It returns only a typed judgment (`Noul`/`Choice`/`Score`). Full review reasoning needs a generative model. So Jev is for **labeling and routing**, not for replacing review. (`plan_typesafe-jev-decision-layer.md` §5; `plan_typesafe-jev-spend-reduction.md` finding 1)

2. **Keyword search over transcripts is not a measurement.** The 2026-09-27 scan counted *mentions*, and repeated policy/prose text contaminated the totals. Any first-pass filter must be a model judgment on a bounded chunk, not a grep. (`plan_typesafe-jev-spend-reduction.md` finding 3)

3. **"Sent to reviewer" is a structured event, not prose.** Work reaches reviewers through `bin/ai-review`, `bin/ai-review-pool`, and sealed packets (`bin/ai-review-packet`). The events log at `tools/reviewer_events.py:18-22` is the authoritative dispatch/outcome spine. Join transcript review-arcs to that spine before counting waste — do not infer a paid review from a chat mention of the word "review".

4. **Value is ordered, not binary.** Albert rejected a yes/no value question (2026-10-12). "Named a real problem but did not know how to fix it" is still valuable — the main LLM can fix it once identified. The scale is five ordered levels (see §8). Jev's `Score` type is the correct primitive.

5. **A five-level scale is a `Score`, not a `Choice`.** `Score` is for ordered severity/levels. `Choice` is for mutually exclusive unordered categories (including `none/uncertain`). Using `Choice` for value would throw away the ordering and make "almost worthless" and "net negative" look equally distant from "mildly useful". (`plan_typesafe-jev-spend-reduction.md` §9.2)

6. **Cheap ≠ free.** Jev at `$0.042/1M` input tokens is cheap per call, but a huge archive × many chunks multiplies. The pipeline must pre-select, batch independent questions, cap per-run calls, and record actual `usage.input_tokens`/`usage.output_tokens`. "More to Jev" is the cost strategy **only** if each Jev call displaces a more expensive frontier read of the same content.

7. **Safety-gate reviews that find nothing are not automatically waste.** A `reviewer-safety` (or other mandatory) review that returns "nothing added" still purchased assurance on a protected change. Those must be measured in a separate bucket from discretionary sends. Albert locked this distinction on 2026-10-12.

8. **`jev-latest` is a moving alias.** Thresholds calibrated on one model break when the alias moves. Pin the model returned by `GET /v1/models`, record it in config and in every verification artifact, and treat a model change as invalidating calibration. (`plan_typesafe-jev-advisory-integrations.md` rejected approach 3)

9. **Transcripts may go to TypeSafe for this analysis.** Owner ruling 2026-10-12 (verbatim meaning): transcripts have had private information redacted; they are no longer private. A prior owner-approved backtest already sent transcript text to TypeSafe (2026-09-18, `plan_typesafe-jev-decision-layer.md` §7). This still does **not** license committing raw text into the public repo.

10. **Frontier LLM only reads what Jev marks.** That is the whole token-saving shape of this pipeline. If the implementer finds themselves loading the full archive into a frontier model "to be safe", the plan has been abandoned — stop.

---

## 7. Approaches considered and REJECTED, and why

| Approach | Why rejected |
|---|---|
| Read every transcript with a frontier LLM and ask it to find waste | Defeats the purpose. That is the cost this plan exists to avoid. |
| Grep / keyword counts for "review", "APPROVE", "blocker" | 2026-09-27 already showed this: mentions ≠ paid work; policy prose creates false positives. |
| Jev as a full review replacement | Jev cannot reason or cite source evidence. Reviews stay generative. |
| Binary yes/no "did the reviewer add value?" | Albert, 2026-10-12: needs ordered levels. "Problem, no fix" is medium value, not "yes". |
| Treat "problem without suggestion" as non-value | Albert, 2026-10-12: the main LLM can fix a named problem. That is value. |
| Segment by reviewer inside Jev (a separate classification run) | Unnecessary. Reviewer identity comes free from the events log / PR metadata. Segment in post-processing after labeling. |
| `Choice` for the value label | Wrong primitive. Value is ordered → `Score`. |
| `fast-jev-compaction` plugin | Rejected earlier by recorded replay and unresolved safety constraints. Do not revive. |
| Thresholds borrowed from TypeSafe demos or `jev-latest` | Model/domain drift. Must calibrate on our own labeled sample. |
| Open-ended Jev prompts ("summarize the review") | Jev does not do open-ended text. Frozen questions + closed labels only. |
| Counting every "reviewer found nothing" as waste | Wrong. Mandatory safety reviews buy assurance (§6.7). |
| Building a new HTTP client for this target | Advisory plan §9.2 owns the single bounded client. Consume it, or build that step once and share. |
| Mining the spend-reduction baseline file as if it were this analysis | That baseline tested a different target and recorded a no-go. Reuse its *method*, not its conclusion. |

---

## 8. Design decisions already made (dated)

### Locked — do not relitigate

| Decision | Date | Source |
|---|---|---|
| Two-stage pipeline: (1) chunk filter for review-related content, (2) review-interaction value label | 2026-10-12 | Albert |
| Five ordered value levels, Jev `Score`: **highest** = named a real problem + gave a useful suggestion; **medium** = named a real problem but did not know the solution; **low** = minor style only; **none** = nothing added / uncertain; **negative** = identified something that ended up being wrong | 2026-10-12 | Albert ("categories confirmed") |
| "Named a real problem" without a suggested fix is still value (medium) | 2026-10-12 | Albert |
| Segment by reviewer, change type, repo, and time **after** labeling, in the same analysis — not as separate Jev runs | 2026-10-12 | Albert + design |
| Mandatory safety-gate reviews that find nothing are measured in a separate bucket; they are not counted as discretionary waste | 2026-10-12 | Albert |
| The more classification given to Jev, the cheaper the analysis — push labels down to Jev and reserve frontier tokens for the small slice that needs real reading | 2026-10-12 | Albert |
| Transcripts are redacted and may be sent to TypeSafe for this analysis; raw text still never commits to the public repo | 2026-10-12 | Albert |
| Frozen Jev questions + closed labels + calibrated threshold + abstain on uncertainty/error (the spend-reduction §9.2 pattern) | 2026-09-27 | Existing plan |
| Pinned model name recorded everywhere; `jev-latest` never used for calibration | 2026-09-20 | Existing plan |
| Jev never opens a gate and never replaces the review verdict | standing | Existing plans |
| One shared bounded Jev client (`tools/lib/jev-client.sh` + `config/jev-decisions.json`) | 2026-09-20 | Advisory plan §9.2 |

### Open — implementer judgment, with criteria

| Open question | How to decide |
|---|---|
| Definition of **negative value** ("ended up being wrong") | Prefer: a finding is negative only if the transcript arc shows the finding was incorrect — either the author/main LLM pushed back with evidence and the reviewer withdrew/softened it, or the resulting fix was later reverted or undone as wrong. If the arc is silent, do **not** mark negative; leave it at its face level and flag for the labeled-sample pass. If this is still undecidable at Phase 4, stop and ask the owner — it is a business-meaning definition of what counts as harmful review. |
| Chunk size and overlap | Start with a size that keeps one review request + verdict + first author reaction together when possible (see Step 3). Tune only on the tuning split, once. |
| Exact question wording and thresholds | Produce them in the calibration step from labeled data. Do not copy TypeSafe demo wording. |
| Whether "reviewer tooling / meta discussion" is a third filter category | Yes if the labeled sample shows the chunk filter otherwise confuses "talking about reviewers" with "a change was reviewed". Keep it as a `Choice` sibling label so those chunks are excluded from value scoring but still counted. |
| Keep the pipeline after the report | Default: keep the caller scripts + config + labeled fixtures as evidence; delete any bulk derived data. Decide at Phase 6. |
| Which machine runs the full archive pass | Whichever managed host has the archive and a working `op run` + Jev key. Name it in the verification artifact. |

---

## 9. The plan — numbered, ordered, executable steps

Phases are context-cut points. **Before starting each phase, re-read this plan's STATUS table and that phase's steps.** If the STATUS table and this section disagree, STATUS wins on what is done; this section wins on how.

### Phase 0 — Session setup

**Step 0.1 — Worktree and task class.**
Create a current-upstream worktree of `popcre/ai-devops` (never edit the landing checkout). Run `bin/ai-task-gates start --class private-evidence` if the session will read raw transcripts in the same change set; run `--class code` / `--class tooling` once the change set is only scripts; run `--class prose` for report/plan-only commits. Reclassify at each boundary; do not smuggle code into a prose declaration.
Done when: `git worktree list` shows the new path; `bin/ai-task-gates show` prints the declared class.
Dependency: none.

**Step 0.2 — Required reading.**
Read `AGENTS.md`, `docs/task-router.md` rows for transcript analysis and reviewer work, `plan_typesafe-jev-decision-layer.md` §§5–7, `plan_typesafe-jev-advisory-integrations.md` §9.2, `plan_typesafe-jev-spend-reduction.md` §§5–9 and its STATUS, `plan_reviewer-spend-waste.md` STATUS (read-only, do not redo), and this plan in full.
Done when: the implementer can state the five value levels and the safety-gate bucket rule without looking them up.

### Phase 1 — Inventory and read-all cost baseline

**Step 1.1 — Locate and inventory the transcript archive.**
On the host named in §12, enumerate session transcripts (Claude, Codex, MiMo — whichever cover reviewer work). Count files/records. Record: total records, approximate bytes, date range, and how many records mention review activity *by cheap structural signals* (role/tool name, `ai-review` invocations, reviewer event ids) — not by prose keywords alone. Exclude system prompts, copied policy text, tool stdout dumps, subagent copies, and duplicate transcripts from the candidate pool, following spend-reduction §9.1.
Done when: `tests/verification/jev/review-waste-inventory-<UTC>.md` exists with aggregate counts only (no transcript text, no private identifiers, no archive paths beyond a machine name).
Dependency: 0.1.

**Step 1.2 — Estimate what frontier-read-all would cost.**
Using billed token fields where present (state what cannot be priced), estimate the cost of sending *all* candidate review-related content to a frontier model for classification. Also estimate Jev cost at the pinned model rate for the same content under the intended chunking. This is the number the final report compares against.
Done when: the same inventory artifact contains both estimates with the price date and model pin.
Dependency: 1.1.

**Step 1.3 — Join to the reviewer events spine.**
Read `tools/reviewer_events.py` and the live `events.jsonl` location it defines. Build a local join key list: dispatch id / head / digest / PR number / timestamp — whatever the log actually carries. This defines what counts as "work sent to a reviewer".
Done when: the inventory artifact records which join keys exist and how many transcript candidate chunks can be tied to at least one event.
Dependency: 1.1.

### Phase 2 — Shared Jev client and decision config

**Step 2.1 — Consume or build the shared client.**
First check whether `tools/lib/jev-client.sh` and `config/jev-decisions.json` exist (advisory plan §9.2). If yes, consume them and do not create another transport. If no, execute advisory-plan §9.2 exactly as the common foundation (secret bootstrap via `op run`, bounded timeouts, byte limits, per-run call caps, `jev_cleanup`, no key in logs) and update the advisory plan STATUS. Reuse/refactor `bin/ai-jev-probe` and `bin/ai-jev-completion-shadow` onto it.
Done when: `bash tests/test-ai-jev-scripts.sh` passes; `GET /v1/models` result (exact pin) is recorded in `config/jev-decisions.json`.
Dependency: 0.1. Can run parallel to Phase 1.

**Step 2.2 — Add the review-waste question set to config.**
In `config/jev-decisions.json`, add only this target's questions:
- `chunk_filter` — `Noul` (or a `Choice` if the meta-discussion sibling is kept; see §8 open).
- `value_level` — `Score` against the five ordered levels in §8 (labels: `highest`, `medium`, `low`, `none`, `negative`).
Record exact wording, label enums, and starting thresholds as *unfrozen* placeholders that calibration will freeze.
Done when: `tests/test-tool-version-pins.sh` (or the advisory equivalent) validates the config schema; no second client file exists.
Dependency: 2.1.

**Step 2.3 — Thin callers.**
Add `bin/ai-jev-review-waste` (and a Windows `.cmd` shim if the repo convention requires one) as a thin consumer of the shared client. Read-only. Returns `abstain` on any error, uncertainty, model mismatch, or changed source digest. Batch independent chunk questions in one call where they share state. Preselect public state in code.
Done when: `bash tests/test-ai-jev-review-waste.sh` exists and passes with stubbed endpoint; `tests/test-ai-jev-scripts.sh` still passes.
Dependency: 2.2.

### Phase 3 — Chunk filter (Noul) + calibration

**Step 3.1 — Chunking.**
Write a local chunker (script under `tools/` or `bin/`) that splits candidate transcript records into bounded chunks aimed at keeping one review request + verdict + first author reaction together when they are adjacent. Emit chunk ids + digests only into the repo tree; keep chunk text in a private working directory outside the repo.
Done when: a unit test feeds a small synthetic multi-turn fixture and asserts chunk boundaries and that no chunk text is written under the repo root.
Dependency: 1.1, 2.3.

**Step 3.2 — Labeled filter sample.**
Build `tests/fixtures/jev/review-waste-chunk-labels.json` with at least 30 independently labeled public/synthetic chunk cases: positives (real review request/verdict/reaction), negatives (unrelated chat), near matches (meta discussion of reviewers/tooling), and adversarial inputs (copied policy text that says "review", prompt-injection-shaped text, huge tool dumps). Split into tuning and untouched holdout **before** any threshold change.
Done when: fixture file exists; labels are public/synthetic only (no real transcript excerpts in the repo).
Dependency: 3.1.

**Step 3.3 — Freeze filter wording and threshold.**
At most one tuning pass on the tuning split. Freeze question wording and threshold. Run the holdout. Save `tests/verification/jev/review-waste-chunk-shadow-<UTC>.md` with per-case public id/digest, label, model pin, config digest, probabilities, abstention, confusion counts, usage tokens, latency.
Done when: holdout confusion counts are recorded and the freeze is written into `config/jev-decisions.json`.
Dependency: 3.2.

**Step 3.4 — Shadow pass over a sample of the real archive.**
Run the frozen chunk filter over a small bounded sample of real chunks (private working dir). Do not send the whole archive yet. Record only aggregates: how many chunks marked, how many abstained.
Done when: a short aggregate note sits in the Phase 3 verification artifact; no raw chunk text in the repo.
Dependency: 3.3.

### Phase 4 — Review-arc stitch + value Score

**Step 4.1 — Stitch review arcs.**
Using the events-log join keys (Step 1.3) plus adjacent marked chunks, assemble **review interactions**: one dispatch/PR head → reviewer verdict → author reaction/fix (or non-fix). One interaction is the unit that receives one `value_level` Score. Do not score isolated chunks.
Done when: a synthetic fixture test proves three chunk fragments + one event become exactly one interaction, and a chunk with no event stays unscored.
Dependency: 3.3, 1.3.

**Step 4.2 — Labeled value sample.**
Build `tests/fixtures/jev/review-waste-value-labels.json` with at least 30 public/synthetic interaction cases spanning all five levels (including several **negative** and several safety-gate "nothing added" cases so the bucket rule is testable). Same tuning/holdout discipline as Step 3.2.
Done when: fixture exists and covers every level label at least once; holdout untouched.
Dependency: 4.1.

**Step 4.3 — Freeze value wording and threshold(s).**
`Score` with five ordered labels. At most one tuning pass. Freeze. Save `tests/verification/jev/review-waste-value-shadow-<UTC>.md` in the same record shape as Step 3.3.
Done when: config frozen; holdout artifact exists.
Dependency: 4.2.

**Step 4.4 — Classify the real corpus (bounded).**
Run the frozen value Score over stitched interactions from the sample, then the full candidate set, with per-run call caps and cost logging. Separate bucket for mandatory safety-gate interactions (from task-gates class / gate type in the join), so "nothing added" there is not scored as discretionary waste.
Done when: aggregate counts per level per bucket exist in the private working dir, with total Jev tokens/cost; repo tree holds only the verification summary.
Dependency: 4.3.

### Phase 5 — Aggregation + waste report

**Step 5.1 — Slice the labeled results.**
Group by: reviewer identity, class of work (task class / change kind from the join), repository, time (month), and mandatory-vs-discretionary. Compute per-slice: n, rate(highest+medium), rate(low), rate(none), rate(negative), and estimated cost if billed data exists.
Done when: a local table exists and each cell has n ≥ threshold (default 5) before it is written to a public artifact; smaller cells are suppressed to avoid identifying one conversation.
Dependency: 4.4.

**Step 5.2 — Write the public waste report.**
Create `tests/verification/jev/review-waste-report-<UTC>.md`. Aggregate only: slice labels, counts/rates, Jev vs frontier cost comparison from Step 1.2, model pin, config digests, method. **No transcript text, no private identifiers, no archive paths.** Name the low-value patterns in plain English.
Done when: a privacy check (same standard as spend-reduction §9.1 "Reviewer access to the baseline") passes: no excerpts, no prompts, no small cells.
Dependency: 5.1.

**Step 5.3 — Decision brief.**
Write a short brief for Albert (can be a section of the report): which classes of review traffic show low value rates, which are mandatory and stay, and what a cost saving could look like — as options, not as an implemented change.
Done when: the brief names options and stops. No policy change is made in this plan.
Dependency: 5.2.

### Phase 6 — Closeout

**Step 6.1 — Land evidence and update plans.**
PR the public artifacts + scripts + fixtures + tests. Update STATUS tables here and in the advisory plan if the shared client changed. Link the report from the issue this work is tracked on (create one if none exists, titled for review-waste mining). Fold durable conclusions into `plan_typesafe-jev-decision-layer.md`. Delete this plan's handoff when the work is truly done, or leave it open if Phase 6 is incomplete.
Done when: merged commit on `origin/main` names the report artifact; STATUS rows cite those paths.
Dependency: 5.3.

**Step 6.2 — Keep-or-delete derived data.**
Delete bulk derived chunk/interaction text from the private working dir unless the owner asks to keep it for a follow-on trial. Keep labeled fixtures, config, callers, and verification summaries.
Done when: working dir contents are listed in the closing note.

---

## 10. Tests required

Named tests — not "add tests":

| Test | Proves |
|---|---|
| `tests/test-ai-jev-scripts.sh` (existing, must stay green) | Shared client secret/timeout/malformed-response contract |
| `tests/test-ai-jev-review-waste.sh` (new) | Thin caller: abstains on error/model mismatch; batches questions; never prints a key |
| `tests/test-jev-review-waste-chunker.sh` (new) | Chunk boundaries on a synthetic multi-turn fixture; **no chunk text written under the repo root** |
| `tests/test-jev-review-waste-value-arc.sh` (new) | Stitches request+verdict+reaction into one interaction using join keys; unscored when no event |
| `tests/test-jev-review-waste-metrics.sh` (new) | Holdout split preserved; no label leakage; small-cell suppression; refuses savings claim when price/usage fields missing |
| `tests/test-tool-version-pins.sh` (extend) | `config/jev-decisions.json` schema, pinned model, label enums |
| Existing reviewer suites named by `docs/task-router.md` for the touched wrappers | No regression if `ai-jev-probe` / `completion-shadow` are refactored |

Offline only in CI. Live Jev calls are local, bounded, and recorded in `tests/verification/jev/`.

---

## 11. Constraints, standing rules, and gotchas in force

- **Public repo.** Never commit raw transcript text, excerpts, prompts, credentials, request bodies, or generated logs. Aggregates only.
- **Task class honesty.** `private-evidence` while reading raw transcripts; redeclare when the change set becomes code/prose. A protected class cannot be acknowledged away.
- **One Jev client.** `tools/lib/jev-client.sh` only. No second transport, no second secret bootstrap.
- **Pinned model.** Never calibrate against `jev-latest`. A model change invalidates thresholds.
- **Abstain on everything uncertain.** Error, timeout, malformed response, model mismatch, changed source digest → `abstain`, not a guessed label.
- **Jev is read-only.** It never opens a gate, never issues a review verdict, never mutates state.
- **Safety-gate bucket is separate.** Mandatory reviews are not discretionary waste, even at value `none`.
- **Do not redo** `plan_reviewer-spend-waste.md` (done) or reopen `plan_typesafe-jev-spend-reduction.md`'s no-go (different target).
- **Bounded calls.** Timeouts, byte limits, per-run caps. No open-ended loops around the network.
- **Windows:** PowerShell-compatible; run Bash tests through Git Bash (`bin/ai-task-gates.cmd` and sibling `.cmd` launchers exist for a reason).
- **Git:** branch + PR + merge queue; never push to `main`; `git var GIT_COMMITTER_IDENT` must show `Albert Hazan <u2giants@users.noreply.github.com>`; stage only task-owned files; no destructive resets.
- **Secrets:** Jev key lives in 1Password vault `vibe_coding`, item `typesafe.ai API`, resolved through `op run` at execution time. Never in chat, argv, logs, or commits.
- **Live proof.** A STATUS row is done only with an artifact path, not a bare number.
- **This is not the place to change review policy.** Evidence only.

---

## 12. Access and environment

| Need | Where |
|---|---|
| Repo | `popcre/ai-devops`, worktree off `origin/main`. `bin/ai-gh` for all GitHub calls. |
| Transcript archive | Local path on the analysis host. Historically `/home/ahazan/Dropbox/ai/chat_transcripts/` on Linux (edge-dev3). On Windows, the matching Dropbox path if synced. MiMo sessions: `~/.local/share/mimocode/mimocode.db` (SQLite) — use `mimo-transcript-backup` skill conventions for mining; keep any backup in the private transcripts repo only. **Never copy raw archive files into `popcre/ai-devops`.** |
| Reviewer events | `~/.local/state/ai-devops/reviewer-events/events.jsonl` (override `AI_REVIEW_EVENT_DIR`); writer `tools/reviewer_events.py` |
| Jev API | `POST https://api.typesafe.ai/v1/systemone`; discover pin via `GET /v1/models`; docs `https://docs.typesafe.ai/api` |
| Jev credential | 1Password vault `vibe_coding`, item `typesafe.ai API`. Resolve with `op run` only. |
| Reachability check | `bin/ai-jev-probe` (bounded) |
| Task gates | `bin/ai-task-gates` (Git Bash) / `bin/ai-task-gates.cmd` |
| Test collision check | `bin/ai-test-local --check-collision` before a full local series |
| Owner ruling on transcript redaction | Albert, 2026-10-12 chat: transcripts redacted, no longer private; still do not commit raw text |

---

## 13. Definition of done + risks and open questions

### Definition of done

- [ ] Inventory artifact with cost estimates (`tests/verification/jev/review-waste-inventory-<UTC>.md`)
- [ ] Shared Jev client consumed or built; pinned model recorded; `tests/test-ai-jev-scripts.sh` green
- [ ] Chunk filter frozen + holdout artifact; value Score frozen + holdout artifact
- [ ] Review arcs stitched with join keys; safety-gate bucket separate
- [ ] Public waste report with privacy check passed (`tests/verification/jev/review-waste-report-<UTC>.md`)
- [ ] Decision brief naming low-value patterns as **options** for Albert
- [ ] All named tests in §10 green; `bin/ai-test-local --check-collision` clean before a full series
- [ ] Branch + PR + merge queue; commit on `origin/main` verified
- [ ] STATUS table updated with artifact paths; advisory plan STATUS updated if shared client changed
- [ ] Handoff deleted or explicitly left open; durable conclusions folded into `plan_typesafe-jev-decision-layer.md`

### Risks

| Risk | Mitigation |
|---|---|
| Chunk filter floods false positives from policy text | Holdout includes copied-policy adversarial cases; meta-discussion sibling label |
| Value scale disagrees with human judgment | 30+ labeled sample with human labels before any full run; one tuning pass only |
| Cost of Jev still large on a huge archive | Phase 1 estimates first; per-run caps; batch shared-state questions; abort if estimate exceeds a sane bound and re-scope to a date slice |
| Model pin changes mid-run | Record pin on every artifact; abort calibration validity on mismatch |
| Small cells identify one conversation | Suppression threshold in metrics test |
| Implementer "helpfully" changes review policy | §4 NOT list; §1 goal statement; deliver options only |
| Accidental commit of raw text | Chunker test asserts no text under repo root; privacy check before PR |

### Open questions (with criteria)

See §8 open table. The only one that can stop Phase 4 is the **negative-value definition**; if the transcript arc cannot decide it per case, mark `abstain` and surface the contested cases to the owner.

---

## Self-audit (required — final answers preserved)

**1. Could a brand-new AI session with no project knowledge execute this plan without asking anything?**
Yes. §1 goal + "goal wins"; §2 defines Jev, the repo, the pipeline shape; §5 current state with what exists vs missing (`jev-client.sh` absent); §9 steps name files and gates; §12 gives paths, credential location (never values), and the owner ruling. Gap found and fixed during drafting: negative-value definition was left as pure prose — §8 open table now gives the preferred definition, the abstain rule, and the stop-and-ask criterion.

**2. Does the plan carry every piece of background, nuance, and reasoning — including what we ruled out and why?**
Yes. §6 findings (1–10) carry the Jev capability limits, mention≠call, events spine, Score-vs-Choice, safety-gate bucket, model pin, redaction ruling, frontier-only-on-marked. §7 rejected-approach table includes the binary-value rejection, the "problem without fix is value" correction, keyword search, compaction plugin, and "count every nothing as waste". The 2026-09-27 no-go is explicitly not reopened.

**3. Is the ultimate goal clear enough for judgment calls when a step is wrong?**
Yes. §1 states the business goal in plain English (stop paying for reviews that almost never improve anything) and the hard constraint (quality on high-value traffic unchanged), plus "if a step conflicts with this goal, the goal wins — stop and flag it". §13 reinforces that policy change is out of scope and options-only.
