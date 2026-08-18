# Mixed-provider reviewer check, 2026-08-18

## Result

Grok, Kimi, and GLM all returned usable verdicts in less than 15 minutes. None
failed from exhausted allowance, empty assistant output, service unavailability,
or turn exhaustion.

| Provider | Exact head | Elapsed | Verdict | Outcome |
|---|---:|---:|---|---|
| Grok 4.6 | `25e3096` | 257 seconds | APPROVE with one finding | Found stale installed Grok recovery guidance. Corrected in `4772407`. |
| Kimi K3 | `d082c8d` | 371 seconds including its sealed test run | APPROVE | No catastrophic provider failure. Kimi reports no token or cost data. |
| GLM 5.3 | `d082c8d` | 347 seconds | REJECT | Found a real race that could replace another review's evidence. Corrected in `c175770`. |
| GLM 5.3 recheck | `c175770` | 197 seconds | APPROVE | Confirmed the evidence-clobber blocker was fully fixed. |

The local scoreboard contains four normalized rows for these checks. Its report
was: 4 reviews, 4 usable verdicts, 1 substantive finding, 0 reviews over 15
minutes. Three rows are deliberately marked stale because later corrections
advanced the commit; the final GLM approval is exact for `c175770`.

## What the check changed

- The installed Grok skill now matches the wrapper: turn exhaustion triggers a
  smaller, fresh review, never an automatic turn-limit increase.
- Kimi now accepts the sealed packet options that its internal packet builder
  already used: `--base`, `--tests`, `--decision`, and `--assert-head`.
- Preflight always builds its packet in a disposable snapshot. It cannot replace
  or delete an in-flight review packet in an ordinary clone.

## Decision

The old 15-minute failure did not occur in this mixed-provider sample. The
reduced repair is safe to ship. This result does not justify a lower turn limit,
a new review front door, or automatic provider selection.
