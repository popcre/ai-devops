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
nonzero. Raw paid responses are retained by the preceding #405 repair. The
integrated #393 whole-source check owns this refusal, retaining the observed
head/source, null verdict, packet identity and fixed governed mode/head.

The wrapper also initializes its session identifier rather than inheriting an
ambient `ID` variable, keeping a live doctor out of session storage.

## Verification

- Working baseline: `b6922ea8e2de` plus prerequisite #405 patch `fb0d847a1bc1`.
- Host: Windows, Git Bash 5.3.15, Python 3.13.15.
- Command: `bash tests/test-ai-deepseek-agent.sh` through Git Bash.
- Initial terminal result: **104 passed, 0 failed, 0 skipped**.
- Integrated with #393 dependency `7e833788afab` on September 11, 2026:
  **118 passed, 0 failed, 0 skipped**.
- Cases cover both flag forms, duplicate/missing/wrong heads, explicit formal
  mode, terminal grammar, extra/fenced/trailing decisions, persisted mode,
  ordinary continuation, genuine BLOCKED continuation, ambient ID, and moved
  head with retained transcript/stale metadata.
- Wrapper SHA-256:
  `1bdacc3387870a6613575fa096f3257ffc55200f91d3e9e59e370f69a5b92009`.
- Suite SHA-256:
  `53a09b08673645901d792c8084afe550a8235e57b3b6c9f21d017a38a7d78ea3`.
- `git diff --check` passed.

Independent exact-head review, required CI, merged identity, installation, live
consumer proof, and private incident reconciliation remain delivery gates.
This evidence does not close all of #394 or the parent programme.
