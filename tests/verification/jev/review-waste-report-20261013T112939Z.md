# Review-waste report — large sweep (20261013T112939Z)

**Model pin:** `jev-1.13.0`  
**Host:** edge-dev (Windows)  
**Scale:** 250 files, 2938 chunks, filter jobs 570, interactions scored 49 (cap 400)  
**Method:** Jev Choice chunk filter -> event-head arc stitch -> Jev Score value level  
**Privacy:** aggregates only; no transcript text, no private identifiers, no archive paths  

## What this is

A much larger pass over the local AI session archive than the 12-file pilot.
Jev (cheap decision model) labels chunks and review interactions. A frontier
LLM is not used for this sweep. Safety-gate reviews are bucketed separately
and are not counted as discretionary waste.

## Results

- Files sampled: **250** (event-head joined first, then review-marked)
- Chunks seen: **2938** (no structural review signal skipped: 2368)
- Chunk filter labels: `{'abstain': 312, 'meta_discussion': 232, 'unrelated': 8, 'review_interaction': 18}`
- Marked chunks: **93**; stitched interactions (capped): **49**
- Buckets: `{'discretionary': 49}`
- Value face labels: `{'none': 41, 'discretionary:none': 41, 'abstain': 8, 'discretionary:abstain': 8}`
- Low/none/negative: **41**; highest/medium: **0**; abstain: **8**; error: **0**
- Jev usage this run: input=1,474,857 output=29,972 (~$0.06 @ $0.042/1M)
- Wall time: 29s

## Slices (n>=5 only)

| slice | n |
|---|---|
| provider:codex | 18 |
| provider:qwen | 11 |
| discretionary:none | 41 |

## Decision brief (options only — no policy change)

- In this sweep, low/none/negative face levels: **41**; highest/medium: **0**.
- Mandatory safety-gate interactions stay in their own bucket (not discretionary waste).
- Options: (a) act on slices that cluster in low/none; (b) keep safety-gate traffic unchanged;
  (c) expand holdout before any policy change; (d) stop here and treat this as the baseline.

## Contested / abstain

- Chunk-filter abstains: 312
- Value abstains: 8
- Negative-value rule: only when the arc shows pushback-with-evidence + withdraw, or a fix later reverted.
  Face level is kept otherwise (not forced to negative).

## Artifacts

- Pilot report: `review-waste-report-20261012T180833Z.md`
- This report: `review-waste-report-20261013T112939Z.md`
- Inventory: `review-waste-inventory-20261012T162801Z.md`
- Calibration: `review-waste-chunk-shadow-20261012T180611Z.md`, `review-waste-value-shadow-20261012T180611Z.md`
