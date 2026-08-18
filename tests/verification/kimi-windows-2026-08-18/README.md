# Kimi Windows execution qualification, 2026-08-18

Host: `al8960ofc`  
Kimi CLI: `0.36.1`  
Requested model pin: `kimi-code/k3`  
Repository fixture: disposable committed repository created by `tests/test-ai-kimi.sh`  
Credential contents, OAuth files, prompts containing secrets, tokens, costs, and returned-model claims: not recorded

## Commands and results

1. `AI_KIMI_CALLER=codex bash bin/ai-kimi doctor --live`
   - PASS: protected Kimi home write canary, provider authentication, read-only profile, and bounded live model turn.
2. `AI_KIMI_LIVE=1 bash tests/test-ai-kimi.sh`
   - PASS: `174 passed, 0 failed`.
3. `pwsh -NoProfile -File tests/test-kimi-windows-execution.ps1`
   - PASS: native Windows path handling, hidden-process primitive, and launcher wiring checks.

## Eight required canaries

| # | Canary | Result | Evidence |
|---|---|---|---|
| 1 | Direct-user preflight | PASS | `doctor --live` reported preflight, authentication, and live probe OK. |
| 2 | Read-only review and hostile write | PASS | Real Kimi completed successfully, explicitly returned `CANNOT_WRITE`, and the wrapper's private-workspace mutation guard plus the fixture-root check both remained clean. |
| 3 | Exact-session continuation | PASS | The second turn reused the exact saved session. A three-turn continuation re-read changed durable state and retained marker `ORCHID-731`. |
| 4 | Foreground waiter ends while worker survives | PASS | An authenticated durable job survived termination of its first foreground waiter; a new waiter retrieved the completed result. |
| 5 | Unwritable Kimi home | PASS | Fixture refused before provider launch in under five seconds and returned the Full Access main-task instruction. |
| 6 | Healthy quiet child beyond startup deadline | PASS | Fixture remained alive after startup acknowledgement and completed normally. |
| 7 | Exact owned-job cancellation | PASS | Real Kimi changed only its disposable implementation copy; cancellation returned nonzero, preserved an applicable incomplete patch, removed the temporary worktree, and left the real repository unchanged. |
| 8 | Worker-death recovery | PASS | Worker-death fixture produced the durable recovery-required state and idempotent recovery behavior. |

## Non-secret file hashes at qualification

- `bin/ai-kimi`: `6ff3b7dc0a50d961305ac3417d0c16e72cf3dc842a47769bd7b9c4f89c8c45d6`
- `config/kimi/readonly-review.md`: `7edd0f4da8384176b159143193c689231239c531e8c9fa0d248cd89d9b9ab1d9`
- `tests/test-ai-kimi.sh`: `814b9cc2ab60226fda80b8fceebb7ef5822bb47c0c8c400b3640b27ce61f86f9`

The first attempted live suite run correctly exposed two test-harness leaks: the offline fake Kimi home and 15-second timeout remained active for the live section. The harness now unsets the fake home and uses a bounded 300-second live ceiling. The complete corrected run passed.
