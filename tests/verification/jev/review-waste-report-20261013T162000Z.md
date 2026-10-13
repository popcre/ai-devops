# Review-waste report — full archive, events-joined (20261013T162000Z)

**Model pin:** `jev-1.13.0`  
**Host:** edge-dev (Windows)  
**Scale:** every session transcript (9,104 files) scanned for all 2,889 reviewer-event heads; 2,290 heads present in the archive and scored  
**Method:** events-spine join (paid reviews only) -> Jev Score on the five-level value scale  
**Privacy:** aggregates only; no transcript text, no private identifiers, no archive paths  

## What this is

Every review that was actually sent to a reviewer (reviewer events log) and
appears in the local AI session archive is scored for value. No sampling of
the paid-review population. Safety-gate reviews are bucketed separately and
are not counted as discretionary waste.

## Results

- Event heads in log: **2,889**
- Heads found in the archive: **2,290**
- Decided value labels: **654**
- Abstain (uncertain): **566**
- Error (rate/size, retried): **1070**
- Buckets: `{'discretionary': 2270, 'mandatory_safety_gate': 20}`

| face level | n | share of decided |
|---|---|---|
| none (added nothing) | 604 | 92.4% |
| highest (problem + useful fix) | 44 | 6.7% |
| medium (problem, no fix) | 3 | 0.5% |
| low (style only) | 1 | 0.2% |
| negative (wrong finding) | 2 | 0.3% |

- Low/none/negative: **607**
- Highest/medium: **47**
- Jev usage this pass: input=30,537,882 output=21,960 (~$1.28 @ $0.042/1M)

## Slices (n>=5, decided only)

| slice | n |
|---|---|
| provider:claude | 23 |
| provider:codex | 379 |
| provider:deepseek | 26 |
| provider:gemini | 28 |
| provider:glm | 19 |
| provider:grok | 65 |
| provider:kimi | 7 |
| provider:muse | 74 |
| provider:qwen | 30 |
| claude:none | 18 |
| codex:none | 372 |
| deepseek:highest | 8 |
| deepseek:none | 18 |
| gemini:none | 25 |
| glm:none | 16 |
| grok:highest | 8 |
| grok:none | 57 |
| kimi:none | 7 |
| muse:highest | 11 |
| muse:none | 63 |
| qwen:none | 26 |

### Provider x none (the waste signal)

| provider | none | decided | none rate |
|---|---|---|---|
| codex | 372 | 379 | 98% |
| muse | 63 | 74 | 85% |
| grok | 57 | 65 | 88% |
| qwen | 26 | 30 | 87% |
| gemini | 25 | 28 | 89% |
| deepseek | 18 | 26 | 69% |
| claude | 18 | 23 | 78% |
| glm | 16 | 19 | 84% |
| kimi | 7 | 7 | 100% |

## Decision brief (options only — no policy change)

Across every paid review found in the archive, **604 of 654 decided
interactions (92%) added nothing useful**. Only
**47** named a real problem with or without a fix. Negative findings were rare (2).

Options for the owner (do not implement here):
1. Treat discretionary review traffic that sits in the `none` pile as candidates to cut or shrink.
2. Leave slices with real findings unchanged (review quality on high-value traffic must not drop).
3. Keep mandatory safety-gate reviews as assurance, not waste (separate bucket).
4. Use this as the durable baseline; re-run later to measure change.

## Contested / abstain

- Value abstains: **566** (kept at face level, not forced)
- Value errors after retries: **1070** (not scored; not counted as waste)
- Negative requires arc evidence of pushback+withdraw or later-revert; else face level kept.

## Artifacts

- This report: `review-waste-report-20261013T162000Z.md`
- Prior sample: `review-waste-report-20261013T112939Z.md`
- Pilot: `review-waste-report-20261012T180833Z.md`
- Inventory: `review-waste-inventory-20261012T162801Z.md`
- Calibration: `review-waste-chunk-shadow-20261012T180611Z.md`, `review-waste-value-shadow-20261012T180611Z.md`
