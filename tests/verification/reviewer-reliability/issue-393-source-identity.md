# #393: exact source identity through every reviewer

Owner: reviewer source identity under #337 and #159. This record extends the
existing reviewer verification directory; it is not another review harness.

## Cause and change

PR #344 was inspected before work. Its namespace-preserving source-base repair
is useful, but its exact head has failed Grok concurrency CI. PR #402 landed
the narrower source-base groundwork as
`b6922ea8e2de41726c6cd55958555921cc4a6629`; neither PR alone carries the
requested repository/base/head identity through all nine wrappers.

The packet tool now resolves the original repository before snapshot creation,
retains local and remote ref namespaces, and validates source, target, merge
base, complete snapshot bytes, and complete split diff before provider contact.
Every reviewer binds that identity and checks it again after the paid response.
A changed target cannot turn an otherwise valid old response into a current
approval. Paid output remains recoverable.

DeepSeek receives the complete manifest, full diff and untracked source as
attachments. UTF-8 and binary bytes have explicit encodings and hashes. Message
bodies travel through a framed pipe, including inputs above Windows argument
limits. A retained packet and conversation survive stale-source rejection;
ordinary fresh continuation remains available.

An immutable receipt may be published only directly inside the original
repository's ignored `.ai/reviews` directory. A receipt records validated source
and packet identity; it is not a verdict. The governed consumer separately
checks the live PR target and head before accepting a successful review.

## Verification and acceptance

Focused source fixtures cover stale local main, non-main targets, explicit
base/head refusal, altered or incomplete packet evidence, target movement,
receipt destination/overwrite refusal, and retained paid output. DeepSeek's
earlier full focused run passed 83 checks; its final changed source cases passed
24 with no failures or skips. The Muse target-movement probe passed its two
behavioral checks and 42 setup/structural checks. The Codex target-movement probe
proved rejection and paid-report retention.

The Kimi full focused run had 218 passes and one diagnostic-precedence failure:
the source check masked an already proven read-only violation. Preserving that
earlier safety reason passed the isolated reproduction (15 checks, no failures).
The source-prefix preservation probe passed 10 checks with no failures. Required
CI will check the final combined tree rather than treating earlier local counts
as exact-head evidence.

The first independent GLM review identified a remaining packet exclusion that
hid legitimate `.ai-review-notes/` source. The corrected packet ignores only its
exact generated directory and no longer filters source names by prefix. The full
packet run passed 110 checks with one new assertion aimed at the wrong inventory
location; correcting that assertion to the manifest passed all 58 focused checks,
including snapshot/build/live verification of the legitimate source directory.
The Kimi precedence assertion is now committed, and Muse/Gemini help exposes the
source flags. These changes require a fresh exact-head independent review.

Final exact-head independent review, required CI, merge, installed hashes and a live
governed comparison are still pending. This artifact does not close #393.
