# Kimi reviewer failure reconciliation — 2026-08-19

Issue: [#46](https://github.com/u2giants/ai-devops/issues/46)

This document reconciles the original local reviewer-issue narratives with the
surviving wrapper-owned `job.json` records on `edge-dev`. The original evidence
packages remain unchanged under `.ai/reviewer-issues/`.

## Proven failure matrix

Re-derived 2026-08-20 from the exact job records named below. Paths are included
only as machine-local evidence locations; no prompt, private source, OAuth data,
or provider log content is copied here.

| Sequence | Exit | Terminal reason | Provider seconds | Output bytes | Evidence suffix under `~/.local/state/ai-devops/kimi/jobs/` |
|---|---:|---|---:|---:|---|
| 214 | 1 | `usage-limit` | 468 | 203640 | `287d26eaa827/claude--seq214-1249-licensing-read/job.json` |
| 216 | 127 | `failed` | 6 | 0 | `de5caa2ff97d/claude--seq216-1140-fr-redesign/job.json` |
| 218 | 1 | `usage-limit` | 6 | 0 | `596396a708ee/claude--seq218-1140-fr-delta/job.json` |
| 220 | 1 | `usage-limit` | 6 | 0 | `97e9ef829b4a/claude--seq220-1249-neighbour-guards/job.json` |
| 222 | 1 | `usage-limit` | 6 | 0 | `039d78ebe841/claude--seq222-1249-drop-coverage/job.json` |
| 224 | 1 | `usage-limit` | 7 | 0 | `7b6f6e29b6cc/claude--seq224-1261-ci-psql/job.json` |
| 228 | 1 | `usage-limit` | 6 | 0 | `fcd7cf218608/claude--seq228-1216-sesame/job.json` |
| 230 | 1 | `usage-limit` | 7 | 0 | `0ca6a76da271/claude--seq230-1216-sesame-delta/job.json` |
| 232 | 1 | `usage-limit` | 6 | 0 | `6c05ceccad97/claude--seq232-1216-sesame-r3/job.json` |
| 234 | 1 | `usage-limit` | 6 | 0 | `3dea5a086aec/claude--seq234-prod3/job.json` |

Result: nine explicit usage-limit failures and one unexplained exit 127. The
original narrative's claim that sequences 216–234 were all exit 127 is false.

## Fixed historical wrapper defects

Commit `f65cc77315e4b119d918ae3a4fb12f463f04c430` fixed two defects:

- findings above `## Verdict` were discarded by tail extraction;
- missing answer/verdict output could exit as success.

Sequence 202's surviving raw stream contains its complete findings and
`VERDICT: REVISE`; it does not prove current extraction loss.

## Active wrapper defects owned by issue #46

- `.ai/reviews/` directory rules are tested against the directory rather than
  the exact output file, producing false unsafe-folder warnings.
- the durable worker and foreground result path both write reports;
- failed partial review output has no readable fail-closed artifact;
- typed terminal reasons collapse into a generic resume-hint message;
- repository-only reports can disappear with caller-created temporary copies;
- exit 127 records insufficient safe diagnostic evidence to name the internal
  failing child.

## Provider/account failures

The nine usage-limit records are Kimi account failures. The wrapper must report,
preserve, and quarantine them correctly, but code cannot replenish allowance.

## Unproven claims

Sequence 216 emitted Kimi's version metadata and then exited 127 without stderr.
The top-level Kimi executable therefore started. “Command not found” may describe
an internal child but is not proven and must not be presented as root cause.

## Reproduction artifacts

Redacted fixtures live under `tests/fixtures/ai-kimi-review-failures/`. Run the
focused suite documented in `plan_kimi-review-failure-recovery.md` to reproduce
the wrapper behaviors without Kimi credentials or private source.
