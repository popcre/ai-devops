# Grok 4.6 five-review failure-rate trial

Date: 2026-08-18

Purpose: determine whether the former 15-minute/no-verdict Grok failure still
occurs before continuing the reviewer-system repair.

All five runs used `ai-grok-review`, Grok 4.6, unchanged read-only permissions,
the evidence packet, and the existing 20-turn / 15-minute ceiling. Each reviewed
a real, already-pushed small commit in a clean disposable worktree.

| Run | Commit | Change | Wall time | Turns | Tokens | Cost | Result |
|---|---|---|---:|---:|---:|---:|---|
| 1 | `eea2094` | one-file documentation router | about 2m23s | 6 | 321,629 | $0.05060594 | usable APPROVE |
| 2 | `ef4ec47` | 116-line documentation addition | about 3m01s | 6 | 317,891 | $0.06733938 | usable APPROVE |
| 3 | `971cf32` | three-file memory synchronization | about 1m43s | 7 | 319,951 | $0.04684282 | usable REJECT |
| 4 | `7ec0d01` | one-line Windows setup correction | about 1m51s | 7 | 291,572 | $0.04282776 | usable APPROVE |
| 5 | `33f7f9f` | three-file memory synchronization | about 1m44s | 6 | 262,617 | $0.05298594 | usable APPROVE |

Totals: 32 turns, 1,513,660 tokens, $0.26060184. Mean: 6.4 turns and
about 2m08s. Slowest: about 3m01s. Usable-verdict rate: 5/5.
Fifteen-minute failures: 0/5. No-verdict failures: 0/5.

Conclusion: the former catastrophic failure did not reproduce in the current
Grok-small-review slice. This does not prove that the old Kimi allowance failure
or GLM empty-response failure is gone. Do not lower the ordinary Grok limit to
6 turns: two healthy reviews needed 7 turns, and the earlier A/B needed 8.

Run 3 also found a substantive stale-memory overwrite in commit `971cf32`.
That quality finding is separate from this timing trial.
