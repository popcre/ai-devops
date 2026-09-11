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

## Merged and installed checkpoint — 2026-09-11

PR #410 merged as `d8e7450d9d886742ec7f653c268b197fda028dc4` after
independent Grok APPROVE on `ac6a1c34e3bdce8ed724f02a9602dd6d762c3f71`
against `bb493afc3e53930a688474e9f79f872a6fd04c93`. Retained review SHA256:
`e4823f8bc69229cdc61362a43e85d3ae20c1ac5f578df60f2407caa53539a737`.
Final local sandbox coverage passed 85 checks, captured-ref coverage passed nine,
and the Qwen crash-readiness reproduction passed 16, with no failures.

PR run `34572992566` passed Linux and all four Windows sections. Its identical
hosted safety suite passed Codex 49/0, authentication publication 7/0/0 and Grok
226/0/0. The original safety job reached its 30-minute limit with passing
assertions and was cancelled; its cancellation was not treated as success.
The qualified hosted result supplied complete equivalent evidence under merged
PR #411. Exact landing run `34577200959` passed, including queue evidence and
Linux verification.

The clean canonical checkout was fast-forwarded under the installation lock,
with no active local runner worker. Installed launchers resolve to that checkout.
The installed packet resolver, invoked in an actual isolated worktree, returned
the asserted head `ac8ab53fb817fa02c8ff75fd6355136bfc591b4c`, target and merge
base `7414afefd6cf841609df7c42429638403780406c`; explicit assertions passed.

| Installed file | SHA256 |
|---|---|
| `ai-claude-review` | `70a001c729acc564a96431496fcf3af1102701be0b06a8d9a94e7376ebe313d7` |
| `ai-codex-review` | `5f2196c59e0a11faa3d59d22070a7cf737f3e762b6c64875de3b42dff57a1165` |
| `ai-deepseek-agent` | `d18773e494505222c4712eca6d2f187a47d701c6ef77e32cc427ffbb3c14e957` |
| `ai-gemini` | `90d7db6797fd96dcc1e117d513227f59a359994554ee8485f9d52a661c2f99a8` |
| `ai-glm` | `00be68f77704d6ae63b6e50a51b46133863ae119656a5cad80085049a590eb37` |
| `ai-grok-review` | `f9a13e1d170c6c4e84fb4770972307a9aa3626763b387bd4ddd7234326a96e29` |
| `ai-kimi` | `adb0cfc1a7dc1492fe09ab78a0ded324315faef214c8d7f27d4d021b4a010653` |
| `ai-muse` | `ce34d2b825214d1dd319babac8cbe4f82d2cb50741f3a477dde11091a4f02187` |
| `ai-qwen` | `bdc6dec4f6cc3bb4be6f91f69b67b520638320fbdcc6e2f8569a3c8f3d4c20b6` |
| `ai-review-packet` | `69b78a4144b5b102c67edc0d08a087680a6996bde2bd7ebb4b9b1f32744bc31b` |
| `ai-review-sandbox` | `306e2f2d003901ed9e8154fa0b73761fe507abab31a4dfd2cb39d2bc6bc3cbb4` |

The governed live comparison and affected private incident reconciliation remain
pending. PR #344 remains open until that acceptance is complete. This checkpoint
does not close #393, #337 or #159, reset the 198-record round, or advance #398/#166.
