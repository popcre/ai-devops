# Provider core repair verification

Verified against starting head `a784cae90758a8e3279ef1a1d7b62c400d13b4fb` on 2026-08-22 UTC.

## Completed checks

- `tests/test-ai-codex-review.sh`: 22 passed, 0 failed.
- `tests/test-ai-qwen.sh`: 37 passed, 0 failed.
- `tests/test-ai-glm.sh`: 236 passed, 0 failed.
- `tests/test-ai-grok-implement.sh`: 29 passed, 0 failed.
- `tests/test-ai-kimi.sh`: 173 passed, 0 failed.
- `tests/test-ai-review-sandbox.sh`: 63 passed, 0 failed.
- `tests/test-ai-review-preflight.sh`: 26 passed, 0 failed.
- `git diff --check`: passed.

## Behaviors proved

- Codex reviews receive a complete disposable source snapshot, run with an
  explicit read-only sandbox and allowed reasoning level, detect attempted
  writes or stale source, require an exact verdict, and publish an atomic
  lifecycle-accounted report.
- Qwen review evidence is sealed to an exact source digest and continuation is
  rejected before any provider call after dirty, untracked, commit, or legacy
  evidence drift.
- GLM `server start` and `server restart` do not report success until health is
  actually ready; delayed readiness, launch failure, and bounded timeout paths
  are covered on Linux and Windows fixtures.
- Linux CI portability fixes are covered for Grok, Kimi, GLM, and the shared
  review-snapshot integration test.

Provider-neutral lifecycle wiring and bounded live qualification remain owned
by the next plan gate; these results do not claim those gates are complete.
