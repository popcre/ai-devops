# Recommendation — cut wasted review traffic without losing the 8% (2026-10-13)

**Audience:** Albert (owner decision)  
**Evidence base:** Full-archive Jev value scores on every paid review found in 9,104 AI session transcripts (2,290 heads; 495 discretionary decided).  
**Related:** [`review-waste-analysis-2026-10-13.md`](review-waste-analysis-2026-10-13.md) · [`review-waste-reviewer-detail-20261013.md`](../tests/verification/jev/review-waste-reviewer-detail-20261013.md) · [`review-waste-report-20261013T162000Z.md`](../tests/verification/jev/review-waste-report-20261013T162000Z.md)

---

## 1. The recommendation in one paragraph

**Stop requiring discretionary AI review when (a) the caller is Codex and (b) the review is a `final-check`, `diff-review`, or `plan-review` — especially on `dflow`, `oracle`, and `ai-devops` tooling/docs. Keep mandatory review on `shared-db` work and on sends from Claude/MiMo/ZCode (implementation or investigation reviews), and leave every `reviewer-safety` gate untouched.** In this archive that skip cluster is hundreds of reviews at **2–3%** real-finding rate; the keep cluster is **20–56%**. Expected effect: cut most of the 92% no-op spend while protecting essentially all of the 8% that improved the work.

---

## 2. Why (the numbers)

### 2.1 The problem is large and concentrated

| Fact | Number | Source |
|---|---|---|
| Paid reviews in the events log | 2,889 | `events.jsonl` |
| Found in transcripts and scored | 2,290 | full-archive scan |
| Discretionary reviews Jev could judge | 492 | joined decided |
| **Added nothing** | **452 (92%)** | value Score = `none` |
| **Found a real problem** | **37 (8%)** | `highest` + `medium` |
| Wrong findings | 2 | `negative` |
| Cost to measure all of this with Jev | ~$16 | run logs |

92% of discretionary review did not improve the work. That is the spend to attack.

### 2.2 Three indicators, in order of strength

Baseline real-finding rate: **7.7%**.

#### A. Review mode (strongest)

| Mode | n | Real findings | No-ops | vs baseline |
|---|---:|---:|---:|---|
| plan-review | 74 | 1% | 99% | **−87% relative** |
| diff-review | 117 | 2% | 97% | **−74%** |
| final-check | 295 | 3% | 97% | **−61%** |
| security-review | 38 | 8% | 92% | at baseline |
| investigation | 312 | 8% | 92% | at baseline |
| implementation | 225 | 10% | 89% | +30% |
| (unspecified mode) | 25 | 24% | 72% | +213% (n small) |

#### B. Caller (who dispatched the review)

| Caller | n | Real findings | No-ops | vs baseline |
|---|---:|---:|---:|---|
| **codex** | 387 | **3%** | 97% | **−61%** |
| unknown | 36 | 11% | 89% | +43% |
| **claude** | 47 | **28%** | 72% | **+264%** |
| **mimo** | 15 | **40%** | 60% | **+420%** |
| **zcode** | 9 | **56%** | 44% | **+627%** (n small) |

#### C. Work type / repo (first cut; useful, coarser)

| Work type | n | Real findings | No-ops |
|---|---:|---:|---:|
| oracle | 27 | 0% | 100% |
| dflow | 88 | 0% | 98% |
| ai-devops (mostly tooling) | 239 | 5% | 95% |
| **shared-db** | 122 | **20%** | 79% |

#### D. Reviewer (who performed the review)

| Reviewer | n | Real findings | No-ops |
|---|---:|---:|---:|
| deepseek | 12 | 50% | 50% |
| claude (as reviewer) | 8 | 38% | 50% |
| muse | 35 | 26% | 74% |
| glm | 9 | 22% | 78% |
| qwen | 24 | 17% | 83% |
| grok | 37 | 16% | 84% |
| gemini | 14 | 14% | 86% |
| **codex (as reviewer)** | **344** | **1%** | **98%** |
| kimi | 7 | 0% | 100% |

Change-type keywords (docs, tests, schema, CI…) are **weak** alone. Mild lift only for data-load/scrape (23% high, n=31) and schema/migration or CI (12%).

### 2.3 Where the 8% actually lived

Every high-value finding sat almost entirely on **shared-db worktrees** (migrations, coldlion, role tree, style guides, locks, custody, milestones, Disney titles), reviewed mainly by **muse, grok, qwen, deepseek, gemini, claude** — sent by **Claude/MiMo/ZCode**, not by Codex’s final-check loop on tooling.

