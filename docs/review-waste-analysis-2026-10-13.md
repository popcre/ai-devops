# Review-waste analysis — findings and routing pattern (2026-10-13)

**Status:** evidence complete. No review policy has been changed by this work.  
**Primary artifact:** [`tests/verification/jev/review-waste-report-20261013T162000Z.md`](../tests/verification/jev/review-waste-report-20261013T162000Z.md)  
**Per-reviewer detail:** [`tests/verification/jev/review-waste-reviewer-detail-20261013.md`](../tests/verification/jev/review-waste-reviewer-detail-20261013.md)  
**Method plan:** [`plan_jev-review-waste-mining.md`](../plan_jev-review-waste-mining.md)  
**Model:** TypeSafe Jev `jev-1.13.0` (typed Score only; no free text)

---

## 1. Why this exists

Albert pays real money for AI code reviews. Some classes of work almost never
come back with a correction or improvement. Those reviews are waste. Other
classes almost always find something worth fixing.

Goal: **stop paying for reviews that almost never improve anything, without
losing the reviews that do.**

This document records what the data showed. Policy change is Albert's decision.

---

## 2. What was measured

| Item | Value |
|---|---|
| Corpus | Local AI session transcript archive, **9,104** session files |
| Paid-review spine | Reviewer events log: **2,889** dispatch heads |
| Heads present in archive | **2,290** (these are the scored population) |
| Value labels decided | **654** (of 2,290; rest abstain/error after retries) |
| Discretionary decided (joined) | **492** |
| Method | Stitch review arc (dispatch/head → verdict → author reaction) → Jev `Score` on five ordered levels |
| Five levels | `highest` (problem + useful fix) · `medium` (problem, no fix) · `low` (style) · `none` (nothing added) · `negative` (wrong finding) |
| Safety-gate rule | Mandatory safety reviews that find nothing are **assurance**, not discretionary waste — separate bucket |
| Privacy | Aggregates only in the public repo. Raw transcripts never committed. |

---

## 3. Headline result

Of discretionary reviews Jev could judge (joined sample n=492):

| Outcome | n | Share |
|---|---:|---:|
| **Added nothing** (`none`) | 452 | **92%** |
| **Found a real problem** (`highest` + `medium`) | 37 | **8%** |
| Style only (`low`) | 1 | <1% |
| Wrong finding (`negative`) | 2 | <1% |

**92% of discretionary review traffic, in this history, did not improve the work.**

The 8% that did are concentrated — not spread evenly (see §5).

---

## 4. Can we separate the work that should skip review?

**Yes.** The separator is **class of work (repository) × which reviewer is used**,
not a single keyword in the prompt.

### 4.1 By class of work (discretionary, n≥10)

| Work type | n | None rate | High rate | Reading |
|---|---:|---:|---:|---|
| `oracle` | 27 | **100%** | 0% | Never paid off in this history |
| `dflow` | 88 | **98%** | 0% | Never paid off |
| `ai-devops` | 239 | **95%** | 5% | Almost never pays off |
| `shared-db` | 122 | 79% | **20%** | **The only place real findings live** |

No work type had a *low* none-rate at n≥10. Even `shared-db` is mostly
no-ops — but it contains essentially all of the valuable findings.

### 4.2 By reviewer × work (n≥8)

| Pairing | n | High rate | Note |
|---|---:|---:|---|
| **deepseek @ shared-db** | 9 | **67%** | Best yield in the archive |
| **muse @ shared-db** | 25 | **32%** | Strong |
| **grok @ shared-db** | 20 | 20% | Solid |
| **qwen @ shared-db** | 17 | 18% | Solid |
| codex @ ai-devops | 194 | 2% | Volume without value |
| codex @ dflow | 85 | 0% | Skip |
| codex @ shared-db | 32 | 0% | Codex missed what others found |
| codex @ oracle | 27 | 0% | Skip |

### 4.3 The keepers (the 8%) — where they actually were

Every `highest`/`medium` finding (n=47 in the wider sample) sat almost entirely
on **shared-db worktrees** (style-guide, migrations, coldlion, role-tree,
disney titles, custody, milestone schedules, locks, etc.), reviewed by
**muse, grok, qwen, deepseek, gemini, claude** — not by Codex-on-tooling.

### 4.4 Proposed split (options only — not implemented)

| Lane | Scope | History | Option |
|---|---|---|---|
| **SKIP** | `dflow`, `oracle`, Codex-heavy `ai-devops` docs/tooling | 95–100% no-op | Make discretionary review optional |
| **MIXED** | rest of `ai-devops`, especially safety-class | mostly no-op | Optional, or only `reviewer-safety` |
| **KEEP** | `shared-db` with muse / grok / qwen / deepseek (and other non-Codex on that repo) | 20–67% real findings | **Keep mandatory review** |

Safety-gate / `reviewer-safety` traffic stays mandatory regardless (assurance).

---

## 4.5 Stronger separators than repo: review mode and caller

Repo is a good first cut, but two other indicators separate even harder
(discretionary decided, n=495; baseline high rate 8%):

### By review *mode* (what kind of review was asked for)

| Mode (from review arc) | n | High rate | None rate | Reading |
|---|---:|---:|---:|---|
| **plan-review** | 74 | **1%** | 99% | Almost pure waste |
| **diff-review** | 117 | **2%** | 97% | Almost pure waste |
| **final-check** | 295 | **3%** | 97% | Almost pure waste |
| security-review | 38 | 8% | 92% | Baseline |
| implementation | 225 | **10%** | 89% | Slightly above |
| investigation / diagnosis | 312 | 8% | 92% | Baseline |
| (no mode named) | 25 | **24%** | 72% | Small n; often real work reviews |

