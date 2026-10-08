# StepFun review cost — measured findings (2026-10-07/08)

Related: [issue #1336](https://github.com/popcre/ai-devops/issues/1336),
[PR #1422](https://github.com/popcre/ai-devops/pull/1422),
[PR #1482](https://github.com/popcre/ai-devops/pull/1482),
[plan_stepfun-harness-efficiency.md](../plan_stepfun-harness-efficiency.md).

## How it was measured

A local recording proxy sat between the review door and `api.stepfun.ai`
(`AI_STEPFUN_BASE_URL=http://127.0.0.1:<port>/v1`). It forwarded every request
unchanged and logged the message count and the `usage` block of each response.
Every run reviewed the same change, `0f501234..05f35dd8`, through
`ai-review stepfun diff-review` (the StepCode review door on Linux).

To repeat it:

- Route through the **review door** (`ai-review`). `ai-stepfun review` uses
  StepCode's built-in model entry, which refuses a non-StepFun base URL
  ("No models available").
- `ai-review` returns a cached pass for an already-reviewed head; add
  `--additional-reviewer` to force a fresh run.
- Set `TMPDIR` to a roomy disk. A full `/tmp` makes the door fail with
  "could not copy the review workdir".
- Run one review at a time. Two at once trip the per-minute cap (below).
- It costs real credit: about 2–6M input tokens per review. Nine test reviews
  exhausted the account once.

## What StepFun does

- **Automatic prefix caching works and is reported.** Responses carry
  `usage.prompt_tokens_details.cached_tokens`; identical leading text is
  reused across calls without any cache key.
- **The harness keeps the prefix stable.** In every recorded run, each call's
  history was an exact extension of the previous call's; 93–97% of input
  tokens were billed as cached.
- **The rate limit is tokens per minute, not only requests.** 429 bodies read
  `request limited TPM reached, current: 559755, limit: 500000`. Cached tokens
  count toward it. A late review step resends about 60–100k tokens, so roughly
  five fast steps a minute hit the cap. The shared request pacer (#1432)
  limits requests per minute and does not prevent this.

## Where the tokens go

A review is a long loop of small steps, usually one tool call each. Every step
resends the whole conversation: about 16k tokens of fixed instructions and
tool descriptions plus everything read so far. Input per review is roughly
steps × average context, so the step count dominates.

## Results (same review each time)

| Run | Door version | Calls | 429s | Input tokens | Uncached | Outcome |
|---|---|---|---|---|---|---|
| base1 | before #1482 | 61 | 2 | 3.79M | 114k | APPROVE |
| base2 | before #1482 (ran alongside fewer1) | 106 | 17 | 5.05M | 323k | failed: TPM cap |
| base3 | before #1482 | 112 | 12 | 6.49M | 296k | failed: TPM cap |
| fewer1 | batched-steps prompt | 36 | 6 | 1.95M | 222k | APPROVE |
| fewer2 | batched-steps prompt | 61 | 6 | 4.20M | 230k | APPROVE |
| fewer3 | batched-steps prompt | 60 | 20 | 2.04M | 177k | failed: TPM cap |
| final | merged #1482 (prompt + in-place resume) | 47 | 0 | 3.44M | 241k | APPROVE |

Identical runs vary widely (36 to 112 calls), so one run proves little.
Completed batched runs averaged lower, but the clearest loss was failure:
three of six pre-merge runs died on the TPM cap and threw away every token
they had spent.

## The waste that was fixed

1. **Cold restart on rate limit (#1482).** When a 429 outlasted StepCode's own
   retry, the door killed the session and reran the review from the first
   message, buying every earlier step again. The door now sends a `followUp`
   prompt into the same live RPC conversation after the shared cooldown
   (`AI_STEPFUN_RATE_RESUMES`, default 6). Live proof: after seven 429s the
   review continued at message 16 with a warm cache. The whole-turn rerun
   remains the fallback. A plain (non-`followUp`) prompt fails with "Agent is
   already processing", because StepCode may already be retrying itself.
2. **Batched steps (#1482).** The packet preamble asks Step 5 to request
   several files or commands in one step and to read whole files, not slices.
3. **False doctor failure (#1422).** The door wraps the health probe in review
   framing, so Step 5 answered with a short review instead of `STEPFUN-OK`;
   doctor now accepts any report with a Verdict section after exit 0.

## Not done

- The fixed ~16k-token instruction and tool block rides on every step. It is
  cached, but it counts toward the TPM cap. Trimming the tool list is the next
  lever.
- Pacing by tokens per minute, not just requests, would avoid the cap.
- Persistent sessions across reviews stay rejected (cross-review leakage; see
  the plan's Phase 4).
