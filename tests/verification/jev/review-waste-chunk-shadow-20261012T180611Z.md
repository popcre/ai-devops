# Review-waste chunk-filter shadow (20261012T180611Z)

**Model pin:** `jev-1.13.0` (live `GET`/`POST` echo confirmed)  
**Config:** `config/jev-decisions.json`  
**Cases:** `tests/fixtures/jev/` public/synthetic only  
**Usage totals (holdout+tune):** {'input_tokens': 15265, 'output_tokens': 1634}

## Holdout confusion (label → pred)

| label | pred | n |
|---|---|---|
| meta_discussion | meta_discussion | 2 |
| review_interaction | abstain | 5 |
| review_interaction | review_interaction | 1 |
| unrelated | abstain | 1 |
| unrelated | unrelated | 3 |

- Tuning split: n=20 decided=14 accuracy(decided)=1.00
- Holdout split: n=12 decided=6 accuracy(decided)=1.00

## Per-case public ids (holdout)

| id | label | pred | confidence | abstain |
|---|---|---|---|---|
| c021 | review_interaction | abstain | 0.7 | True |
| c022 | review_interaction | abstain | 0.64 | True |
| c023 | review_interaction | abstain | 0.19 | True |
| c024 | review_interaction | review_interaction | 0.79 | False |
| c025 | review_interaction | abstain | 0.19 | True |
| c026 | meta_discussion | meta_discussion | 0.98 | False |
| c027 | meta_discussion | meta_discussion | 0.97 | False |
| c028 | unrelated | unrelated | 0.77 | False |
| c029 | unrelated | abstain | 0.62 | True |
| c030 | unrelated | unrelated | 1.0 | False |
| c031 | review_interaction | abstain | 0.21 | True |
| c032 | unrelated | unrelated | 1.0 | False |

## Freeze

One tuning pass on synthetic labels. Wording and thresholds in config
are frozen for this run. Holdout above is from frozen settings.
No raw state text in this artifact.