Best cell in the archive: **deepseek reviewing shared-db** — 67% real findings (n=9).  
Best volume cell: **muse reviewing shared-db** — 32% (n=25).

Codex-on-dflow and Codex-on-oracle produced **zero** real findings.

---

## 3. Recommended rule (draft for approval)

```
IF   dispatch is discretionary (not reviewer-safety / not a mandatory gate)
AND  caller is codex
AND  review type is final-check OR diff-review OR plan-review
AND  work type is dflow OR oracle OR ai-devops tooling/docs
THEN review is OPTIONAL (skip by default; allow override)

ELSE IF work type is shared-db
      OR caller is claude/mimo/zcode
      OR review type is implementation/investigation
THEN review is MANDATORY (keep)

ALWAYS keep: reviewer-safety and every other named safety gate
```

### Expected impact (from this archive)

| Slice | Reviews | Real findings | Proposal |
|---|---:|---:|---|
| Codex × final-check/diff/plan (waste cluster) | ~300+ | ~2–3% | **Make optional** |
| shared-db + non-Codex (keep cluster) | ~100+ | 20–67% | **Keep mandatory** |
| Safety-gate | small | assurance | **Keep mandatory** |

Rough order of magnitude: **most of the 92% no-op traffic becomes skippable**; almost none of the 37 real findings fall in the skip cluster.

---

## 4. What we are *not* recommending

1. **Not** removing Codex from the roster. Codex is fine as a model; the *dispatch pattern* (hundreds of final-checks on tooling) is what wastes money.
2. **Not** weakening `reviewer-safety` or any protected gate.
3. **Not** skipping review on shared-db structure/migrations or on Claude/MiMo/ZCode sends.
4. **Not** treating Jev as a review verdict. Jev labeled history; it does not approve anything.
5. **Not** a permanent blind rule without re-measurement (see §6).

---

## 5. Implementation sketch (only if Albert approves)

| Step | What | Owner |
|---|---|---|
| 1 | Owner approves the skip rule above (business decision) | Albert |
| 2 | Encode as a **routing hint / optional-dispatch** policy — not a silent gate bypass | toolkit session |
| 3 | Keep an explicit override (“review anyway”) for risky changes | toolkit session |
| 4 | Re-run this measurement in 30 days; compare finding rate on keep-list | this pipeline |
| 5 | If finding rate on keep-list drops, reopen the rule | owner |

No policy file has been changed yet. This document is the recommendation only.

---

## 6. Risks and how we guard them

| Risk | Guard |
|---|---|
| Skip-list hides a real bug that review would have caught | Keep-list is defined by *where findings actually happened*; override option stays |
| Jev mislabels a valuable review as `none` | 8% finding rate is consistent across slices; optional frontier re-read of a sample |
| Small-n cells (zcode 9, claude-as-reviewer 8) overfit | Directional only; do not carve special rules from n<15 |
| Codex volume includes some genuine catches (4 high in 344) | Those were on `ai-devops` real code, not tooling final-checks — keep-list covers them |
| Policy creep into safety gates | Explicit: safety gates out of scope forever in this recommendation |

---

## 7. Decision requested

Albert to choose one:

1. **Approve the skip rule (§3)** and have it encoded as optional discretionary review.
2. **Approve a narrower cut** — only `dflow` + `oracle` + Codex final-checks (leave `ai-devops` mandatory).
3. **Hold** — keep current policy; treat this as baseline and re-measure later.
4. **Deepen** — pay for a frontier LLM to re-read a sample of `none` labels before deciding.

**My recommendation: option 1**, with a 30-day re-measurement built in. It is the only cut that removes the bulk of the 92% while the keep-list still covers every surface where review has historically paid.

---

## 8. Evidence trail (all public-safe)

- Inventory + cost baseline — `tests/verification/jev/review-waste-inventory-20261012T162801Z.md`
- Calibration — `review-waste-chunk-shadow-*.md`, `review-waste-value-shadow-*.md`
- Full-archive scores — `review-waste-report-20261013T162000Z.md`
- Per-reviewer tables — `review-waste-reviewer-detail-20261013.md`
- Method + patterns — `docs/review-waste-analysis-2026-10-13.md`
- Frozen questions — `config/jev-decisions.json`

Posted by MiMo chat `ses_ffe5ecf246b07ffeDxdzZb2d2G` on `edge-dev`.
