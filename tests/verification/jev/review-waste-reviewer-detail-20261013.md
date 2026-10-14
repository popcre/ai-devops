# Reviewer quality and work-type patterns (2026-10-13)

**Source:** full-archive events-joined Jev value scores (report `review-waste-report-20261013T162000Z.md`)  
**Population:** 1818 paid-review interactions joined to the reviewer events log  
**Decided:** 495 | **abstain:** 484 | **error (unscored):** 839  
**Discretionary decided:** 492 | **Safety-gate decided:** 3  
**Privacy:** aggregates only; no transcript text

---

## 1. Headline

Of discretionary reviews that Jev could judge:

- **452 / 492 (92%) added nothing**
- **37 (8%) found a real problem** (the keepers)
- Low/style-only: 1
- Wrong findings: 2

Safety-gate reviews (n=3) are assurance, not waste — excluded below.

---

## 2. Can we separate the work that should skip review?

**Yes — by repository / class of work and by reviewer assignment, not by a single magic keyword.**

The strongest separations in this archive (discretionary, n>=10):

**High waste (none rate high) — candidates to stop sending or make optional:**
### Work types with high waste

| work | n | none | high | low | neg | none rate | high rate |
|---|---:|---:|---:|---:|---:|---:|---:|
| ai-devops | 239 | 228 | 11 | 0 | 0 | 95% | 5% |
| shared-db | 122 | 96 | 25 | 1 | 0 | 79% | 20% |
| dflow | 88 | 86 | 0 | 0 | 2 | 98% | 0% |
| oracle | 27 | 27 | 0 | 0 | 0 | 100% | 0% |


**Lower waste (none rate lower) — these reviews earn their keep:**
### Work types with lower waste

| work | n | none | high | low | neg | none rate | high rate |
|---|---:|---:|---:|---:|---:|---:|---:|
| (no cell reached n>=5) | | | | | | | |


**Concrete split that separates the 8% (keep) from the 92% (skip):**

| lane | what it is | history | recommendation |
|---|---|---|---|
| **SKIP** | dflow, oracle, most ai-devops tooling/docs | 95-100% no-op, almost zero findings | make discretionary review optional |
| **MIXED** | ai-devops with non-Codex reviewers | still mostly no-op | optional, or only for safety-class changes |
| **KEEP** | shared-db work, especially with muse / grok / qwen / deepseek | 20%+ real findings (deepseek @ shared-db 67% high) | keep mandatory review |

The 8% that matter are concentrated in **shared-db** and in **non-Codex reviewers**. Codex-on-dflow and Codex-on-oracle produced **zero** real findings in this history.

This is a policy choice — not implemented here.

---

## 3. How good or bad is each reviewer?

Discretionary decided reviews only. **High** = named a real problem (highest+medium). **None** = added nothing.

### Per-reviewer value

| reviewer | n | none | high | low | neg | none rate | high rate |
|---|---:|---:|---:|---:|---:|---:|---:|
| deepseek | 12 | 6 | 6 | 0 | 0 | 50% | 50% |
| claude | 8 | 4 | 3 | 1 | 0 | 50% | 38% |
| muse | 35 | 26 | 9 | 0 | 0 | 74% | 26% |
| glm | 9 | 7 | 2 | 0 | 0 | 78% | 22% |
| qwen | 24 | 20 | 4 | 0 | 0 | 83% | 17% |
| grok | 37 | 31 | 6 | 0 | 0 | 84% | 16% |
| gemini | 14 | 12 | 2 | 0 | 0 | 86% | 14% |
| codex | 344 | 338 | 4 | 0 | 2 | 98% | 1% |
| kimi | 7 | 7 | 0 | 0 | 0 | 100% | 0% |


### Ranking (high rate first)

| rank | reviewer | n | high rate | none rate | verdict |
|---:|---|---:|---:|---:|---|
| 1 | deepseek | 12 | 50% | 50% | earns its keep |
| 2 | claude | 8 | 38% | 50% | earns its keep |
| 3 | muse | 35 | 26% | 74% | mixed |
| 4 | glm | 9 | 22% | 78% | mixed |
| 5 | qwen | 24 | 17% | 83% | mixed |
| 6 | grok | 37 | 16% | 84% | mixed |
| 7 | gemini | 14 | 14% | 86% | mostly no-op in this history |
| 8 | codex | 344 | 1% | 98% | mostly no-op in this history |
| 9 | kimi | 7 | 0% | 100% | mostly no-op in this history |

