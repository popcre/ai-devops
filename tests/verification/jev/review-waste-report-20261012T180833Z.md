# Review-waste report (20261012T180833Z)

**Model pin:** `jev-1.13.0`  
**Host:** edge-dev (Windows)  
**Corpus:** local Dropbox transcript archive, bounded 12-file review-marked sample  
**Method:** Jev `Choice` chunk filter → event-head arc stitch → Jev `Score` value level  
**Privacy:** aggregates only; no transcript text, no private identifiers, no archive paths  

## Inventory recap (Phase 1)

- Session transcripts: 9,235 files / ~13.0 GB; review-marked ~72% of files, ~11.7 GB candidates
- Events spine: 13,055 rows / 2,839 unique heads / 6,662 run_ids (2026-09-07 → 2026-10-12)
- Head-join rate: ~32.5% of session files contain ≥1 event head SHA (lower bound)
- Frontier-read-all (review-marked): ~$2.3k–$8.8k vs Jev filter ~$34–$123 (see inventory artifact)

## Calibration (Phase 3/4, synthetic fixtures)

- Chunk filter holdout accuracy (decided): see chunk-shadow artifact (target 1.0 on decided)
- Value Score holdout accuracy (decided): see value-shadow artifact
- Frozen thresholds: chunk conf≥0.75, value conf≥0.7
- Negative-value rule: only when the arc shows pushback-with-evidence + withdraw, or fix later reverted; else face level (plan §8)

## Bounded real-archive shadow (this run)

- Files sampled: 12 (review-marked, 20KB–2MB)
- Chunks seen: 115
- Chunk filter labels: {'no_signal_skipped': 93, 'abstain': 18, 'meta_discussion': 4}
- Stitched interactions (capped 20): 3
- Buckets: {'discretionary': 3}
- Value labels (face): {'discretionary:none': 3, 'none': 3}
- Jev usage this run: input=53438 output=1176 (~$0.0022 @ $0.042/1M)

## Slices (n≥5 only)

| slice | n |
|---|---|
| (no slice reached n≥5 — suppressed) | |

## Decision brief (options only — no policy change)

- In this bounded sample, low/none/negative face levels: **3**; highest/medium: **0**; abstain: **0**.
- Mandatory safety-gate interactions are bucketed separately and are **not** discretionary waste (plan §6.7).
- Options for the owner (do not implement here): (a) date-slice a larger archive pass; (b) shrink discretionary sends that cluster in `low`/`none`; (c) keep safety-gate traffic unchanged; (d) expand holdout before any policy change.

## Contested / abstain cases

- Chunk-filter abstains: 18 (below threshold — not forced to a label)
- Value abstains: 0
- Negative-value cases in the real sample: see interactions table below; if the arc does not show pushback+withdraw or later-revert, the face level is kept (not forced to negative).

## Interactions (public ids only)

| head_prefix | provider | bucket | label |
|---|---|---|---|
| 42afce6c | codex | discretionary | none |
| 9b4e939f | codex | discretionary | none |
| f486cec5 | kimi | discretionary | none |

## Artifacts

- Inventory: `tests/verification/jev/review-waste-inventory-20261012T162801Z.md`
- Chunk shadow: `review-waste-chunk-shadow-20261012T180611Z.md`
- Value shadow: `review-waste-value-shadow-20261012T180611Z.md`
- This report: `review-waste-report-20261012T180833Z.md`
- Private work dir (delete or keep at owner decision): `C:\Users\ahazan\AppData\Local\Temp\jev-review-waste-work`
