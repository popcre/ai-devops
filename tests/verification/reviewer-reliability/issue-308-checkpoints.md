# Reviewer log repair checkpoint verification

Owner: [issue #308](https://github.com/popcre/ai-devops/issues/308).
Verified on EDGE-DEV, 2026-09-08. This is installation and controlled-fixture
evidence; it does not clear the real reviewer backlog or claim fleet-wide coverage.

## Merged source and independent review

- Implementation: [PR #314](https://github.com/popcre/ai-devops/pull/314), merged as
  `f1facf60189670b43e07b95399a769eedb493cf1`, verified on fetched `origin/main`.
- Reviewed head: `ee7e7d6b0a9243ca2059d6eeaef5f0465960935f`.
- Read-only Claude Opus 5 final review: APPROVE, exit 0, run
  `20260908T002346-1121838-27696`.
- Reviewed source digest:
  `8177ce2c4f1f70ed1857681d10a6e0c178e5cc1328140997c21d3eab39237985`.
- The final review checked canonical source keys, complete Qwen parser fixtures,
  strict joins, link refusal, and recorder credential isolation. The merged
  runtime, tests, and affected shared skill match that reviewed head; intervening
  main changes were unrelated documentation.

## Tests and repairs proved

[PR CI run 34173126280](https://github.com/popcre/ai-devops/actions/runs/34173126280)
passed all three suites:

- Linux offline: 65 Bash suites, zero failures.
- Windows offline: 65 Bash suites and 18 PowerShell suites, zero failures.
- Windows reviewer safety: 41 lifecycle and 214 isolation assertions passed,
  zero failures and zero skips.

The incident/checkpoint suite passed 117 cases with zero failures and one skip on
each CI platform. Qwen passed all 104 cases on both. Local incident/checkpoint
verification passed 114 cases with zero failures and four platform skips; the
full local Qwen suite passed 104 cases with zero failures.

The exact merge commit passed the Linux merge-queue check in
[run 34178027688](https://github.com/popcre/ai-devops/actions/runs/34178027688).
Windows jobs were skipped there under the existing queue policy; no duplicate
post-merge suite was run.

Earlier runs exposed sourced-library handling, eager Windows home lookup, and
crash-fixture worker ownership assumptions. Those were repaired without weakening
safety assertions. Full Windows CI then exposed short-path/long-path identity
differences. Production normalization now follows explicit link refusal; two
remaining fixture keys were corrected afterward. A native short-TEMP reproducer
first recreated both fixture failures, then passed 57 cases with zero failures
and four platform skips. The extracted Qwen parser gained its required dependency
and two additional provider-refusal assertions. Cancelled or superseded runs are
not counted as passes, and no CI timeout was increased.

## Installed behavior

The canonical checkout was clean and active local reviewer launches were allowed
to finish before installation. A protected private backup preceded the documented
`ai-install-skills --keep-orphans` installation. Its preview found no local edits;
global adoption was not requested or performed.

All ten affected entry points route to canonical source, including GLM's existing
catalogued Windows CMD entry point. The three helpers match the reviewed Git
blobs, accounting for normal Windows checkout line endings. Both installed copies
of the shared skill match source. Twenty-five original incident records, three
machine-configuration files, and persistent User PATH are unchanged.

Gemini passed official live qualification, including exact resumption, mutation
refusal, unchanged outside sentinel, and durable reports. Qwen passed the unchanged
official qualifier in a monitored 234.3-second run using the supported,
invocation-only `AI_REVIEW_PREFLIGHT_TIMEOUT=300` allowance. Its real qualification
record matched the installed wrapper/runtime/preloader identities; full-file
manifests before and after showed no runtime changes. No production stamp was manually
created, restored, or promoted.

## Controlled two-round proof

The actual installed commands ran against a unique private fixture. Each round
received one intentional Grok invalid-operation refusal before any provider call.
The first event was recorded as a synthetic incident and resolved with merged
source and test/review/install evidence. The second event was explicitly
classified with evidence. Both rounds completed successfully.

The retained proof asserts all of the following:

- Each round contains exactly its one new candidate.
- The second round's lower boundary equals the first completed upper boundary.
- The old candidate is excluded and the appended event is detected.
- The completed records form the correct parent chain, with no active round or
  remaining fixture blocker.
- The original fixture incident and its entire original evidence package remain
  byte-identical; only append-only resolution/completion records were added.

The first fixture's legacy audit records that its directory began empty. That is
not a legacy audit of the real machine backlog. All private records remain local;
no incident archive or `resolved.md` was created.

## Explicit operational limits and closure audit

All nine registered wrappers have durable invocation recording. The scoreboard
remains a cross-check; interrupted invocations remain visible, and missing,
replaced, truncated, malformed, or ambiguous history blocks advancement. A first
real maintenance round still needs a private legacy audit because overwritten
pre-installation metadata cannot be recovered.

The separate Qwen fast-check limitation remains open in
[issue #322](https://github.com/popcre/ai-devops/issues/322). Two qualification
attempts failed generic post-write validation, including one with a larger
allowance. Independent passive doctors passed in 95–153 seconds, exceeding the
unchanged ten-second default; that timing is a measured limitation, not a complete
explanation of every failed attempt. The later monitored qualification passed.
Its incident is explicitly **partially resolved**, with the exact installed
commit, live evidence, and remaining work attached. No global timeout or default
reviewer check was changed, and no default-Qwen-fast-check pass is claimed here.

The checkpoint implementation, installation, and controlled proof are complete.
The predecessor planning commit `15d696cdf5b3c90e1d1b9df9dd52dddffba5ffab` is on
main; its obligations are fulfilled, and its decisions and rejected approaches
remain in the plan. The matching checkpoint handoff is retired with this report.