### Reviewers with real yield (high rate >= 15%, n>=15)

- **muse** — 9 real findings in 35 reviews (26% high, 74% none)
- **qwen** — 4 real findings in 24 reviews (17% high, 83% none)
- **grok** — 6 real findings in 37 reviews (16% high, 84% none)

### Reviewers with mostly no-op results (none rate >= 85%, n>=15)

- **codex** — 338 no-ops in 344 reviews (1% high)

---

## 4. Reviewer x work type (n>=8)

### Provider at work type

| reviewer @ work | n | none | high | low | neg | none rate | high rate |
|---|---:|---:|---:|---:|---:|---:|---:|
| codex @ ai-devops | 194 | 190 | 4 | 0 | 0 | 98% | 2% |
| codex @ dflow | 85 | 83 | 0 | 0 | 2 | 98% | 0% |
| codex @ shared-db | 32 | 32 | 0 | 0 | 0 | 100% | 0% |
| codex @ oracle | 27 | 27 | 0 | 0 | 0 | 100% | 0% |
| muse @ shared-db | 25 | 17 | 8 | 0 | 0 | 68% | 32% |
| grok @ shared-db | 20 | 16 | 4 | 0 | 0 | 80% | 20% |
| qwen @ shared-db | 17 | 14 | 3 | 0 | 0 | 82% | 18% |
| grok @ ai-devops | 13 | 12 | 1 | 0 | 0 | 92% | 8% |
| deepseek @ shared-db | 9 | 3 | 6 | 0 | 0 | 33% | 67% |
| gemini @ ai-devops | 8 | 8 | 0 | 0 | 0 | 100% | 0% |


---

## 5. Other slices

### By repository / work type

| work | n | none | high | low | neg | none rate | high rate |
|---|---:|---:|---:|---:|---:|---:|---:|
| ai-devops | 239 | 228 | 11 | 0 | 0 | 95% | 5% |
| shared-db | 122 | 96 | 25 | 1 | 0 | 79% | 20% |
| dflow | 88 | 86 | 0 | 0 | 2 | 98% | 0% |
| oracle | 27 | 27 | 0 | 0 | 0 | 100% | 0% |


### By caller (wrapper)

| caller | n | none | high | low | neg | none rate | high rate |
|---|---:|---:|---:|---:|---:|---:|---:|
| codex | 384 | 372 | 9 | 1 | 2 | 97% | 2% |
| claude | 47 | 34 | 13 | 0 | 0 | 72% | 28% |
| unknown | 36 | 32 | 4 | 0 | 0 | 89% | 11% |
| mimo | 15 | 9 | 6 | 0 | 0 | 60% | 40% |
| zcode | 9 | 4 | 5 | 0 | 0 | 44% | 56% |


### By operation

| operation | n | none | high | low | neg | none rate | high rate |
|---|---:|---:|---:|---:|---:|---:|---:|
| invocation | 491 | 451 | 37 | 1 | 2 | 92% | 8% |


---

## 6. Safety-gate bucket (do not treat as waste)

| face level | n |
|---|---:|
| none | 2 |
| highest | 1 |

---

## 7. Decision brief — routing rule draft (options only)

1. **Skip-list (high waste):** ai-devops, shared-db, dflow, oracle — consider making review optional.
2. **Keep-list (reviews pay off):** (none at n>=10) — keep mandatory review.
3. **Reviewer mix:** keep routing high-stakes work to reviewers with high-rate findings; avoid relying on reviewers whose history is almost all no-ops for those paths.
4. **Safety gates unchanged.**
5. **Do not cut review on the 8% class** — the 37 real findings are exactly what review is for.

Nothing in this report changes policy by itself.

---

## Method notes

- Value labels come from Jev `Score` on stitched review arcs (dispatch/head -> verdict -> reaction), joined to `events.jsonl`.
- "None" means the model judged the review added nothing of value on that arc. Abstains and errors are excluded from rates.
- Small cells (n<5, or n<8 for the cross table) are suppressed.
- This is historical correlation, not a controlled experiment.
