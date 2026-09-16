# Grok investigate #513 — Windows evidence (2026-09-16)

Redacted. No credentials, transcripts, or raw live JSON.

## Landed

- Merge: `origin/main` `7f0f8f6c` (PR #517). Issue #513 closed.
- Command: `ai-grok-implement investigate`. Formal `ai-grok-review` unchanged.
- Pin: `config/provider-cli-versions.json` Grok `1.0.13`. Not upgraded.
- #249 broker: not implemented.

## Offline

- `tests/test-ai-grok-implement.sh`: 80 passed, 0 failed.
- `tests/test-ai-grok-review.sh`: 272 passed, 0 failed (investigate is not a review command; review still deny-Bash / disable-web-search).

## Live on edge-dev (Windows)

- `ai-grok-implement doctor`: binary present, version policy OK for exactly `1.0.13`, auth (models) OK.
- Paid `investigate` and paid `run --allow-shell` both returned `stopReason: cancelled` on turn 1 before any shell write. Primary checkout unchanged. Remote-less copy had no remotes.
- Treat that cancel as pin behavior on this host. Do not "fix" it by upgrading Grok, widening review, or building #249.

## Exact-head review

- Claude Opus 5 `final-check` APPROVE on `6a63f84e`, run `20260916T214612-2826818-29891`.
- Earlier REJECT heads `cdde073c` (POSIX Windows homes; copied auth) and `5d60ccb4` (HOME held auth; denylist not allowlist; unproven inode; docs overclaimed live HTTP) are superseded.

## Not done here

- Parent Step 0 multi-provider baseline directory.
- Ubuntu live canary.
- GLM #254, Kimi #255, Qwen #256, Muse #257.
