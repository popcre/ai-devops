# Review-waste value-level shadow (20261012T180611Z)

**Model pin:** `jev-1.13.0` (live `GET`/`POST` echo confirmed)  
**Config:** `config/jev-decisions.json`  
**Cases:** `tests/fixtures/jev/` public/synthetic only  
**Usage totals (holdout+tune):** {'input_tokens': 15537, 'output_tokens': 576}

## Holdout confusion (label → pred)

| label | pred | n |
|---|---|---|
| highest | abstain | 1 |
| highest | highest | 1 |
| low | low | 2 |
| medium | medium | 2 |
| negative | negative | 3 |
| none | none | 3 |

- Tuning split: n=20 decided=17 accuracy(decided)=0.94
- Holdout split: n=12 decided=11 accuracy(decided)=1.00

## Per-case public ids (holdout)

| id | label | pred | confidence | abstain |
|---|---|---|---|---|
| v021 | highest | highest | 0.88 | False |
| v022 | medium | medium | 0.75 | False |
| v023 | low | low | 0.73 | False |
| v024 | none | none | 1.0 | False |
| v025 | negative | negative | 1.0 | False |
| v026 | negative | negative | 0.99 | False |
| v027 | none | none | 1.0 | False |
| v028 | highest | abstain | 0.36 | True |
| v029 | medium | medium | 0.93 | False |
| v030 | low | low | 0.93 | False |
| v031 | none | none | 1.0 | False |
| v032 | negative | negative | 0.99 | False |

## Freeze

One tuning pass on synthetic labels. Wording and thresholds in config
are frozen for this run. Holdout above is from frozen settings.
No raw state text in this artifact.