**Type of review is a first-class signal.** Final-check / diff-review /
plan-review traffic is where the waste lives.

### By *caller* (which agent sent the work to review)

| Caller | n | High rate | None rate | Reading |
|---|---:|---:|---:|---|
| **codex** | 387 | **3%** | 97% | Dominates volume; almost no yield |
| claude | 47 | **28%** | 72% | Strong |
| unknown | 36 | 11% | 89% | Mixed |
| mimo | 15 | **40%** | 60% | Strong (small n) |
| zcode | 9 | **56%** | 44% | Strong (small n) |

**Who sent it matters as much as what repo it is.** Codex-initiated reviews
are 3% yield; Claude/MiMo/ZCode-initiated reviews are 28–56% yield.

### Change-type tags (weaker alone)

Keywords in the review arc do **not** separate well on their own (almost every
arc mentions config/security/tests). Mild lift only:

| Tag | n | High rate |
|---|---:|---:|
| data load / scrape | 31 | **23%** |
| schema / migration | 208 | 12% |
| CI workflow | 190 | 12% |
| windows / install | 355 | 5% |
| docs | 462 | 7% |

### Combined rule that actually separates the 8%

Waste cluster (**skip candidates**):
caller=codex **AND** mode in (inal-check, diff-review, plan-review)
→ in this history that is hundreds of reviews at ~2–3% high rate.

Keep cluster (**mandatory review**):
caller in (claude, mimo, zcode) **OR** shared-db + non-Codex reviewer
**OR** mode is implementation/investigation on data-load / schema work
→ 20–56% high rates.

That is a **review-type + caller** rule, not a repo rule. Repo was the first
cut; this is the sharper one.

## 5. How good or bad is each reviewer?

Discretionary decided only. **High** = named a real problem (`highest`+`medium`).

| Rank | Reviewer | n | High rate | None rate | Verdict |
|---:|---|---:|---:|---:|---|
| 1 | **deepseek** | 12 | **50%** | 50% | Earns its keep |
| 2 | **claude** | 8 | 38% | 50% | Earns its keep (small n) |
| 3 | **muse** | 35 | **26%** | 74% | Mixed — strongest at volume |
| 4 | glm | 9 | 22% | 78% | Mixed (small n) |
| 5 | qwen | 24 | 17% | 83% | Mixed |
| 6 | grok | 37 | 16% | 84% | Mixed |
| 7 | gemini | 14 | 14% | 86% | Low yield |
| 8 | **codex** | **344** | **1%** | **98%** | **Mostly no-op in this history** |
| 9 | kimi | 7 | 0% | 100% | No yield (small n) |

### Plain reading

- **Codex** generated **70% of the review volume** and **almost none of the value**
  (338 of 344 reviews added nothing). Cutting Codex-on-tooling/dflow/oracle
  traffic is the single largest savings lever.
- **Deepseek** and **muse** are the best value producers, especially on `shared-db`.
- **Grok / qwen** are consistent mid-yield on `shared-db`.
- **Kimi / gemini** rarely found problems in this history.

Full tables (work types, callers, operations, reviewer×work) live in
[`review-waste-reviewer-detail-20261013.md`](../tests/verification/jev/review-waste-reviewer-detail-20261013.md).

---

## 6. Cost of the analysis vs cost of the waste

| Item | Amount |
|---|---|
| Jev labeling (full archive + value pass) | ~**$16** |
| Frontier LLM read-all of the same corpus (est. from inventory) | **$2,300–$8,800** |
| Shape of a wasted review | Reviewer tokens + latency + queue time for a no-op |
| Shape of a kept review | Same cost, but it found a real problem |

The measurement itself is cheap. The waste it measures is not.

---

## 7. What this does **not** say

- It does **not** say Codex is a bad model. It says *this dispatch pattern*
  (mostly tooling/docs/dflow/oracle) almost never needed review.
- It does **not** authorize cutting `reviewer-safety` or any mandatory gate.
- It does **not** replace independent review on the keep-list.
- Small-n cells (claude 8, deepseek 12, glm 9) are directional, not precise.
- Jev labels; it does not reason. A frontier LLM can re-read a marked subset
  if deeper confirmation is wanted.

---

## 8. Recommended next actions (owner decisions)

1. **Approve a skip-list** for `dflow` / `oracle` / Codex-heavy `ai-devops`
   discretionary review (optional instead of mandatory).
2. **Keep mandatory review** on `shared-db` (especially with muse/grok/qwen/deepseek).
3. **Leave safety gates unchanged.**
4. Optionally re-score a sample with a frontier LLM to confirm Jev's `none` labels.
5. Re-run this pipeline later to measure whether the skip-list cut waste
   without losing findings.

---

## 9. Evidence index

| Artifact | What it holds |
|---|---|
| `review-waste-inventory-20261012T162801Z.md` | Archive size, cost baseline, events join keys |
| `review-waste-chunk-shadow-20261012T180611Z.md` | Chunk-filter calibration |
| `review-waste-value-shadow-20261012T180611Z.md` | Value-score calibration |
| `review-waste-report-20261012T180833Z.md` | 12-file pilot |
| `review-waste-report-20261013T112939Z.md` | 250-file sample |
| `review-waste-report-20261013T162000Z.md` | **Full archive, events-joined** |
| `review-waste-reviewer-detail-20261013.md` | **Per-reviewer + work-type tables** |
| `config/jev-decisions.json` | Frozen Jev questions and five-level scale |
| `tools/lib/jev-client.sh` | Shared bounded Jev client |

Posted by MiMo chat `ses_ffe5ecf246b07ffeDxdzZb2d2G` on `edge-dev`.
