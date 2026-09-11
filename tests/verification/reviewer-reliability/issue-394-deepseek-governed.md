# #394 DeepSeek explicit governed terminal mode

This terminal-only slice adds `--governed-verdict SHA` and
`--governed-verdict=SHA` alongside `--review`. Ordinary conversations retain
their existing output and continuation behavior. This does not re-enable any
retired consumer or replace #393 source-identity receipts.

## Contract and proof

Read-only inspection of the governed consumer at live upstream
`a671cd47aaf7608c07a9db31822d3c708fda85b3` confirmed that it requires one final
`VERDICT: APPROVE|REVISE|REJECT <exact-head>` line and rejects additional decision
lines. Ordinary DeepSeek `## Verdict` output does not satisfy that contract.

Governed mode validates every supplied head before provider contact, keeps its
mode/head in session metadata, and rejects silent mode changes. Its new-session
identifier goes to stderr so stdout contains only review text. A genuine BLOCKED
review is saved as BLOCKED, returns nonzero without authorizing stdout, and can
be continued explicitly in the same mode when evidence becomes available.

The post-provider head check runs after the paid transcript and attachment
record are durable. A moved head publishes `source_changed` metadata and returns
nonzero. Raw paid responses are retained by the preceding #405 repair. #393's
richer whole-source checks must retain that ordering during integration.

The wrapper also initializes its session identifier rather than inheriting an
ambient `ID` variable, keeping a live doctor out of session storage.

## Verification

- Working baseline: `b6922ea8e2de` plus prerequisite #405 patch `fb0d847a1bc1`.
- Host: Windows, Git Bash 5.3.15, Python 3.13.15.
- Command: `bash tests/test-ai-deepseek-agent.sh` through Git Bash.
- Final result on September 11, 2026: **104 passed, 0 failed, 0 skipped**.
- Cases cover both flag forms, duplicate/missing/wrong heads, explicit formal
  mode, terminal grammar, extra/fenced/trailing decisions, persisted mode,
  ordinary continuation, genuine BLOCKED continuation, ambient ID, and moved
  head with retained transcript/stale metadata.
- Wrapper SHA-256:
  `65eee07d553ab0a6a0f26d8e4e092fe904793d15e4465e9f7d31f652c2ce120e`.
- Suite SHA-256:
  `58a0e9a43d95208f53b546609103b47228ba4b2c403871e0d63ef137fe0179e9`.
- `git diff --check` passed.

Independent exact-head review, required CI, merged identity, installation, live
consumer proof, and private incident reconciliation remain delivery gates.
This evidence does not close all of #394 or the parent programme.
